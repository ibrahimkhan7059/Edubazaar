-- ============================================
-- EduBazaar Messaging System Database Schema (FIXED)
-- ============================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Conversations Table (Chat rooms between users)
CREATE TABLE IF NOT EXISTS conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    participant_1_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    participant_2_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    listing_id UUID REFERENCES listings(id) ON DELETE SET NULL, -- Optional: conversation about specific listing
    last_message_id UUID, -- Will reference messages(id) after messages table is created
    last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    participant_1_unread_count INTEGER DEFAULT 0,
    participant_2_unread_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure participants are different users
    CONSTRAINT different_participants CHECK (participant_1_id != participant_2_id)
);

-- Messages Table (Individual messages within conversations)
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE NOT NULL,
    sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    message_text TEXT NOT NULL,
    message_type TEXT DEFAULT 'text', -- 'text', 'image', 'listing_share', 'system'
    attachment_url TEXT, -- For images or files
    listing_reference_id UUID REFERENCES listings(id) ON DELETE SET NULL, -- For shared listings
    is_read BOOLEAN DEFAULT FALSE,
    is_edited BOOLEAN DEFAULT FALSE,
    edited_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create unique index for preventing duplicate conversations (same participants in any order)
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_conversation 
ON conversations (LEAST(participant_1_id, participant_2_id), GREATEST(participant_1_id, participant_2_id));

-- Add foreign key constraint for last_message_id in conversations
ALTER TABLE conversations 
ADD CONSTRAINT fk_last_message 
FOREIGN KEY (last_message_id) REFERENCES messages(id) ON DELETE SET NULL;

-- ============================================
-- INDEXES for Performance
-- ============================================

-- Index for finding conversations by participant
CREATE INDEX IF NOT EXISTS idx_conversations_participant_1 ON conversations(participant_1_id);
CREATE INDEX IF NOT EXISTS idx_conversations_participant_2 ON conversations(participant_2_id);
CREATE INDEX IF NOT EXISTS idx_conversations_last_message_at ON conversations(last_message_at DESC);

-- Index for messages by conversation (for chat history)
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created ON messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON messages(conversation_id, is_read) WHERE is_read = FALSE;

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on both tables
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Conversations Policies
-- Users can view conversations they participate in
CREATE POLICY "Users can view their conversations" ON conversations
    FOR SELECT USING (
        auth.uid() = participant_1_id OR 
        auth.uid() = participant_2_id
    );

-- Users can create conversations they participate in
CREATE POLICY "Users can create conversations" ON conversations
    FOR INSERT WITH CHECK (
        auth.uid() = participant_1_id OR 
        auth.uid() = participant_2_id
    );

-- Users can update conversations they participate in
CREATE POLICY "Users can update their conversations" ON conversations
    FOR UPDATE USING (
        auth.uid() = participant_1_id OR 
        auth.uid() = participant_2_id
    );

-- Messages Policies
-- Users can view messages in conversations they participate in
CREATE POLICY "Users can view messages in their conversations" ON messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM conversations c 
            WHERE c.id = conversation_id 
            AND (c.participant_1_id = auth.uid() OR c.participant_2_id = auth.uid())
        )
    );

-- Users can send messages in conversations they participate in
CREATE POLICY "Users can send messages in their conversations" ON messages
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id AND
        EXISTS (
            SELECT 1 FROM conversations c 
            WHERE c.id = conversation_id 
            AND (c.participant_1_id = auth.uid() OR c.participant_2_id = auth.uid())
        )
    );

-- Users can update their own messages (for editing)
CREATE POLICY "Users can update their own messages" ON messages
    FOR UPDATE USING (auth.uid() = sender_id);

-- ============================================
-- DATABASE FUNCTIONS
-- ============================================

-- Function to get or create conversation between two users
CREATE OR REPLACE FUNCTION get_or_create_conversation(
    user1_id UUID,
    user2_id UUID,
    listing_ref_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    conversation_id UUID;
    participant1 UUID;
    participant2 UUID;
BEGIN
    -- Ensure consistent ordering of participants
    IF user1_id < user2_id THEN
        participant1 := user1_id;
        participant2 := user2_id;
    ELSE
        participant1 := user2_id;
        participant2 := user1_id;
    END IF;
    
    -- Try to find existing conversation
    SELECT id INTO conversation_id
    FROM conversations
    WHERE participant_1_id = participant1 
    AND participant_2_id = participant2;
    
    -- If no conversation exists, create one
    IF conversation_id IS NULL THEN
        INSERT INTO conversations (participant_1_id, participant_2_id, listing_id)
        VALUES (participant1, participant2, listing_ref_id)
        RETURNING id INTO conversation_id;
    END IF;
    
    RETURN conversation_id;
END;
$$;

-- Function to update conversation metadata when new message is sent
CREATE OR REPLACE FUNCTION update_conversation_on_new_message()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    other_participant_id UUID;
BEGIN
    -- Find the other participant (not the sender)
    SELECT CASE 
        WHEN NEW.sender_id = c.participant_1_id THEN c.participant_2_id
        ELSE c.participant_1_id
    END INTO other_participant_id
    FROM conversations c
    WHERE c.id = NEW.conversation_id;
    
    -- Update conversation metadata
    UPDATE conversations SET
        last_message_id = NEW.id,
        last_message_at = NEW.created_at,
        -- Increment unread count for the other participant
        participant_1_unread_count = CASE 
            WHEN other_participant_id = participant_1_id THEN participant_1_unread_count + 1
            ELSE participant_1_unread_count
        END,
        participant_2_unread_count = CASE 
            WHEN other_participant_id = participant_2_id THEN participant_2_unread_count + 1
            ELSE participant_2_unread_count
        END,
        updated_at = NOW()
    WHERE id = NEW.conversation_id;
    
    RETURN NEW;
END;
$$;

-- Trigger to update conversation when message is inserted
CREATE TRIGGER update_conversation_on_message
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION update_conversation_on_new_message();

-- Function to mark messages as read and reset unread count
CREATE OR REPLACE FUNCTION mark_messages_as_read(
    conv_id UUID,
    user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Mark messages as read
    UPDATE messages 
    SET is_read = TRUE, updated_at = NOW()
    WHERE conversation_id = conv_id 
    AND sender_id != user_id 
    AND is_read = FALSE;
    
    -- Reset unread count for this user
    UPDATE conversations SET
        participant_1_unread_count = CASE 
            WHEN participant_1_id = user_id THEN 0
            ELSE participant_1_unread_count
        END,
        participant_2_unread_count = CASE 
            WHEN participant_2_id = user_id THEN 0
            ELSE participant_2_unread_count
        END,
        updated_at = NOW()
    WHERE id = conv_id;
END;
$$;

-- ============================================
-- VIEWS FOR EASY QUERYING
-- ============================================

-- View to get conversation details with participant info
CREATE OR REPLACE VIEW conversation_details AS
SELECT 
    c.id,
    c.participant_1_id,
    c.participant_2_id,
    c.listing_id,
    c.last_message_at,
    c.participant_1_unread_count,
    c.participant_2_unread_count,
    c.is_active,
    c.created_at,
    -- Participant 1 details
    p1.name as participant_1_name,
    p1.profile_pic_url as participant_1_avatar,
    -- Participant 2 details  
    p2.name as participant_2_name,
    p2.profile_pic_url as participant_2_avatar,
    -- Last message details
    m.message_text as last_message_text,
    m.message_type as last_message_type,
    m.sender_id as last_message_sender_id,
    -- Listing details if conversation is about a listing
    l.title as listing_title,
    l.images as listing_images
FROM conversations c
LEFT JOIN user_profiles p1 ON c.participant_1_id = p1.id
LEFT JOIN user_profiles p2 ON c.participant_2_id = p2.id
LEFT JOIN messages m ON c.last_message_id = m.id
LEFT JOIN listings l ON c.listing_id = l.id
ORDER BY c.last_message_at DESC;

-- Grant access to the view
GRANT SELECT ON conversation_details TO authenticated;

-- ============================================
-- SUCCESS MESSAGE
-- ============================================

-- Messaging tables created successfully!
-- You can now use the messaging system in your Flutter app.
-- 
-- Tables created:
-- ✅ conversations
-- ✅ messages
-- ✅ conversation_details (view)
-- 
-- Functions created:
-- ✅ get_or_create_conversation()
-- ✅ mark_messages_as_read()
-- ✅ update_conversation_on_new_message()
--
-- Next steps:
-- 1. Test the messaging system in your Flutter app
-- 2. Create some test conversations
-- 3. Send messages between users 