-- Chat Images Schema
-- Run this SQL in your Supabase SQL Editor

-- Create storage bucket for chat attachments (if not exists)
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-attachments', 'chat-attachments', true)
ON CONFLICT (id) DO NOTHING;

-- Set up RLS policies for chat-attachments bucket
CREATE POLICY "Users can upload chat images" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'chat-attachments' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can view chat images" ON storage.objects
FOR SELECT USING (
  bucket_id = 'chat-attachments'
);

CREATE POLICY "Users can delete their chat images" ON storage.objects
FOR DELETE USING (
  bucket_id = 'chat-attachments' 
  AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Ensure messages table has attachment fields (they should already exist)
-- This is just to verify the schema

DO $$ 
BEGIN
    -- Check if attachment_url column exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'messages' 
        AND column_name = 'attachment_url'
    ) THEN
        ALTER TABLE messages 
        ADD COLUMN attachment_url TEXT;
    END IF;

    -- Add comment for clarity
    COMMENT ON COLUMN messages.attachment_url IS 'URL for image/file attachments in messages';
END $$;

-- Create index for faster attachment queries
CREATE INDEX IF NOT EXISTS idx_messages_attachments 
ON messages(attachment_url) 
WHERE attachment_url IS NOT NULL;

-- Update RLS policies to allow image message operations
DROP POLICY IF EXISTS "Users can insert messages in their conversations" ON messages;
CREATE POLICY "Users can insert messages in their conversations" 
ON messages FOR INSERT WITH CHECK (
  conversation_id IN (
    SELECT id FROM conversations 
    WHERE participant_1_id = auth.uid() 
    OR participant_2_id = auth.uid()
  )
);

-- Create a function to clean up orphaned chat images
CREATE OR REPLACE FUNCTION cleanup_orphaned_chat_images()
RETURNS void AS $$
BEGIN
  -- Delete storage objects that don't have corresponding messages
  -- This should be run periodically as a maintenance task
  DELETE FROM storage.objects 
  WHERE bucket_id = 'chat-attachments'
  AND NOT EXISTS (
    SELECT 1 FROM messages 
    WHERE messages.attachment_url LIKE '%' || storage.objects.name || '%'
  )
  AND created_at < NOW() - INTERVAL '24 hours'; -- Only delete files older than 24 hours
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON messages TO authenticated;
GRANT ALL ON storage.objects TO authenticated;
GRANT ALL ON storage.buckets TO authenticated;

COMMENT ON FUNCTION cleanup_orphaned_chat_images() IS 'Clean up chat images that are no longer referenced by any messages';

-- Example usage (run manually when needed):
-- SELECT cleanup_orphaned_chat_images(); 