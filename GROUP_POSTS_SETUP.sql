-- Group Posts Setup
-- This script creates the necessary tables and policies for group posts functionality

-- Create group_posts table
CREATE TABLE IF NOT EXISTS group_posts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES study_groups(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    author_name TEXT NOT NULL,
    author_avatar TEXT,
    post_type VARCHAR(20) DEFAULT 'discussion' CHECK (post_type IN ('discussion', 'announcement', 'question', 'resource')),
    title TEXT,
    content TEXT NOT NULL,
    image_url TEXT,
    file_url TEXT,
    file_name TEXT,
    file_size INTEGER,
    like_count INTEGER DEFAULT 0,
    comment_count INTEGER DEFAULT 0,
    is_pinned BOOLEAN DEFAULT FALSE,
    is_edited BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create group_post_likes table
CREATE TABLE IF NOT EXISTS group_post_likes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID NOT NULL REFERENCES group_posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

-- Create group_post_comments table
CREATE TABLE IF NOT EXISTS group_post_comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id UUID NOT NULL REFERENCES group_posts(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    author_name TEXT NOT NULL,
    author_avatar TEXT,
    content TEXT NOT NULL,
    is_edited BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_group_posts_group_id ON group_posts(group_id);
CREATE INDEX IF NOT EXISTS idx_group_posts_author_id ON group_posts(author_id);
CREATE INDEX IF NOT EXISTS idx_group_posts_created_at ON group_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_group_posts_post_type ON group_posts(post_type);
CREATE INDEX IF NOT EXISTS idx_group_post_likes_post_id ON group_post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_group_post_likes_user_id ON group_post_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_group_post_comments_post_id ON group_post_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_group_post_comments_author_id ON group_post_comments(author_id);

-- Enable RLS
ALTER TABLE group_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_post_comments ENABLE ROW LEVEL SECURITY;

-- RLS Policies for group_posts
-- Users can view posts if they are members of the group
CREATE POLICY "Users can view group posts if they are group members" ON group_posts
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM group_members 
            WHERE group_id = group_posts.group_id 
            AND user_id = auth.uid()
        )
    );

-- Users can create posts if they are members of the group
CREATE POLICY "Group members can create posts" ON group_posts
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM group_members 
            WHERE group_id = group_posts.group_id 
            AND user_id = auth.uid()
        )
    );

-- Users can update their own posts
CREATE POLICY "Users can update their own posts" ON group_posts
    FOR UPDATE USING (author_id = auth.uid());

-- Group admins can update any post in their group
CREATE POLICY "Group admins can update any post" ON group_posts
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM group_members 
            WHERE group_id = group_posts.group_id 
            AND user_id = auth.uid() 
            AND role = 'admin'
        )
    );

-- Users can delete their own posts
CREATE POLICY "Users can delete their own posts" ON group_posts
    FOR DELETE USING (author_id = auth.uid());

-- Group admins can delete any post in their group
CREATE POLICY "Group admins can delete any post" ON group_posts
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM group_members 
            WHERE group_id = group_posts.group_id 
            AND user_id = auth.uid() 
            AND role = 'admin'
        )
    );

-- RLS Policies for group_post_likes
CREATE POLICY "Users can view post likes if they are group members" ON group_post_likes
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM group_members gm
            JOIN group_posts gp ON gm.group_id = gp.group_id
            WHERE gp.id = group_post_likes.post_id 
            AND gm.user_id = auth.uid()
        )
    );

CREATE POLICY "Group members can like posts" ON group_post_likes
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM group_members gm
            JOIN group_posts gp ON gm.group_id = gp.group_id
            WHERE gp.id = group_post_likes.post_id 
            AND gm.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can unlike their own likes" ON group_post_likes
    FOR DELETE USING (user_id = auth.uid());

-- RLS Policies for group_post_comments
CREATE POLICY "Users can view comments if they are group members" ON group_post_comments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM group_members gm
            JOIN group_posts gp ON gm.group_id = gp.group_id
            WHERE gp.id = group_post_comments.post_id 
            AND gm.user_id = auth.uid()
        )
    );

CREATE POLICY "Group members can create comments" ON group_post_comments
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM group_members gm
            JOIN group_posts gp ON gm.group_id = gp.group_id
            WHERE gp.id = group_post_comments.post_id 
            AND gm.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update their own comments" ON group_post_comments
    FOR UPDATE USING (author_id = auth.uid());

CREATE POLICY "Users can delete their own comments" ON group_post_comments
    FOR DELETE USING (author_id = auth.uid());

-- Functions for updating counts
CREATE OR REPLACE FUNCTION update_post_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE group_posts 
        SET like_count = like_count + 1 
        WHERE id = NEW.post_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE group_posts 
        SET like_count = like_count - 1 
        WHERE id = OLD.post_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_post_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE group_posts 
        SET comment_count = comment_count + 1 
        WHERE id = NEW.post_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE group_posts 
        SET comment_count = comment_count - 1 
        WHERE id = OLD.post_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Triggers for automatic count updates
DROP TRIGGER IF EXISTS trigger_update_post_like_count ON group_post_likes;
CREATE TRIGGER trigger_update_post_like_count
    AFTER INSERT OR DELETE ON group_post_likes
    FOR EACH ROW EXECUTE FUNCTION update_post_like_count();

DROP TRIGGER IF EXISTS trigger_update_post_comment_count ON group_post_comments;
CREATE TRIGGER trigger_update_post_comment_count
    AFTER INSERT OR DELETE ON group_post_comments
    FOR EACH ROW EXECUTE FUNCTION update_post_comment_count();

-- Grant permissions
GRANT ALL ON group_posts TO authenticated;
GRANT ALL ON group_post_likes TO authenticated;
GRANT ALL ON group_post_comments TO authenticated;

-- Insert sample data for testing
INSERT INTO group_posts (group_id, author_id, author_name, post_type, title, content) 
SELECT 
    sg.id,
    gm.user_id,
    up.name,
    'discussion',
    'Welcome to ' || sg.name || '!',
    'Welcome everyone! This is our first discussion post. Feel free to introduce yourself and share your thoughts.'
FROM study_groups sg
JOIN group_members gm ON sg.id = gm.group_id
JOIN user_profiles up ON gm.user_id = up.id
WHERE gm.role = 'admin'
LIMIT 1; 