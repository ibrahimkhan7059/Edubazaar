-- ============================================
-- Fix User Notification Settings Table
-- ============================================

-- Create or update the user_notification_settings table with basic columns
CREATE TABLE IF NOT EXISTS user_notification_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE,
    
    -- Basic notification settings
    push_notifications BOOLEAN DEFAULT TRUE,
    sound_enabled BOOLEAN DEFAULT TRUE,
    vibration_enabled BOOLEAN DEFAULT TRUE,
    email_notifications BOOLEAN DEFAULT FALSE,
    
    -- Quiet hours
    quiet_hours_enabled BOOLEAN DEFAULT FALSE,
    quiet_hours_start TIME DEFAULT '22:00',
    quiet_hours_end TIME DEFAULT '08:00',
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add missing columns if they don't exist (optional columns)
DO $$ 
BEGIN
    -- Try to add local_notifications column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN local_notifications BOOLEAN DEFAULT TRUE;
        RAISE NOTICE 'Added local_notifications column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE 'local_notifications column already exists';
    END;
    
    -- Try to add chat_notifications column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN chat_notifications BOOLEAN DEFAULT TRUE;
        RAISE NOTICE 'Added chat_notifications column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE 'chat_notifications column already exists';
    END;
    
    -- Try to add marketplace_notifications column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN marketplace_notifications BOOLEAN DEFAULT TRUE;
        RAISE NOTICE 'Added marketplace_notifications column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE 'marketplace_notifications column already exists';
    END;
    
    -- Try to add community_notifications column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN community_notifications BOOLEAN DEFAULT TRUE;
        RAISE NOTICE 'Added community_notifications column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE 'community_notifications column already exists';
    END;
END $$;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_user_notification_settings_user_id 
ON user_notification_settings(user_id);

-- Enable RLS (Row Level Security)
ALTER TABLE user_notification_settings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own notification settings" ON user_notification_settings;
DROP POLICY IF EXISTS "Users can update their own notification settings" ON user_notification_settings;
DROP POLICY IF EXISTS "Users can insert their own notification settings" ON user_notification_settings;

-- Create RLS policies
CREATE POLICY "Users can view their own notification settings" 
ON user_notification_settings FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own notification settings" 
ON user_notification_settings FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own notification settings" 
ON user_notification_settings FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Create or replace function to update timestamp
CREATE OR REPLACE FUNCTION update_notification_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for auto-updating timestamp
DROP TRIGGER IF EXISTS update_notification_settings_timestamp ON user_notification_settings;
CREATE TRIGGER update_notification_settings_timestamp
    BEFORE UPDATE ON user_notification_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_notification_settings_updated_at();

-- Show final table structure
\d user_notification_settings;

-- Test query to verify table works
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'user_notification_settings' 
ORDER BY ordinal_position; 