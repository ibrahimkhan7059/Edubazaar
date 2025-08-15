-- ============================================
-- EduBazaar Profile Management Database Schema (FIXED)
-- ============================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- User Profiles Table (Extended user information)
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    profile_pic_url TEXT,
    cover_photo_url TEXT,
    university TEXT,
    course TEXT,
    semester TEXT,
    bio TEXT,
    phone_number TEXT,
    interests TEXT[], -- Array of interests/tags
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    last_active TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    joined_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User Reviews Table
CREATE TABLE IF NOT EXISTS user_reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reviewer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    reviewed_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    listing_id UUID REFERENCES listings(id) ON DELETE SET NULL,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5) NOT NULL,
    review_text TEXT,
    is_anonymous BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Prevent self-reviews
    CONSTRAINT no_self_review CHECK (reviewer_id != reviewed_id),
    -- Prevent duplicate reviews for same listing
    CONSTRAINT unique_review_per_listing UNIQUE (reviewer_id, reviewed_id, listing_id)
);

-- User Transactions Table
CREATE TABLE IF NOT EXISTS user_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    seller_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    buyer_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    listing_id UUID REFERENCES listings(id) ON DELETE CASCADE NOT NULL,
    transaction_type TEXT CHECK (transaction_type IN ('sale', 'rent', 'exchange', 'donation')) NOT NULL,
    amount DECIMAL(10,2) DEFAULT 0,
    currency TEXT DEFAULT 'PKR',
    status TEXT CHECK (status IN ('pending', 'completed', 'cancelled', 'refunded')) DEFAULT 'pending',
    payment_method TEXT,
    transaction_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completion_date TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User Favorites Table
CREATE TABLE IF NOT EXISTS user_favorites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    listing_id UUID REFERENCES listings(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Prevent duplicate favorites
    CONSTRAINT unique_user_listing_favorite UNIQUE (user_id, listing_id)
);

-- User Profile Stats View (for efficient querying)
DROP VIEW IF EXISTS user_profile_stats;
CREATE OR REPLACE VIEW user_profile_stats AS
SELECT 
    up.*,
    COALESCE(listing_stats.total_listings, 0) as total_listings,
    COALESCE(listing_stats.active_listings, 0) as active_listings,
    COALESCE(listing_stats.sold_listings, 0) as sold_listings,
    COALESCE(review_stats.average_rating, 0.0) as average_rating,
    COALESCE(review_stats.total_reviews, 0) as total_reviews,
    COALESCE(transaction_stats.total_sales, 0) as total_sales,
    COALESCE(transaction_stats.total_purchases, 0) as total_purchases,
    COALESCE(donation_stats.total_donations_given, 0) as total_donations_given,
    COALESCE(donation_stats.total_donations_received, 0) as total_donations_received
FROM user_profiles up
LEFT JOIN (
    -- Listing statistics
    SELECT 
        user_id,
        COUNT(*) as total_listings,
        COUNT(CASE WHEN status = 'available' THEN 1 END) as active_listings,
        COUNT(CASE WHEN status = 'sold' THEN 1 END) as sold_listings
    FROM listings
    WHERE status != 'deleted'
    GROUP BY user_id
) listing_stats ON up.id = listing_stats.user_id
LEFT JOIN (
    -- Review statistics
    SELECT 
        reviewed_id as user_id,
        AVG(rating::numeric) as average_rating,
        COUNT(*) as total_reviews
    FROM user_reviews
    GROUP BY reviewed_id
) review_stats ON up.id = review_stats.user_id
LEFT JOIN (
    -- Transaction statistics
    SELECT 
        user_id,
        COUNT(CASE WHEN user_type = 'seller' THEN 1 END) as total_sales,
        COUNT(CASE WHEN user_type = 'buyer' THEN 1 END) as total_purchases
    FROM (
        SELECT seller_id as user_id, 'seller' as user_type FROM user_transactions WHERE status = 'completed'
        UNION ALL
        SELECT buyer_id as user_id, 'buyer' as user_type FROM user_transactions WHERE status = 'completed'
    ) transaction_data
    GROUP BY user_id
) transaction_stats ON up.id = transaction_stats.user_id
LEFT JOIN (
    -- Donation statistics
    SELECT 
        user_id,
        COUNT(CASE WHEN user_type = 'giver' THEN 1 END) as total_donations_given,
        COUNT(CASE WHEN user_type = 'receiver' THEN 1 END) as total_donations_received
    FROM (
        SELECT seller_id as user_id, 'giver' as user_type FROM user_transactions 
        WHERE transaction_type = 'donation' AND status = 'completed'
        UNION ALL
        SELECT buyer_id as user_id, 'receiver' as user_type FROM user_transactions 
        WHERE transaction_type = 'donation' AND status = 'completed'
    ) donation_data
    GROUP BY user_id
) donation_stats ON up.id = donation_stats.user_id;

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON user_profiles(email);
CREATE INDEX IF NOT EXISTS idx_user_profiles_university ON user_profiles(university);
CREATE INDEX IF NOT EXISTS idx_user_profiles_course ON user_profiles(course);
CREATE INDEX IF NOT EXISTS idx_user_profiles_is_active ON user_profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_user_profiles_last_active ON user_profiles(last_active);

CREATE INDEX IF NOT EXISTS idx_user_reviews_reviewed_id ON user_reviews(reviewed_id);
CREATE INDEX IF NOT EXISTS idx_user_reviews_reviewer_id ON user_reviews(reviewer_id);
CREATE INDEX IF NOT EXISTS idx_user_reviews_listing_id ON user_reviews(listing_id);
CREATE INDEX IF NOT EXISTS idx_user_reviews_created_at ON user_reviews(created_at);

CREATE INDEX IF NOT EXISTS idx_user_transactions_seller_id ON user_transactions(seller_id);
CREATE INDEX IF NOT EXISTS idx_user_transactions_buyer_id ON user_transactions(buyer_id);
CREATE INDEX IF NOT EXISTS idx_user_transactions_listing_id ON user_transactions(listing_id);
CREATE INDEX IF NOT EXISTS idx_user_transactions_status ON user_transactions(status);
CREATE INDEX IF NOT EXISTS idx_user_transactions_transaction_date ON user_transactions(transaction_date);

CREATE INDEX IF NOT EXISTS idx_user_favorites_user_id ON user_favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_user_favorites_listing_id ON user_favorites(listing_id);

-- Row Level Security (RLS) Policies
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;

-- User Profiles Policies
CREATE POLICY "Users can view all profiles" ON user_profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON user_profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON user_profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- User Reviews Policies
CREATE POLICY "Users can view all reviews" ON user_reviews FOR SELECT USING (true);
CREATE POLICY "Users can create reviews" ON user_reviews FOR INSERT WITH CHECK (auth.uid() = reviewer_id);
CREATE POLICY "Users can update own reviews" ON user_reviews FOR UPDATE USING (auth.uid() = reviewer_id);
CREATE POLICY "Users can delete own reviews" ON user_reviews FOR DELETE USING (auth.uid() = reviewer_id);

-- User Transactions Policies
CREATE POLICY "Users can view own transactions" ON user_transactions FOR SELECT USING (auth.uid() = seller_id OR auth.uid() = buyer_id);
CREATE POLICY "Users can create transactions" ON user_transactions FOR INSERT WITH CHECK (auth.uid() = seller_id OR auth.uid() = buyer_id);
CREATE POLICY "Users can update own transactions" ON user_transactions FOR UPDATE USING (auth.uid() = seller_id OR auth.uid() = buyer_id);

-- User Favorites Policies
CREATE POLICY "Users can view own favorites" ON user_favorites FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own favorites" ON user_favorites FOR ALL USING (auth.uid() = user_id);

-- Functions for better functionality
CREATE OR REPLACE FUNCTION update_user_last_active(user_uuid UUID)
RETURNS void AS $$
BEGIN
    UPDATE user_profiles 
    SET last_active = NOW() 
    WHERE id = user_uuid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION update_user_last_active(UUID) TO authenticated;

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply the trigger to all tables
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_reviews_updated_at BEFORE UPDATE ON user_reviews FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_transactions_updated_at BEFORE UPDATE ON user_transactions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- STORAGE BUCKETS FOR PROFILE IMAGES
-- ============================================

-- Create storage bucket for profile pictures
INSERT INTO storage.buckets (id, name, public) 
VALUES ('profile-pictures', 'profile-pictures', true)
ON CONFLICT (id) DO NOTHING;

-- Create storage bucket for cover photos
INSERT INTO storage.buckets (id, name, public) 
VALUES ('cover-photos', 'cover-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for profile pictures
CREATE POLICY "Users can upload own profile pictures" ON storage.objects 
FOR INSERT WITH CHECK (
    bucket_id = 'profile-pictures' AND 
    auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can update own profile pictures" ON storage.objects 
FOR UPDATE USING (
    bucket_id = 'profile-pictures' AND 
    auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete own profile pictures" ON storage.objects 
FOR DELETE USING (
    bucket_id = 'profile-pictures' AND 
    auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Anyone can view profile pictures" ON storage.objects 
FOR SELECT USING (bucket_id = 'profile-pictures');

-- Storage policies for cover photos
CREATE POLICY "Users can upload own cover photos" ON storage.objects 
FOR INSERT WITH CHECK (
    bucket_id = 'cover-photos' AND 
    auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can update own cover photos" ON storage.objects 
FOR UPDATE USING (
    bucket_id = 'cover-photos' AND 
    auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can delete own cover photos" ON storage.objects 
FOR DELETE USING (
    bucket_id = 'cover-photos' AND 
    auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Anyone can view cover photos" ON storage.objects 
FOR SELECT USING (bucket_id = 'cover-photos'); 