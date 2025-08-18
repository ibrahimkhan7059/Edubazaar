-- ================================================
-- QUICK LOG SCRIPTS FOR EDUBAZAAR NOTIFICATIONS
-- ================================================
-- Copy and run individual scripts as needed

-- ==== SCRIPT 1: CHECK RECENT LOGS (Last 20) ====
-- Copy from here:
SELECT 
    to_char(created_at, 'MM-DD HH24:MI:SS') as time,
    event_type,
    details->>'message_id' as msg_id,
    details->>'recipient_id' as recipient,
    details
FROM logs 
ORDER BY created_at DESC 
LIMIT 20;
-- To here ^^^^

-- ==== SCRIPT 2: CHECK NOTIFICATION QUEUE ====
-- Copy from here:
SELECT 
    to_char(created_at, 'MM-DD HH24:MI:SS') as time,
    status,
    sender_name,
    LEFT(message_text, 30) as message,
    attempts,
    error_details
FROM notification_queue 
ORDER BY created_at DESC 
LIMIT 15;
-- To here ^^^^

-- ==== SCRIPT 3: CHECK FCM TOKENS ====
-- Copy from here:
SELECT 
    user_id,
    device_type,
    LEFT(fcm_token, 40) || '...' as token,
    to_char(created_at, 'MM-DD HH24:MI') as created
FROM user_fcm_tokens 
ORDER BY created_at DESC;
-- To here ^^^^

-- ==== SCRIPT 4: CHECK ERRORS ONLY ====
-- Copy from here:
SELECT 
    to_char(created_at, 'MM-DD HH24:MI:SS') as time,
    event_type,
    error,
    details
FROM logs 
WHERE error IS NOT NULL
ORDER BY created_at DESC 
LIMIT 10;
-- To here ^^^^

-- ==== SCRIPT 5: CHECK PENDING NOTIFICATIONS ====
-- Copy from here:
SELECT 
    to_char(created_at, 'MM-DD HH24:MI:SS') as time,
    sender_name,
    LEFT(message_text, 50) as message,
    (fcm_tokens->0->>'device_type') as device,
    attempts
FROM notification_queue 
WHERE status = 'pending'
ORDER BY created_at DESC;
-- To here ^^^^

-- ==== SCRIPT 6: COUNT SUMMARY ====
-- Copy from here:
SELECT 
    'Logs' as table_name, COUNT(*) as count FROM logs
UNION ALL
SELECT 
    'FCM Tokens', COUNT(*) FROM user_fcm_tokens
UNION ALL
SELECT 
    'Pending Queue', COUNT(*) FROM notification_queue WHERE status = 'pending'
UNION ALL
SELECT 
    'Failed Queue', COUNT(*) FROM notification_queue WHERE status = 'failed'
UNION ALL
SELECT 
    'Sent Queue', COUNT(*) FROM notification_queue WHERE status = 'sent'
UNION ALL
SELECT 
    'Chat Notifications', COUNT(*) FROM chat_notifications;
-- To here ^^^^

-- ==== SCRIPT 7: TEST TRIGGER (Send Test Log) ====
-- Copy from here:
INSERT INTO logs (event_type, details) 
VALUES ('test_log', json_build_object(
    'test', true,
    'timestamp', NOW(),
    'message', 'Testing log system'
));

SELECT 'Test log inserted successfully!' as result;
-- To here ^^^^

-- ==== SCRIPT 8: CLEAR OLD LOGS (Optional) ====
-- Copy from here (CAREFUL - This deletes data):
-- DELETE FROM logs WHERE created_at < NOW() - INTERVAL '1 day';
-- DELETE FROM notification_queue WHERE status IN ('sent', 'failed') AND created_at < NOW() - INTERVAL '1 hour';
-- SELECT 'Old logs cleaned!' as result;
-- To here ^^^^ 