# Firebase Setup Instructions

Your current google-services.json file has the wrong package name. You need to add a new Android app to your Firebase project with the correct package name.

## Steps to Fix:

1. **Go to Firebase Console**: https://console.firebase.google.com/project/edubazaar-467505
2. **Add Android App**:
   - Click "Add app" or the "+" icon
   - Select "Android"
   - **Package name**: `io.github.ibrahimkhan7059.edubazaar` (without .new)
   - **App nickname**: EduBazaar (or any name you prefer)
   - **SHA-1**: Generate using: `cd android && ./gradlew signingReport`

3. **Download new google-services.json**:
   - Download the new google-services.json file
   - Replace the current one in: `android/app/google-services.json`

4. **Update Auth Service**:
   - Use the Android client ID (type 1) from the new google-services.json
   - Update the serverClientId in auth_service.dart

## Current Package Names:
- ❌ Old (invalid): `io.github.ibrahimkhan7059.edubazaar.new`
- ✅ New (correct): `io.github.ibrahimkhan7059.edubazaar`

## Alternative Package Name Options:
If you want to keep it unique, you could use:
- `io.github.ibrahimkhan7059.edubazaar` (recommended)
- `com.ibrahimkhan7059.edubazaar`
- `app.edubazaar.student`

The key is that it cannot contain Java keywords like "new", "class", "static", etc.
