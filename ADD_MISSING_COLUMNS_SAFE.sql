-- =====================================================
-- ADD MISSING COLUMNS TO EXISTING COMMUNITY TABLES (SAFE)
-- =====================================================

-- Add missing columns to community_events table (if it exists)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'community_events') THEN
        -- Add event_type column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'community_events' AND column_name = 'event_type') THEN
            ALTER TABLE community_events ADD COLUMN event_type VARCHAR(50) DEFAULT 'study' CHECK (event_type IN ('study', 'social', 'academic', 'workshop'));
            RAISE NOTICE 'Added event_type column to community_events';
        END IF;
        
        -- Add registration_deadline column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'community_events' AND column_name = 'registration_deadline') THEN
            ALTER TABLE community_events ADD COLUMN registration_deadline TIMESTAMP WITH TIME ZONE;
            RAISE NOTICE 'Added registration_deadline column to community_events';
        END IF;
        
        -- Add cover_image_url column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'community_events' AND column_name = 'cover_image_url') THEN
            ALTER TABLE community_events ADD COLUMN cover_image_url TEXT;
            RAISE NOTICE 'Added cover_image_url column to community_events';
        END IF;
        
        -- Add tags column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'community_events' AND column_name = 'tags') THEN
            ALTER TABLE community_events ADD COLUMN tags TEXT[] DEFAULT '{}';
            RAISE NOTICE 'Added tags column to community_events';
        END IF;
    ELSE
        RAISE NOTICE 'community_events table does not exist, skipping...';
    END IF;
END $$;

-- Add missing columns to study_groups table (if it exists)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'study_groups') THEN
        -- Add rules column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'study_groups' AND column_name = 'rules') THEN
            ALTER TABLE study_groups ADD COLUMN rules TEXT;
            RAISE NOTICE 'Added rules column to study_groups';
        END IF;
        
        -- Add meeting_schedule column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'study_groups' AND column_name = 'meeting_schedule') THEN
            ALTER TABLE study_groups ADD COLUMN meeting_schedule TEXT;
            RAISE NOTICE 'Added meeting_schedule column to study_groups';
        END IF;
        
        -- Add cover_image_url column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'study_groups' AND column_name = 'cover_image_url') THEN
            ALTER TABLE study_groups ADD COLUMN cover_image_url TEXT;
            RAISE NOTICE 'Added cover_image_url column to study_groups';
        END IF;
        
        -- Add tags column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'study_groups' AND column_name = 'tags') THEN
            ALTER TABLE study_groups ADD COLUMN tags TEXT[] DEFAULT '{}';
            RAISE NOTICE 'Added tags column to study_groups';
        END IF;
    ELSE
        RAISE NOTICE 'study_groups table does not exist, skipping...';
    END IF;
END $$;

-- Add missing columns to forum_topics table (if it exists)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'forum_topics') THEN
        -- Add is_sticky column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'forum_topics' AND column_name = 'is_sticky') THEN
            ALTER TABLE forum_topics ADD COLUMN is_sticky BOOLEAN DEFAULT false;
            RAISE NOTICE 'Added is_sticky column to forum_topics';
        END IF;
        
        -- Add is_locked column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'forum_topics' AND column_name = 'is_locked') THEN
            ALTER TABLE forum_topics ADD COLUMN is_locked BOOLEAN DEFAULT false;
            RAISE NOTICE 'Added is_locked column to forum_topics';
        END IF;
        
        -- Add tags column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'forum_topics' AND column_name = 'tags') THEN
            ALTER TABLE forum_topics ADD COLUMN tags TEXT[] DEFAULT '{}';
            RAISE NOTICE 'Added tags column to forum_topics';
        END IF;
        
        -- Add last_reply_at column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'forum_topics' AND column_name = 'last_reply_at') THEN
            ALTER TABLE forum_topics ADD COLUMN last_reply_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
            RAISE NOTICE 'Added last_reply_at column to forum_topics';
        END IF;
    ELSE
        RAISE NOTICE 'forum_topics table does not exist, skipping...';
    END IF;
END $$;

-- Add missing columns to forum_replies table (if it exists)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'forum_replies') THEN
        -- Add is_solution column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'forum_replies' AND column_name = 'is_solution') THEN
            ALTER TABLE forum_replies ADD COLUMN is_solution BOOLEAN DEFAULT false;
            RAISE NOTICE 'Added is_solution column to forum_replies';
        END IF;
        
        -- Add parent_reply_id column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'forum_replies' AND column_name = 'parent_reply_id') THEN
            ALTER TABLE forum_replies ADD COLUMN parent_reply_id UUID REFERENCES forum_replies(id) ON DELETE CASCADE;
            RAISE NOTICE 'Added parent_reply_id column to forum_replies';
        END IF;
    ELSE
        RAISE NOTICE 'forum_replies table does not exist, skipping...';
    END IF;
END $$;

-- Add missing columns to group_posts table (if it exists)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'group_posts') THEN
        -- Add post_type column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'group_posts' AND column_name = 'post_type') THEN
            ALTER TABLE group_posts ADD COLUMN post_type VARCHAR(20) DEFAULT 'discussion' CHECK (post_type IN ('discussion', 'announcement', 'question', 'resource'));
            RAISE NOTICE 'Added post_type column to group_posts';
        END IF;
        
        -- Add is_pinned column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'group_posts' AND column_name = 'is_pinned') THEN
            ALTER TABLE group_posts ADD COLUMN is_pinned BOOLEAN DEFAULT false;
            RAISE NOTICE 'Added is_pinned column to group_posts';
        END IF;
    ELSE
        RAISE NOTICE 'group_posts table does not exist, skipping...';
    END IF;
END $$;

-- Add missing columns to study_resources table (if it exists)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'study_resources') THEN
        -- Add thumbnail_url column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'study_resources' AND column_name = 'thumbnail_url') THEN
            ALTER TABLE study_resources ADD COLUMN thumbnail_url TEXT;
            RAISE NOTICE 'Added thumbnail_url column to study_resources';
        END IF;
        
        -- Add is_approved column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'study_resources' AND column_name = 'is_approved') THEN
            ALTER TABLE study_resources ADD COLUMN is_approved BOOLEAN DEFAULT true;
            RAISE NOTICE 'Added is_approved column to study_resources';
        END IF;
        
        -- Add academic_level column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'study_resources' AND column_name = 'academic_level') THEN
            ALTER TABLE study_resources ADD COLUMN academic_level VARCHAR(50) DEFAULT 'undergraduate' CHECK (academic_level IN ('high_school', 'undergraduate', 'graduate', 'professional'));
            RAISE NOTICE 'Added academic_level column to study_resources';
        END IF;
        
        -- Add tags column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'study_resources' AND column_name = 'tags') THEN
            ALTER TABLE study_resources ADD COLUMN tags TEXT[] DEFAULT '{}';
            RAISE NOTICE 'Added tags column to study_resources';
        END IF;
    ELSE
        RAISE NOTICE 'study_resources table does not exist, skipping...';
    END IF;
END $$;

-- Add missing columns to group_members table (if it exists)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'group_members') THEN
        -- Add role column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'group_members' AND column_name = 'role') THEN
            ALTER TABLE group_members ADD COLUMN role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('admin', 'moderator', 'member'));
            RAISE NOTICE 'Added role column to group_members';
        END IF;
    ELSE
        RAISE NOTICE 'group_members table does not exist, skipping...';
    END IF;
END $$;

-- Add missing columns to event_participants table (if it exists)
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'event_participants') THEN
        -- Add status column if it doesn't exist
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                       WHERE table_name = 'event_participants' AND column_name = 'status') THEN
            ALTER TABLE event_participants ADD COLUMN status VARCHAR(20) DEFAULT 'registered' CHECK (status IN ('registered', 'attended', 'cancelled'));
            RAISE NOTICE 'Added status column to event_participants';
        END IF;
    ELSE
        RAISE NOTICE 'event_participants table does not exist, skipping...';
    END IF;
END $$;

-- =====================================================
-- ADD MISSING CONSTRAINTS (SAFE)
-- =====================================================

-- Add unique constraint to group_members if it exists
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'group_members') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                       WHERE table_name = 'group_members' AND constraint_name = 'group_members_group_id_user_id_key') THEN
            ALTER TABLE group_members ADD CONSTRAINT group_members_group_id_user_id_key UNIQUE (group_id, user_id);
            RAISE NOTICE 'Added unique constraint to group_members';
        END IF;
    END IF;
END $$;

-- Add unique constraint to event_participants if it exists
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'event_participants') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                       WHERE table_name = 'event_participants' AND constraint_name = 'event_participants_event_id_user_id_key') THEN
            ALTER TABLE event_participants ADD CONSTRAINT event_participants_event_id_user_id_key UNIQUE (event_id, user_id);
            RAISE NOTICE 'Added unique constraint to event_participants';
        END IF;
    END IF;
END $$;

-- Add unique constraint to resource_likes if it exists
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'resource_likes') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                       WHERE table_name = 'resource_likes' AND constraint_name = 'resource_likes_resource_id_user_id_key') THEN
            ALTER TABLE resource_likes ADD CONSTRAINT resource_likes_resource_id_user_id_key UNIQUE (resource_id, user_id);
            RAISE NOTICE 'Added unique constraint to resource_likes';
        END IF;
    END IF;
END $$;

-- =====================================================
-- CHECK WHICH TABLES EXIST
-- =====================================================

-- Show which community tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN (
    'study_groups', 'group_members', 'group_posts',
    'forum_topics', 'forum_replies',
    'community_events', 'event_participants',
    'study_resources', 'resource_likes', 'resource_downloads'
)
ORDER BY table_name;

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================

-- 🎉 MISSING COLUMNS ADDED SUCCESSFULLY! 🎉
-- 
-- All missing columns have been added to existing community tables!
-- Check the output above to see which tables exist and which columns were added.
-- 
-- Next steps:
-- 1. Create storage buckets for community features
-- 2. Test the community features in your app
-- 3. Implement the detail screens for each community feature 
 
 