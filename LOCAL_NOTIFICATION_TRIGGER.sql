-- ================================================
-- LOCAL NOTIFICATION TRIGGER (Working Solution)
-- ================================================
-- Since FCM Legacy API is disabled, use local notifications

-- Mark all failed notifications as processed
UPDATE notification_queue 
SET status = 'failed', error_details = 'FCM Legacy API disabled by Google'
WHERE status = 'pending';

-- Create a simpler trigger that focuses on local notifications
DROP TRIGGER IF EXISTS notify_chat_trigger ON messages;
DROP FUNCTION IF EXISTS notify_chat_on_message() CASCADE;

-- Create simplified trigger function
CREATE OR REPLACE FUNCTION notify_chat_on_message() RETURNS TRIGGER AS $$
DECLARE
    recipient_id uuid;
    sender_profile jsonb;
    message_content text;
    notification_title text;
    notification_body text;
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

    -- Log message received
    INSERT INTO logs (event_type, details) 
    VALUES ('message_received', json_build_object(
        'message_id', NEW.id,
        'conversation_id', NEW.conversation_id,
        'sender_id', NEW.sender_id,
        'recipient_id', recipient_id,
        'message_content', message_content,
        'notification_method', 'local_only'
    ));

    -- Add to chat_notifications table for UI (This will trigger Flutter local notifications)
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
                'notification_type', 'local',
                'timestamp', NOW()
            )
        );

        -- Log successful notification
        INSERT INTO logs (event_type, details) 
        VALUES ('local_notification_created', json_build_object(
            'message_id', NEW.id,
            'recipient_id', recipient_id,
            'title', notification_title,
            'body', notification_body,
            'method', 'local_notification'
        ));

    EXCEPTION WHEN OTHERS THEN
        INSERT INTO logs (event_type, error, details) 
        VALUES ('notification_error', 'Failed to create local notification: ' || SQLERRM, json_build_object(
            'message_id', NEW.id,
            'recipient_id', recipient_id,
            'step', 'local_notification'
        ));
    END;

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
VALUES ('local_notification_system', json_build_object(
    'timestamp', NOW(),
    'message', 'Switched to local notifications system',
    'reason', 'FCM Legacy API disabled by Google',
    'method', 'chat_notifications_table_realtime'
));

SELECT 
    '✅ LOCAL NOTIFICATION SYSTEM ACTIVE!' as status,
    'FCM Legacy API → Local Notifications' as change,
    'Send message to test local notifications' as next_step; 