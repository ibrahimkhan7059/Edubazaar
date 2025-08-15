-- =====================================================
-- CREATE COMMUNITY TABLES IF NOT EXISTS
-- =====================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- STUDY GROUPS TABLES
-- =====================================================

-- Study Groups table
CREATE TABLE IF NOT EXISTS study_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    subject VARCHAR(100) NOT NULL,
    max_members INTEGER DEFAULT 50,
    is_private BOOLEAN DEFAULT false,
    creator_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    tags TEXT[] DEFAULT '{}',
    cover_image_url TEXT,
    rules TEXT,
    meeting_schedule TEXT
);

-- Group Members table
CREATE TABLE IF NOT EXISTS group_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID REFERENCES study_groups(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'member' CHECK (role IN ('admin', 'moderator', 'member')),
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(group_id, user_id)
);

-- Group Posts table
CREATE TABLE IF NOT EXISTS group_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID REFERENCES study_groups(id) ON DELETE CASCADE,
    author_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    post_type VARCHAR(20) DEFAULT 'discussion' CHECK (post_type IN ('discussion', 'announcement', 'question', 'resource')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    like_count INTEGER DEFAULT 0,
    comment_count INTEGER DEFAULT 0,
    is_pinned BOOLEAN DEFAULT false
);

-- =====================================================
-- FORUM TABLES
-- =====================================================

-- Forum Topics table
CREATE TABLE IF NOT EXISTS forum_topics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    category VARCHAR(50) NOT NULL,
    author_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    view_count INTEGER DEFAULT 0,
    reply_count INTEGER DEFAULT 0,
    like_count INTEGER DEFAULT 0,
    is_sticky BOOLEAN DEFAULT false,
    is_locked BOOLEAN DEFAULT false,
    tags TEXT[] DEFAULT '{}',
    last_reply_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Forum Replies table
CREATE TABLE IF NOT EXISTS forum_replies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    topic_id UUID REFERENCES forum_topics(id) ON DELETE CASCADE,
    author_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    like_count INTEGER DEFAULT 0,
    is_solution BOOLEAN DEFAULT false,
    parent_reply_id UUID REFERENCES forum_replies(id) ON DELETE CASCADE
);

-- =====================================================
-- EVENTS TABLES
-- =====================================================

-- Community Events table
CREATE TABLE IF NOT EXISTS community_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    event_date TIMESTAMP WITH TIME ZONE NOT NULL,
    location VARCHAR(255),
    organizer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    max_participants INTEGER,
    current_participants INTEGER DEFAULT 0,
    is_online BOOLEAN DEFAULT false,
    meeting_link TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    event_type VARCHAR(50) DEFAULT 'study' CHECK (event_type IN ('study', 'social', 'academic', 'workshop')),
    tags TEXT[] DEFAULT '{}',
    cover_image_url TEXT,
    registration_deadline TIMESTAMP WITH TIME ZONE
);

-- Event Participants table
CREATE TABLE IF NOT EXISTS event_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID REFERENCES community_events(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'registered' CHECK (status IN ('registered', 'attended', 'cancelled')),
    registered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(event_id, user_id)
);

-- =====================================================
-- RESOURCES TABLES
-- =====================================================

-- Study Resources table
CREATE TABLE IF NOT EXISTS study_resources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    file_url TEXT NOT NULL,
    file_type VARCHAR(20) NOT NULL,
    file_size INTEGER NOT NULL,
    subject VARCHAR(100) NOT NULL,
    uploader_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    download_count INTEGER DEFAULT 0,
    like_count INTEGER DEFAULT 0,
    tags TEXT[] DEFAULT '{}',
    thumbnail_url TEXT,
    is_approved BOOLEAN DEFAULT true,
    academic_level VARCHAR(50) DEFAULT 'undergraduate' CHECK (academic_level IN ('high_school', 'undergraduate', 'graduate', 'professional'))
);

-- Resource Likes table
CREATE TABLE IF NOT EXISTS resource_likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    resource_id UUID REFERENCES study_resources(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(resource_id, user_id)
);

-- Resource Downloads table
CREATE TABLE IF NOT EXISTS resource_downloads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    resource_id UUID REFERENCES study_resources(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    downloaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- INDEXES FOR PERFORMANCE (IF NOT EXISTS)
-- =====================================================

-- Study Groups indexes
CREATE INDEX IF NOT EXISTS idx_study_groups_creator_id ON study_groups(creator_id);
CREATE INDEX IF NOT EXISTS idx_study_groups_subject ON study_groups(subject);
CREATE INDEX IF NOT EXISTS idx_study_groups_created_at ON study_groups(created_at);
CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user_id ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_group_posts_group_id ON group_posts(group_id);
CREATE INDEX IF NOT EXISTS idx_group_posts_author_id ON group_posts(author_id);
CREATE INDEX IF NOT EXISTS idx_group_posts_created_at ON group_posts(created_at);

-- Forum indexes
CREATE INDEX IF NOT EXISTS idx_forum_topics_author_id ON forum_topics(author_id);
CREATE INDEX IF NOT EXISTS idx_forum_topics_category ON forum_topics(category);
CREATE INDEX IF NOT EXISTS idx_forum_topics_created_at ON forum_topics(created_at);
CREATE INDEX IF NOT EXISTS idx_forum_topics_last_reply_at ON forum_topics(last_reply_at);
CREATE INDEX IF NOT EXISTS idx_forum_replies_topic_id ON forum_replies(topic_id);
CREATE INDEX IF NOT EXISTS idx_forum_replies_author_id ON forum_replies(author_id);
CREATE INDEX IF NOT EXISTS idx_forum_replies_created_at ON forum_replies(created_at);

-- Events indexes
CREATE INDEX IF NOT EXISTS idx_community_events_organizer_id ON community_events(organizer_id);
CREATE INDEX IF NOT EXISTS idx_community_events_event_date ON community_events(event_date);
CREATE INDEX IF NOT EXISTS idx_community_events_event_type ON community_events(event_type);
CREATE INDEX IF NOT EXISTS idx_event_participants_event_id ON event_participants(event_id);
CREATE INDEX IF NOT EXISTS idx_event_participants_user_id ON event_participants(user_id);

-- Resources indexes
CREATE INDEX IF NOT EXISTS idx_study_resources_uploader_id ON study_resources(uploader_id);
CREATE INDEX IF NOT EXISTS idx_study_resources_subject ON study_resources(subject);
CREATE INDEX IF NOT EXISTS idx_study_resources_created_at ON study_resources(created_at);
CREATE INDEX IF NOT EXISTS idx_study_resources_academic_level ON study_resources(academic_level);
CREATE INDEX IF NOT EXISTS idx_resource_likes_resource_id ON resource_likes(resource_id);
CREATE INDEX IF NOT EXISTS idx_resource_likes_user_id ON resource_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_resource_downloads_resource_id ON resource_downloads(resource_id);
CREATE INDEX IF NOT EXISTS idx_resource_downloads_user_id ON resource_downloads(user_id);

-- =====================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE study_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE forum_replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE resource_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE resource_downloads ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist and recreate them
DROP POLICY IF EXISTS "Study groups are viewable by everyone" ON study_groups;
DROP POLICY IF EXISTS "Users can create study groups" ON study_groups;
DROP POLICY IF EXISTS "Creators can update their study groups" ON study_groups;
DROP POLICY IF EXISTS "Creators can delete their study groups" ON study_groups;

DROP POLICY IF EXISTS "Group members are viewable by group members" ON group_members;
DROP POLICY IF EXISTS "Users can join public groups" ON group_members;
DROP POLICY IF EXISTS "Users can leave groups" ON group_members;

DROP POLICY IF EXISTS "Group posts are viewable by group members" ON group_posts;
DROP POLICY IF EXISTS "Group members can create posts" ON group_posts;
DROP POLICY IF EXISTS "Authors can update their posts" ON group_posts;
DROP POLICY IF EXISTS "Authors and admins can delete posts" ON group_posts;

DROP POLICY IF EXISTS "Forum topics are viewable by everyone" ON forum_topics;
DROP POLICY IF EXISTS "Authenticated users can create forum topics" ON forum_topics;
DROP POLICY IF EXISTS "Authors can update their forum topics" ON forum_topics;
DROP POLICY IF EXISTS "Authors can delete their forum topics" ON forum_topics;

DROP POLICY IF EXISTS "Forum replies are viewable by everyone" ON forum_replies;
DROP POLICY IF EXISTS "Authenticated users can create forum replies" ON forum_replies;
DROP POLICY IF EXISTS "Authors can update their forum replies" ON forum_replies;
DROP POLICY IF EXISTS "Authors can delete their forum replies" ON forum_replies;

DROP POLICY IF EXISTS "Community events are viewable by everyone" ON community_events;
DROP POLICY IF EXISTS "Authenticated users can create events" ON community_events;
DROP POLICY IF EXISTS "Organizers can update their events" ON community_events;
DROP POLICY IF EXISTS "Organizers can delete their events" ON community_events;

DROP POLICY IF EXISTS "Event participants are viewable by event participants" ON event_participants;
DROP POLICY IF EXISTS "Users can register for events" ON event_participants;
DROP POLICY IF EXISTS "Users can update their participation status" ON event_participants;
DROP POLICY IF EXISTS "Users can cancel their participation" ON event_participants;

DROP POLICY IF EXISTS "Study resources are viewable by everyone" ON study_resources;
DROP POLICY IF EXISTS "Authenticated users can upload resources" ON study_resources;
DROP POLICY IF EXISTS "Uploaders can update their resources" ON study_resources;
DROP POLICY IF EXISTS "Uploaders can delete their resources" ON study_resources;

DROP POLICY IF EXISTS "Resource likes are viewable by everyone" ON resource_likes;
DROP POLICY IF EXISTS "Authenticated users can like resources" ON resource_likes;
DROP POLICY IF EXISTS "Users can unlike resources" ON resource_likes;

DROP POLICY IF EXISTS "Resource downloads are viewable by uploaders" ON resource_downloads;
DROP POLICY IF EXISTS "Authenticated users can download resources" ON resource_downloads;

-- Study Groups policies
CREATE POLICY "Study groups are viewable by everyone" ON study_groups
    FOR SELECT USING (true);

CREATE POLICY "Users can create study groups" ON study_groups
    FOR INSERT WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "Creators can update their study groups" ON study_groups
    FOR UPDATE USING (auth.uid() = creator_id);

CREATE POLICY "Creators can delete their study groups" ON study_groups
    FOR DELETE USING (auth.uid() = creator_id);

-- Group Members policies
CREATE POLICY "Group members are viewable by group members" ON group_members
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM group_members gm 
            WHERE gm.group_id = group_members.group_id 
            AND gm.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can join public groups" ON group_members
    FOR INSERT WITH CHECK (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM study_groups sg 
            WHERE sg.id = group_id 
            AND sg.is_private = false
        )
    );

CREATE POLICY "Users can leave groups" ON group_members
    FOR DELETE USING (auth.uid() = user_id);

-- Group Posts policies
CREATE POLICY "Group posts are viewable by group members" ON group_posts
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM group_members gm 
            WHERE gm.group_id = group_posts.group_id 
            AND gm.user_id = auth.uid()
        )
    );

CREATE POLICY "Group members can create posts" ON group_posts
    FOR INSERT WITH CHECK (
        auth.uid() = author_id AND
        EXISTS (
            SELECT 1 FROM group_members gm 
            WHERE gm.group_id = group_posts.group_id 
            AND gm.user_id = auth.uid()
        )
    );

CREATE POLICY "Authors can update their posts" ON group_posts
    FOR UPDATE USING (auth.uid() = author_id);

CREATE POLICY "Authors and admins can delete posts" ON group_posts
    FOR DELETE USING (
        auth.uid() = author_id OR
        EXISTS (
            SELECT 1 FROM group_members gm 
            WHERE gm.group_id = group_posts.group_id 
            AND gm.user_id = auth.uid() 
            AND gm.role IN ('admin', 'moderator')
        )
    );

-- Forum Topics policies
CREATE POLICY "Forum topics are viewable by everyone" ON forum_topics
    FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create forum topics" ON forum_topics
    FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Authors can update their forum topics" ON forum_topics
    FOR UPDATE USING (auth.uid() = author_id);

CREATE POLICY "Authors can delete their forum topics" ON forum_topics
    FOR DELETE USING (auth.uid() = author_id);

-- Forum Replies policies
CREATE POLICY "Forum replies are viewable by everyone" ON forum_replies
    FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create forum replies" ON forum_replies
    FOR INSERT WITH CHECK (auth.uid() = author_id);

CREATE POLICY "Authors can update their forum replies" ON forum_replies
    FOR UPDATE USING (auth.uid() = author_id);

CREATE POLICY "Authors can delete their forum replies" ON forum_replies
    FOR DELETE USING (auth.uid() = author_id);

-- Community Events policies
CREATE POLICY "Community events are viewable by everyone" ON community_events
    FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create events" ON community_events
    FOR INSERT WITH CHECK (auth.uid() = organizer_id);

CREATE POLICY "Organizers can update their events" ON community_events
    FOR UPDATE USING (auth.uid() = organizer_id);

CREATE POLICY "Organizers can delete their events" ON community_events
    FOR DELETE USING (auth.uid() = organizer_id);

-- Event Participants policies
CREATE POLICY "Event participants are viewable by event participants" ON event_participants
    FOR SELECT USING (
        user_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM community_events ce 
            WHERE ce.id = event_participants.event_id 
            AND ce.organizer_id = auth.uid()
        )
    );

CREATE POLICY "Users can register for events" ON event_participants
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their participation status" ON event_participants
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can cancel their participation" ON event_participants
    FOR DELETE USING (auth.uid() = user_id);

-- Study Resources policies
CREATE POLICY "Study resources are viewable by everyone" ON study_resources
    FOR SELECT USING (is_approved = true);

CREATE POLICY "Authenticated users can upload resources" ON study_resources
    FOR INSERT WITH CHECK (auth.uid() = uploader_id);

CREATE POLICY "Uploaders can update their resources" ON study_resources
    FOR UPDATE USING (auth.uid() = uploader_id);

CREATE POLICY "Uploaders can delete their resources" ON study_resources
    FOR DELETE USING (auth.uid() = uploader_id);

-- Resource Likes policies
CREATE POLICY "Resource likes are viewable by everyone" ON resource_likes
    FOR SELECT USING (true);

CREATE POLICY "Authenticated users can like resources" ON resource_likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can unlike resources" ON resource_likes
    FOR DELETE USING (auth.uid() = user_id);

-- Resource Downloads policies
CREATE POLICY "Resource downloads are viewable by uploaders" ON resource_downloads
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM study_resources sr 
            WHERE sr.id = resource_downloads.resource_id 
            AND sr.uploader_id = auth.uid()
        )
    );

CREATE POLICY "Authenticated users can download resources" ON resource_downloads
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- =====================================================
-- TRIGGERS AND FUNCTIONS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS update_study_groups_updated_at ON study_groups;
DROP TRIGGER IF EXISTS update_group_posts_updated_at ON group_posts;
DROP TRIGGER IF EXISTS update_forum_topics_updated_at ON forum_topics;
DROP TRIGGER IF EXISTS update_forum_replies_updated_at ON forum_replies;
DROP TRIGGER IF EXISTS update_community_events_updated_at ON community_events;
DROP TRIGGER IF EXISTS update_study_resources_updated_at ON study_resources;

-- Apply updated_at triggers to all tables
CREATE TRIGGER update_study_groups_updated_at BEFORE UPDATE ON study_groups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_group_posts_updated_at BEFORE UPDATE ON group_posts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_forum_topics_updated_at BEFORE UPDATE ON forum_topics
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_forum_replies_updated_at BEFORE UPDATE ON forum_replies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_community_events_updated_at BEFORE UPDATE ON community_events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_study_resources_updated_at BEFORE UPDATE ON study_resources
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to update reply count and last reply time
CREATE OR REPLACE FUNCTION update_forum_topic_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE forum_topics 
        SET reply_count = reply_count + 1,
            last_reply_at = NOW()
        WHERE id = NEW.topic_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE forum_topics 
        SET reply_count = reply_count - 1
        WHERE id = OLD.topic_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

-- Drop and recreate forum reply count trigger
DROP TRIGGER IF EXISTS update_forum_topic_reply_count ON forum_replies;
CREATE TRIGGER update_forum_topic_reply_count 
    AFTER INSERT OR DELETE ON forum_replies
    FOR EACH ROW EXECUTE FUNCTION update_forum_topic_stats();

-- Function to update event participant count
CREATE OR REPLACE FUNCTION update_event_participant_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE community_events 
        SET current_participants = current_participants + 1
        WHERE id = NEW.event_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE community_events 
        SET current_participants = current_participants - 1
        WHERE id = OLD.event_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

-- Drop and recreate event participant count trigger
DROP TRIGGER IF EXISTS update_event_participant_count_trigger ON event_participants;
CREATE TRIGGER update_event_participant_count_trigger 
    AFTER INSERT OR DELETE ON event_participants
    FOR EACH ROW EXECUTE FUNCTION update_event_participant_count();

-- Function to update resource like count
CREATE OR REPLACE FUNCTION update_resource_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE study_resources 
        SET like_count = like_count + 1
        WHERE id = NEW.resource_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE study_resources 
        SET like_count = like_count - 1
        WHERE id = OLD.resource_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

-- Drop and recreate resource like count trigger
DROP TRIGGER IF EXISTS update_resource_like_count_trigger ON resource_likes;
CREATE TRIGGER update_resource_like_count_trigger 
    AFTER INSERT OR DELETE ON resource_likes
    FOR EACH ROW EXECUTE FUNCTION update_resource_like_count();

-- Function to update resource download count
CREATE OR REPLACE FUNCTION update_resource_download_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE study_resources 
        SET download_count = download_count + 1
        WHERE id = NEW.resource_id;
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

-- Drop and recreate resource download count trigger
DROP TRIGGER IF EXISTS update_resource_download_count_trigger ON resource_downloads;
CREATE TRIGGER update_resource_download_count_trigger 
    AFTER INSERT ON resource_downloads
    FOR EACH ROW EXECUTE FUNCTION update_resource_download_count();

-- Function to update group member count
CREATE OR REPLACE FUNCTION update_group_member_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE study_groups 
        SET max_members = COALESCE(max_members, 50)
        WHERE id = NEW.group_id;
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ language 'plpgsql';

-- Drop and recreate group member count trigger
DROP TRIGGER IF EXISTS update_group_member_count_trigger ON group_members;
CREATE TRIGGER update_group_member_count_trigger 
    AFTER INSERT ON group_members
    FOR EACH ROW EXECUTE FUNCTION update_group_member_count();

-- =====================================================
-- VERIFICATION
-- =====================================================

-- Check if all tables were created successfully
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN (
    'study_groups', 'group_members', 'group_posts',
    'forum_topics', 'forum_replies',
    'community_events', 'event_participants',
    'study_resources', 'resource_likes', 'resource_downloads'
)
ORDER BY table_name;

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================

-- 🎉 COMMUNITY TABLES SETUP COMPLETE! 🎉
-- 
-- All community tables have been created or updated!
-- You can now use all community features in your EduBazaar app.
-- 
-- Next steps:
-- 1. Create storage buckets for community features
-- 2. Test the community features in your app
-- 3. Implement the detail screens for each community feature 
 
 