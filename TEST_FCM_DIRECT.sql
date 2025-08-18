-- Get FCM token data for manual testing
SELECT 
    uft.user_id,
    p.full_name,
    uft.fcm_token,
    uft.device_type,
    uft.created_at
FROM user_fcm_tokens uft
LEFT JOIN profiles p ON p.id = uft.user_id
ORDER BY uft.created_at DESC
LIMIT 5;

-- Get the specific notification that failed
SELECT 
    nq.id,
    nq.message_text,
    nq.sender_name,
    nq.fcm_tokens,
    nq.error_details,
    nq.attempts,
    nq.status
FROM notification_queue nq
WHERE nq.status = 'failed'
ORDER BY nq.created_at DESC
LIMIT 3; 