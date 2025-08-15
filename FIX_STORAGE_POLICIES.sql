-- ============================================
-- FIX STORAGE POLICIES FOR STUDY GROUP COVERS
-- ============================================

-- Enable RLS on storage objects if not already enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop existing policies for study-group-covers if they exist
DROP POLICY IF EXISTS "Allow authenticated users to upload group covers" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read access to group covers" ON storage.objects;
DROP POLICY IF EXISTS "Allow group admins to update group covers" ON storage.objects;
DROP POLICY IF EXISTS "Allow group admins to delete group covers" ON storage.objects;

-- Create new policies for study-group-covers bucket
CREATE POLICY "Allow authenticated users to upload group covers" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'study-group-covers' 
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Allow public read access to group covers" ON storage.objects
FOR SELECT USING (
  bucket_id = 'study-group-covers'
);

CREATE POLICY "Allow group admins to update group covers" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'study-group-covers' 
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Allow group admins to delete group covers" ON storage.objects
FOR DELETE USING (
  bucket_id = 'study-group-covers' 
  AND auth.role() = 'authenticated'
);

-- ============================================
-- VERIFICATION
-- ============================================

-- Check if policies were created successfully
SELECT 
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'objects' 
AND policyname LIKE '%group%'
ORDER BY policyname; 