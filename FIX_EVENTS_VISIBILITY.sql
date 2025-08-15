-- ============================================================================
-- FIX EVENTS VISIBILITY - ALLOW ALL USERS TO SEE ALL EVENTS
-- ============================================================================
-- This script fixes the issue where users can't see events created by other users
-- Run this in your Supabase SQL Editor

-- 1. DROP THE EXISTING RESTRICTIVE POLICY
-- ============================================================================
DROP POLICY IF EXISTS "events_select_policy" ON events;

-- 2. CREATE A NEW POLICY THAT ALLOWS ALL AUTHENTICATED USERS TO SEE ALL EVENTS
-- ============================================================================
CREATE POLICY "events_select_policy" 
ON events FOR SELECT 
USING (auth.uid() IS NOT NULL);

-- 3. VERIFY THE POLICY IS WORKING
-- ============================================================================
-- You can test with this query:
-- SELECT id, title, organizer_id, is_public, requires_approval FROM events LIMIT 10;

-- 4. EXPLANATION OF THE FIX
-- ============================================================================
-- BEFORE: Users could only see:
--   - Public events (is_public = true)
--   - Events they organize (organizer_id = auth.uid())
--
-- AFTER: All authenticated users can see ALL events, including:
--   - Public events
--   - Private events (is_public = false)
--   - Events requiring approval
--   - Events created by any user
--
-- This fixes the issue where upcoming events from other users weren't showing up
-- because they were private or required approval.

-- 5. IF YOU WANT TO REVERT LATER (optional)
-- ============================================================================
-- To revert to the restrictive policy, run:
/*
DROP POLICY IF EXISTS "events_select_policy" ON events;

CREATE POLICY "events_select_policy" 
ON events FOR SELECT 
USING (
    is_public = true 
    OR organizer_id = auth.uid()
);
*/ 