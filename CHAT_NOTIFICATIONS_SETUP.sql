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
CREATE OR REPLACE FUNCTION notify_chat_on_message()
RETURNS TRIGGER AS $$
DECLARE
  recipient_id UUID;
  sender_name TEXT;
  response TEXT;
  service_key TEXT;
BEGIN
  -- Get conversation details to find recipient
  SELECT 
    CASE 
      WHEN participant_1_id = NEW.sender_id THEN participant_2_id
      ELSE participant_1_id
    END INTO recipient_id
  FROM conversations 
  WHERE id = NEW.conversation_id;
  
  -- Get sender name
  SELECT name INTO sender_name
  FROM user_profiles 
  WHERE id = NEW.sender_id;
  
  -- Insert notification directly into database
  INSERT INTO chat_notifications (
    user_id, 
    title, 
    body, 
    data
  ) VALUES (
    recipient_id,
    'New Message',
    COALESCE(sender_name, 'Someone') || ': ' || LEFT(NEW.message_text, 50),
    json_build_object(
      'type', 'message_inserted',
      'conversationId', NEW.conversation_id,
      'messageId', NEW.id,
      'senderId', NEW.sender_id,
      'messageText', NEW.message_text,
      'timestamp', NOW()
    )
  );

  -- Get service key
  service_key := get_service_key();

  -- Call Edge Function to send FCM notification
  SELECT
    net.http_post(
      url := 'https://jpsgjzprweboqnbjlfhh.supabase.co/functions/v1/notify-chat',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_key,
        'x-edge-secret', 'edubazaar-secret-2024-xyz123'
      ),
      body := jsonb_build_object(
        'type', 'message_inserted',
        'message', jsonb_build_object(
          'id', NEW.id,
          'conversation_id', NEW.conversation_id,
          'sender_id', NEW.sender_id,
          'message_text', NEW.message_text
        )
      )
    ) INTO response;

  -- Log the response for debugging
  INSERT INTO logs (event_type, details) VALUES (
    'fcm_notification_sent',
    jsonb_build_object(
      'message_id', NEW.id,
      'response', response,
      'timestamp', NOW()
    )
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_notify_chat_on_message ON public.messages;
CREATE TRIGGER trigger_notify_chat_on_message
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION notify_chat_on_message(); 