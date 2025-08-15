-- Add coordinates columns to listings table
-- Run this in your Supabase SQL editor

-- Add latitude column
ALTER TABLE listings 
ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 8);

-- Add longitude column  
ALTER TABLE listings 
ADD COLUMN IF NOT EXISTS longitude DECIMAL(10, 8);

-- Add comments for documentation
COMMENT ON COLUMN listings.latitude IS 'Latitude coordinate for pickup location (decimal degrees)';
COMMENT ON COLUMN listings.longitude IS 'Longitude coordinate for pickup location (decimal degrees)';

-- Create index for better query performance on coordinates
CREATE INDEX IF NOT EXISTS idx_listings_coordinates 
ON listings(latitude, longitude);

-- Update existing listings to have default coordinates (optional)
-- You can uncomment and modify this if you want to set default coordinates for existing listings
-- UPDATE listings 
-- SET latitude = 33.6844, longitude = 73.0479 
-- WHERE latitude IS NULL AND longitude IS NULL;

-- Verify the changes
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'listings' 
AND column_name IN ('latitude', 'longitude');

-- Show sample of updated table structure
SELECT 
    id,
    title,
    pickup_location,
    latitude,
    longitude,
    created_at
FROM listings 
LIMIT 5; 