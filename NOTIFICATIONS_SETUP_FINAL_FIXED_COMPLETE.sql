-- Complete Notification System Setup for Supabase - ERROR-FREE VERSION
-- This script sets up the entire notification infrastructure
-- Run this in Supabase SQL Editor

-- Clean up existing objects first
DROP TRIGGER IF EXISTS notify_chat_trigger ON messages;
DROP FUNCTION IF EXISTS notify_chat_on_message() CASCADE;
DROP FUNCTION IF EXISTS update_conversation_data(UUID, UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS cleanup_old_logs() CASCADE;
DROP FUNCTION IF EXISTS get_service_key() CASCADE;

-- Drop tables if they exist (be careful in production)
DROP TABLE IF EXISTS logs CASCADE;
DROP TABLE IF EXISTS user_fcm_tokens CASCADE;
DROP TABLE IF EXISTS user_notification_settings CASCADE;
DROP TABLE IF EXISTS app_config CASCADE;

-- Create net schema and http extension if not exists
CREATE SCHEMA IF NOT EXISTS net;
CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA net;

-- Grant permissions on net schema
GRANT USAGE ON SCHEMA net TO postgres, authenticated, anon, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA net TO postgres, authenticated, anon, service_role;

-- Create app_config table for storing sensitive configuration
CREATE TABLE app_config (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    key TEXT UNIQUE NOT NULL,
    value TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create logs table for debugging
CREATE TABLE logs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    event_type TEXT NOT NULL,
    details JSONB,
    error TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create user notification settings table
CREATE TABLE user_notification_settings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    push_notifications BOOLEAN DEFAULT true,
    email_notifications BOOLEAN DEFAULT true,
    in_app_notifications BOOLEAN DEFAULT true,
    message_notifications BOOLEAN DEFAULT true,
    event_notifications BOOLEAN DEFAULT true,
    group_notifications BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create FCM tokens table
CREATE TABLE user_fcm_tokens (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    device_type TEXT CHECK (device_type IN ('android', 'ios', 'web')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, fcm_token)
);

-- Ensure profiles table exists with correct structure
CREATE TABLE IF NOT EXISTS profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    full_name TEXT,
    username TEXT UNIQUE,
    avatar_url TEXT,
    bio TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ensure conversations table exists with correct structure
CREATE TABLE IF NOT EXISTS conversations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    participant_1_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    participant_2_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    participant_1_unread_count INTEGER DEFAULT 0,
    participant_2_unread_count INTEGER DEFAULT 0,
    last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_message_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(participant_1_id, participant_2_id)
);

-- Ensure messages table exists with correct structure matching your Flutter model
CREATE TABLE IF NOT EXISTS messages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    message_text TEXT NOT NULL,  -- THIS IS THE CORRECT COLUMN NAME
    message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'listing_share', 'system')),
    attachment_url TEXT,
    listing_reference_id TEXT,
    is_read BOOLEAN DEFAULT false,
    is_edited BOOLEAN DEFAULT false,
    edited_at TIMESTAMP WITH TIME ZONE,
    is_delivered BOOLEAN DEFAULT false,
    delivered_at TIMESTAMP WITH TIME ZONE,
    read_at TIMESTAMP WITH TIME ZONE,
    reactions JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_conversations_participant_1 ON conversations(participant_1_id);
CREATE INDEX IF NOT EXISTS idx_conversations_participant_2 ON conversations(participant_2_id);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);
CREATE INDEX IF NOT EXISTS idx_user_notification_settings_user_id ON user_notification_settings(user_id);
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
            SELECT 1 FROM conversations 
            WHERE id = conversation_id 
            AND (participant_1_id = auth.uid() OR participant_2_id = auth.uid())
        )
    );

CREATE POLICY "Users can send messages" 
    ON messages FOR INSERT 
    WITH CHECK (
        auth.uid() = sender_id AND
        EXISTS (
            SELECT 1 FROM conversations 
            WHERE id = conversation_id 
            AND (participant_1_id = auth.uid() OR participant_2_id = auth.uid())
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the main trigger function with CORRECT COLUMN NAME
CREATE OR REPLACE FUNCTION notify_chat_on_message() RETURNS TRIGGER AS $$
DECLARE
    conversation_data jsonb;
    sender_profile jsonb;
    recipient_id uuid;
    service_key text;
    http_request net.http_request;
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
        'message_text', NEW.message_text  -- CORRECT COLUMN NAME
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
        'message_text', NEW.message_text,  -- CORRECT COLUMN NAME
        'sender_name', sender_profile->>'full_name',
        'conversation_data', conversation_data
    );

    -- Log notification attempt
    INSERT INTO logs (event_type, details) 
    VALUES ('notification_attempt', payload);

    -- Construct the HTTP request
    http_request := net.http_request(
        'POST',
        edge_function_url,
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || service_key
        ),
        body := payload::text
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
        'message_text', NEW.message_text,  -- CORRECT COLUMN NAME
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

-- Create the trigger
CREATE TRIGGER notify_chat_trigger
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_chat_on_message();

-- Create cleanup function for old logs
CREATE OR REPLACE FUNCTION cleanup_old_logs() RETURNS void AS $$
BEGIN
    DELETE FROM logs WHERE created_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;

-- Function to get service key
CREATE OR REPLACE FUNCTION get_service_key() RETURNS text AS $$
DECLARE
    key_value text;
BEGIN
    SELECT value INTO key_value FROM app_config WHERE key = 'service_key';
    RETURN key_value;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert your service key (replace with your actual key)
INSERT INTO app_config (key, value) 
VALUES ('service_key', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impwc2dqenByd2Vib3FuYmpsZmhoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTc3ODI3MCwiZXhwIjoyMDY3MzU0MjcwfQ.xkW1Qzau3gmY60WAzTJs3iYHpaojjCLmeINI6A2HREQ')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- Grant necessary permissions
GRANT SELECT ON app_config TO postgres, authenticated, anon, service_role;
GRANT INSERT ON logs TO postgres, authenticated, anon, service_role;
GRANT SELECT ON logs TO postgres, authenticated, anon, service_role;

/*
=== TESTING INSTRUCTIONS ===

1. Run this entire script in Supabase SQL Editor

2. Verify the setup by running:
   SELECT * FROM app_config;
   SELECT * FROM user_fcm_tokens;

3. Test the notification flow:
   - Send a message from one user to another
   - Check logs table: SELECT * FROM logs ORDER BY created_at DESC;
   - You should see: message_received, fcm_token_check, notification_attempt, notification_sent

4. Check for any errors:
   SELECT * FROM logs WHERE error IS NOT NULL ORDER BY created_at DESC;

5. To clean old logs manually:
   SELECT cleanup_old_logs();

=== KEY FIXES IN THIS VERSION ===
- FIXED: Used correct column name 'message_text' instead of 'content' or 'message'
- FIXED: FCM token check by changing recipient_id from text to uuid
- Added SECURITY DEFINER to bypass RLS policies
- Added fcm_token_check log event for debugging
- Improved error handling and logging
- Added proper indexes for performance
- Updated messages table structure to match your Flutter model exactly
*/ 