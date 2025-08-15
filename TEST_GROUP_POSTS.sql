-- Test Group Posts Tables
-- This script tests if the group posts functionality is properly set up

-- Check if tables exist
SELECT 
    table_name,
    CASE 
        WHEN table_name = 'group_posts' THEN '✅'
        WHEN table_name = 'group_post_likes' THEN '✅'
        WHEN table_name = 'group_post_comments' THEN '✅'
        ELSE '❌'
    END as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('group_posts', 'group_post_likes', 'group_post_comments');

-- Check if RLS is enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables 
WHERE tablename IN ('group_posts', 'group_post_likes', 'group_post_comments');

-- Check if policies exist
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename IN ('group_posts', 'group_post_likes', 'group_post_comments');

-- Test inserting a sample post (if tables exist)
DO $$
BEGIN
    -- Check if group_posts table exists
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'group_posts') THEN
        -- Insert a test post if there are any study groups
        INSERT INTO group_posts (group_id, author_id, author_name, post_type, content)
        SELECT 
            sg.id,
            gm.user_id,
            up.name,
            'discussion',
            'Test post from database setup'
        FROM study_groups sg
        JOIN group_members gm ON sg.id = gm.group_id
        JOIN user_profiles up ON gm.user_id = up.id
        WHERE gm.role = 'admin'
        LIMIT 1;
        
        RAISE NOTICE 'Test post inserted successfully';
    ELSE
        RAISE NOTICE 'group_posts table does not exist. Please run GROUP_POSTS_SETUP.sql first.';
    END IF;
END $$; 