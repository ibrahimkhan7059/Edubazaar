-- Quick Database Test for Community Features
-- Run this in Supabase SQL Editor

-- Check if tables exist
SELECT 
  'study_groups' as table_name,
  EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'study_groups'
  ) as exists
UNION ALL
SELECT 
  'forum_topics' as table_name,
  EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'forum_topics'
  ) as exists
UNION ALL
SELECT 
  'community_events' as table_name,
  EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'community_events'
  ) as exists
UNION ALL
SELECT 
  'study_resources' as table_name,
  EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'study_resources'
  ) as exists;

-- Check current user (if authenticated)
SELECT 
  'Current User' as info,
  auth.uid() as user_id;

-- Test simple insert (this will fail if RLS blocks it)
-- INSERT INTO study_groups (name, description, subject, creator_id, is_private, max_members, tags) 
-- VALUES ('Test Group', 'Test Description', 'Test Subject', auth.uid(), false, 50, ARRAY['test'])
-- RETURNING id; 