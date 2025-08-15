-- Test Database Connection and Tables
-- Run this in Supabase SQL Editor to check if tables exist

-- Check if study_groups table exists
SELECT 
  table_name,
  CASE 
    WHEN table_name IS NOT NULL THEN 'EXISTS' 
    ELSE 'NOT FOUND' 
  END as status
FROM information_schema.tables 
WHERE table_name = 'study_groups';

-- Check if forum_topics table exists
SELECT 
  table_name,
  CASE 
    WHEN table_name IS NOT NULL THEN 'EXISTS' 
    ELSE 'NOT FOUND' 
  END as status
FROM information_schema.tables 
WHERE table_name = 'forum_topics';

-- Check if community_events table exists
SELECT 
  table_name,
  CASE 
    WHEN table_name IS NOT NULL THEN 'EXISTS' 
    ELSE 'NOT FOUND' 
  END as status
FROM information_schema.tables 
WHERE table_name = 'community_events';

-- Check if study_resources table exists
SELECT 
  table_name,
  CASE 
    WHEN table_name IS NOT NULL THEN 'EXISTS' 
    ELSE 'NOT FOUND' 
  END as status
FROM information_schema.tables 
WHERE table_name = 'study_resources';

-- Check table structure for study_groups
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'study_groups'
ORDER BY ordinal_position;

-- Check RLS policies for study_groups
SELECT 
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'study_groups';

-- Test insert permission (this will fail if RLS is blocking)
-- INSERT INTO study_groups (name, description, subject, creator_id, is_private, max_members, tags) 
-- VALUES ('Test Group', 'Test Description', 'Test Subject', '00000000-0000-0000-0000-000000000000', false, 50, ARRAY['test']);

-- Check current user (if authenticated)
SELECT auth.uid() as current_user_id; 