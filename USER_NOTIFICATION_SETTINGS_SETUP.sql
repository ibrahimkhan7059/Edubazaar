-- ============================================
-- User Notification Settings Setup for EduBazaar
-- ============================================

-- Create user notification settings table
CREATE TABLE IF NOT EXISTS user_notification_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE,
  
  -- General settings
  push_notifications BOOLEAN DEFAULT TRUE,
  local_notifications BOOLEAN DEFAULT TRUE,
  sound_enabled BOOLEAN DEFAULT TRUE,
  vibration_enabled BOOLEAN DEFAULT TRUE,
  
  -- Notification type preferences
  chat_notifications BOOLEAN DEFAULT TRUE,
  marketplace_notifications BOOLEAN DEFAULT TRUE,
  community_notifications BOOLEAN DEFAULT TRUE,
  email_notifications BOOLEAN DEFAULT FALSE,
  
  -- Quiet hours settings
  quiet_hours_enabled BOOLEAN DEFAULT FALSE,
  quiet_hours_start TIME DEFAULT '22:00',
  quiet_hours_end TIME DEFAULT '08:00',
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_notification_settings_user_id ON user_notification_settings(user_id);

-- Enable RLS (Row Level Security)
ALTER TABLE user_notification_settings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own notification settings" ON user_notification_settings;
DROP POLICY IF EXISTS "Users can update their own notification settings" ON user_notification_settings;
DROP POLICY IF EXISTS "Users can insert their own notification settings" ON user_notification_settings;

-- Create RLS policies
CREATE POLICY "Users can view their own notification settings" ON user_notification_settings
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notification settings" ON user_notification_settings
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own notification settings" ON user_notification_settings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create FCM tokens table for push notifications
CREATE TABLE IF NOT EXISTS user_fcm_tokens (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  fcm_token TEXT NOT NULL,
  device_type TEXT DEFAULT 'android',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, fcm_token)
);

-- Create indexes for FCM tokens
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_id ON user_fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_token ON user_fcm_tokens(fcm_token);
CREATE INDEX IF NOT EXISTS idx_user_fcm_tokens_user_active ON user_fcm_tokens(user_id);

-- Enable RLS for FCM tokens
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own FCM tokens" ON user_fcm_tokens;
DROP POLICY IF EXISTS "Users can update their own FCM tokens" ON user_fcm_tokens;
DROP POLICY IF EXISTS "Users can insert their own FCM tokens" ON user_fcm_tokens;
DROP POLICY IF EXISTS "Service role can manage FCM tokens" ON user_fcm_tokens;

-- Create RLS policies for FCM tokens
CREATE POLICY "Users can view their own FCM tokens" ON user_fcm_tokens
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own FCM tokens" ON user_fcm_tokens
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own FCM tokens" ON user_fcm_tokens
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role can manage FCM tokens" ON user_fcm_tokens
  FOR ALL USING (auth.role() = 'service_role');

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
DROP TRIGGER IF EXISTS trigger_update_user_notification_settings_updated_at ON user_notification_settings;
CREATE TRIGGER trigger_update_user_notification_settings_updated_at
  BEFORE UPDATE ON user_notification_settings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_update_user_fcm_tokens_updated_at ON user_fcm_tokens;
CREATE TRIGGER trigger_update_user_fcm_tokens_updated_at
  BEFORE UPDATE ON user_fcm_tokens
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default settings for existing users (optional)
-- This will create default settings for users who already exist
INSERT INTO user_notification_settings (user_id)
SELECT id FROM auth.users
WHERE id NOT IN (SELECT user_id FROM user_notification_settings)
ON CONFLICT (user_id) DO NOTHING;

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON user_notification_settings TO authenticated;
GRANT SELECT, INSERT, UPDATE ON user_fcm_tokens TO authenticated;
GRANT ALL ON user_notification_settings TO service_role;
GRANT ALL ON user_fcm_tokens TO service_role;

-- Verify the setup
SELECT 'Tables created successfully' as status;
SELECT COUNT(*) as user_notification_settings_count FROM user_notification_settings;
SELECT COUNT(*) as user_fcm_tokens_count FROM user_fcm_tokens; 