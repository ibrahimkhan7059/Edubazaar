-- Check Member Counts for All Study Groups
-- This script will show you the current member counts and help identify any mismatches

-- Show all groups with their member counts
SELECT 
    sg.id,
    sg.name,
    sg.member_count as database_count,
    COUNT(gm.user_id) as actual_members,
    CASE 
        WHEN sg.member_count = COUNT(gm.user_id) THEN '✅ Match'
        ELSE '❌ Mismatch'
    END as status
FROM study_groups sg
LEFT JOIN group_members gm ON sg.id = gm.group_id
GROUP BY sg.id, sg.name, sg.member_count
ORDER BY sg.name;

-- Show detailed breakdown for each group
SELECT 
    sg.name as group_name,
    gm.role,
    COUNT(*) as count_by_role,
    STRING_AGG(up.name, ', ') as member_names
FROM study_groups sg
LEFT JOIN group_members gm ON sg.id = gm.group_id
LEFT JOIN user_profiles up ON gm.user_id = up.id
GROUP BY sg.id, sg.name, gm.role
ORDER BY sg.name, gm.role;

-- Show groups with potential issues
SELECT 
    sg.name,
    sg.member_count as database_count,
    COUNT(gm.user_id) as actual_count,
    (sg.member_count - COUNT(gm.user_id)) as difference
FROM study_groups sg
LEFT JOIN group_members gm ON sg.id = gm.group_id
GROUP BY sg.id, sg.name, sg.member_count
HAVING sg.member_count != COUNT(gm.user_id)
ORDER BY ABS(sg.member_count - COUNT(gm.user_id)) DESC; 