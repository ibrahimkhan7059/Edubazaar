-- Simple test: Insert a listing with coordinates
-- Run this in Supabase SQL Editor

-- First, add the columns if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'listings' AND column_name = 'latitude'
    ) THEN
        ALTER TABLE listings ADD COLUMN latitude DECIMAL(10, 8);
        RAISE NOTICE 'Added latitude column';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'listings' AND column_name = 'longitude'
    ) THEN
        ALTER TABLE listings ADD COLUMN longitude DECIMAL(10, 8);
        RAISE NOTICE 'Added longitude column';
    END IF;
END $$;

-- Insert a simple test listing
INSERT INTO listings (
    id,
    user_id,
    title,
    description,
    price,
    type,
    category,
    condition,
    images,
    tags,
    subject,
    pickup_location,
    latitude,
    longitude,
    allow_shipping,
    status,
    created_at,
    updated_at,
    views,
    favorites
) VALUES (
    gen_random_uuid(),
    (SELECT id FROM auth.users LIMIT 1),
    'Test Book - Coordinates Demo',
    'This is a test book to verify coordinates are working.',
    1000,
    'book',
    'textbooks',
    'good',
    ARRAY['https://example.com/test.jpg'],
    ARRAY['test', 'demo'],
    'Computer Science',
    'Islamabad, Pakistan',
    33.6844,
    73.0479,
    false,
    'active',
    NOW(),
    NOW(),
    0,
    0
);

-- Verify it was created
SELECT 
    title,
    pickup_location,
    latitude,
    longitude,
    created_at
FROM listings 
WHERE title = 'Test Book - Coordinates Demo'; 