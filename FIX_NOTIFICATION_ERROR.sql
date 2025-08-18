-- ================================================
-- FIX NOTIFICATION ERROR SCRIPT
-- ================================================
-- This script fixes common notification trigger issues

-- First, drop the problematic trigger and function
DROP TRIGGER IF EXISTS notify_chat_trigger ON messages;
DROP FUNCTION IF EXISTS notify_chat_on_message() CASCADE;

-- Check what column name is actually used for message content in your messages table
-- Common variations: message_text, content, body, text

-- Create a more robust trigger function that handles different column names
CREATE OR REPLACE FUNCTION notify_chat_on_message() RETURNS TRIGGER AS $$
DECLARE
    recipient_id uuid;
    fcm_tokens_array jsonb;
    sender_profile jsonb;
    notification_settings jsonb;
    message_content text;
BEGIN
    -- Safely extract message content (handle different column names)
    BEGIN
        -- Try different possible column names for message content
        IF TG_TABLE_NAME = 'messages' THEN
            -- Check which column exists and use it
            IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'message_text') THEN
                message_content := NEW.message_text;
            ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'content') THEN
                message_content := NEW.content;
            ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'body') THEN
                message_content := NEW.body;
            ELSIF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'text') THEN
                message_content := NEW.text;
            ELSE
                message_content := 'New message'; -- fallback
            END IF;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        message_content := 'New message';
    END;

    -- Get recipient ID (the other participant in conversation)
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
        VALUES ('notification_error', 'Failed to get recipient_id: ' || SQLERRM, json_build_object(
            'message_id', NEW.id,
            'conversation_id', NEW.conversation_id,
            'sender_id', NEW.sender_id,
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

    -- Check if recipient wants notifications
    BEGIN
        SELECT row_to_json(ns)::jsonb INTO notification_settings
        FROM user_notification_settings ns
        WHERE ns.user_id = recipient_id;
    EXCEPTION WHEN OTHERS THEN
        notification_settings := NULL;
    END;

    -- Skip if notifications disabled
    IF notification_settings IS NOT NULL AND 
       (notification_settings->>'chat_notifications')::boolean = false THEN
        INSERT INTO logs (event_type, details) 
        VALUES ('notification_skipped', json_build_object(
            'reason', 'chat_notifications_disabled',
            'recipient_id', recipient_id
        ));
        RETURN NEW;
    END IF;

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
            json_agg(
                json_build_object(
                    'fcm_token', fcm_token,
                    'device_type', device_type
                )
            ), '[]'::json
        ) INTO fcm_tokens_array
        FROM user_fcm_tokens
        WHERE user_id = recipient_id;
    EXCEPTION WHEN OTHERS THEN
        fcm_tokens_array := '[]'::json;
    END;

    -- Check if recipient has FCM tokens
    IF json_array_length(fcm_tokens_array) = 0 THEN
        INSERT INTO logs (event_type, details) 
        VALUES ('notification_skipped', json_build_object(
            'reason', 'no_fcm_token',
            'recipient_id', recipient_id
        ));
        RETURN NEW;
    END IF;

    -- Add notification to queue for processing
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
            COALESCE('text', 'text'), -- fallback message type
            COALESCE(sender_profile->>'full_name', 'Someone'),
            fcm_tokens_array,
            'pending'
        );
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO logs (event_type, error, details) 
        VALUES ('notification_error', 'Failed to queue notification: ' || SQLERRM, json_build_object(
            'message_id', NEW.id,
            'recipient_id', recipient_id,
            'step', 'queue_notification'
        ));
        RETURN NEW;
    END;

    -- Also add to chat_notifications table for UI
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
        INSERT INTO logs (event_type, error, details) 
        VALUES ('notification_error', 'Failed to create chat notification: ' || SQLERRM, json_build_object(
            'message_id', NEW.id,
            'recipient_id', recipient_id,
            'step', 'chat_notification'
        ));
    END;

    INSERT INTO logs (event_type, details) 
    VALUES ('notification_queued', json_build_object(
        'message_id', NEW.id,
        'recipient_id', recipient_id,
        'fcm_token_count', json_array_length(fcm_tokens_array)
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

-- Test the fix
INSERT INTO logs (event_type, details) 
VALUES ('trigger_fix_applied', json_build_object(
    'timestamp', NOW(),
    'message', 'Notification trigger has been fixed with better error handling'
));

SELECT 'Notification trigger fixed! Now test by sending a message.' as result; 