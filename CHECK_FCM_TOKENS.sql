-- Check FCM tokens for all users
SELECT 
    uft.user_id,
    p.full_name,
    uft.fcm_token,
    uft.device_type,
    uft.created_at
FROM user_fcm_tokens uft
LEFT JOIN profiles p ON p.id = uft.user_id
ORDER BY uft.created_at DESC;

-- Check users without FCM tokens
SELECT 
    p.id as user_id,
    p.full_name,
    p.created_at as user_created_at
FROM profiles p
LEFT JOIN user_fcm_tokens uft ON uft.user_id = p.id
WHERE uft.id IS NULL
ORDER BY p.created_at DESC; 