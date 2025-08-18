-- ================================================
-- NOTIFICATION STATUS LOGS - RECENT ACTIVITY
-- ================================================
-- Shows recent notification activity with clear status indicators

-- Main status overview with emojis and colors
SELECT 
    '🎯 NOTIFICATION SYSTEM STATUS (Last 30 minutes)' as section,
    '' as separator;

SELECT 
    to_char(created_at, 'MM-DD HH24:MI:SS') as time,
    CASE event_type
        WHEN 'trigger_fixed' THEN '🔧 FIXED'
        WHEN 'message_received' THEN '📨 MSG RECEIVED'
        WHEN 'notification_queued' THEN '✅ QUEUED FOR SENDING'
        WHEN 'notification_skipped' THEN '⏭️ SKIPPED'
        WHEN 'notification_error' THEN '❌ ERROR'
        WHEN 'notification_warning' THEN '⚠️ WARNING'
        WHEN 'fcm_token_check' THEN '🔑 TOKEN CHECK'
        WHEN 'notification_attempt' THEN '📤 SENDING ATTEMPT'
        WHEN 'test_log' THEN '🧪 TEST'
        ELSE '📋 ' || event_type
    END as status,
    CASE 
        WHEN details ? 'recipient_id' THEN 'To: ' || LEFT(details->>'recipient_id', 8) || '...'
        WHEN details ? 'sender_id' THEN 'From: ' || LEFT(details->>'sender_id', 8) || '...'
        ELSE ''
    END as user_info,
    CASE 
        WHEN details ? 'message_content' THEN LEFT(details->>'message_content', 40) || '...'
        WHEN details ? 'message_text' THEN LEFT(details->>'message_text', 40) || '...'
        WHEN details ? 'reason' THEN 'Reason: ' || (details->>'reason')
        WHEN details ? 'step' THEN 'Step: ' || (details->>'step')
        WHEN details ? 'fcm_token_count' THEN 'Tokens: ' || (details->>'fcm_token_count')
        WHEN error IS NOT NULL THEN 'Error: ' || LEFT(error, 50) || '...'
        ELSE 'OK'
    END as details_summary,
    details
FROM logs 
WHERE created_at > NOW() - INTERVAL '30 minutes'
ORDER BY created_at DESC 
LIMIT 20;

-- Separator
SELECT '' as separator, '' as data, '' as info, '' as details, '' as more;

-- Notification Queue Status
SELECT 
    '📤 NOTIFICATION QUEUE STATUS' as section,
    '' as separator;

SELECT 
    CASE status
        WHEN 'pending' THEN '🟡 PENDING'
        WHEN 'processing' THEN '🔄 PROCESSING'
        WHEN 'sent' THEN '✅ SENT'
        WHEN 'failed' THEN '❌ FAILED'
        ELSE '❓ ' || status
    END as queue_status,
    COUNT(*) as count,
    MIN(to_char(created_at, 'MM-DD HH24:MI')) as oldest,
    MAX(to_char(created_at, 'MM-DD HH24:MI')) as newest
FROM notification_queue 
GROUP BY status
ORDER BY 
    CASE status
        WHEN 'pending' THEN 1
        WHEN 'processing' THEN 2
        WHEN 'sent' THEN 3
        WHEN 'failed' THEN 4
        ELSE 5
    END;

-- Separator
SELECT '' as separator, '' as data, '' as info, '' as details, '' as more;

-- Recent Queue Items
SELECT 
    '🔄 RECENT QUEUE ITEMS (Last 10)' as section,
    '' as separator;

SELECT 
    to_char(created_at, 'MM-DD HH24:MI:SS') as time,
    CASE status
        WHEN 'pending' THEN '🟡 PENDING'
        WHEN 'processing' THEN '🔄 PROCESSING' 
        WHEN 'sent' THEN '✅ SENT'
        WHEN 'failed' THEN '❌ FAILED'
        ELSE status
    END as status,
    sender_name,
    LEFT(message_text, 30) || '...' as message,
    attempts,
    CASE 
        WHEN error_details IS NOT NULL THEN LEFT(error_details, 50) || '...'
        ELSE 'OK'
    END as error_info
FROM notification_queue 
ORDER BY created_at DESC 
LIMIT 10;

-- Separator  
SELECT '' as separator, '' as data, '' as info, '' as details, '' as more;

-- Error Summary
SELECT 
    '❌ RECENT ERRORS (Last 10)' as section,
    '' as separator;

SELECT 
    to_char(created_at, 'MM-DD HH24:MI:SS') as time,
    event_type,
    LEFT(error, 60) || '...' as error_message,
    CASE 
        WHEN details ? 'step' THEN 'Step: ' || (details->>'step')
        WHEN details ? 'sqlstate' THEN 'SQL: ' || (details->>'sqlstate')
        ELSE 'General'
    END as error_context
FROM logs 
WHERE error IS NOT NULL
ORDER BY created_at DESC 
LIMIT 10;

-- Separator
SELECT '' as separator, '' as data, '' as info, '' as details, '' as more;

-- Summary Statistics with Status
SELECT 
    '📊 CURRENT STATISTICS' as section,
    '' as separator;

SELECT 
    CASE metric
        WHEN 'Recent Logs (30min)' THEN '📋 ' || metric
        WHEN 'FCM Tokens' THEN '🔑 ' || metric
        WHEN 'Pending Notifications' THEN '🟡 ' || metric
        WHEN 'Failed Notifications' THEN '❌ ' || metric  
        WHEN 'Sent Notifications' THEN '✅ ' || metric
        WHEN 'Recent Errors (30min)' THEN '🚨 ' || metric
        ELSE metric
    END as status_metric,
    count,
    CASE 
        WHEN metric LIKE '%Error%' AND count > 0 THEN '⚠️ NEEDS ATTENTION'
        WHEN metric LIKE '%Pending%' AND count > 5 THEN '⚠️ HIGH QUEUE'
        WHEN metric LIKE '%Failed%' AND count > 0 THEN '⚠️ CHECK ISSUES'
        WHEN metric LIKE '%Sent%' AND count > 0 THEN '✅ WORKING'
        ELSE '✅ NORMAL'
    END as health_status
FROM (
    SELECT 'Recent Logs (30min)' as metric, COUNT(*) as count 
    FROM logs WHERE created_at > NOW() - INTERVAL '30 minutes'
    UNION ALL
    SELECT 'FCM Tokens', COUNT(*) FROM user_fcm_tokens
    UNION ALL
    SELECT 'Pending Notifications', COUNT(*) FROM notification_queue WHERE status = 'pending'
    UNION ALL
    SELECT 'Failed Notifications', COUNT(*) FROM notification_queue WHERE status = 'failed'  
    UNION ALL
    SELECT 'Sent Notifications', COUNT(*) FROM notification_queue WHERE status = 'sent'
    UNION ALL
    SELECT 'Recent Errors (30min)', COUNT(*) 
    FROM logs WHERE error IS NOT NULL AND created_at > NOW() - INTERVAL '30 minutes'
) stats;

-- Final Status Message
SELECT 
    '🎯 NOTIFICATION SYSTEM HEALTH CHECK COMPLETE!' as message,
    'Check the sections above for detailed status' as instruction,
    CASE 
        WHEN EXISTS (SELECT 1 FROM logs WHERE event_type = 'notification_error' AND created_at > NOW() - INTERVAL '10 minutes')
        THEN '⚠️ Recent errors detected - check error section'
        WHEN EXISTS (SELECT 1 FROM notification_queue WHERE status = 'pending' AND created_at < NOW() - INTERVAL '5 minutes')
        THEN '⚠️ Old pending notifications - check queue processing'
        WHEN EXISTS (SELECT 1 FROM logs WHERE event_type = 'notification_queued' AND created_at > NOW() - INTERVAL '5 minutes')
        THEN '✅ System is actively processing notifications'
        ELSE '✅ System appears healthy'
    END as overall_health; 