# Google Cloud Console Setup for Google Sign-In

## Step 1: Create Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Sign in with your Google account
3. Click **"Select a project"** or **"New Project"**
4. Click **"NEW PROJECT"**
5. Enter project name: `EduBazaar` (or any name you want)
6. Click **"CREATE"**

## Step 2: Enable Google Sign-In API
1. In your project, go to **"APIs & Services"** > **"Library"**
2. Search for **"Google Sign-In API"** or **"Google+ API"**
3. Click on it and press **"ENABLE"**

## Step 3: Create OAuth 2.0 Credentials
1. Go to **"APIs & Services"** > **"Credentials"**
2. Click **"+ CREATE CREDENTIALS"**
3. Select **"OAuth 2.0 Client IDs"**
4. If prompted, configure OAuth consent screen first:
   - User Type: **External**
   - App name: `EduBazaar`
   - User support email: Your email
   - Developer contact: Your email
   - Click **"SAVE AND CONTINUE"**

## Step 4: Create Android OAuth Client
1. Back in Credentials, click **"+ CREATE CREDENTIALS"** > **"OAuth 2.0 Client IDs"**
2. Application type: **Android**
3. Name: `EduBazaar Android`
4. Package name: `com.example.edubazaar`
5. SHA-1 certificate fingerprint: **[NEED TO GET THIS]**

## Step 5: Get SHA-1 Fingerprint
Open command prompt/terminal and run:
```bash
# For Windows (in your project folder)
cd android
./gradlew signingReport

# OR alternative method
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

Look for **SHA1** fingerprint like: `12:34:56:78:90:AB:CD:EF...`

## Step 6: Complete OAuth Client Setup
1. Copy the SHA-1 fingerprint
2. Paste it in the **SHA-1 certificate fingerprint** field
3. Click **"CREATE"**
4. **IMPORTANT**: Download the `google-services.json` file
5. Place it in `android/app/` folder (replace the existing one)

## Step 7: Test Setup
```bash
flutter clean
flutter pub get
flutter run
```

## Troubleshooting
- Make sure package name is exactly `com.example.edubazaar`
- SHA-1 fingerprint must be correct
- `google-services.json` must be in `android/app/` folder
- Internet connection required for testing

## What You'll Get
- Real `google-services.json` file
- Working Google Sign-In
- No more platform errors 