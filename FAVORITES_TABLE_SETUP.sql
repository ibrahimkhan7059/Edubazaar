-- Favorites Table Setup for EduBazaar
-- Run this in your Supabase SQL Editor

-- 1. Create favorites table if it doesn't exist
CREATE TABLE IF NOT EXISTS favorites (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    listing_id UUID REFERENCES listings(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, listing_id)
);

-- 2. Enable RLS on favorites table
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

-- 3. Create RLS policies for favorites
-- Users can view their own favorites
DROP POLICY IF EXISTS "Users can view their own favorites" ON favorites;
CREATE POLICY "Users can view their own favorites"
ON favorites FOR SELECT USING (
    user_id = auth.uid()
);

-- Users can insert their own favorites
DROP POLICY IF EXISTS "Users can insert their own favorites" ON favorites;
CREATE POLICY "Users can insert their own favorites"
ON favorites FOR INSERT WITH CHECK (
    user_id = auth.uid()
);

-- Users can delete their own favorites
DROP POLICY IF EXISTS "Users can delete their own favorites" ON favorites;
CREATE POLICY "Users can delete their own favorites"
ON favorites FOR DELETE USING (
    user_id = auth.uid()
);

-- 4. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_listing_id ON favorites(listing_id);
CREATE INDEX IF NOT EXISTS idx_favorites_user_listing ON favorites(user_id, listing_id);

-- 5. Grant permissions
GRANT ALL ON favorites TO authenticated;

-- 6. Create function to increment listing views
CREATE OR REPLACE FUNCTION increment_listing_views(listing_uuid UUID)
RETURNS void AS $$
BEGIN
    UPDATE listings 
    SET views = views + 1 
    WHERE id = listing_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Create function to update favorites count
CREATE OR REPLACE FUNCTION update_listing_favorites_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE listings 
        SET favorites = favorites + 1 
        WHERE id = NEW.listing_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE listings 
        SET favorites = favorites - 1 
        WHERE id = OLD.listing_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Create trigger to automatically update favorites count
DROP TRIGGER IF EXISTS trigger_update_favorites_count ON favorites;
CREATE TRIGGER trigger_update_favorites_count
    AFTER INSERT OR DELETE ON favorites
    FOR EACH ROW
    EXECUTE FUNCTION update_listing_favorites_count();

-- 9. Initialize favorites count for existing listings
UPDATE listings 
SET favorites = (
    SELECT COUNT(*) 
    FROM favorites 
    WHERE favorites.listing_id = listings.id
)
WHERE favorites IS NULL;

-- 10. Verify the setup
SELECT 'Favorites table setup completed successfully' as status; 