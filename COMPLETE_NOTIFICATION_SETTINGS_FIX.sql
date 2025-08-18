-- ============================================
-- COMPLETE Fix for User Notification Settings Table
-- Add ALL Missing Columns
-- ============================================

-- First, let's see what exists
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_notification_settings' 
ORDER BY ordinal_position;

-- Add ALL missing columns one by one
DO $$ 
BEGIN
    RAISE NOTICE 'Starting to add missing columns...';
    
    -- Add push_notifications column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN push_notifications BOOLEAN DEFAULT TRUE;
        RAISE NOTICE '✅ Added push_notifications column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE '📋 push_notifications column already exists';
    END;
    
    -- Add local_notifications column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN local_notifications BOOLEAN DEFAULT TRUE;
        RAISE NOTICE '✅ Added local_notifications column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE '📋 local_notifications column already exists';
    END;
    
    -- Add sound_enabled column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN sound_enabled BOOLEAN DEFAULT TRUE;
        RAISE NOTICE '✅ Added sound_enabled column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE '📋 sound_enabled column already exists';
    END;
    
    -- Add vibration_enabled column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN vibration_enabled BOOLEAN DEFAULT TRUE;
        RAISE NOTICE '✅ Added vibration_enabled column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE '📋 vibration_enabled column already exists';
    END;
    
    -- Add chat_notifications column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN chat_notifications BOOLEAN DEFAULT TRUE;
        RAISE NOTICE '✅ Added chat_notifications column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE '📋 chat_notifications column already exists';
    END;
    
    -- Add marketplace_notifications column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN marketplace_notifications BOOLEAN DEFAULT TRUE;
        RAISE NOTICE '✅ Added marketplace_notifications column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE '📋 marketplace_notifications column already exists';
    END;
    
    -- Add community_notifications column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN community_notifications BOOLEAN DEFAULT TRUE;
        RAISE NOTICE '✅ Added community_notifications column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE '📋 community_notifications column already exists';
    END;
    
    -- Add email_notifications column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN email_notifications BOOLEAN DEFAULT FALSE;
        RAISE NOTICE '✅ Added email_notifications column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE '📋 email_notifications column already exists';
    END;
    
    -- Add quiet_hours_enabled column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN quiet_hours_enabled BOOLEAN DEFAULT FALSE;
        RAISE NOTICE '✅ Added quiet_hours_enabled column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE '📋 quiet_hours_enabled column already exists';
    END;
    
    -- Add quiet_hours_start column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN quiet_hours_start TIME DEFAULT '22:00';
        RAISE NOTICE '✅ Added quiet_hours_start column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE '📋 quiet_hours_start column already exists';
    END;
    
    -- Add quiet_hours_end column
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN quiet_hours_end TIME DEFAULT '08:00';
        RAISE NOTICE '✅ Added quiet_hours_end column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE '📋 quiet_hours_end column already exists';
    END;
    
    -- Add created_at column if missing
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        RAISE NOTICE '✅ Added created_at column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE '📋 created_at column already exists';
    END;
    
    -- Add updated_at column if missing
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        RAISE NOTICE '✅ Added updated_at column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE '📋 updated_at column already exists';
    END;
    
    RAISE NOTICE '🎉 Finished adding all missing columns!';
END $$;

-- Make sure user_id column exists and is set up properly
DO $$
BEGIN
    -- Add user_id column if missing
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN user_id UUID;
        RAISE NOTICE '✅ Added user_id column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE '📋 user_id column already exists';
    END;
    
    -- Add id column if missing
    BEGIN
        ALTER TABLE user_notification_settings ADD COLUMN id UUID DEFAULT gen_random_uuid() PRIMARY KEY;
        RAISE NOTICE '✅ Added id column';
    EXCEPTION 
        WHEN duplicate_column THEN 
            RAISE NOTICE '📋 id column already exists';
        WHEN others THEN
            RAISE NOTICE '📋 id column exists or is already primary key';
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
RAISE NOTICE '📋 Final table structure:';
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'user_notification_settings' 
ORDER BY ordinal_position;

-- Test insert to make sure everything works
DO $$
DECLARE
    test_user_id UUID := gen_random_uuid();
BEGIN
    -- Test insert
    INSERT INTO user_notification_settings (user_id) VALUES (test_user_id);
    RAISE NOTICE '✅ Test insert successful';
    
    -- Clean up test data
    DELETE FROM user_notification_settings WHERE user_id = test_user_id;
    RAISE NOTICE '✅ Test cleanup successful';
    
    RAISE NOTICE '🎉 ALL COLUMNS ADDED SUCCESSFULLY! TABLE IS READY! 🎉';
EXCEPTION
    WHEN others THEN
        RAISE NOTICE '❌ Test failed: %', SQLERRM;
END $$; 