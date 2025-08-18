-- ================================================
-- NOTIFICATION LOGS CHECKER FOR EDUBAZAAR
-- ================================================
-- Run this script to check all notification-related logs and data

-- 1. Check recent logs (last 50 entries)
SELECT 
    '📋 RECENT LOGS (Last 50)' as section,
    '' as separator;

SELECT 
    created_at,
    event_type,
    details,
    error
FROM logs 
ORDER BY created_at DESC 
LIMIT 50;

-- Separator
SELECT '' as separator, '' as data, '' as info, '' as details;

-- 2. Check notification queue status
SELECT 
    '📤 NOTIFICATION QUEUE STATUS' as section,
    '' as separator;

SELECT 
    status,
    COUNT(*) as count,
    MIN(created_at) as oldest,
    MAX(created_at) as newest
FROM notification_queue 
GROUP BY status
ORDER BY count DESC;

-- Separator
SELECT '' as separator, '' as data, '' as info, '' as details;

-- 3. Check recent notification queue entries
SELECT 
    '🔄 RECENT NOTIFICATION QUEUE (Last 20)' as section,
    '' as separator;

SELECT 
    created_at,
    status,
    sender_name,
    message_text,
    attempts,
    error_details,
    (fcm_tokens->0->>'device_type') as device_type
FROM notification_queue 
ORDER BY created_at DESC 
LIMIT 20;

-- Separator
SELECT '' as separator, '' as data, '' as info, '' as details;

-- 4. Check FCM tokens
SELECT 
    '🔑 FCM TOKENS STATUS' as section,
    '' as separator;

SELECT 
    user_id,
    device_type,
    LEFT(fcm_token, 30) || '...' as token_preview,
    created_at
FROM user_fcm_tokens 
ORDER BY created_at DESC 
LIMIT 10;

-- Separator
SELECT '' as separator, '' as data, '' as info, '' as details;

-- 5. Check chat notifications (UI notifications)
SELECT 
    '💬 CHAT NOTIFICATIONS (Last 20)' as section,
    '' as separator;

SELECT 
    created_at,
    type,
    title,
    LEFT(body, 50) || '...' as body_preview,
    is_read,
    user_id
FROM chat_notifications 
ORDER BY created_at DESC 
LIMIT 20;

-- Separator
SELECT '' as separator, '' as data, '' as info, '' as details;

-- 6. Check notification settings
SELECT 
    '⚙️ USER NOTIFICATION SETTINGS' as section,
    '' as separator;

SELECT 
    user_id,
    push_notifications,
    chat_notifications,
    sound_enabled,
    created_at
FROM user_notification_settings 
ORDER BY created_at DESC 
LIMIT 10;

-- Separator
SELECT '' as separator, '' as data, '' as info, '' as details;

-- 7. Check for errors in logs
SELECT 
    '❌ RECENT ERRORS (Last 10)' as section,
    '' as separator;

SELECT 
    created_at,
    event_type,
    error,
    details
FROM logs 
WHERE error IS NOT NULL
ORDER BY created_at DESC 
LIMIT 10;

-- Separator
SELECT '' as separator, '' as data, '' as info, '' as details;

-- 8. Summary statistics
SELECT 
    '📊 SUMMARY STATISTICS' as section,
    '' as separator;

SELECT 
    'Total Logs' as metric,
    COUNT(*) as count,
    '' as details
FROM logs
UNION ALL
SELECT 
    'Total FCM Tokens' as metric,
    COUNT(*) as count,
    '' as details
FROM user_fcm_tokens
UNION ALL
SELECT 
    'Pending Notifications' as metric,
    COUNT(*) as count,
    '' as details
FROM notification_queue 
WHERE status = 'pending'
UNION ALL
SELECT 
    'Failed Notifications' as metric,
    COUNT(*) as count,
    '' as details
FROM notification_queue 
WHERE status = 'failed'
UNION ALL
SELECT 
    'Sent Notifications' as metric,
    COUNT(*) as count,
    '' as details
FROM notification_queue 
WHERE status = 'sent'
UNION ALL
SELECT 
    'Unread Chat Notifications' as metric,
    COUNT(*) as count,
    '' as details
FROM chat_notifications 
WHERE is_read = false;

-- Final message
SELECT 
    '✅ LOG CHECK COMPLETE!' as message,
    'Check the results above for notification system status' as info; 