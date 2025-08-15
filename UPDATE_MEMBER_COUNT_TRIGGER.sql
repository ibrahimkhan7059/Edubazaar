-- Update Member Count Trigger
-- This trigger automatically updates the member_count in study_groups table
-- when users join or leave groups

-- Function to update member count
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

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS trigger_update_member_count_insert ON group_members;
DROP TRIGGER IF EXISTS trigger_update_member_count_delete ON group_members;

-- Create triggers for insert and delete
CREATE TRIGGER trigger_update_member_count_insert
    AFTER INSERT ON group_members
    FOR EACH ROW
    EXECUTE FUNCTION update_group_member_count();

CREATE TRIGGER trigger_update_member_count_delete
    AFTER DELETE ON group_members
    FOR EACH ROW
    EXECUTE FUNCTION update_group_member_count();

-- Update existing groups with correct member counts
UPDATE study_groups 
SET member_count = (
    SELECT COUNT(*) 
    FROM group_members 
    WHERE group_id = study_groups.id
); 