-- SIMPLE MEMBER MANAGEMENT POLICIES
-- This script creates simpler, more permissive policies for testing

-- Enable RLS on group_members table
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies
DROP POLICY IF EXISTS "Users can view group members" ON group_members;
DROP POLICY IF EXISTS "Admins can add members" ON group_members;
DROP POLICY IF EXISTS "Admins can remove members" ON group_members;
DROP POLICY IF EXISTS "Admins can update member roles" ON group_members;

-- Simple policy: Allow all operations for authenticated users (for testing)
CREATE POLICY "Allow all operations for authenticated users" ON group_members
    FOR ALL USING (auth.uid() IS NOT NULL);

-- Grant permissions
GRANT ALL ON group_members TO authenticated;

-- Simple member management setup completed! 