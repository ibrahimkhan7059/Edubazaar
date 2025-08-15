-- Verify Member Count Trigger
-- This script checks if the trigger is properly installed and working

-- Check if the trigger function exists
SELECT 
    proname as function_name,
    prosrc as function_source
FROM pg_proc 
WHERE proname = 'update_group_member_count';

-- Check if the triggers exist
SELECT 
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    tgtype,
    tgenabled
FROM pg_trigger 
WHERE tgname LIKE '%member_count%';

-- Test the trigger by adding a test member (if needed)
-- This will show if the trigger is working
-- (You can run this manually if you want to test)

-- Check current member counts vs actual counts
SELECT 
    'Current State' as check_type,
    sg.name,
    sg.member_count as stored_count,
    COUNT(gm.user_id) as actual_count,
    CASE 
        WHEN sg.member_count = COUNT(gm.user_id) THEN '✅ Match'
        ELSE '❌ Mismatch'
    END as status
FROM study_groups sg
LEFT JOIN group_members gm ON sg.id = gm.group_id
GROUP BY sg.id, sg.name, sg.member_count
ORDER BY sg.name; 