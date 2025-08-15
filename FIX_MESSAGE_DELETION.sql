-- Fix Message Deletion Issues
-- Run this in your Supabase SQL Editor

-- 1. Enable RLS on messages table if not already enabled
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- 2. Create DELETE policy for messages
DROP POLICY IF EXISTS "Users can delete their own messages" ON messages;
CREATE POLICY "Users can delete their own messages" 
ON messages FOR DELETE USING (
  sender_id = auth.uid()
);

-- 3. Create SELECT policy for messages (if not exists)
DROP POLICY IF EXISTS "Users can view messages in their conversations" ON messages;
CREATE POLICY "Users can view messages in their conversations" 
ON messages FOR SELECT USING (
  conversation_id IN (
    SELECT id FROM conversations 
    WHERE participant_1_id = auth.uid() 
    OR participant_2_id = auth.uid()
  )
);

-- 4. Create UPDATE policy for messages (if not exists)
DROP POLICY IF EXISTS "Users can update their own messages" ON messages;
CREATE POLICY "Users can update their own messages" 
ON messages FOR UPDATE USING (
  sender_id = auth.uid()
);

-- 5. Create INSERT policy for messages (if not exists)
DROP POLICY IF EXISTS "Users can insert messages in their conversations" ON messages;
CREATE POLICY "Users can insert messages in their conversations" 
ON messages FOR INSERT WITH CHECK (
  conversation_id IN (
    SELECT id FROM conversations 
    WHERE participant_1_id = auth.uid() 
    OR participant_2_id = auth.uid()
  )
);

-- 6. Grant necessary permissions
GRANT ALL ON messages TO authenticated;

-- 7. Create index for faster message queries
CREATE INDEX IF NOT EXISTS idx_messages_sender_id 
ON messages(sender_id);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_id 
ON messages(conversation_id);

-- 8. Verify the setup
SELECT 'Message deletion policies created successfully' as status; 