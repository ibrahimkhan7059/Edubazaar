-- Fix Member Count Update Issue
-- This script ensures member counts are updated correctly when users join/leave

-- First, let's check if the trigger function exists
SELECT 
    'Checking trigger function:' as info;

SELECT 
    proname as function_name,
    prosrc as function_source
FROM pg_proc 
WHERE proname = 'update_group_member_count';

-- Check if the trigger exists
SELECT 
    'Checking triggers:' as info;

SELECT 
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    tgtype,
    tgenabled
FROM pg_trigger 
WHERE tgname LIKE '%member_count%';

-- Drop and recreate the trigger function
DROP FUNCTION IF EXISTS update_group_member_count() CASCADE;

CREATE OR REPLACE FUNCTION update_group_member_count()
RETURNS TRIGGER AS $$
BEGIN
    -- Update member count for the affected group
    UPDATE study_groups 
    SET member_count = (
        SELECT COUNT(*) 
        FROM group_members 
        WHERE group_id = COALESCE(NEW.group_id, OLD.group_id)
    )
    WHERE id = COALESCE(NEW.group_id, OLD.group_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER update_group_member_count_trigger
    AFTER INSERT OR DELETE ON group_members
    FOR EACH ROW EXECUTE FUNCTION update_group_member_count();

-- Update all existing member counts to be correct
UPDATE study_groups 
SET member_count = (
    SELECT COUNT(*) 
    FROM group_members 
    WHERE group_id = study_groups.id
);

-- Show the results
SELECT 
    'Updated member counts:' as info;

SELECT 
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