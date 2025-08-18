-- Reset failed notifications to pending for retry
UPDATE notification_queue 
SET status = 'pending', 
    attempts = 0, 
    error_details = NULL,
    processed_at = NULL
WHERE status = 'failed' 
AND created_at > NOW() - INTERVAL '1 hour';

-- Check current queue status
SELECT 
    id,
    message_text,
    status,
    attempts,
    error_details,
    created_at
FROM notification_queue 
ORDER BY created_at DESC 
LIMIT 3; 