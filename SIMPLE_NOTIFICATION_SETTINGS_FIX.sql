-- ============================================
-- SIMPLE Fix for User Notification Settings Table
-- Just Add Missing Columns - NO Complex Features
-- ============================================

-- Create the table if it doesn't exist (basic structure)
CREATE TABLE IF NOT EXISTS user_notification_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID
);

-- Add missing columns - Simple approach
ALTER TABLE user_notification_settings ADD COLUMN IF NOT EXISTS push_notifications BOOLEAN DEFAULT TRUE;
ALTER TABLE user_notification_settings ADD COLUMN IF NOT EXISTS local_notifications BOOLEAN DEFAULT TRUE;
ALTER TABLE user_notification_settings ADD COLUMN IF NOT EXISTS sound_enabled BOOLEAN DEFAULT TRUE;
ALTER TABLE user_notification_settings ADD COLUMN IF NOT EXISTS vibration_enabled BOOLEAN DEFAULT TRUE;
ALTER TABLE user_notification_settings ADD COLUMN IF NOT EXISTS chat_notifications BOOLEAN DEFAULT TRUE;
ALTER TABLE user_notification_settings ADD COLUMN IF NOT EXISTS marketplace_notifications BOOLEAN DEFAULT TRUE;
ALTER TABLE user_notification_settings ADD COLUMN IF NOT EXISTS community_notifications BOOLEAN DEFAULT TRUE;
ALTER TABLE user_notification_settings ADD COLUMN IF NOT EXISTS email_notifications BOOLEAN DEFAULT FALSE;
ALTER TABLE user_notification_settings ADD COLUMN IF NOT EXISTS quiet_hours_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE user_notification_settings ADD COLUMN IF NOT EXISTS quiet_hours_start TIME DEFAULT '22:00';
ALTER TABLE user_notification_settings ADD COLUMN IF NOT EXISTS quiet_hours_end TIME DEFAULT '08:00';
ALTER TABLE user_notification_settings ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE user_notification_settings ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Basic RLS setup
ALTER TABLE user_notification_settings ENABLE ROW LEVEL SECURITY;

-- Simple policies (recreate if needed)
DROP POLICY IF EXISTS "Users can manage their own notification settings" ON user_notification_settings;

CREATE POLICY "Users can manage their own notification settings" 
ON user_notification_settings 
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_user_notification_settings_user_id 
ON user_notification_settings(user_id);

-- Verify table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_notification_settings' 
ORDER BY ordinal_position; 