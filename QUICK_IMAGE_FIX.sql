-- Quick Image Upload Fix
-- Run this in your Supabase SQL Editor

-- 1. Create storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-attachments', 'chat-attachments', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Simple RLS policies
DROP POLICY IF EXISTS "Allow all chat attachments" ON storage.objects;
CREATE POLICY "Allow all chat attachments" ON storage.objects
FOR ALL USING (bucket_id = 'chat-attachments');

-- 3. Ensure messages table has attachment_url
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

-- 4. Grant permissions
GRANT ALL ON storage.objects TO authenticated;
GRANT ALL ON storage.buckets TO authenticated;

-- 5. Verify
SELECT 'Image upload ready!' as status; 