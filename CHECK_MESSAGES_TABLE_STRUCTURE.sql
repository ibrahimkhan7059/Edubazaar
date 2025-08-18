-- Check the actual structure of the messages table
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'messages' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Also check a sample record to see the actual column names
SELECT * FROM messages LIMIT 1; 