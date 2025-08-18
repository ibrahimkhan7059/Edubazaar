# FCM HTTP v1 API Setup for Real Push Notifications

## 🚨 Problem: FCM Legacy API Disabled
- Google ne Legacy API (`https://fcm.googleapis.com/fcm/send`) disable kar diya
- HTTP v1 API (`https://fcm.googleapis.com/v1/projects/{project}/messages:send`) still working

## ✅ Solution: Switch to FCM HTTP v1 API

### Step 1: Get Firebase Service Account Key
1. **Firebase Console** → Project Settings → Service Accounts
2. **Generate new private key** button click karo
3. **JSON file download** hoga - ye service account key hai

### Step 2: Add Secrets to Supabase
```
Supabase Dashboard → Functions → Secrets

Add these:
- FIREBASE_PROJECT_ID: edubazaar-467505
- FIREBASE_SERVICE_ACCOUNT: {paste entire JSON content}
```

### Step 3: Update Edge Function
Replace current Edge Function with FCM v1 API version.

### Step 4: Test Real Push Notifications
- App completely close kar ke test karo
- Doosre device se message send karo
- Push notification receive hona chahiye

## 🎯 Benefits of FCM v1 API:
- ✅ Real push notifications (app closed bhi)
- ✅ Cross-device notifications  
- ✅ Background notifications
- ✅ Rich notifications with images
- ✅ Official Google support

## 📱 Flow with FCM v1:
```
User A (Any State) → Message → FCM v1 → User B Device → Push Notification
```

## ⚡ Quick Setup Commands:
1. Download service account JSON from Firebase
2. Add to Supabase secrets
3. Deploy updated Edge Function
4. Test cross-device notifications 