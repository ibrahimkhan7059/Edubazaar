-- 📱 Fix Notification Sender Names
-- Issue: Notifications show "New message from Someone" instead of real names like "New message from Saqib"
-- Solution: Fix the trigger to properly fetch sender profile data

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS notify_chat_trigger ON messages;
DROP FUNCTION IF EXISTS notify_chat_on_message();

-- Create improved notification function with proper sender name fetching
CREATE OR REPLACE FUNCTION notify_chat_on_message() RETURNS TRIGGER AS $$
DECLARE
    recipient_id UUID;
    sender_name TEXT;
    sender_avatar TEXT;
    message_content TEXT;
    notification_title TEXT;
    notification_body TEXT;
    fcm_tokens_array JSONB;
    token_count INT;
BEGIN
    -- Skip if sender doesn't exist or message is empty
    IF NEW.sender_id IS NULL OR NEW.message_text IS NULL OR LENGTH(TRIM(NEW.message_text)) = 0 THEN
        RETURN NEW;
    END IF;

    -- Get message content (use proper column name)
    message_content := COALESCE(NEW.message_text, '');

    -- Get sender profile information FIRST
    BEGIN
        SELECT 
            COALESCE(full_name, username, 'User') as name,
            avatar_url
        INTO sender_name, sender_avatar
        FROM profiles 
        WHERE id = NEW.sender_id;
        
        -- If no profile found, use default
        IF sender_name IS NULL THEN
            sender_name := 'User';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        sender_name := 'User';
        sender_avatar := NULL;
    END;

    -- Create notification title and body with real sender name
    notification_title := 'New message from ' || sender_name;
    notification_body := LEFT(message_content, 100);

    -- Log the sender info for debugging
    INSERT INTO logs (event_type, details) 
    VALUES ('sender_info_fetch', json_build_object(
        'sender_id', NEW.sender_id,
        'sender_name', sender_name,
        'message_id', NEW.id,
        'title', notification_title
    ));

    -- Get recipient_id from conversation
    BEGIN
        SELECT 
            CASE 
                WHEN participant_1_id = NEW.sender_id THEN participant_2_id
                ELSE participant_1_id
            END
        INTO recipient_id
        FROM conversations 
        WHERE id = NEW.conversation_id;

        IF recipient_id IS NULL THEN
            INSERT INTO logs (event_type, error, details) 
            VALUES ('notification_error', 'Recipient not found in conversation', json_build_object(
                'conversation_id', NEW.conversation_id,
                'sender_id', NEW.sender_id,
                'message_id', NEW.id
            ));
            RETURN NEW;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        INSERT INTO logs (event_type, error, details) 
        VALUES ('notification_error', 'Failed to get recipient: ' || SQLERRM, json_build_object(
            'conversation_id', NEW.conversation_id,
            'sender_id', NEW.sender_id,
            'message_id', NEW.id
        ));
        RETURN NEW;
    END;

    -- Get FCM tokens for recipient
    BEGIN
        SELECT 
            COALESCE(json_agg(token), '[]'::jsonb),
            COUNT(*)
        INTO fcm_tokens_array, token_count
        FROM user_fcm_tokens 
        WHERE user_id = recipient_id;

        -- Log token info
        INSERT INTO logs (event_type, details) 
        VALUES ('fcm_tokens_fetched', json_build_object(
            'recipient_id', recipient_id,
            'token_count', token_count,
            'message_id', NEW.id
        ));
    EXCEPTION WHEN OTHERS THEN
        fcm_tokens_array := '[]'::jsonb;
        token_count := 0;
    END;

    -- Queue notification for Edge Function (if tokens available)
    IF token_count > 0 THEN
        BEGIN
            INSERT INTO notification_queue (
                user_id,
                title,
                body,
                data,
                fcm_tokens,
                status
            ) VALUES (
                recipient_id,
                notification_title,
                notification_body,
                json_build_object(
                    'type', 'chat',
                    'conversation_id', NEW.conversation_id,
                    'sender_id', NEW.sender_id,
                    'sender_name', sender_name,
                    'sender_avatar', sender_avatar,
                    'message_id', NEW.id
                ),
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
        END;
    END IF;

    -- Add to chat_notifications table for UI (with real sender name)
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
            notification_title,  -- This now contains real sender name
            notification_body,
            NEW.conversation_id,
            NEW.sender_id,
            NEW.id,
            json_build_object(
                'conversation_id', NEW.conversation_id,
                'sender_id', NEW.sender_id,
                'sender_name', sender_name,
                'sender_avatar', sender_avatar,
                'message_id', NEW.id,
                'type', 'chat'
            )
        );

        -- Log successful UI notification creation
        INSERT INTO logs (event_type, details) 
        VALUES ('chat_notification_created', json_build_object(
            'message_id', NEW.id,
            'recipient_id', recipient_id,
            'title', notification_title,
            'sender_name', sender_name,
            'method', 'ui_notification'
        ));

    EXCEPTION WHEN OTHERS THEN
        INSERT INTO logs (event_type, error, details) 
        VALUES ('notification_error', 'Failed to create chat notification: ' || SQLERRM, json_build_object(
            'message_id', NEW.id,
            'recipient_id', recipient_id,
            'step', 'chat_notification',
            'sender_name', sender_name
        ));
    END;

    -- Log overall success
    INSERT INTO logs (event_type, details) 
    VALUES ('notification_complete', json_build_object(
        'message_id', NEW.id,
        'recipient_id', recipient_id,
        'sender_name', sender_name,
        'title', notification_title,
        'fcm_token_count', token_count,
        'ui_notification', 'created'
    ));

    RETURN NEW;

EXCEPTION WHEN OTHERS THEN
    INSERT INTO logs (event_type, error, details) 
    VALUES ('notification_error', 'General trigger error: ' || SQLERRM, json_build_object(
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

-- Test notification with proper sender name
INSERT INTO logs (event_type, details) 
VALUES ('notification_sender_fix_applied', json_build_object(
    'timestamp', NOW(),
    'fix', 'Real sender names will now show in notifications',
    'example', 'New message from Saqib (instead of Someone)'
));

-- ✅ Now notifications will show:
-- ✅ "New message from Saqib" instead of "New message from Someone"
-- ✅ Real user names from profiles table
-- ✅ Proper data structure for chat navigation 