-- ================================================
-- FINAL PUSH NOTIFICATION SETUP FOR EDUBAZAAR
-- ================================================
-- This script handles all existing table structure issues

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Clean up existing objects safely
DROP TRIGGER IF EXISTS notify_chat_trigger ON messages;
DROP FUNCTION IF EXISTS notify_chat_on_message() CASCADE;
DROP FUNCTION IF EXISTS get_pending_notifications(integer) CASCADE;
DROP FUNCTION IF EXISTS mark_notification_sent(uuid, boolean, text) CASCADE;
DROP FUNCTION IF EXISTS cleanup_old_logs() CASCADE;

-- Create/update app_config table with proper structure
CREATE TABLE IF NOT EXISTS app_config (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    key TEXT UNIQUE NOT NULL,
    value TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add updated_at column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'app_config' AND column_name = 'updated_at') THEN
        ALTER TABLE app_config ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    END IF;
END $$;

-- Create other tables
CREATE TABLE IF NOT EXISTS logs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    event_type TEXT NOT NULL,
    details JSONB DEFAULT '{}',
    error TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_fcm_tokens (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    device_type TEXT CHECK (device_type IN ('android', 'ios', 'web')) DEFAULT 'android',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, fcm_token)
);

CREATE TABLE IF NOT EXISTS user_notification_settings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    push_notifications BOOLEAN DEFAULT TRUE,
    local_notifications BOOLEAN DEFAULT TRUE,
    sound_enabled BOOLEAN DEFAULT TRUE,
    vibration_enabled BOOLEAN DEFAULT TRUE,
    chat_notifications BOOLEAN DEFAULT TRUE,
    marketplace_notifications BOOLEAN DEFAULT TRUE,
    community_notifications BOOLEAN DEFAULT TRUE,
    email_notifications BOOLEAN DEFAULT FALSE,
    quiet_hours_enabled BOOLEAN DEFAULT FALSE,
    quiet_hours_start TIME DEFAULT '22:00',
    quiet_hours_end TIME DEFAULT '08:00',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notification_queue (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    message_id UUID,
    conversation_id UUID,
    sender_id UUID,
    recipient_id UUID,
    message_text TEXT,
    message_type TEXT DEFAULT 'text',
    sender_name TEXT,
    fcm_tokens JSONB DEFAULT '[]',
    payload JSONB DEFAULT '{}',
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'sent', 'failed')),
    attempts INTEGER DEFAULT 0,
    error_details TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ
);

-- Handle chat_notifications table - add missing columns if they don't exist
DO $$ 
BEGIN
    -- Add missing columns if they don't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'chat_notifications' AND column_name = 'type') THEN
        ALTER TABLE chat_notifications ADD COLUMN type TEXT DEFAULT 'chat_message';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'chat_notifications' AND column_name = 'conversation_id') THEN
        ALTER TABLE chat_notifications ADD COLUMN conversation_id UUID;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'chat_notifications' AND column_name = 'sender_id') THEN
        ALTER TABLE chat_notifications ADD COLUMN sender_id UUID;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'chat_notifications' AND column_name = 'message_id') THEN
        ALTER TABLE chat_notifications ADD COLUMN message_id UUID;
    END IF;
END $$;

-- Create indexes safely
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_id ON user_fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_token ON user_fcm_tokens(fcm_token);
CREATE INDEX IF NOT EXISTS idx_notification_queue_status ON notification_queue(status);
CREATE INDEX IF NOT EXISTS idx_notification_queue_created ON notification_queue(created_at);
CREATE INDEX IF NOT EXISTS idx_logs_event_type ON logs(event_type);
CREATE INDEX IF NOT EXISTS idx_logs_created_at ON logs(created_at);
CREATE INDEX IF NOT EXISTS idx_chat_notifications_user_id ON chat_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_notifications_unread ON chat_notifications(user_id, is_read);
CREATE INDEX IF NOT EXISTS idx_user_notification_settings_user_id ON user_notification_settings(user_id);

-- Enable RLS safely
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies safely and recreate
DO $$ 
BEGIN
    -- Drop existing policies if they exist
    DROP POLICY IF EXISTS "Users can manage their own FCM tokens" ON user_fcm_tokens;
    DROP POLICY IF EXISTS "Users can manage their own notification settings" ON user_notification_settings;
    DROP POLICY IF EXISTS "Users can view their own notifications" ON chat_notifications;
    DROP POLICY IF EXISTS "Users can update their own notifications" ON chat_notifications;
    DROP POLICY IF EXISTS "Users can insert their own notifications" ON chat_notifications;
END $$;

-- Create policies
CREATE POLICY "Users can manage their own FCM tokens" ON user_fcm_tokens
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own notification settings" ON user_notification_settings
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own notifications" ON chat_notifications
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notifications" ON chat_notifications
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own notifications" ON chat_notifications
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON logs TO postgres, authenticated, anon, service_role;
GRANT SELECT ON app_config TO postgres, authenticated, anon, service_role;
GRANT ALL ON notification_queue TO postgres, authenticated, anon, service_role;

-- CREATE FRESH HELPER FUNCTIONS
CREATE FUNCTION get_pending_notifications(limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
    id UUID,
    message_id UUID,
    conversation_id UUID,
    sender_id UUID,
    recipient_id UUID,
    message_text TEXT,
    sender_name TEXT,
    fcm_tokens JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        nq.id,
        nq.message_id,
        nq.conversation_id,
        nq.sender_id,
        nq.recipient_id,
        nq.message_text,
        nq.sender_name,
        nq.fcm_tokens
    FROM notification_queue nq
    WHERE nq.status = 'pending'
    ORDER BY nq.created_at ASC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE FUNCTION mark_notification_sent(
    notification_id UUID,
    success BOOLEAN,
    error_msg TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    UPDATE notification_queue 
    SET 
        status = CASE WHEN success THEN 'sent' ELSE 'failed' END,
        processed_at = NOW(),
        attempts = attempts + 1,
        error_details = error_msg
    WHERE id = notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Main notification trigger function
CREATE FUNCTION notify_chat_on_message() RETURNS TRIGGER AS $$
DECLARE
    recipient_id uuid;
    fcm_tokens_array jsonb;
    sender_profile jsonb;
    notification_settings jsonb;
BEGIN
    -- Get recipient ID (the other participant in conversation)
    SELECT 
        CASE 
            WHEN participant_1_id = NEW.sender_id THEN participant_2_id
            ELSE participant_1_id
        END INTO recipient_id
    FROM conversations 
    WHERE id = NEW.conversation_id;

    -- Log message received
    INSERT INTO logs (event_type, details) 
    VALUES ('message_received', json_build_object(
        'message_id', NEW.id,
        'conversation_id', NEW.conversation_id,
        'sender_id', NEW.sender_id,
        'recipient_id', recipient_id,
        'message_text', NEW.message_text
    ));

    -- Check if recipient wants notifications
    SELECT row_to_json(ns)::jsonb INTO notification_settings
    FROM user_notification_settings ns
    WHERE ns.user_id = recipient_id;

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
    SELECT row_to_json(p)::jsonb INTO sender_profile
    FROM profiles p
    WHERE p.id = NEW.sender_id;

    -- Get FCM tokens for recipient
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
        NEW.message_text,
        COALESCE(NEW.message_type, 'text'),
        COALESCE(sender_profile->>'full_name', 'Someone'),
        fcm_tokens_array,
        'pending'
    );

    -- Also add to chat_notifications table for UI
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
        LEFT(NEW.message_text, 100),
        NEW.conversation_id,
        NEW.sender_id,
        NEW.id,
        json_build_object(
            'conversation_id', NEW.conversation_id,
            'sender_id', NEW.sender_id,
            'message_id', NEW.id
        )
    );

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
        'sqlstate', SQLSTATE
    ));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
CREATE TRIGGER notify_chat_trigger
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_chat_on_message();

-- Safely insert/update service role key
DO $$
BEGIN
    -- Check if updated_at column exists, if not use simpler insert
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'app_config' AND column_name = 'updated_at') THEN
        INSERT INTO app_config (key, value) 
        VALUES ('service_key', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impwc2dqenByd2Vib3FuYmpsZmhoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTc3ODI3MCwiZXhwIjoyMDY3MzU0MjcwfQ.xkW1Qzau3gmY60WAzTJs3iYHpaojjCLmeINI6A2HREQ')
        ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();
    ELSE
        INSERT INTO app_config (key, value) 
        VALUES ('service_key', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impwc2dqenByd2Vib3FuYmpsZmhoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTc3ODI3MCwiZXhwIjoyMDY3MzU0MjcwfQ.xkW1Qzau3gmY60WAzTJs3iYHpaojjCLmeINI6A2HREQ')
        ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
    END IF;
END $$;

-- Cleanup function for old logs
CREATE FUNCTION cleanup_old_logs() RETURNS void AS $$
BEGIN
    DELETE FROM logs WHERE created_at < NOW() - INTERVAL '7 days';
    DELETE FROM notification_queue WHERE status IN ('sent', 'failed') AND created_at < NOW() - INTERVAL '3 days';
END;
$$ LANGUAGE plpgsql;

-- Test the setup and show results
DO $$
DECLARE
    fcm_count INTEGER;
    settings_count INTEGER;
    queue_count INTEGER;
    notifications_count INTEGER;
BEGIN
    -- Get counts safely
    SELECT COUNT(*) INTO fcm_count FROM user_fcm_tokens;
    SELECT COUNT(*) INTO settings_count FROM user_notification_settings;
    SELECT COUNT(*) INTO queue_count FROM notification_queue;
    SELECT COUNT(*) INTO notifications_count FROM chat_notifications;
    
    RAISE NOTICE '✅ FINAL push notification setup completed successfully!';
    RAISE NOTICE '📋 Tables verified: app_config, logs, user_fcm_tokens, user_notification_settings, notification_queue, chat_notifications';
    RAISE NOTICE '🔧 Functions created: get_pending_notifications, mark_notification_sent, notify_chat_on_message, cleanup_old_logs';
    RAISE NOTICE '⚡ Trigger created: notify_chat_trigger on messages table';
    RAISE NOTICE '🛡️ RLS policies updated safely';
    RAISE NOTICE '🚀 Ready for push notifications testing!';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Current data counts:';
    RAISE NOTICE '   - FCM tokens: %', fcm_count;
    RAISE NOTICE '   - Notification settings: %', settings_count;
    RAISE NOTICE '   - Notification queue: %', queue_count;
    RAISE NOTICE '   - Chat notifications: %', notifications_count;
    RAISE NOTICE '';
    RAISE NOTICE '🎯 Next steps:';
    RAISE NOTICE '   1. Test the app notifications';
    RAISE NOTICE '   2. Send a message to trigger notifications';
    RAISE NOTICE '   3. Check logs: SELECT * FROM logs ORDER BY created_at DESC;';
END $$; 