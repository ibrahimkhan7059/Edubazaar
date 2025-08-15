-- EduBazaar Listings Table Setup
-- Run this SQL in your Supabase Dashboard → SQL Editor

-- Create listings table
CREATE TABLE listings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  price DECIMAL(10,2), -- NULL for donations/free items
  type TEXT NOT NULL CHECK (type IN ('book', 'notes', 'pastPapers', 'studyGuides', 'equipment', 'other')),
  category TEXT NOT NULL CHECK (category IN (
    'mathematics', 'physics', 'chemistry', 'biology', 'computerScience', 
    'engineering', 'medicine', 'business', 'economics', 'psychology', 
    'history', 'literature', 'languages', 'arts', 'law', 'textbooks', 
    'fiction', 'nonFiction', 'reference', 'calculators', 'labEquipment', 
    'stationery', 'other'
  )),
  condition TEXT CHECK (condition IN ('likeNew', 'excellent', 'good', 'fair', 'poor')),
  images TEXT[] DEFAULT '{}', -- Array of image URLs
  tags TEXT[] DEFAULT '{}', -- Array of tags
  subject TEXT,
  course_code TEXT,
  university TEXT,
  author TEXT, -- For books
  isbn TEXT, -- For books
  edition TEXT, -- For books
  file_url TEXT, -- For digital resources
  pickup_location TEXT,
  allow_shipping BOOLEAN DEFAULT FALSE,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'sold', 'reserved', 'inactive', 'deleted')),
  views INTEGER DEFAULT 0,
  favorites INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_listings_user_id ON listings(user_id);
CREATE INDEX idx_listings_type ON listings(type);
CREATE INDEX idx_listings_category ON listings(category);
CREATE INDEX idx_listings_status ON listings(status);
CREATE INDEX idx_listings_created_at ON listings(created_at DESC);
CREATE INDEX idx_listings_price ON listings(price);

-- Enable Row Level Security
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Anyone can view active listings
CREATE POLICY "Anyone can view active listings" ON listings
  FOR SELECT USING (status = 'active');

-- Users can view their own listings (all statuses)
CREATE POLICY "Users can view own listings" ON listings
  FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own listings
CREATE POLICY "Users can insert own listings" ON listings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own listings
CREATE POLICY "Users can update own listings" ON listings
  FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own listings
CREATE POLICY "Users can delete own listings" ON listings
  FOR DELETE USING (auth.uid() = user_id);

-- Create favorites table
CREATE TABLE favorites (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  listing_id UUID REFERENCES listings(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, listing_id)
);

-- Enable RLS for favorites
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;

-- Policies for favorites
CREATE POLICY "Users can view own favorites" ON favorites
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own favorites" ON favorites
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own favorites" ON favorites
  FOR DELETE USING (auth.uid() = user_id);

-- Create function to update listing favorites count
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
$$ LANGUAGE plpgsql;

-- Create triggers to automatically update favorites count
CREATE TRIGGER favorites_count_trigger
  AFTER INSERT OR DELETE ON favorites
  FOR EACH ROW
  EXECUTE FUNCTION update_listing_favorites_count();

-- Create function to update views count
CREATE OR REPLACE FUNCTION increment_listing_views(listing_uuid UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE listings 
  SET views = views + 1 
  WHERE id = listing_uuid;
END;
$$ LANGUAGE plpgsql;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_listings_updated_at
  BEFORE UPDATE ON listings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Insert some sample data (optional)
INSERT INTO listings (user_id, title, description, price, type, category, condition, tags, subject, author, edition, pickup_location, allow_shipping, status) VALUES
(
  (SELECT id FROM auth.users LIMIT 1), -- Uses first user, you can replace with actual user ID
  'Calculus: Early Transcendentals',
  'Excellent condition textbook for Calculus I & II. No highlighting or writing.',
  75.00,
  'book',
  'mathematics',
  'excellent',
  ARRAY['calculus', 'mathematics', 'textbook'],
  'Mathematics',
  'James Stewart',
  '8th Edition',
  'Campus Library',
  true,
  'active'
),
(
  (SELECT id FROM auth.users LIMIT 1),
  'Chemistry Notes & Study Guides',
  'Comprehensive notes for Organic Chemistry with practice problems and solutions.',
  NULL, -- Free donation
  'notes',
  'chemistry',
  NULL,
  ARRAY['chemistry', 'notes', 'organic', 'free'],
  'Chemistry',
  NULL,
  NULL,
  'Student Center',
  true,
  'active'
);

-- Grant necessary permissions
GRANT ALL ON listings TO authenticated;
GRANT ALL ON favorites TO authenticated; 