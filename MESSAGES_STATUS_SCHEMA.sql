-- Add message status fields to messages table
-- Run this SQL in your Supabase SQL editor

-- Add delivery status fields to messages table
ALTER TABLE messages 
ADD COLUMN IF NOT EXISTS is_delivered BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

-- Update existing messages to show as delivered (for demo)
UPDATE messages 
SET is_delivered = true, 
    delivered_at = created_at 
WHERE is_delivered = false;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_messages_delivery_status 
ON messages(conversation_id, is_delivered, read_at);

-- Update RLS policies to include new fields
DROP POLICY IF EXISTS "Users can view messages in their conversations" ON messages;
CREATE POLICY "Users can view messages in their conversations" 
ON messages FOR SELECT USING (
  conversation_id IN (
    SELECT id FROM conversations 
    WHERE participant_1_id = auth.uid() 
    OR participant_2_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Users can update message status" ON messages;
CREATE POLICY "Users can update message status" 
ON messages FOR UPDATE USING (
  conversation_id IN (
    SELECT id FROM conversations 
    WHERE participant_1_id = auth.uid() 
    OR participant_2_id = auth.uid()
  )
);

-- Grant necessary permissions
GRANT SELECT, UPDATE ON messages TO authenticated;

COMMENT ON COLUMN messages.is_delivered IS 'Whether message has been delivered to recipient';
COMMENT ON COLUMN messages.delivered_at IS 'Timestamp when message was delivered';
COMMENT ON COLUMN messages.read_at IS 'Timestamp when message was read by recipient'; 