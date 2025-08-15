-- Verify and fix member count trigger
-- Run this in your Supabase SQL editor

-- 1. Check if the trigger function exists
SELECT 
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'update_group_member_count';

-- 2. Check if the trigger exists
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'trigger_update_group_member_count';

-- 3. Drop and recreate the trigger function to ensure it's correct
DROP FUNCTION IF EXISTS update_group_member_count() CASCADE;

CREATE OR REPLACE FUNCTION update_group_member_count()
RETURNS TRIGGER AS $$
BEGIN
    -- Update member_count for the affected group
    IF TG_OP = 'INSERT' THEN
        UPDATE study_groups 
        SET member_count = (
            SELECT COUNT(*) 
            FROM group_members 
            WHERE group_id = NEW.group_id
        )
        WHERE id = NEW.group_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE study_groups 
        SET member_count = (
            SELECT COUNT(*) 
            FROM group_members 
            WHERE group_id = OLD.group_id
        )
        WHERE id = OLD.group_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 4. Create the trigger
DROP TRIGGER IF EXISTS trigger_update_group_member_count ON group_members;

CREATE TRIGGER trigger_update_group_member_count
    AFTER INSERT OR DELETE ON group_members
    FOR EACH ROW
    EXECUTE FUNCTION update_group_member_count();

-- 5. Test the trigger by updating all groups
UPDATE study_groups 
SET member_count = (
    SELECT COUNT(*) 
    FROM group_members 
    WHERE group_members.group_id = study_groups.id
);

-- 6. Verify the counts are correct
SELECT 
    sg.id,
    sg.name,
    sg.member_count,
    COUNT(gm.id) as actual_member_count
FROM study_groups sg
LEFT JOIN group_members gm ON sg.id = gm.group_id
GROUP BY sg.id, sg.name, sg.member_count
ORDER BY sg.name; 