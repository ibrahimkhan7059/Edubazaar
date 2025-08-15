-- MEMBER MANAGEMENT SETUP
-- This script sets up the necessary policies and functions for member management

-- Enable RLS on group_members table (if not already enabled)
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view group members" ON group_members;
DROP POLICY IF EXISTS "Admins can add members" ON group_members;
DROP POLICY IF EXISTS "Admins can remove members" ON group_members;
DROP POLICY IF EXISTS "Admins can update member roles" ON group_members;

-- Policy: Users can view members of groups they are members of
CREATE POLICY "Users can view group members" ON group_members
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM group_members gm
            WHERE gm.group_id = group_members.group_id
            AND gm.user_id = auth.uid()
        )
    );

-- Policy: Only admins can add members to their groups
CREATE POLICY "Admins can add members" ON group_members
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM group_members gm
            WHERE gm.group_id = group_members.group_id
            AND gm.user_id = auth.uid()
            AND gm.role = 'admin'
        )
    );

-- Policy: Only admins can remove members from their groups (except themselves)
CREATE POLICY "Admins can remove members" ON group_members
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM group_members gm
            WHERE gm.group_id = group_members.group_id
            AND gm.user_id = auth.uid()
            AND gm.role = 'admin'
        )
        AND user_id != auth.uid() -- Cannot remove yourself
    );

-- Policy: Only admins can update member roles
CREATE POLICY "Admins can update member roles" ON group_members
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM group_members gm
            WHERE gm.group_id = group_members.group_id
            AND gm.user_id = auth.uid()
            AND gm.role = 'admin'
        )
    );

-- Function to check if user is admin of a group
CREATE OR REPLACE FUNCTION is_group_admin(group_id UUID, user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM group_members
        WHERE group_members.group_id = $1
        AND group_members.user_id = $2
        AND group_members.role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to search users by name or email
CREATE OR REPLACE FUNCTION search_users(search_query TEXT)
RETURNS TABLE (
    id UUID,
    name TEXT,
    email TEXT,
    profile_pic_url TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        up.id,
        up.name,
        up.email,
        up.profile_pic_url
    FROM user_profiles up
    WHERE up.name ILIKE '%' || search_query || '%'
    OR up.email ILIKE '%' || search_query || '%'
    ORDER BY up.name ASC
    LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION is_group_admin(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION search_users(TEXT) TO authenticated;

-- Grant permissions on group_members table
GRANT SELECT, INSERT, UPDATE, DELETE ON group_members TO authenticated;

-- Member management setup completed successfully! 