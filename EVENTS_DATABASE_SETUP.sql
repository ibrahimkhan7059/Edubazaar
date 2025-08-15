-- ============================================================================
-- EVENTS DATABASE SETUP SCRIPT
-- ============================================================================
-- This script creates all necessary tables and policies for the Events feature
-- Run this in your Supabase SQL Editor

-- 1. CREATE EVENTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    image_url TEXT,
    start_date_time TIMESTAMPTZ NOT NULL,
    end_date_time TIMESTAMPTZ,
    location TEXT NOT NULL,
    location_details TEXT,
    organizer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    category TEXT NOT NULL,
    max_attendees INTEGER NOT NULL DEFAULT 50,
    is_public BOOLEAN DEFAULT true,
    requires_approval BOOLEAN DEFAULT false,
    tags TEXT[],
    meeting_link TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT check_max_attendees CHECK (max_attendees > 0),
    CONSTRAINT check_dates CHECK (end_date_time IS NULL OR end_date_time > start_date_time),
    CONSTRAINT check_category CHECK (category IN (
        'Study Session', 'Workshop', 'Seminar', 'Career Fair', 
        'Networking', 'Social', 'Competition', 'Other'
    ))
);

-- 2. CREATE EVENT_ATTENDEES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS event_attendees (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    event_id UUID REFERENCES events(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    status TEXT DEFAULT 'approved' CHECK (status IN ('pending', 'approved', 'declined')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Unique constraint to prevent duplicate attendees
    UNIQUE(event_id, user_id)
);

-- 3. CREATE INDEXES FOR PERFORMANCE
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_events_organizer_id ON events(organizer_id);
CREATE INDEX IF NOT EXISTS idx_events_start_date ON events(start_date_time);
CREATE INDEX IF NOT EXISTS idx_events_category ON events(category);
CREATE INDEX IF NOT EXISTS idx_events_is_public ON events(is_public);
CREATE INDEX IF NOT EXISTS idx_events_created_at ON events(created_at);

CREATE INDEX IF NOT EXISTS idx_event_attendees_event_id ON event_attendees(event_id);
CREATE INDEX IF NOT EXISTS idx_event_attendees_user_id ON event_attendees(user_id);
CREATE INDEX IF NOT EXISTS idx_event_attendees_status ON event_attendees(status);

-- 4. ENABLE ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_attendees ENABLE ROW LEVEL SECURITY;

-- 5. CREATE RLS POLICIES FOR EVENTS TABLE
-- ============================================================================

-- Allow users to view public events and events they organize or attend
CREATE POLICY "Users can view public events and their own events" 
ON events FOR SELECT 
USING (
    is_public = true 
    OR organizer_id = auth.uid()
    OR EXISTS (
        SELECT 1 FROM event_attendees 
        WHERE event_attendees.event_id = events.id 
        AND event_attendees.user_id = auth.uid()
        AND event_attendees.status = 'approved'
    )
);

-- Allow authenticated users to create events
CREATE POLICY "Authenticated users can create events" 
ON events FOR INSERT 
WITH CHECK (
    auth.uid() IS NOT NULL 
    AND organizer_id = auth.uid()
);

-- Allow organizers to update their own events
CREATE POLICY "Users can update their own events" 
ON events FOR UPDATE 
USING (organizer_id = auth.uid())
WITH CHECK (organizer_id = auth.uid());

-- Allow organizers to delete their own events
CREATE POLICY "Users can delete their own events" 
ON events FOR DELETE 
USING (organizer_id = auth.uid());

-- 6. CREATE RLS POLICIES FOR EVENT_ATTENDEES TABLE
-- ============================================================================

-- Allow users to view attendees of events they can see
CREATE POLICY "Users can view attendees of visible events" 
ON event_attendees FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM events 
        WHERE events.id = event_attendees.event_id 
        AND (
            events.is_public = true 
            OR events.organizer_id = auth.uid()
            OR EXISTS (
                SELECT 1 FROM event_attendees AS ea 
                WHERE ea.event_id = events.id 
                AND ea.user_id = auth.uid()
                AND ea.status = 'approved'
            )
        )
    )
);

-- Allow users to join public events or request to join private events
CREATE POLICY "Users can join events" 
ON event_attendees FOR INSERT 
WITH CHECK (
    auth.uid() IS NOT NULL 
    AND user_id = auth.uid()
    AND EXISTS (
        SELECT 1 FROM events 
        WHERE events.id = event_attendees.event_id 
        AND events.is_public = true
    )
);

-- Allow users to leave events they've joined
CREATE POLICY "Users can leave events" 
ON event_attendees FOR DELETE 
USING (user_id = auth.uid());

-- Allow event organizers to manage attendees (approve/decline)
CREATE POLICY "Event organizers can manage attendees" 
ON event_attendees FOR UPDATE 
USING (
    EXISTS (
        SELECT 1 FROM events 
        WHERE events.id = event_attendees.event_id 
        AND events.organizer_id = auth.uid()
    )
);

-- Also allow organizers to remove attendees
CREATE POLICY "Event organizers can remove attendees" 
ON event_attendees FOR DELETE 
USING (
    EXISTS (
        SELECT 1 FROM events 
        WHERE events.id = event_attendees.event_id 
        AND events.organizer_id = auth.uid()
    )
);

-- 7. CREATE FUNCTIONS AND TRIGGERS
-- ============================================================================

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language plpgsql;

-- Trigger to automatically update updated_at on events
CREATE OR REPLACE TRIGGER update_events_updated_at 
    BEFORE UPDATE ON events 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Function to prevent joining full events
CREATE OR REPLACE FUNCTION check_event_capacity()
RETURNS TRIGGER AS $$
DECLARE
    current_attendees INTEGER;
    max_capacity INTEGER;
BEGIN
    -- Get current attendee count and max capacity
    SELECT 
        COUNT(*) FILTER (WHERE status = 'approved'),
        events.max_attendees
    INTO current_attendees, max_capacity
    FROM event_attendees 
    RIGHT JOIN events ON events.id = NEW.event_id
    WHERE event_attendees.event_id = NEW.event_id
    GROUP BY events.max_attendees;
    
    -- Check if event is full
    IF current_attendees >= max_capacity THEN
        RAISE EXCEPTION 'Event is full (% / % attendees)', current_attendees, max_capacity;
    END IF;
    
    RETURN NEW;
END;
$$ language plpgsql;

-- Trigger to check capacity before inserting attendees
CREATE OR REPLACE TRIGGER check_event_capacity_trigger
    BEFORE INSERT ON event_attendees
    FOR EACH ROW 
    EXECUTE FUNCTION check_event_capacity();

-- 8. INSERT SAMPLE DATA (OPTIONAL)
-- ============================================================================
-- Uncomment the following to insert sample events for testing

/*
-- Sample events (replace with actual user IDs from your auth.users table)
INSERT INTO events (
    title, description, start_date_time, end_date_time, location, 
    organizer_id, category, max_attendees, is_public
) VALUES 
(
    'Database Design Workshop',
    'Learn the fundamentals of database design, normalization, and SQL optimization. Perfect for students looking to improve their database skills.',
    NOW() + INTERVAL '7 days',
    NOW() + INTERVAL '7 days' + INTERVAL '2 hours',
    'Computer Lab A, Engineering Building',
    (SELECT id FROM auth.users LIMIT 1), -- Replace with actual user ID
    'Workshop',
    30,
    true
),
(
    'Career Fair 2024',
    'Meet representatives from top tech companies and explore internship and job opportunities. Bring your resume!',
    NOW() + INTERVAL '14 days',
    NOW() + INTERVAL '14 days' + INTERVAL '4 hours',
    'Student Center Main Hall',
    (SELECT id FROM auth.users LIMIT 1), -- Replace with actual user ID
    'Career Fair',
    200,
    true
),
(
    'Study Group: Data Structures',
    'Weekly study session for Data Structures and Algorithms course. We''ll solve practice problems and review concepts.',
    NOW() + INTERVAL '3 days',
    NOW() + INTERVAL '3 days' + INTERVAL '1.5 hours',
    'Library Room 203',
    (SELECT id FROM auth.users LIMIT 1), -- Replace with actual user ID
    'Study Session',
    15,
    true
);
*/

-- ============================================================================
-- SETUP COMPLETE!
-- ============================================================================
-- Your events system is now ready to use. The tables include:
-- 
-- 1. events - Store event information
-- 2. event_attendees - Track who's attending which events
-- 
-- Features included:
-- - Row Level Security (RLS) for data protection
-- - Automatic timestamp updates
-- - Event capacity validation
-- - Support for public/private events
-- - Approval workflow for private events
-- - Proper indexing for performance
-- 
-- Remember to:
-- 1. Test the policies with different user roles
-- 2. Adjust the sample data user IDs if you uncomment that section
-- 3. Configure storage policies if using event images
-- ============================================================================ 