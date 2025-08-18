-- Fix for net.http_request function syntax issue
-- Replace only the trigger function with corrected HTTP request syntax

CREATE OR REPLACE FUNCTION notify_chat_on_message() RETURNS TRIGGER AS $$
DECLARE
    conversation_data jsonb;
    sender_profile jsonb;
    recipient_id uuid;
    service_key text;
    http_response net.http_response;
    edge_function_url text;
    payload jsonb;
    has_fcm_token boolean;
    fcm_token_count integer;
BEGIN
    -- Get conversation data
    SELECT row_to_json(c)::jsonb INTO conversation_data
    FROM conversations c
    WHERE c.id = NEW.conversation_id;

    -- Get sender profile data
    SELECT row_to_json(p)::jsonb INTO sender_profile
    FROM profiles p
    WHERE p.id = NEW.sender_id;

    -- Determine recipient_id (the other user in the conversation)
    SELECT 
        CASE 
            WHEN participant_1_id = NEW.sender_id THEN participant_2_id 
            ELSE participant_1_id 
        END INTO recipient_id
    FROM conversations 
    WHERE id = NEW.conversation_id;

    -- Log initial message data
    INSERT INTO logs (event_type, details) 
    VALUES ('message_received', json_build_object(
        'message_id', NEW.id,
        'conversation_id', NEW.conversation_id,
        'sender_id', NEW.sender_id,
        'recipient_id', recipient_id::text,
        'message_text', NEW.message_text,
        'message_type', NEW.message_type
    ));

    -- Check if recipient has FCM token
    SELECT COUNT(*) INTO fcm_token_count
    FROM user_fcm_tokens
    WHERE user_id = recipient_id;
    
    has_fcm_token := (fcm_token_count > 0);

    -- Log token check details for debugging
    INSERT INTO logs (event_type, details) 
    VALUES ('fcm_token_check', json_build_object(
        'recipient_id', recipient_id::text,
        'fcm_token_count', fcm_token_count,
        'has_fcm_token', has_fcm_token
    ));

    -- If no FCM token, skip notification
    IF NOT has_fcm_token THEN
        INSERT INTO logs (event_type, details) 
        VALUES ('notification_skipped', json_build_object(
            'reason', 'no_fcm_token',
            'recipient_id', recipient_id::text,
            'fcm_token_count', fcm_token_count
        ));
        
        -- Update conversation data and return
        PERFORM update_conversation_data(NEW.conversation_id, recipient_id, NEW.id);
        RETURN NEW;
    END IF;

    -- Get service key from app_config
    SELECT value INTO service_key FROM app_config WHERE key = 'service_key';

    -- Construct the Edge Function URL
    edge_function_url := 'https://jpsgjzprweboqnbjlfhh.functions.supabase.co/notify-chat';

    -- Construct the payload
    payload := json_build_object(
        'message_id', NEW.id,
        'conversation_id', NEW.conversation_id,
        'sender_id', NEW.sender_id,
        'recipient_id', recipient_id::text,
        'message_text', NEW.message_text,
        'message_type', NEW.message_type,
        'sender_name', sender_profile->>'full_name',
        'conversation_data', conversation_data
    );

    -- Log notification attempt
    INSERT INTO logs (event_type, details) 
    VALUES ('notification_attempt', payload);

    -- Make the HTTP request using the CORRECTED syntax
    SELECT net.http_post(
        url := edge_function_url,
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || service_key
        ),
        body := payload::text
    ) INTO http_response;

    -- Log the response
    INSERT INTO logs (event_type, details) 
    VALUES ('notification_sent', json_build_object(
        'status_code', http_response.status,
        'response_body', http_response.body::jsonb,
        'message_id', NEW.id
    ));

    -- Update conversation data
    PERFORM update_conversation_data(NEW.conversation_id, recipient_id, NEW.id);

    RETURN NEW;

EXCEPTION WHEN OTHERS THEN
    -- Log any errors with full context
    INSERT INTO logs (event_type, error, details) 
    VALUES ('notification_error', SQLERRM || ' | ' || SQLSTATE, json_build_object(
        'message_id', NEW.id,
        'conversation_id', NEW.conversation_id,
        'sender_id', NEW.sender_id,
        'recipient_id', recipient_id::text,
        'message_text', NEW.message_text,
        'message_type', NEW.message_type,
        'error_context', json_build_object(
            'conversation_data_found', conversation_data IS NOT NULL,
            'sender_profile_found', sender_profile IS NOT NULL,
            'recipient_id_found', recipient_id IS NOT NULL,
            'service_key_found', service_key IS NOT NULL
        )
    ));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; 