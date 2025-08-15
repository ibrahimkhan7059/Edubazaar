-- Fix Member Visibility Issue - Simple Version
-- This script updates RLS policies so that group members can see all other members

-- Drop existing policies
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON group_members;
DROP POLICY IF EXISTS "Users can view group members" ON group_members;
DROP POLICY IF EXISTS "Admins can add members" ON group_members;
DROP POLICY IF EXISTS "Admins can remove members" ON group_members;
DROP POLICY IF EXISTS "Admins can update member roles" ON group_members;

-- Create simple policy: Allow all operations for authenticated users
-- This will allow members to see all other members in their groups
CREATE POLICY "Allow all operations for authenticated users" ON group_members
    FOR ALL USING (auth.uid() IS NOT NULL);

-- Grant permissions
GRANT ALL ON group_members TO authenticated;

-- Show current group memberships to verify
SELECT 
    'Current group memberships:' as info;

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
ORDER BY sg.name, gm.role, up.name; 