-- ================================================
-- QUICK FIX FOR JSON_ARRAY_LENGTH ERROR
-- ================================================
-- This fixes the json_array_length function issue

-- Drop and recreate the trigger function with correct JSONB functions
DROP TRIGGER IF EXISTS notify_chat_trigger ON messages;
DROP FUNCTION IF EXISTS notify_chat_on_message() CASCADE;

-- Create corrected trigger function
CREATE OR REPLACE FUNCTION notify_chat_on_message() RETURNS TRIGGER AS $$
DECLARE
    recipient_id uuid;
    fcm_tokens_array jsonb;
    sender_profile jsonb;
    notification_settings jsonb;
    message_content text;
    token_count integer;
BEGIN
    -- Safely extract message content
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

    -- Log message received
    INSERT INTO logs (event_type, details) 
    VALUES ('message_received', json_build_object(
        'message_id', NEW.id,
        'conversation_id', NEW.conversation_id,
        'sender_id', NEW.sender_id,
        'recipient_id', recipient_id,
        'message_content', message_content
    ));

    -- Get sender profile
    BEGIN
        SELECT row_to_json(p)::jsonb INTO sender_profile
        FROM profiles p
        WHERE p.id = NEW.sender_id;
    EXCEPTION WHEN OTHERS THEN
        sender_profile := json_build_object('full_name', 'Someone');
    END;

    -- Get FCM tokens for recipient
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
    EXCEPTION WHEN OTHERS THEN
        fcm_tokens_array := '[]'::jsonb;
    END;

    -- Get token count using correct JSONB function
    BEGIN
        token_count := jsonb_array_length(fcm_tokens_array);
    EXCEPTION WHEN OTHERS THEN
        token_count := 0;
    END;

    -- Check if recipient has FCM tokens
    IF token_count = 0 THEN
        INSERT INTO logs (event_type, details) 
        VALUES ('notification_skipped', json_build_object(
            'reason', 'no_fcm_token',
            'recipient_id', recipient_id,
            'token_count', token_count
        ));
        RETURN NEW;
    END IF;

    -- Add notification to queue
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
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO logs (event_type, error, details) 
        VALUES ('notification_error', 'Failed to queue: ' || SQLERRM, json_build_object(
            'message_id', NEW.id,
            'step', 'queue_notification'
        ));
        RETURN NEW;
    END;

    -- Add to chat_notifications for UI
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
            'New message from ' || COALESCE(sender_profile->>'full_name', 'Someone'),
            LEFT(message_content, 100),
            NEW.conversation_id,
            NEW.sender_id,
            NEW.id,
            json_build_object(
                'conversation_id', NEW.conversation_id,
                'sender_id', NEW.sender_id,
                'message_id', NEW.id
            )
        );
    EXCEPTION WHEN OTHERS THEN
        -- Log but don't fail
        INSERT INTO logs (event_type, error, details) 
        VALUES ('notification_warning', 'Chat notification failed: ' || SQLERRM, json_build_object(
            'message_id', NEW.id,
            'step', 'chat_notification'
        ));
    END;

    -- Log success
    INSERT INTO logs (event_type, details) 
    VALUES ('notification_queued', json_build_object(
        'message_id', NEW.id,
        'recipient_id', recipient_id,
        'fcm_token_count', token_count,
        'sender_name', COALESCE(sender_profile->>'full_name', 'Someone')
    ));

    RETURN NEW;

EXCEPTION WHEN OTHERS THEN
    INSERT INTO logs (event_type, error, details) 
    VALUES ('notification_error', SQLERRM, json_build_object(
        'message_id', NEW.id,
        'conversation_id', NEW.conversation_id,
        'sender_id', NEW.sender_id,
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

-- Test log
INSERT INTO logs (event_type, details) 
VALUES ('trigger_fixed', json_build_object(
    'timestamp', NOW(),
    'fix', 'Replaced json_array_length with jsonb_array_length',
    'message', 'Notification trigger should work now'
));

SELECT 
    '✅ TRIGGER FIXED!' as status,
    'json_array_length → jsonb_array_length' as main_fix,
    'Now test by sending a message' as next_step; 