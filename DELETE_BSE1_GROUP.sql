-- Delete BSE1 Group
-- This script will remove the BSE1 group and all its related data

-- First, let's see what we're about to delete
SELECT 
    'Finding BSE1 group:' as info;

SELECT 
    id,
    name,
    creator_id,
    member_count,
    created_at
FROM study_groups 
WHERE name ILIKE '%BSE1%';

-- Show all members of this group
SELECT 
    'Members of BSE1 group:' as info;

SELECT 
    gm.group_id,
    sg.name as group_name,
    gm.user_id,
    up.name as user_name,
    gm.role,
    gm.joined_at
FROM group_members gm
JOIN study_groups sg ON gm.group_id = sg.id
JOIN user_profiles up ON gm.user_id = up.id
WHERE sg.name ILIKE '%BSE1%';

-- Delete in the correct order (due to foreign key constraints)
-- 1. Delete group members first
DELETE FROM group_members 
WHERE group_id IN (
    SELECT id FROM study_groups 
    WHERE name ILIKE '%BSE1%'
);

-- 2. Delete the study group
DELETE FROM study_groups 
WHERE name ILIKE '%BSE1%';

-- Verify deletion
SELECT 
    'Verification - Remaining groups:' as info;

SELECT 
    id,
    name,
    creator_id,
    member_count,
    created_at
FROM study_groups 
ORDER BY created_at DESC; 