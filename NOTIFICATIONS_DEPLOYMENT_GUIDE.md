# Chat Notifications Deployment Guide

## Overview
This guide will help you deploy chat notifications for EduBazaar using Supabase Edge Functions and database triggers.

## Prerequisites
- Supabase project with admin access
- Firebase project with FCM enabled
- Firebase service account JSON file

## Step 1: Get Your Supabase Project Details

1. Go to your Supabase dashboard: https://supabase.com/dashboard
2. Select your project
3. Note down:
   - **Project Reference** (e.g., `abcdefghijklmnop`)
   - **Project URL** (e.g., `https://abcdefghijklmnop.supabase.co`)
   - **Service Role Key** (Settings → API → Project API keys → service_role)

## Step 2: Deploy the Edge Function

### Option A: Using Supabase CLI (Recommended)

1. Install Supabase CLI:
   ```bash
   # Windows (PowerShell)
   winget install Supabase.CLI
   
   # Or download manually:
   # https://github.com/supabase/cli/releases/latest/download/supabase_windows_amd64.exe
   ```

2. Login to Supabase:
   ```bash
   supabase login
   ```

3. Link your project:
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   ```

4. Deploy the function:
   ```bash
   supabase functions deploy notify-chat --no-verify-jwt
   ```

### Option B: Manual Deployment

1. Go to Supabase Dashboard → Edge Functions
2. Click "Create a new function"
3. Name: `notify-chat`
4. Copy the code from `supabase/functions/notify-chat/index.ts`
5. Click "Deploy"

## Step 3: Set Environment Variables

In Supabase Dashboard → Edge Functions → notify-chat → Settings:

1. **FCM_SERVICE_ACCOUNT**: Your Firebase service account JSON (entire content)
2. **EDGE_NOTIFY_SECRET**: A strong random string (e.g., `supabase-chat-secret-2024`)
3. **SUPABASE_URL**: Your project URL
4. **SUPABASE_SERVICE_ROLE_KEY**: Your service role key

## Step 4: Update SQL Script

1. Open `CHAT_NOTIFICATIONS_SETUP.sql`
2. Replace placeholders:
   - `YOUR_PROJECT_REF` → Your actual project reference
   - `YOUR_EDGE_NOTIFY_SECRET` → Same secret you set in Step 3

## Step 5: Run Database Setup

1. Go to Supabase Dashboard → SQL Editor
2. Copy and paste the updated `CHAT_NOTIFICATIONS_SETUP.sql`
3. Click "Run"

## Step 6: Test the Setup

### Test Message Trigger
```sql
-- Create a test conversation first
INSERT INTO conversations (participant_1_id, participant_2_id)
VALUES ('test-user-1', 'test-user-2');

-- Then insert a test message
INSERT INTO messages (conversation_id, sender_id, message_text, message_type)
VALUES (
  (SELECT id FROM conversations LIMIT 1),
  'test-user-1',
  'Hello, this is a test message!',
  'text'
);
```

### Check Logs
1. Go to Edge Functions → notify-chat → Logs
2. Look for successful execution or errors

## Step 7: Client-Side Integration

### Add FCM Token Saving
In your Flutter app, ensure FCM tokens are saved to `user_profiles`:

```dart
// After getting FCM token
final token = await FirebaseMessaging.instance.getToken();
if (token != null) {
  await supabase
    .from('user_profiles')
    .update({'fcm_token': token})
    .eq('id', currentUserId);
}
```

### Handle Notification Taps
```dart
// In your notification service
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  final data = message.data;
  if (data['type'] == 'chat_message') {
    // Navigate to chat screen
    Navigator.pushNamed(context, '/chat', arguments: {
      'conversationId': data['conversationId'],
      'otherUserId': data['senderId'],
    });
  }
});
```

## Troubleshooting

### Common Issues

1. **"Function not found"**
   - Ensure the function is deployed
   - Check the function name in SQL triggers

2. **"Unauthorized"**
   - Verify `EDGE_NOTIFY_SECRET` matches in both places
   - Check environment variables are set correctly

3. **"FCM_SERVICE_ACCOUNT not set"**
   - Ensure the environment variable is set
   - Check JSON format is correct

4. **"HTTP extension not available"**
   - Run: `CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;`

### Debug Steps

1. Check Edge Function logs
2. Verify database triggers exist
3. Test with simple HTTP calls
4. Check environment variables

## Security Notes

- Keep `EDGE_NOTIFY_SECRET` secure and random
- Use service role key only in Edge Functions
- Validate all inputs in the function
- Monitor function usage and logs

## Next Steps

After successful deployment:
1. Test with real users
2. Monitor notification delivery
3. Add analytics if needed
4. Consider rate limiting for production

## Support

If you encounter issues:
1. Check Supabase documentation
2. Review Edge Function logs
3. Verify all environment variables
4. Test with simplified payloads 