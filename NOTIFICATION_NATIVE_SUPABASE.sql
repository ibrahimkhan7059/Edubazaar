-- Native Supabase solution - Store notifications in a table for Edge Function to process
-- This avoids HTTP extension issues completely

-- Create notifications queue table
CREATE TABLE IF NOT EXISTS notification_queue (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    message_id UUID NOT NULL,
    conversation_id UUID NOT NULL,
    sender_id UUID NOT NULL,
    recipient_id UUID NOT NULL,
    message_text TEXT NOT NULL,
    message_type TEXT DEFAULT 'text',
    sender_name TEXT,
    fcm_tokens JSONB,
    payload JSONB,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'sent', 'failed')),
    attempts INTEGER DEFAULT 0,
    error_details TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE
);

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_notification_queue_status ON notification_queue(status);
CREATE INDEX IF NOT EXISTS idx_notification_queue_created_at ON notification_queue(created_at);

-- Updated trigger function that stores notification in queue
CREATE OR REPLACE FUNCTION notify_chat_on_message() RETURNS TRIGGER AS $$
DECLARE
    conversation_data jsonb;
    sender_profile jsonb;
    recipient_id uuid;
    has_fcm_token boolean;
    fcm_token_count integer;
    fcm_tokens_array jsonb;
    payload jsonb;
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

    -- Get all FCM tokens for recipient
    SELECT 
        COUNT(*) as token_count,
        COALESCE(json_agg(
            json_build_object(
                'fcm_token', fcm_token,
                'device_type', device_type
            )
        ), '[]'::json) as tokens
    INTO fcm_token_count, fcm_tokens_array
    FROM user_fcm_tokens
    WHERE user_id = recipient_id;
    
    has_fcm_token := (fcm_token_count > 0);

    -- Log token check details for debugging
    INSERT INTO logs (event_type, details) 
    VALUES ('fcm_token_check', json_build_object(
        'recipient_id', recipient_id::text,
        'fcm_token_count', fcm_token_count,
        'has_fcm_token', has_fcm_token,
        'tokens', fcm_tokens_array
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

    -- Construct the full payload
    payload := json_build_object(
        'message_id', NEW.id,
        'conversation_id', NEW.conversation_id,
        'sender_id', NEW.sender_id,
        'recipient_id', recipient_id::text,
        'message_text', NEW.message_text,
        'message_type', NEW.message_type,
        'sender_name', sender_profile->>'full_name',
        'conversation_data', conversation_data,
        'timestamp', extract(epoch from now())
    );

    -- Insert notification into queue for processing
    INSERT INTO notification_queue (
        message_id,
        conversation_id,
        sender_id,
        recipient_id,
        message_text,
        message_type,
        sender_name,
        fcm_tokens,
        payload,
        status
    ) VALUES (
        NEW.id,
        NEW.conversation_id,
        NEW.sender_id,
        recipient_id,
        NEW.message_text,
        NEW.message_type,
        sender_profile->>'full_name',
        fcm_tokens_array,
        payload,
        'pending'
    );

    -- Log successful queue insertion
    INSERT INTO logs (event_type, details) 
    VALUES ('notification_queued', json_build_object(
        'message_id', NEW.id,
        'recipient_id', recipient_id::text,
        'fcm_token_count', fcm_token_count,
        'status', 'queued_for_processing'
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
            'recipient_id_found', recipient_id IS NOT NULL
        )
    ));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get pending notifications (for Edge Function to call)
CREATE OR REPLACE FUNCTION get_pending_notifications(limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
    id UUID,
    message_id UUID,
    conversation_id UUID,
    sender_id UUID,
    recipient_id UUID,
    message_text TEXT,
    message_type TEXT,
    sender_name TEXT,
    fcm_tokens JSONB,
    payload JSONB,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    UPDATE notification_queue 
    SET status = 'processing', processed_at = NOW()
    WHERE notification_queue.id IN (
        SELECT notification_queue.id 
        FROM notification_queue 
        WHERE notification_queue.status = 'pending' 
        ORDER BY notification_queue.created_at ASC 
        LIMIT limit_count
    )
    RETURNING 
        notification_queue.id,
        notification_queue.message_id,
        notification_queue.conversation_id,
        notification_queue.sender_id,
        notification_queue.recipient_id,
        notification_queue.message_text,
        notification_queue.message_type,
        notification_queue.sender_name,
        notification_queue.fcm_tokens,
        notification_queue.payload,
        notification_queue.created_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to mark notification as sent
CREATE OR REPLACE FUNCTION mark_notification_sent(notification_id UUID, success BOOLEAN DEFAULT TRUE, error_msg TEXT DEFAULT NULL)
RETURNS VOID AS $$
BEGIN
    UPDATE notification_queue 
    SET 
        status = CASE WHEN success THEN 'sent' ELSE 'failed' END,
        attempts = attempts + 1,
        error_details = error_msg,
        processed_at = NOW()
    WHERE id = notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create RLS policies for notification_queue
ALTER TABLE notification_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Service role can manage notification queue" 
    ON notification_queue FOR ALL 
    USING (true) 
    WITH CHECK (true);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON notification_queue TO postgres, authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION get_pending_notifications(INTEGER) TO postgres, authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION mark_notification_sent(UUID, BOOLEAN, TEXT) TO postgres, authenticated, anon, service_role; 