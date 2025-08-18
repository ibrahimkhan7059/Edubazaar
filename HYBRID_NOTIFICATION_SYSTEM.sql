-- ================================================
-- HYBRID NOTIFICATION SYSTEM
-- ================================================
-- Uses both local notifications + prepares for FCM v1

-- Update trigger to support both local and push notifications
DROP TRIGGER IF EXISTS notify_chat_trigger ON messages;
DROP FUNCTION IF EXISTS notify_chat_on_message() CASCADE;

CREATE OR REPLACE FUNCTION notify_chat_on_message() RETURNS TRIGGER AS $$
DECLARE
    recipient_id uuid;
    sender_profile jsonb;
    message_content text;
    notification_title text;
    notification_body text;
    fcm_tokens_array jsonb;
    token_count integer;
BEGIN
    -- Extract message content
    BEGIN
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'message_text') THEN
            message_content := NEW.message_text;
        ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'content') THEN
            message_content := NEW.content;
        ELSE
            message_content := 'New message';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        message_content := 'New message';
    END;

    -- Get recipient ID
    BEGIN
        SELECT 
            CASE 
                WHEN participant_1_id = NEW.sender_id THEN participant_2_id
                ELSE participant_1_id
            END INTO recipient_id
        FROM conversations 
        WHERE id = NEW.conversation_id;
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO logs (event_type, error, details) 
        VALUES ('notification_error', 'Failed to get recipient: ' || SQLERRM, json_build_object(
            'message_id', NEW.id,
            'step', 'get_recipient'
        ));
        RETURN NEW;
    END;

    -- Get sender profile
    BEGIN
        SELECT row_to_json(p)::jsonb INTO sender_profile
        FROM profiles p
        WHERE p.id = NEW.sender_id;
        
        notification_title := 'New message from ' || COALESCE(sender_profile->>'full_name', 'Someone');
        notification_body := LEFT(message_content, 100);
    EXCEPTION WHEN OTHERS THEN
        notification_title := 'New message';
        notification_body := LEFT(message_content, 100);
    END;

    -- Get FCM tokens for future push notifications
    BEGIN
        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'fcm_token', fcm_token,
                    'device_type', device_type
                )
            ), '[]'::jsonb
        ) INTO fcm_tokens_array
        FROM user_fcm_tokens
        WHERE user_id = recipient_id;
        
        token_count := jsonb_array_length(fcm_tokens_array);
    EXCEPTION WHEN OTHERS THEN
        fcm_tokens_array := '[]'::jsonb;
        token_count := 0;
    END;

    -- Log message received
    INSERT INTO logs (event_type, details) 
    VALUES ('message_received', json_build_object(
        'message_id', NEW.id,
        'conversation_id', NEW.conversation_id,
        'sender_id', NEW.sender_id,
        'recipient_id', recipient_id,
        'message_content', message_content,
        'fcm_token_count', token_count,
        'notification_method', 'hybrid'
    ));

    -- ALWAYS create local notification (for app-open scenarios)
    BEGIN
        INSERT INTO chat_notifications (
            user_id,
            type,
            title,
            body,
            conversation_id,
            sender_id,
            message_id,
            data
        ) VALUES (
            recipient_id,
            'chat_message',
            notification_title,
            notification_body,
            NEW.conversation_id,
            NEW.sender_id,
            NEW.id,
            json_build_object(
                'conversation_id', NEW.conversation_id,
                'sender_id', NEW.sender_id,
                'message_id', NEW.id,
                'notification_type', 'hybrid',
                'timestamp', NOW()
            )
        );

        INSERT INTO logs (event_type, details) 
        VALUES ('local_notification_created', json_build_object(
            'message_id', NEW.id,
            'recipient_id', recipient_id,
            'title', notification_title,
            'method', 'local_realtime'
        ));

    EXCEPTION WHEN OTHERS THEN
        INSERT INTO logs (event_type, error, details) 
        VALUES ('notification_error', 'Local notification failed: ' || SQLERRM, json_build_object(
            'message_id', NEW.id,
            'step', 'local_notification'
        ));
    END;

    -- ALSO queue for push notification (when FCM v1 is ready)
    IF token_count > 0 THEN
        BEGIN
            INSERT INTO notification_queue (
                message_id,
                conversation_id,
                sender_id,
                recipient_id,
                message_text,
                message_type,
                sender_name,
                fcm_tokens,
                status
            ) VALUES (
                NEW.id,
                NEW.conversation_id,
                NEW.sender_id,
                recipient_id,
                message_content,
                'text',
                COALESCE(sender_profile->>'full_name', 'Someone'),
                fcm_tokens_array,
                'pending'
            );

            INSERT INTO logs (event_type, details) 
            VALUES ('push_notification_queued', json_build_object(
                'message_id', NEW.id,
                'recipient_id', recipient_id,
                'fcm_token_count', token_count,
                'status', 'ready_for_fcm_v1'
            ));

        EXCEPTION WHEN OTHERS THEN
            INSERT INTO logs (event_type, error, details) 
            VALUES ('notification_error', 'Push queue failed: ' || SQLERRM, json_build_object(
                'message_id', NEW.id,
                'step', 'push_queue'
            ));
        END;
    ELSE
        INSERT INTO logs (event_type, details) 
        VALUES ('push_notification_skipped', json_build_object(
            'reason', 'no_fcm_token',
            'recipient_id', recipient_id,
            'message_id', NEW.id
        ));
    END IF;

    RETURN NEW;

EXCEPTION WHEN OTHERS THEN
    INSERT INTO logs (event_type, error, details) 
    VALUES ('notification_error', SQLERRM, json_build_object(
        'message_id', NEW.id,
        'sqlstate', SQLSTATE,
        'step', 'general_error'
    ));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
CREATE TRIGGER notify_chat_trigger
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_chat_on_message();

-- Log system status
INSERT INTO logs (event_type, details) 
VALUES ('hybrid_notification_system', json_build_object(
    'timestamp', NOW(),
    'system', 'hybrid',
    'local_notifications', 'active',
    'push_notifications', 'queued_for_fcm_v1',
    'benefits', 'App open = instant local, App closed = push when FCM v1 ready'
));

SELECT 
    '✅ HYBRID NOTIFICATION SYSTEM ACTIVE!' as status,
    'Local notifications (app open) + FCM queue (app closed)' as method,
    'Local works now, FCM v1 setup needed for closed app' as next_step; 