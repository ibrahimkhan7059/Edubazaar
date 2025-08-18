-- ============================================
-- Chat Notifications Setup for EduBazaar
-- ============================================

-- Create notifications table for direct storage
CREATE TABLE IF NOT EXISTS chat_notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_chat_notifications_user_id ON chat_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_notifications_unread ON chat_notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_chat_notifications_created ON chat_notifications(created_at DESC);

-- Enable RLS (Row Level Security)
ALTER TABLE chat_notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own notifications" ON chat_notifications;
DROP POLICY IF EXISTS "Users can mark their notifications as read" ON chat_notifications;
DROP POLICY IF EXISTS "Service role can insert notifications" ON chat_notifications;

-- Create RLS policies
CREATE POLICY "Users can view their own notifications" ON chat_notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can mark their notifications as read" ON chat_notifications
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Service role can insert notifications" ON chat_notifications
  FOR INSERT WITH CHECK (true);

-- Drop existing tables and functions if they exist
DROP FUNCTION IF EXISTS notify_chat_on_message() CASCADE;
DROP FUNCTION IF EXISTS get_service_key() CASCADE;
DROP TABLE IF EXISTS app_config CASCADE;
DROP TABLE IF EXISTS logs CASCADE;

-- Create config table for storing service keys and other settings
CREATE TABLE app_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert service key
INSERT INTO app_config (key, value)
VALUES (
  'service_key',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impwc2dqenByd2Vib3FuYmpsZmhoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTc3ODI3MCwiZXhwIjoyMDY3MzU0MjcwfQ.xkW1Qzau3gmY60WAzTJs3iYHpaojjCLmeINI6A2HREQ'
) ON CONFLICT (key) DO UPDATE 
SET value = EXCLUDED.value,
    created_at = NOW();

-- Create logs table if not exists
CREATE TABLE logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  event_type TEXT NOT NULL,
  details JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable http extension if not enabled
CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;

-- Create function to get service key
CREATE OR REPLACE FUNCTION get_service_key()
RETURNS TEXT AS $$
BEGIN
  RETURN (SELECT value FROM app_config WHERE key = 'service_key');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create simple trigger function that stores notifications and calls Edge Function
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

  RETURN NEW;

EXCEPTION WHEN OTHERS THEN
  -- Log any errors
  INSERT INTO logs (event_type, details) 
  VALUES ('notification_error', json_build_object('error', SQLERRM || ' | ' || SQLSTATE));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_notify_chat_on_message ON public.messages;
CREATE TRIGGER trigger_notify_chat_on_message
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION notify_chat_on_message(); 