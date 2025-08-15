-- ============================================
-- STORAGE BUCKET POLICIES FOR COMMUNITY FEATURES
-- ============================================

-- Enable RLS on all storage buckets
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- ============================================
-- STUDY GROUP COVERS BUCKET POLICIES
-- ============================================

-- Policy to allow authenticated users to upload group cover images
CREATE POLICY "Allow authenticated users to upload group covers" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'study-group-covers' 
  AND auth.role() = 'authenticated'
);

-- Policy to allow public read access to group cover images
CREATE POLICY "Allow public read access to group covers" ON storage.objects
FOR SELECT USING (
  bucket_id = 'study-group-covers'
);

-- Policy to allow group creators/admins to update their group covers
CREATE POLICY "Allow group admins to update group covers" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'study-group-covers' 
  AND auth.role() = 'authenticated'
);

-- Policy to allow group creators/admins to delete their group covers
CREATE POLICY "Allow group admins to delete group covers" ON storage.objects
FOR DELETE USING (
  bucket_id = 'study-group-covers' 
  AND auth.role() = 'authenticated'
);

-- ============================================
-- COMMUNITY AVATARS BUCKET POLICIES
-- ============================================

-- Policy to allow authenticated users to upload avatars
CREATE POLICY "Allow authenticated users to upload avatars" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'community-avatars' 
  AND auth.role() = 'authenticated'
);

-- Policy to allow public read access to avatars
CREATE POLICY "Allow public read access to avatars" ON storage.objects
FOR SELECT USING (
  bucket_id = 'community-avatars'
);

-- Policy to allow users to update their own avatars
CREATE POLICY "Allow users to update their avatars" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'community-avatars' 
  AND auth.role() = 'authenticated'
);

-- Policy to allow users to delete their own avatars
CREATE POLICY "Allow users to delete their avatars" ON storage.objects
FOR DELETE USING (
  bucket_id = 'community-avatars' 
  AND auth.role() = 'authenticated'
);

-- ============================================
-- EVENT COVERS BUCKET POLICIES
-- ============================================

-- Policy to allow authenticated users to upload event covers
CREATE POLICY "Allow authenticated users to upload event covers" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'event-covers' 
  AND auth.role() = 'authenticated'
);

-- Policy to allow public read access to event covers
CREATE POLICY "Allow public read access to event covers" ON storage.objects
FOR SELECT USING (
  bucket_id = 'event-covers'
);

-- Policy to allow event creators to update their event covers
CREATE POLICY "Allow event creators to update event covers" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'event-covers' 
  AND auth.role() = 'authenticated'
);

-- Policy to allow event creators to delete their event covers
CREATE POLICY "Allow event creators to delete event covers" ON storage.objects
FOR DELETE USING (
  bucket_id = 'event-covers' 
  AND auth.role() = 'authenticated'
);

-- ============================================
-- STUDY RESOURCES BUCKET POLICIES
-- ============================================

-- Policy to allow authenticated users to upload study resources
CREATE POLICY "Allow authenticated users to upload study resources" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'study-resources' 
  AND auth.role() = 'authenticated'
);

-- Policy to allow public read access to study resources
CREATE POLICY "Allow public read access to study resources" ON storage.objects
FOR SELECT USING (
  bucket_id = 'study-resources'
);

-- Policy to allow resource uploaders to update their resources
CREATE POLICY "Allow resource uploaders to update study resources" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'study-resources' 
  AND auth.role() = 'authenticated'
);

-- Policy to allow resource uploaders to delete their resources
CREATE POLICY "Allow resource uploaders to delete study resources" ON storage.objects
FOR DELETE USING (
  bucket_id = 'study-resources' 
  AND auth.role() = 'authenticated'
);

-- ============================================
-- RESOURCE THUMBNAILS BUCKET POLICIES
-- ============================================

-- Policy to allow authenticated users to upload resource thumbnails
CREATE POLICY "Allow authenticated users to upload resource thumbnails" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'resource-thumbnails' 
  AND auth.role() = 'authenticated'
);

-- Policy to allow public read access to resource thumbnails
CREATE POLICY "Allow public read access to resource thumbnails" ON storage.objects
FOR SELECT USING (
  bucket_id = 'resource-thumbnails'
);

-- Policy to allow resource uploaders to update their thumbnails
CREATE POLICY "Allow resource uploaders to update resource thumbnails" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'resource-thumbnails' 
  AND auth.role() = 'authenticated'
);

-- Policy to allow resource uploaders to delete their thumbnails
CREATE POLICY "Allow resource uploaders to delete resource thumbnails" ON storage.objects
FOR DELETE USING (
  bucket_id = 'resource-thumbnails' 
  AND auth.role() = 'authenticated'
);

-- ============================================
-- EXISTING BUCKET POLICIES (CHAT & MARKETPLACE)
-- ============================================

-- Chat attachments bucket policies (if not already created)
CREATE POLICY "Allow authenticated users to upload chat images" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'chat-attachments' 
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Allow public read access to chat images" ON storage.objects
FOR SELECT USING (
  bucket_id = 'chat-attachments'
);

-- Marketplace images bucket policies (if not already created)
CREATE POLICY "Allow authenticated users to upload marketplace images" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'marketplace-images' 
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Allow public read access to marketplace images" ON storage.objects
FOR SELECT USING (
  bucket_id = 'marketplace-images'
);

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check if policies were created successfully
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'objects' 
ORDER BY policyname;

-- Check storage buckets
SELECT * FROM storage.buckets WHERE id LIKE '%community%' OR id LIKE '%group%' OR id LIKE '%event%' OR id LIKE '%resource%'; 
 
 