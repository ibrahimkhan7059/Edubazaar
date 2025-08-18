-- ============================================
-- WELCOME EMAIL SETUP FOR EDUBAZAAR
-- ============================================

-- Create table to track welcome emails sent to users
CREATE TABLE IF NOT EXISTS user_welcome_emails (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    email_type VARCHAR(50) NOT NULL DEFAULT 'welcome',
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    email_provider VARCHAR(50), -- 'sendgrid', 'mailgun', 'resend'
    status VARCHAR(20) DEFAULT 'sent', -- 'sent', 'failed', 'pending'
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_welcome_emails_user_id ON user_welcome_emails(user_id);
CREATE INDEX IF NOT EXISTS idx_user_welcome_emails_email_type ON user_welcome_emails(email_type);
CREATE INDEX IF NOT EXISTS idx_user_welcome_emails_sent_at ON user_welcome_emails(sent_at);

-- Enable Row Level Security (RLS)
ALTER TABLE user_welcome_emails ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Users can only see their own welcome email records
CREATE POLICY "Users can view own welcome email records" ON user_welcome_emails
    FOR SELECT USING (auth.uid() = user_id);

-- Service role can insert/update welcome email records
CREATE POLICY "Service role can manage welcome email records" ON user_welcome_emails
    FOR ALL USING (auth.role() = 'service_role');

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_welcome_emails_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at
CREATE TRIGGER trigger_update_user_welcome_emails_updated_at
    BEFORE UPDATE ON user_welcome_emails
    FOR EACH ROW
    EXECUTE FUNCTION update_user_welcome_emails_updated_at();

-- Insert sample data for testing (optional)
-- INSERT INTO user_welcome_emails (user_id, email_type, email_provider, status)
-- VALUES 
--     ('00000000-0000-0000-0000-000000000000', 'welcome', 'sendgrid', 'sent'),
--     ('00000000-0000-0000-0000-000000000001', 'welcome', 'mailgun', 'sent');

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE ON user_welcome_emails TO authenticated;
GRANT ALL ON user_welcome_emails TO service_role;

-- ============================================
-- SUPABASE EDGE FUNCTIONS DEPLOYMENT
-- ============================================

-- To deploy the Edge Functions, run these commands in your terminal:

-- 1. Navigate to your project directory
-- cd your-project-directory

-- 2. Deploy the welcome email function
-- supabase functions deploy send-welcome-email

-- 3. Deploy the Google welcome email function  
-- supabase functions deploy send-google-welcome-email

-- 4. Set environment variables (API keys) in Supabase dashboard:
-- Go to Settings > Edge Functions > Environment Variables
-- Add:
-- SENDGRID_API_KEY=your_sendgrid_api_key
-- MAILGUN_API_KEY=your_mailgun_api_key  
-- MAILGUN_DOMAIN=your_mailgun_domain
-- RESEND_API_KEY=your_resend_api_key

-- ============================================
-- EMAIL SERVICE SETUP INSTRUCTIONS
-- ============================================

-- Option 1: SendGrid (Recommended)
-- 1. Sign up at sendgrid.com
-- 2. Get API key from Settings > API Keys
-- 3. Verify sender domain
-- 4. Add SENDGRID_API_KEY to Supabase secrets

-- Option 2: Mailgun
-- 1. Sign up at mailgun.com
-- 2. Get API key from Settings > API Keys
-- 3. Add MAILGUN_API_KEY and MAILGUN_DOMAIN to Supabase secrets

-- Option 3: Resend
-- 1. Sign up at resend.com
-- 2. Get API key from API Keys section
-- 3. Add RESEND_API_KEY to Supabase secrets

-- ============================================
-- TESTING THE WELCOME EMAIL SYSTEM
-- ============================================

-- Test the welcome email tracking table:
-- SELECT * FROM user_welcome_emails;

-- Test with a specific user:
-- SELECT * FROM user_welcome_emails WHERE user_id = 'your-user-id';

-- Check email status:
-- SELECT 
--     u.email,
--     uwe.email_type,
--     uwe.sent_at,
--     uwe.status,
--     uwe.email_provider
-- FROM user_welcome_emails uwe
-- JOIN auth.users u ON uwe.user_id = u.id
-- ORDER BY uwe.sent_at DESC;

-- ============================================
-- MONITORING AND ANALYTICS
-- ============================================

-- Create view for welcome email analytics
CREATE OR REPLACE VIEW welcome_email_analytics AS
SELECT 
    DATE(sent_at) as send_date,
    email_provider,
    status,
    COUNT(*) as email_count
FROM user_welcome_emails
WHERE email_type = 'welcome'
GROUP BY DATE(sent_at), email_provider, status
ORDER BY send_date DESC;

-- Create view for user engagement tracking
CREATE OR REPLACE VIEW user_welcome_engagement AS
SELECT 
    uwe.user_id,
    u.email,
    uwe.sent_at,
    uwe.email_provider,
    uwe.status,
    CASE 
        WHEN u.last_sign_in_at > uwe.sent_at THEN 'engaged'
        ELSE 'not_engaged'
    END as engagement_status
FROM user_welcome_emails uwe
JOIN auth.users u ON uwe.user_id = u.id
WHERE uwe.email_type = 'welcome'
ORDER BY uwe.sent_at DESC; 