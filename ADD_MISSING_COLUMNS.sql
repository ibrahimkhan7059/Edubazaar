-- =====================================================
-- ADD MISSING COLUMNS TO EXISTING COMMUNITY TABLES
-- =====================================================

-- Add missing columns to community_events table
DO $$ 
BEGIN
    -- Add event_type column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'community_events' AND column_name = 'event_type') THEN
        ALTER TABLE community_events ADD COLUMN event_type VARCHAR(50) DEFAULT 'study' CHECK (event_type IN ('study', 'social', 'academic', 'workshop'));
    END IF;
    
    -- Add registration_deadline column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'community_events' AND column_name = 'registration_deadline') THEN
        ALTER TABLE community_events ADD COLUMN registration_deadline TIMESTAMP WITH TIME ZONE;
    END IF;
    
    -- Add cover_image_url column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'community_events' AND column_name = 'cover_image_url') THEN
        ALTER TABLE community_events ADD COLUMN cover_image_url TEXT;
    END IF;
    
    -- Add tags column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'community_events' AND column_name = 'tags') THEN
        ALTER TABLE community_events ADD COLUMN tags TEXT[] DEFAULT '{}';
    END IF;
END $$;

-- Add missing columns to study_groups table
DO $$ 
BEGIN
    -- Add rules column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'study_groups' AND column_name = 'rules') THEN
        ALTER TABLE study_groups ADD COLUMN rules TEXT;
    END IF;
    
    -- Add meeting_schedule column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'study_groups' AND column_name = 'meeting_schedule') THEN
        ALTER TABLE study_groups ADD COLUMN meeting_schedule TEXT;
    END IF;
    
    -- Add cover_image_url column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'study_groups' AND column_name = 'cover_image_url') THEN
        ALTER TABLE study_groups ADD COLUMN cover_image_url TEXT;
    END IF;
    
    -- Add tags column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'study_groups' AND column_name = 'tags') THEN
        ALTER TABLE study_groups ADD COLUMN tags TEXT[] DEFAULT '{}';
    END IF;
END $$;

-- Add missing columns to forum_topics table
DO $$ 
BEGIN
    -- Add is_sticky column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'forum_topics' AND column_name = 'is_sticky') THEN
        ALTER TABLE forum_topics ADD COLUMN is_sticky BOOLEAN DEFAULT false;
    END IF;
    
    -- Add is_locked column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'forum_topics' AND column_name = 'is_locked') THEN
        ALTER TABLE forum_topics ADD COLUMN is_locked BOOLEAN DEFAULT false;
    END IF;
    
    -- Add tags column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'forum_topics' AND column_name = 'tags') THEN
        ALTER TABLE forum_topics ADD COLUMN tags TEXT[] DEFAULT '{}';
    END IF;
    
    -- Add last_reply_at column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'forum_topics' AND column_name = 'last_reply_at') THEN
        ALTER TABLE forum_topics ADD COLUMN last_reply_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
END $$;

-- Add missing columns to forum_replies table
DO $$ 
BEGIN
    -- Add is_solution column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'forum_replies' AND column_name = 'is_solution') THEN
        ALTER TABLE forum_replies ADD COLUMN is_solution BOOLEAN DEFAULT false;
    END IF;
    
    -- Add parent_reply_id column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'forum_replies' AND column_name = 'parent_reply_id') THEN
        ALTER TABLE forum_replies ADD COLUMN parent_reply_id UUID REFERENCES forum_replies(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Add missing columns to group_posts table
DO $$ 
BEGIN
    -- Add post_type column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'group_posts' AND column_name = 'post_type') THEN
        ALTER TABLE group_posts ADD COLUMN post_type VARCHAR(20) DEFAULT 'discussion' CHECK (post_type IN ('discussion', 'announcement', 'question', 'resource'));
    END IF;
    
    -- Add is_pinned column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'group_posts' AND column_name = 'is_pinned') THEN
        ALTER TABLE group_posts ADD COLUMN is_pinned BOOLEAN DEFAULT false;
    END IF;
END $$;

-- Add missing columns to study_resources table
DO $$ 
BEGIN
    -- Add thumbnail_url column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'study_resources' AND column_name = 'thumbnail_url') THEN
        ALTER TABLE study_resources ADD COLUMN thumbnail_url TEXT;
    END IF;
    
    -- Add is_approved column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'study_resources' AND column_name = 'is_approved') THEN
        ALTER TABLE study_resources ADD COLUMN is_approved BOOLEAN DEFAULT true;
    END IF;
    
    -- Add academic_level column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'study_resources' AND column_name = 'academic_level') THEN
        ALTER TABLE study_resources ADD COLUMN academic_level VARCHAR(50) DEFAULT 'undergraduate' CHECK (academic_level IN ('high_school', 'undergraduate', 'graduate', 'professional'));
    END IF;
    
    -- Add tags column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'study_resources' AND column_name = 'tags') THEN
        ALTER TABLE study_resources ADD COLUMN tags TEXT[] DEFAULT '{}';
    END IF;
END $$;

-- Add missing columns to group_members table
DO $$ 
BEGIN
    -- Add role column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'group_members' AND column_name = 'role') THEN
        ALTER TABLE group_members ADD COLUMN role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('admin', 'moderator', 'member'));
    END IF;
END $$;

-- Add missing columns to event_participants table
DO $$ 
BEGIN
    -- Add status column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'event_participants' AND column_name = 'status') THEN
        ALTER TABLE event_participants ADD COLUMN status VARCHAR(20) DEFAULT 'registered' CHECK (status IN ('registered', 'attended', 'cancelled'));
    END IF;
END $$;

-- =====================================================
-- ADD MISSING CONSTRAINTS
-- =====================================================

-- Add unique constraint to group_members if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE table_name = 'group_members' AND constraint_name = 'group_members_group_id_user_id_key') THEN
        ALTER TABLE group_members ADD CONSTRAINT group_members_group_id_user_id_key UNIQUE (group_id, user_id);
    END IF;
END $$;

-- Add unique constraint to event_participants if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE table_name = 'event_participants' AND constraint_name = 'event_participants_event_id_user_id_key') THEN
        ALTER TABLE event_participants ADD CONSTRAINT event_participants_event_id_user_id_key UNIQUE (event_id, user_id);
    END IF;
END $$;

-- Add unique constraint to resource_likes if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                   WHERE table_name = 'resource_likes' AND constraint_name = 'resource_likes_resource_id_user_id_key') THEN
        ALTER TABLE resource_likes ADD CONSTRAINT resource_likes_resource_id_user_id_key UNIQUE (resource_id, user_id);
    END IF;
END $$;

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Check table structures
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name IN (
    'study_groups', 'group_members', 'group_posts',
    'forum_topics', 'forum_replies',
    'community_events', 'event_participants',
    'study_resources', 'resource_likes', 'resource_downloads'
)
ORDER BY table_name, ordinal_position;

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================

-- 🎉 MISSING COLUMNS ADDED SUCCESSFULLY! 🎉
-- 
-- All missing columns have been added to existing community tables!
-- Your community tables are now complete and ready to use.
-- 
-- Next steps:
-- 1. Create storage buckets for community features
-- 2. Test the community features in your app
-- 3. Implement the detail screens for each community feature 
 
 