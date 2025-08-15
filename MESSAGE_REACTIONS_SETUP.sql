-- Add reactions column to messages table
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS reactions JSONB DEFAULT '{}';

-- Create typing_indicators table
CREATE TABLE IF NOT EXISTS typing_indicators (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    is_typing BOOLEAN DEFAULT true,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(conversation_id, user_id)
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_typing_indicators_conversation 
ON typing_indicators(conversation_id);

CREATE INDEX IF NOT EXISTS idx_typing_indicators_user 
ON typing_indicators(user_id);

-- Add RLS policies for typing_indicators
ALTER TABLE typing_indicators ENABLE ROW LEVEL SECURITY;

-- Users can insert their own typing indicators
CREATE POLICY "Users can insert their own typing indicators" ON typing_indicators
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own typing indicators
CREATE POLICY "Users can update their own typing indicators" ON typing_indicators
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own typing indicators
CREATE POLICY "Users can delete their own typing indicators" ON typing_indicators
    FOR DELETE USING (auth.uid() = user_id);

-- Users can view typing indicators in conversations they participate in
CREATE POLICY "Users can view typing indicators in their conversations" ON typing_indicators
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM conversations 
            WHERE id = typing_indicators.conversation_id 
            AND (participant_1_id = auth.uid() OR participant_2_id = auth.uid())
        )
    );

-- Function to clean up old typing indicators (older than 5 minutes)
CREATE OR REPLACE FUNCTION cleanup_old_typing_indicators()
RETURNS void AS $$
BEGIN
    DELETE FROM typing_indicators 
    WHERE updated_at < NOW() - INTERVAL '5 minutes';
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to automatically clean up old typing indicators
CREATE OR REPLACE FUNCTION trigger_cleanup_typing_indicators()
RETURNS trigger AS $$
BEGIN
    PERFORM cleanup_old_typing_indicators();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add trigger to conversations table to clean up typing indicators when conversation is deleted
CREATE TRIGGER cleanup_typing_indicators_trigger
    AFTER DELETE ON conversations
    FOR EACH ROW
    EXECUTE FUNCTION trigger_cleanup_typing_indicators();

-- Grant necessary permissions
GRANT ALL ON typing_indicators TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated; 