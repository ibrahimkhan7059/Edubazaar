-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- User Profiles Table
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    profile_pic_url TEXT,
    cover_photo_url TEXT,
    university TEXT,
    course TEXT,
    semester TEXT,
    bio TEXT,
    phone_number TEXT,
    joined_date TIMESTAMP DEFAULT NOW(),
    is_verified BOOLEAN DEFAULT FALSE,
    last_active TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- User Reviews Table
CREATE TABLE user_reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reviewer_id UUID REFERENCES auth.users NOT NULL,
    reviewed_id UUID REFERENCES auth.users NOT NULL,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    review_text TEXT,
    listing_id UUID REFERENCES listings,
    created_at TIMESTAMP DEFAULT NOW()
);

-- User Transactions Table
CREATE TABLE user_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    seller_id UUID REFERENCES auth.users NOT NULL,
    buyer_id UUID REFERENCES auth.users NOT NULL,
    listing_id UUID REFERENCES listings NOT NULL,
    transaction_date TIMESTAMP DEFAULT NOW(),
    status TEXT CHECK (status IN ('pending', 'completed', 'cancelled')),
    type TEXT CHECK (type IN ('sale', 'purchase', 'donation')),
    amount DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX idx_user_reviews_reviewed_id ON user_reviews(reviewed_id);
CREATE INDEX idx_user_reviews_reviewer_id ON user_reviews(reviewer_id);
CREATE INDEX idx_user_transactions_seller_id ON user_transactions(seller_id);
CREATE INDEX idx_user_transactions_buyer_id ON user_transactions(buyer_id);
CREATE INDEX idx_user_transactions_listing_id ON user_transactions(listing_id);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create RLS policies
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_transactions ENABLE ROW LEVEL SECURITY;

-- User Profiles policies
CREATE POLICY "Users can view any profile"
    ON user_profiles FOR SELECT
    USING (true);

CREATE POLICY "Users can update their own profile"
    ON user_profiles FOR UPDATE
    USING (auth.uid() = id);

-- Reviews policies
CREATE POLICY "Users can view any review"
    ON user_reviews FOR SELECT
    USING (true);

CREATE POLICY "Users can create reviews"
    ON user_reviews FOR INSERT
    WITH CHECK (auth.uid() = reviewer_id);

CREATE POLICY "Users can update their own reviews"
    ON user_reviews FOR UPDATE
    USING (auth.uid() = reviewer_id);

-- Transactions policies
CREATE POLICY "Users can view their own transactions"
    ON user_transactions FOR SELECT
    USING (auth.uid() = seller_id OR auth.uid() = buyer_id);

CREATE POLICY "Users can create transactions"
    ON user_transactions FOR INSERT
    WITH CHECK (auth.uid() = buyer_id);

CREATE POLICY "Sellers can update their transactions"
    ON user_transactions FOR UPDATE
    USING (auth.uid() = seller_id AND status = 'pending'); 