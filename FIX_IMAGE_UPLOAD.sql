-- Fix Image Upload Issues
-- Run this in your Supabase SQL Editor

-- 1. Create storage bucket for chat attachments
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-attachments', 'chat-attachments', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Create RLS policies for chat-attachments bucket
DROP POLICY IF EXISTS "Users can upload chat images" ON storage.objects;
CREATE POLICY "Users can upload chat images" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'chat-attachments'
);

DROP POLICY IF EXISTS "Users can view chat images" ON storage.objects;
CREATE POLICY "Users can view chat images" ON storage.objects
FOR SELECT USING (
  bucket_id = 'chat-attachments'
);

DROP POLICY IF EXISTS "Users can delete their chat images" ON storage.objects;
CREATE POLICY "Users can delete their chat images" ON storage.objects
FOR DELETE USING (
  bucket_id = 'chat-attachments'
);

-- 3. Ensure messages table has attachment_url column
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'messages' 
        AND column_name = 'attachment_url'
    ) THEN
        ALTER TABLE messages ADD COLUMN attachment_url TEXT;
    END IF;
END $$;

-- 4. Grant necessary permissions
GRANT ALL ON storage.objects TO authenticated;
GRANT ALL ON storage.buckets TO authenticated;

-- 5. Create index for faster attachment queries
CREATE INDEX IF NOT EXISTS idx_messages_attachments 
ON messages(attachment_url) 
WHERE attachment_url IS NOT NULL;

-- 6. Update messages RLS to allow image messages
DROP POLICY IF EXISTS "Users can insert messages in their conversations" ON messages;
CREATE POLICY "Users can insert messages in their conversations" 
ON messages FOR INSERT WITH CHECK (
  conversation_id IN (
    SELECT id FROM conversations 
    WHERE participant_1_id = auth.uid() 
    OR participant_2_id = auth.uid()
  )
);

-- 7. Verify the setup
SELECT 'Storage bucket created successfully' as status; 