-- =====================================================
-- DELETE EXISTING COMMUNITY TABLES
-- =====================================================

-- Drop triggers first (if they exist)
DROP TRIGGER IF EXISTS update_study_groups_updated_at ON study_groups;
DROP TRIGGER IF EXISTS update_group_posts_updated_at ON group_posts;
DROP TRIGGER IF EXISTS update_forum_topics_updated_at ON forum_topics;
DROP TRIGGER IF EXISTS update_forum_replies_updated_at ON forum_replies;
DROP TRIGGER IF EXISTS update_community_events_updated_at ON community_events;
DROP TRIGGER IF EXISTS update_study_resources_updated_at ON study_resources;
DROP TRIGGER IF EXISTS update_forum_topic_reply_count ON forum_replies;
DROP TRIGGER IF EXISTS update_event_participant_count_trigger ON event_participants;
DROP TRIGGER IF EXISTS update_resource_like_count_trigger ON resource_likes;
DROP TRIGGER IF EXISTS update_resource_download_count_trigger ON resource_downloads;
DROP TRIGGER IF EXISTS update_group_member_count_trigger ON group_members;

-- Drop functions
DROP FUNCTION IF EXISTS update_updated_at_column();
DROP FUNCTION IF EXISTS update_forum_topic_stats();
DROP FUNCTION IF EXISTS update_event_participant_count();
DROP FUNCTION IF EXISTS update_resource_like_count();
DROP FUNCTION IF EXISTS update_resource_download_count();
DROP FUNCTION IF EXISTS update_group_member_count();

-- Drop tables in reverse order (child tables first)
DROP TABLE IF EXISTS resource_downloads CASCADE;
DROP TABLE IF EXISTS resource_likes CASCADE;
DROP TABLE IF EXISTS study_resources CASCADE;
DROP TABLE IF EXISTS event_participants CASCADE;
DROP TABLE IF EXISTS community_events CASCADE;
DROP TABLE IF EXISTS forum_replies CASCADE;
DROP TABLE IF EXISTS forum_topics CASCADE;
DROP TABLE IF EXISTS group_posts CASCADE;
DROP TABLE IF EXISTS group_members CASCADE;
DROP TABLE IF EXISTS study_groups CASCADE;

-- Drop any other community-related tables that might exist
DROP TABLE IF EXISTS community_posts CASCADE;
DROP TABLE IF EXISTS community_comments CASCADE;
DROP TABLE IF EXISTS community_likes CASCADE;
DROP TABLE IF EXISTS community_followers CASCADE;
DROP TABLE IF EXISTS community_events_old CASCADE;
DROP TABLE IF EXISTS study_groups_old CASCADE;
DROP TABLE IF EXISTS forum_topics_old CASCADE;
DROP TABLE IF EXISTS study_resources_old CASCADE;

-- Clean up any remaining community-related indexes
-- (These will be automatically dropped when tables are dropped)

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Check if any community tables still exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name LIKE '%community%' 
OR table_name LIKE '%study%' 
OR table_name LIKE '%forum%' 
OR table_name LIKE '%event%' 
OR table_name LIKE '%resource%' 
OR table_name LIKE '%group%';

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================

-- All existing community tables have been deleted!
-- Now you can safely run the COMMUNITY_DATABASE_SETUP.sql script. 
 
 