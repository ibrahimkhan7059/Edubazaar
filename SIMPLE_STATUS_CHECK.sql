-- ================================================
-- SIMPLE NOTIFICATION STATUS CHECK
-- ================================================
-- Quick status overview script

-- Recent Activity (Last 15 entries)
SELECT 
    to_char(created_at, 'MM-DD HH24:MI:SS') as time,
    CASE event_type
        WHEN 'trigger_fixed' THEN '🔧 TRIGGER FIXED'
        WHEN 'message_received' THEN '📨 MESSAGE RECEIVED'
        WHEN 'notification_queued' THEN '✅ NOTIFICATION QUEUED'
        WHEN 'notification_skipped' THEN '⏭️ NOTIFICATION SKIPPED'
        WHEN 'notification_error' THEN '❌ NOTIFICATION ERROR'
        WHEN 'notification_warning' THEN '⚠️ WARNING'
        WHEN 'fcm_token_check' THEN '🔑 FCM TOKEN CHECK'
        WHEN 'test_log' THEN '🧪 TEST LOG'
        ELSE event_type
    END as status,
    CASE 
        WHEN details ? 'reason' THEN details->>'reason'
        WHEN details ? 'fcm_token_count' THEN 'Tokens: ' || (details->>'fcm_token_count')
        WHEN details ? 'sender_name' THEN 'From: ' || (details->>'sender_name')
        WHEN error IS NOT NULL THEN LEFT(error, 60)
        ELSE 'OK'
    END as info
FROM logs 
ORDER BY created_at DESC 
LIMIT 15;

-- Quick Queue Status
SELECT '📤 QUEUE STATUS:' as info, '' as status, '' as count;
SELECT 
    '   ' || CASE status
        WHEN 'pending' THEN '🟡 PENDING'
        WHEN 'sent' THEN '✅ SENT' 
        WHEN 'failed' THEN '❌ FAILED'
        ELSE status
    END as info,
    COUNT(*) as count,
    '' as extra
FROM notification_queue 
GROUP BY status
ORDER BY count DESC;

-- Quick Summary
SELECT '📊 SUMMARY:' as info, '' as value, '' as status;
SELECT 
    '   🔑 FCM Tokens:' as info,
    COUNT(*) as value,
    CASE WHEN COUNT(*) > 0 THEN '✅' ELSE '❌' END as status
FROM user_fcm_tokens
UNION ALL
SELECT 
    '   🟡 Pending:',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✅' ELSE '⚠️' END
FROM notification_queue WHERE status = 'pending'
UNION ALL
SELECT 
    '   ❌ Recent Errors:',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN '✅' ELSE '🚨' END
FROM logs WHERE error IS NOT NULL AND created_at > NOW() - INTERVAL '1 hour';

-- Health Check
SELECT 
    '🎯 SYSTEM HEALTH:' as check,
    CASE 
        WHEN EXISTS (SELECT 1 FROM logs WHERE event_type = 'notification_error' AND created_at > NOW() - INTERVAL '5 minutes')
        THEN '🚨 ERRORS DETECTED'
        WHEN EXISTS (SELECT 1 FROM logs WHERE event_type = 'notification_queued' AND created_at > NOW() - INTERVAL '10 minutes')
        THEN '✅ ACTIVELY WORKING'
        WHEN EXISTS (SELECT 1 FROM user_fcm_tokens)
        THEN '✅ READY (Send test message)'
        ELSE '⚠️ NO RECENT ACTIVITY'
    END as status; 