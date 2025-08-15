-- ============================================
-- EduBazaar Storage Buckets Setup
-- ============================================
-- Run this in Supabase Dashboard → SQL Editor

-- Create storage bucket for listing images
INSERT INTO storage.buckets (id, name, public) 
VALUES ('listing-images', 'listing-images', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for listing images
CREATE POLICY "Users can upload listing images" ON storage.objects 
FOR INSERT WITH CHECK (
    bucket_id = 'listing-images' AND 
    auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can update own listing images" ON storage.objects 
FOR UPDATE USING (
    bucket_id = 'listing-images' AND 
    auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete own listing images" ON storage.objects 
FOR DELETE USING (
    bucket_id = 'listing-images' AND 
    auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Anyone can view listing images" ON storage.objects 
FOR SELECT USING (bucket_id = 'listing-images');

-- ============================================
-- Verify bucket creation
-- ============================================
SELECT id, name, public FROM storage.buckets WHERE id = 'listing-images'; 