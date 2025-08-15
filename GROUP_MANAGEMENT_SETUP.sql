-- GROUP MANAGEMENT SETUP
-- This script sets up the necessary policies for group management

-- Enable RLS on study_groups table (if not already enabled)
ALTER TABLE study_groups ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Admins can update groups" ON study_groups;
DROP POLICY IF EXISTS "Admins can delete groups" ON study_groups;

-- Policy: Only admins can update their groups
CREATE POLICY "Admins can update groups" ON study_groups
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM group_members gm
            WHERE gm.group_id = study_groups.id
            AND gm.user_id = auth.uid()
            AND gm.role = 'admin'
        )
    );

-- Policy: Only admins can delete their groups
CREATE POLICY "Admins can delete groups" ON study_groups
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM group_members gm
            WHERE gm.group_id = study_groups.id
            AND gm.user_id = auth.uid()
            AND gm.role = 'admin'
        )
    );

-- Grant permissions on study_groups table
GRANT SELECT, INSERT, UPDATE, DELETE ON study_groups TO authenticated;

-- Group management setup completed successfully! 