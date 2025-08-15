-- Fixed migration script for adding coordinates to listings table
-- Run this in your Supabase SQL editor

-- Start transaction for safe migration
BEGIN;

-- Check if columns already exist and add them safely
DO $$
BEGIN
    -- Add latitude column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'listings' AND column_name = 'latitude'
    ) THEN
        ALTER TABLE listings ADD COLUMN latitude DECIMAL(10, 8);
        RAISE NOTICE 'Added latitude column to listings table';
    ELSE
        RAISE NOTICE 'latitude column already exists in listings table';
    END IF;

    -- Add longitude column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'listings' AND column_name = 'longitude'
    ) THEN
        ALTER TABLE listings ADD COLUMN longitude DECIMAL(10, 8);
        RAISE NOTICE 'Added longitude column to listings table';
    ELSE
        RAISE NOTICE 'longitude column already exists in listings table';
    END IF;
END $$;

-- Add column comments for documentation
COMMENT ON COLUMN listings.latitude IS 'Latitude coordinate for pickup location (decimal degrees, range: -90 to 90)';
COMMENT ON COLUMN listings.longitude IS 'Longitude coordinate for pickup location (decimal degrees, range: -180 to 180)';

-- Create index for better query performance (only if it doesn't exist)
CREATE INDEX IF NOT EXISTS idx_listings_coordinates ON listings(latitude, longitude);

-- Create index for location-based searches
CREATE INDEX IF NOT EXISTS idx_listings_location_search ON listings(pickup_location) WHERE pickup_location IS NOT NULL;

-- Add constraints safely (check if they exist first)
DO $$
BEGIN
    -- Add latitude range constraint if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'listings' AND constraint_name = 'chk_latitude_range'
    ) THEN
        ALTER TABLE listings 
        ADD CONSTRAINT chk_latitude_range 
        CHECK (latitude IS NULL OR (latitude >= -90 AND latitude <= 90));
        RAISE NOTICE 'Added latitude range constraint';
    ELSE
        RAISE NOTICE 'Latitude range constraint already exists';
    END IF;

    -- Add longitude range constraint if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'listings' AND constraint_name = 'chk_longitude_range'
    ) THEN
        ALTER TABLE listings 
        ADD CONSTRAINT chk_longitude_range 
        CHECK (longitude IS NULL OR (longitude >= -180 AND longitude <= 180));
        RAISE NOTICE 'Added longitude range constraint';
    ELSE
        RAISE NOTICE 'Longitude range constraint already exists';
    END IF;
END $$;

-- Verify the migration
DO $$
DECLARE
    col_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns 
    WHERE table_name = 'listings' 
    AND column_name IN ('latitude', 'longitude');
    
    IF col_count = 2 THEN
        RAISE NOTICE 'Migration successful: Both latitude and longitude columns added';
    ELSE
        RAISE EXCEPTION 'Migration failed: Expected 2 columns, found %', col_count;
    END IF;
END $$;

-- Show final table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default,
    CASE 
        WHEN column_name IN ('latitude', 'longitude') THEN 'NEW_COORDINATES'
        ELSE 'EXISTING'
    END as status
FROM information_schema.columns 
WHERE table_name = 'listings' 
ORDER BY ordinal_position;

-- Commit the transaction
COMMIT;

-- Final verification query
SELECT 
    'Migration completed successfully!' as status,
    COUNT(*) as total_listings,
    COUNT(latitude) as listings_with_latitude,
    COUNT(longitude) as listings_with_longitude,
    COUNT(CASE WHEN latitude IS NOT NULL AND longitude IS NOT NULL THEN 1 END) as listings_with_coordinates
FROM listings; 