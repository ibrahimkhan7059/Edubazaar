-- ================================================
-- DEBUG NOTIFICATION ERROR SCRIPT
-- ================================================
-- This script will identify and fix the notification error

-- 1. Check the specific error details
SELECT 
    'ERROR DETAILS' as section,
    to_char(created_at, 'MM-DD HH24:MI:SS') as time,
    event_type,
    error,
    details->>'sqlstate' as sql_state,
    details->>'message_id' as message_id,
    details->>'sender_id' as sender_id,
    details
FROM logs 
WHERE event_type = 'notification_error'
ORDER BY created_at DESC 
LIMIT 5;

-- 2. Check if messages table has the correct columns
SELECT 
    'MESSAGES TABLE COLUMNS' as section;

SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'messages' 
ORDER BY column_name;

-- 3. Check if conversations table has correct columns  
SELECT 
    'CONVERSATIONS TABLE COLUMNS' as section;

SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'conversations' 
ORDER BY column_name;

-- 4. Check if profiles table exists and has columns
SELECT 
    'PROFILES TABLE COLUMNS' as section;

SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
ORDER BY column_name;

-- 5. Test a simple message insert to see what happens
SELECT 
    'TESTING MESSAGE COLUMN ACCESS' as section;

-- Check if we can access message columns (adjust based on your table structure)
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'message_text') 
        THEN 'message_text column EXISTS' 
        ELSE 'message_text column MISSING' 
    END as message_text_status,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'content') 
        THEN 'content column EXISTS' 
        ELSE 'content column MISSING' 
    END as content_status,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'message_type') 
        THEN 'message_type column EXISTS' 
        ELSE 'message_type column MISSING' 
    END as message_type_status;

-- 6. Check trigger function exists
SELECT 
    'TRIGGER FUNCTION STATUS' as section;

SELECT 
    routine_name,
    routine_type,
    specific_name
FROM information_schema.routines 
WHERE routine_name = 'notify_chat_on_message';

-- 7. Check if trigger exists on messages table
SELECT 
    'TRIGGER STATUS' as section;

SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'notify_chat_trigger';

-- 8. Show sample message record structure
SELECT 
    'SAMPLE MESSAGE STRUCTURE' as section;

SELECT *
FROM messages 
ORDER BY created_at DESC 
LIMIT 1; 