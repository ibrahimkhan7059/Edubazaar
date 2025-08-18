-- Reset failed notifications to pending for retry with FCM v1 API
-- Run this after updating the Edge Function to FCM v1 API

-- Reset failed notifications to pending
UPDATE notification_queue 
SET status = 'pending', 
    attempts = 0, 
    error_details = NULL,
    processed_at = NULL
WHERE status = 'failed' 
AND created_at > NOW() - INTERVAL '1 hour';

-- Show the reset notifications
SELECT 
  id,
  message_id,
  sender_name,
  message_text,
  status,
  attempts,
  created_at
FROM notification_queue 
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;

-- Check FCM tokens are still available
SELECT 
  u.id,
  u.fcm_token,
  u.device_type,
  u.created_at
FROM user_fcm_tokens u
ORDER BY u.created_at DESC
LIMIT 5; 