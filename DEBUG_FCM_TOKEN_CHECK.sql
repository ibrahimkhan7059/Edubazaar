-- Debug FCM token check for specific users
-- Test the exact logic from the trigger

DO $$
DECLARE
    recipient_id text := '41395f14-0a93-45cf-a8e4-4d24c9d255da';
    has_fcm_token boolean;
BEGIN
    -- Test 1: Check with text type (current trigger logic)
    SELECT EXISTS (
        SELECT 1 FROM user_fcm_tokens
        WHERE user_id = recipient_id::uuid
    ) INTO has_fcm_token;
    
    RAISE NOTICE 'Test 1 - recipient_id as text cast to uuid: %', has_fcm_token;
    
    -- Test 2: Check with direct uuid
    SELECT EXISTS (
        SELECT 1 FROM user_fcm_tokens
        WHERE user_id = '41395f14-0a93-45cf-a8e4-4d24c9d255da'::uuid
    ) INTO has_fcm_token;
    
    RAISE NOTICE 'Test 2 - direct uuid: %', has_fcm_token;
    
    -- Test 3: Check actual data in table
    RAISE NOTICE 'Actual FCM tokens for user:';
    PERFORM (
        SELECT RAISE(NOTICE, 'User: %, Token: %', user_id, fcm_token)
        FROM user_fcm_tokens 
        WHERE user_id = '41395f14-0a93-45cf-a8e4-4d24c9d255da'::uuid
    );
    
END $$; 