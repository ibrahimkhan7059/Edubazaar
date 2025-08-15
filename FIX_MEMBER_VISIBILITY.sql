-- Fix Member Visibility Issue
-- This script updates RLS policies so that group members can see all other members

-- First, let's see the current state
SELECT 
    'Current group_members policies' as info;
    
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'group_members';

-- Drop existing policies
DROP POLICY IF EXISTS "Allow all operations for authenticated users" ON group_members;
DROP POLICY IF EXISTS "Users can view group members" ON group_members;
DROP POLICY IF EXISTS "Admins can add members" ON group_members;
DROP POLICY IF EXISTS "Admins can remove members" ON group_members;
DROP POLICY IF EXISTS "Admins can update member roles" ON group_members;

-- Create proper policies for group_members table
-- Policy 1: Users can view members of groups they belong to
CREATE POLICY "Users can view group members" ON group_members
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM group_members gm2 
            WHERE gm2.group_id = group_members.group_id 
            AND gm2.user_id = auth.uid()
        )
    );

-- Policy 2: Users can insert themselves (join groups)
CREATE POLICY "Users can join groups" ON group_members
    FOR INSERT WITH CHECK (
        user_id = auth.uid()
    );

-- Policy 3: Users can delete themselves (leave groups)
CREATE POLICY "Users can leave groups" ON group_members
    FOR DELETE USING (
        user_id = auth.uid()
    );

-- Policy 4: Admins can add members
CREATE POLICY "Admins can add members" ON group_members
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM group_members gm2 
            WHERE gm2.group_id = group_members.group_id 
            AND gm2.user_id = auth.uid()
            AND gm2.role = 'admin'
        )
    );

-- Policy 5: Admins can remove members
CREATE POLICY "Admins can remove members" ON group_members
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM group_members gm2 
            WHERE gm2.group_id = group_members.group_id 
            AND gm2.user_id = auth.uid()
            AND gm2.role = 'admin'
        )
    );

-- Policy 6: Admins can update member roles
CREATE POLICY "Admins can update member roles" ON group_members
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM group_members gm2 
            WHERE gm2.group_id = group_members.group_id 
            AND gm2.user_id = auth.uid()
            AND gm2.role = 'admin'
        )
    );

-- Grant permissions
GRANT ALL ON group_members TO authenticated;

-- Test the policies by showing what members each user can see
SELECT 
    'Testing member visibility' as info;

-- Show all group memberships
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