-- Add last_active column to user_profiles table
ALTER TABLE user_profiles 
ADD COLUMN IF NOT EXISTS last_active TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Create function to update user's last active time
CREATE OR REPLACE FUNCTION update_user_last_active(user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE user_profiles 
  SET last_active = NOW() 
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get user's last active status
CREATE OR REPLACE FUNCTION get_user_last_active_status(user_id UUID)
RETURNS TEXT AS $$
DECLARE
  last_active_time TIMESTAMP WITH TIME ZONE;
  time_diff INTERVAL;
BEGIN
  SELECT last_active INTO last_active_time
  FROM user_profiles 
  WHERE id = user_id;
  
  IF last_active_time IS NULL THEN
    RETURN 'Last seen unknown';
  END IF;
  
  time_diff = NOW() - last_active_time;
  
  -- If last active is within 5 minutes, show "Active now"
  IF time_diff <= INTERVAL '5 minutes' THEN
    RETURN 'Active now';
  -- If within 1 hour, show minutes
  ELSIF time_diff <= INTERVAL '1 hour' THEN
    RETURN 'Last seen ' || EXTRACT(MINUTE FROM time_diff) || ' minutes ago';
  -- If within 24 hours, show hours
  ELSIF time_diff <= INTERVAL '24 hours' THEN
    RETURN 'Last seen ' || EXTRACT(HOUR FROM time_diff) || ' hours ago';
  -- If within 7 days, show days
  ELSIF time_diff <= INTERVAL '7 days' THEN
    RETURN 'Last seen ' || EXTRACT(DAY FROM time_diff) || ' days ago';
  -- If within 4 weeks, show weeks
  ELSIF time_diff <= INTERVAL '28 days' THEN
    RETURN 'Last seen ' || (EXTRACT(DAY FROM time_diff) / 7)::INTEGER || ' weeks ago';
  -- Otherwise show months
  ELSE
    RETURN 'Last seen ' || (EXTRACT(DAY FROM time_diff) / 30)::INTEGER || ' months ago';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION update_user_last_active(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_last_active_status(UUID) TO authenticated;

-- Update existing users to have last_active set to their created_at time
UPDATE user_profiles 
SET last_active = created_at 
WHERE last_active IS NULL; 