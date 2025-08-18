-- ============================================
-- COMPLETE Fix for User Notification Settings Table (CORRECTED)
-- Add ALL Missing Columns - SYNTAX ERROR FIXED
-- ============================================

-- Create the table if it doesn't exist
CREATE TABLE IF NOT EXISTS user_notification_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID
);

-- Add ALL missing columns one by one with error handling
DO $$ 
BEGIN
    -- Add push_notifications column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN push_notifications BOOLEAN DEFAULT TRUE;
    EXCEPTION 
        WHEN duplicate_column THEN 
            NULL; -- Column already exists, skip
    END;
    
    -- Add local_notifications column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN local_notifications BOOLEAN DEFAULT TRUE;
    EXCEPTION 
        WHEN duplicate_column THEN 
            NULL; -- Column already exists, skip
    END;
    
    -- Add sound_enabled column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN sound_enabled BOOLEAN DEFAULT TRUE;
    EXCEPTION 
        WHEN duplicate_column THEN 
            NULL; -- Column already exists, skip
    END;
    
    -- Add vibration_enabled column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN vibration_enabled BOOLEAN DEFAULT TRUE;
    EXCEPTION 
        WHEN duplicate_column THEN 
            NULL; -- Column already exists, skip
    END;
    
    -- Add chat_notifications column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN chat_notifications BOOLEAN DEFAULT TRUE;
    EXCEPTION 
        WHEN duplicate_column THEN 
            NULL; -- Column already exists, skip
    END;
    
    -- Add marketplace_notifications column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN marketplace_notifications BOOLEAN DEFAULT TRUE;
    EXCEPTION 
        WHEN duplicate_column THEN 
            NULL; -- Column already exists, skip
    END;
    
    -- Add community_notifications column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN community_notifications BOOLEAN DEFAULT TRUE;
    EXCEPTION 
        WHEN duplicate_column THEN 
            NULL; -- Column already exists, skip
    END;
    
    -- Add email_notifications column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN email_notifications BOOLEAN DEFAULT FALSE;
    EXCEPTION 
        WHEN duplicate_column THEN 
            NULL; -- Column already exists, skip
    END;
    
    -- Add quiet_hours_enabled column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN quiet_hours_enabled BOOLEAN DEFAULT FALSE;
    EXCEPTION 
        WHEN duplicate_column THEN 
            NULL; -- Column already exists, skip
    END;
    
    -- Add quiet_hours_start column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN quiet_hours_start TIME DEFAULT '22:00';
    EXCEPTION 
        WHEN duplicate_column THEN 
            NULL; -- Column already exists, skip
    END;
    
    -- Add quiet_hours_end column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN quiet_hours_end TIME DEFAULT '08:00';
    EXCEPTION 
        WHEN duplicate_column THEN 
            NULL; -- Column already exists, skip
    END;
    
    -- Add created_at column if missing
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    EXCEPTION 
        WHEN duplicate_column THEN 
            NULL; -- Column already exists, skip
    END;
    
    -- Add updated_at column if missing
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    EXCEPTION 
        WHEN duplicate_column THEN 
            NULL; -- Column already exists, skip
    END;
END $$;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_notification_settings_user_id 
ON user_notification_settings(user_id);

-- Enable RLS (Row Level Security) if not already enabled
ALTER TABLE user_notification_settings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist and recreate
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
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'user_notification_settings' 
ORDER BY ordinal_position; 