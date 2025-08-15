-- Check if coordinate columns exist in listings table
-- Run this in Supabase SQL Editor

-- Check table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'listings' 
AND column_name IN ('latitude', 'longitude')
ORDER BY column_name;

-- Check if any listings have coordinates
SELECT 
    COUNT(*) as total_listings,
    COUNT(latitude) as listings_with_latitude,
    COUNT(longitude) as listings_with_longitude,
    COUNT(CASE WHEN latitude IS NOT NULL AND longitude IS NOT NULL THEN 1 END) as listings_with_coordinates
FROM listings;

-- Show sample listings with coordinates
SELECT 
    id,
    title,
    pickup_location,
    latitude,
    longitude,
    created_at
FROM listings 
WHERE latitude IS NOT NULL OR longitude IS NOT NULL
ORDER BY created_at DESC
LIMIT 5; 