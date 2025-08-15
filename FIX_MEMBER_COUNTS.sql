-- Fix Member Counts for Study Groups
-- This script verifies and corrects member counts for all study groups

-- First, let's see the current state
SELECT 
    sg.id,
    sg.name,
    sg.member_count as current_count,
    COUNT(gm.user_id) as actual_count,
    CASE 
        WHEN sg.member_count = COUNT(gm.user_id) THEN '✅ Correct'
        ELSE '❌ Incorrect'
    END as status
FROM study_groups sg
LEFT JOIN group_members gm ON sg.id = gm.group_id
GROUP BY sg.id, sg.name, sg.member_count
ORDER BY sg.name;

-- Update all member counts to be correct
UPDATE study_groups 
SET member_count = (
    SELECT COUNT(*) 
    FROM group_members 
    WHERE group_id = study_groups.id
);

-- Verify the fix
SELECT 
    sg.id,
    sg.name,
    sg.member_count as updated_count,
    COUNT(gm.user_id) as actual_count,
    CASE 
        WHEN sg.member_count = COUNT(gm.user_id) THEN '✅ Correct'
        ELSE '❌ Still Wrong'
    END as status
FROM study_groups sg
LEFT JOIN group_members gm ON sg.id = gm.group_id
GROUP BY sg.id, sg.name, sg.member_count
ORDER BY sg.name;

-- Show detailed member breakdown for each group
SELECT 
    sg.name as group_name,
    sg.member_count,
    gm.role,
    COUNT(*) as count_by_role
FROM study_groups sg
LEFT JOIN group_members gm ON sg.id = gm.group_id
GROUP BY sg.id, sg.name, sg.member_count, gm.role
ORDER BY sg.name, gm.role; 