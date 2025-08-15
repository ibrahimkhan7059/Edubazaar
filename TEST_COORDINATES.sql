-- Test script to insert a listing with coordinates
-- Run this in Supabase SQL Editor to test if coordinates are working

-- First, make sure the coordinates columns exist
DO $$
BEGIN
    -- Add latitude column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'listings' AND column_name = 'latitude'
    ) THEN
        ALTER TABLE listings ADD COLUMN latitude DECIMAL(10, 8);
        RAISE NOTICE 'Added latitude column';
    END IF;

    -- Add longitude column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'listings' AND column_name = 'longitude'
    ) THEN
        ALTER TABLE listings ADD COLUMN longitude DECIMAL(10, 8);
        RAISE NOTICE 'Added longitude column';
    END IF;
END $$;

-- Insert a test listing with coordinates (Islamabad coordinates)
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
    gen_random_uuid(), -- Generate a new UUID
    (SELECT id FROM auth.users LIMIT 1), -- Use first available user
    'Test Book with Coordinates',
    'This is a test book to verify that coordinates are working properly in the app.',
    500,
    'book',
    'textbooks',
    'excellent',
    ARRAY['https://example.com/test-image.jpg'],
    ARRAY['test', 'coordinates', 'demo'],
    'Computer Science',
    'Islamabad, Pakistan',
    33.6844, -- Islamabad latitude
    73.0479, -- Islamabad longitude
    false,
    'active',
    NOW(),
    NOW(),
    0,
    0
) ON CONFLICT DO NOTHING;

-- Verify the test listing was created
SELECT 
    id,
    title,
    pickup_location,
    latitude,
    longitude,
    created_at
FROM listings 
WHERE title = 'Test Book with Coordinates'
ORDER BY created_at DESC
LIMIT 1;

-- Show all listings with coordinates
SELECT 
    COUNT(*) as total_listings,
    COUNT(latitude) as listings_with_latitude,
    COUNT(longitude) as listings_with_longitude,
    COUNT(CASE WHEN latitude IS NOT NULL AND longitude IS NOT NULL THEN 1 END) as listings_with_coordinates
FROM listings; 