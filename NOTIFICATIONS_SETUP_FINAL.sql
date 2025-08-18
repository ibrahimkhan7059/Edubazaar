-- NOTIFICATIONS SETUP SCRIPT - FINAL VERSION
-- This script sets up the complete notifications system including:
-- - Required base tables (profiles, conversations)
-- - FCM token management
-- - User notification preferences
-- - Message notifications trigger
-- - Logging system
-- - Error handling

-- Enable required extensions
CREATE SCHEMA IF NOT EXISTS net;
CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA net;

-- Clean up any existing objects
DROP TRIGGER IF EXISTS trigger_notify_chat_on_message ON messages;
DROP TRIGGER IF EXISTS on_message_inserted ON messages;
DROP FUNCTION IF EXISTS notify_chat_on_message() CASCADE;
DROP FUNCTION IF EXISTS cleanup_old_logs() CASCADE;
DROP TABLE IF EXISTS logs CASCADE;
DROP TABLE IF EXISTS app_config CASCADE;
DROP TABLE IF EXISTS user_fcm_tokens CASCADE;
DROP TABLE IF EXISTS user_notification_settings CASCADE;

-- Create profiles table if it doesn't exist
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    avatar_url TEXT,
    university TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create conversations table if it doesn't exist
CREATE TABLE IF NOT EXISTS conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    participant_1_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    participant_2_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    listing_id UUID,
    last_message_id UUID,
    last_message_at TIMESTAMPTZ DEFAULT now(),
    participant_1_unread_count INTEGER DEFAULT 0,
    participant_2_unread_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT different_participants CHECK (participant_1_id != participant_2_id)
);

-- Create messages table if it doesn't exist
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE NOT NULL,
    sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    content TEXT,
    message_type TEXT DEFAULT 'text',
    image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    is_read BOOLEAN DEFAULT false
);

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
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(id);
CREATE INDEX IF NOT EXISTS idx_conversations_participant_1 ON conversations(participant_1_id);
CREATE INDEX IF NOT EXISTS idx_conversations_participant_2 ON conversations(participant_2_id);
CREATE INDEX IF NOT EXISTS idx_conversations_last_message_at ON conversations(last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON messages(conversation_id, is_read) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_logs_event_type ON logs(event_type);
CREATE INDEX IF NOT EXISTS idx_logs_created_at ON logs(created_at);
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_id ON user_fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_token ON user_fcm_tokens(fcm_token);

-- Drop existing policies
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view their own conversations" ON conversations;
DROP POLICY IF EXISTS "Users can create conversations" ON conversations;
DROP POLICY IF EXISTS "Users can view messages in their conversations" ON messages;
DROP POLICY IF EXISTS "Users can send messages" ON messages;
DROP POLICY IF EXISTS "Users can view and update their own notification settings" ON user_notification_settings;
DROP POLICY IF EXISTS "Users can manage their own FCM tokens" ON user_fcm_tokens;

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Public profiles are viewable by everyone" 
    ON profiles FOR SELECT 
    USING (true);

CREATE POLICY "Users can update own profile" 
    ON profiles FOR UPDATE 
    USING (auth.uid() = id);

CREATE POLICY "Users can view their own conversations" 
    ON conversations FOR SELECT 
    USING (auth.uid() = participant_1_id OR auth.uid() = participant_2_id);

CREATE POLICY "Users can create conversations" 
    ON conversations FOR INSERT 
    WITH CHECK (auth.uid() = participant_1_id OR auth.uid() = participant_2_id);

CREATE POLICY "Users can view messages in their conversations" 
    ON messages FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM conversations c 
            WHERE c.id = conversation_id 
            AND (c.participant_1_id = auth.uid() OR c.participant_2_id = auth.uid())
        )
    );

CREATE POLICY "Users can send messages" 
    ON messages FOR INSERT 
    WITH CHECK (
        sender_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM conversations c 
            WHERE c.id = conversation_id 
            AND (c.participant_1_id = auth.uid() OR c.participant_2_id = auth.uid())
        )
    );

CREATE POLICY "Users can view and update their own notification settings"
    ON user_notification_settings FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can manage their own FCM tokens"
    ON user_fcm_tokens FOR ALL
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
    has_fcm_token boolean;
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
        'recipient_id', recipient_id
    ));

    -- Check if recipient has FCM token
    SELECT EXISTS (
        SELECT 1 FROM user_fcm_tokens
        WHERE user_id = recipient_id::uuid
    ) INTO has_fcm_token;

    -- If no FCM token, skip notification
    IF NOT has_fcm_token THEN
        INSERT INTO logs (event_type, details) 
        VALUES ('notification_skipped', json_build_object(
            'reason', 'no_fcm_token',
            'recipient_id', recipient_id
        ));
        
        -- Update conversation data and return
        PERFORM update_conversation_data(NEW.conversation_id, recipient_id::uuid, NEW.id);
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
        'recipient_id', recipient_id,
        'message_text', NEW.content,
        'sender_name', sender_profile->>'full_name',
        'conversation_data', conversation_data
    );

    -- Log notification attempt
    INSERT INTO logs (event_type, details) 
    VALUES ('notification_attempt', payload);

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
    VALUES ('notification_sent', json_build_object(
        'status_code', http_response.status,
        'response_body', http_response.body::json,
        'message_id', NEW.id
    ));

    -- Update conversation data
    PERFORM update_conversation_data(NEW.conversation_id, recipient_id::uuid, NEW.id);

    RETURN NEW;

EXCEPTION WHEN OTHERS THEN
    -- Log any errors with full context
    INSERT INTO logs (event_type, error, details) 
    VALUES ('notification_error', SQLERRM || ' | ' || SQLSTATE, json_build_object(
        'message_id', NEW.id,
        'conversation_id', NEW.conversation_id,
        'sender_id', NEW.sender_id,
        'recipient_id', recipient_id,
        'error_context', json_build_object(
            'conversation_data_found', conversation_data IS NOT NULL,
            'sender_profile_found', sender_profile IS NOT NULL,
            'recipient_id_found', recipient_id IS NOT NULL,
            'service_key_found', service_key IS NOT NULL
        )
    ));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create helper function for updating conversation data
CREATE OR REPLACE FUNCTION update_conversation_data(
    conv_id UUID,
    recipient_uuid UUID,
    message_id UUID
) RETURNS void AS $$
BEGIN
    UPDATE conversations 
    SET 
        participant_1_unread_count = CASE 
            WHEN participant_1_id = recipient_uuid 
            THEN participant_1_unread_count + 1 
            ELSE participant_1_unread_count 
        END,
        participant_2_unread_count = CASE 
            WHEN participant_2_id = recipient_uuid 
            THEN participant_2_unread_count + 1 
            ELSE participant_2_unread_count 
        END,
        last_message_at = NOW(),
        last_message_id = message_id
    WHERE id = conv_id;
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

-- Insert service key into app_config
INSERT INTO app_config (key, value) 
VALUES ('service_key', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impwc2dqenByd2Vib3FuYmpsZmhoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTc3ODI3MCwiZXhwIjoyMDY3MzU0MjcwfQ.xkW1Qzau3gmY60WAzTJs3iYHpaojjCLmeINI6A2HREQ')
ON CONFLICT (key) DO UPDATE 
SET value = EXCLUDED.value;

-- Create log cleanup function
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

-- TESTING INSTRUCTIONS:
-- 1. Check if trigger is installed:
--    SELECT * FROM pg_trigger WHERE tgname = 'on_message_inserted';
-- 
-- 2. Check service key:
--    SELECT * FROM app_config WHERE key = 'service_key';
--
-- 3. Monitor logs:
--    SELECT * FROM logs ORDER BY created_at DESC LIMIT 10;
--
-- 4. Check FCM tokens:
--    SELECT * FROM user_fcm_tokens;
--
-- 5. Test the complete flow:
--    - Create a profile
--    - Create a conversation
--    - Send a message
--    - Check logs for notification status 