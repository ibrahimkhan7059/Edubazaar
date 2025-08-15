-- Fix duplicate FCM tokens
BEGIN;

-- Create a temporary table to store unique tokens
CREATE TEMP TABLE unique_tokens AS
SELECT DISTINCT ON (user_id, fcm_token)
  id,
  user_id,
  fcm_token,
  device_type,
  created_at,
  updated_at
FROM user_fcm_tokens
ORDER BY user_id, fcm_token, updated_at DESC;

-- Delete all records from the original table
DELETE FROM user_fcm_tokens;

-- Insert unique records back
INSERT INTO user_fcm_tokens
SELECT * FROM unique_tokens;

-- Drop the temporary table
DROP TABLE unique_tokens;

-- Add unique constraint if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.table_constraints 
    WHERE constraint_name = 'user_fcm_tokens_user_id_fcm_token_key'
  ) THEN
    ALTER TABLE user_fcm_tokens
    ADD CONSTRAINT user_fcm_tokens_user_id_fcm_token_key 
    UNIQUE (user_id, fcm_token);
  END IF;
END $$;

COMMIT;

-- Verify the fix
SELECT COUNT(*) as total_tokens FROM user_fcm_tokens;
SELECT user_id, COUNT(*) as token_count 
FROM user_fcm_tokens 
GROUP BY user_id 
ORDER BY token_count DESC; 