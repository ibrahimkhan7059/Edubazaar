-- Enable required extensions
CREATE SCHEMA IF NOT EXISTS net;
CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA net;

-- Drop existing objects if they exist (in correct order)
DROP TRIGGER IF EXISTS trigger_notify_chat_on_message ON messages;
DROP TRIGGER IF EXISTS on_message_inserted ON messages;
DROP FUNCTION IF EXISTS notify_chat_on_message() CASCADE;
DROP FUNCTION IF EXISTS cleanup_old_logs() CASCADE;
DROP TABLE IF EXISTS logs CASCADE;
DROP TABLE IF EXISTS app_config CASCADE;
DROP TABLE IF EXISTS user_fcm_tokens CASCADE;
DROP TABLE IF EXISTS user_notification_settings CASCADE;

-- Create app_config table for storing service key
CREATE TABLE app_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Create logs table for debugging
CREATE TABLE logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type TEXT NOT NULL,
    error TEXT,
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Create user_notification_settings table
CREATE TABLE user_notification_settings (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    messages_enabled BOOLEAN DEFAULT true,
    listings_enabled BOOLEAN DEFAULT true,
    events_enabled BOOLEAN DEFAULT true,
    groups_enabled BOOLEAN DEFAULT true,
    forums_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create user_fcm_tokens table with unique constraint
CREATE TABLE user_fcm_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    device_type TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, fcm_token)
);

-- Create indexes for better performance
CREATE INDEX idx_logs_event_type ON logs(event_type);
CREATE INDEX idx_logs_created_at ON logs(created_at);
CREATE INDEX idx_user_fcm_tokens_user_id ON user_fcm_tokens(user_id);
CREATE INDEX idx_user_fcm_tokens_token ON user_fcm_tokens(fcm_token);

-- Create RLS policies
ALTER TABLE user_notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Policy for user_notification_settings
CREATE POLICY "Users can view and update their own notification settings"
    ON user_notification_settings
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy for user_fcm_tokens
CREATE POLICY "Users can manage their own FCM tokens"
    ON user_fcm_tokens
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Create the trigger function
CREATE OR REPLACE FUNCTION notify_chat_on_message() RETURNS TRIGGER AS $$
DECLARE
    conversation_data jsonb;
    sender_profile jsonb;
    recipient_id text;
    service_key text;
    http_request net.http_request;
    http_response net.http_response;
    edge_function_url text;
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
            WHEN user1_id = NEW.sender_id THEN user2_id 
            ELSE user1_id 
        END INTO recipient_id
    FROM conversations 
    WHERE id = NEW.conversation_id;

    -- Get service key from app_config
    SELECT value INTO service_key FROM app_config WHERE key = 'service_key';

    -- Log the start of notification process
    INSERT INTO logs (event_type, details) 
    VALUES ('notification_start', json_build_object('message_id', NEW.id, 'conversation_id', NEW.conversation_id));

    -- Check if recipient has notifications enabled
    IF EXISTS (
        SELECT 1 
        FROM user_notification_settings 
        WHERE user_id = recipient_id::uuid 
        AND messages_enabled = true
    ) THEN
        -- Log recipient info
        INSERT INTO logs (event_type, details) 
        VALUES ('notification_recipient', json_build_object('recipient_id', recipient_id));

        -- Construct the Edge Function URL
        edge_function_url := 'https://jpsgjzprweboqnbjlfhh.functions.supabase.co/notify-chat';

        -- Construct the payload
        payload := json_build_object(
            'message_id', NEW.id,
            'conversation_id', NEW.conversation_id,
            'sender_id', NEW.sender_id,
            'recipient_id', recipient_id,
            'message_text', NEW.content,
            'sender_name', sender_profile->>'full_name',
            'conversation_data', conversation_data
        );

        -- Construct the HTTP request
        http_request := net.http_request(
            'POST',                                -- method
            edge_function_url,                     -- url
            headers := jsonb_build_object(         -- headers
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || service_key
            ),
            body := payload::text                  -- body
        );

        -- Make the HTTP request
        http_response := net.http_post(http_request);

        -- Log the response
        INSERT INTO logs (event_type, details) 
        VALUES ('fcm_notification_sent', json_build_object(
            'status_code', http_response.status,
            'response_body', http_response.body::json,
            'message_id', NEW.id
        ));
    ELSE
        -- Log that notifications are disabled
        INSERT INTO logs (event_type, details) 
        VALUES ('notification_skipped', json_build_object(
            'reason', 'notifications_disabled',
            'recipient_id', recipient_id
        ));
    END IF;

    RETURN NEW;

EXCEPTION WHEN OTHERS THEN
    -- Log any errors
    INSERT INTO logs (event_type, error) 
    VALUES ('notification_error', SQLERRM || ' | ' || SQLSTATE);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER on_message_inserted
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_chat_on_message();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA net TO postgres, authenticated, anon, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA net TO postgres, authenticated, anon, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, authenticated, service_role;

-- Insert service key into app_config (replace with your actual key)
INSERT INTO app_config (key, value) 
VALUES ('service_key', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impwc2dqenByd2Vib3FuYmpsZmhoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTc3ODI3MCwiZXhwIjoyMDY3MzU0MjcwfQ.xkW1Qzau3gmY60WAzTJs3iYHpaojjCLmeINI6A2HREQ')
ON CONFLICT (key) DO UPDATE 
SET value = EXCLUDED.value;

-- Function to clean up old logs (keep last 1000 entries)
CREATE OR REPLACE FUNCTION cleanup_old_logs() RETURNS void AS $$
BEGIN
    DELETE FROM logs 
    WHERE id NOT IN (
        SELECT id 
        FROM logs 
        ORDER BY created_at DESC 
        LIMIT 1000
    );
END;
$$ LANGUAGE plpgsql;

-- Note: Since pg_cron is not available, you'll need to manually run the cleanup function periodically
-- To clean up logs manually, run: SELECT cleanup_old_logs(); 