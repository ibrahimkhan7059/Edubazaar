# Google Sign-In Setup Guide

## Step 1: Get SHA-1 Fingerprint

### For Windows (PowerShell):
```bash
cd android
./gradlew signingReport
```

### Alternative Method:
```bash
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

## Step 2: Google Cloud Console Setup
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create new project or select existing
3. Enable "Google Sign-In API"
4. Go to APIs & Services > Credentials
5. Create OAuth 2.0 Client ID:
   - Application type: Android
   - Package name: `com.example.edubazaar`
   - SHA-1 fingerprint: (from step 1)

## Step 3: Download google-services.json
1. After creating OAuth client, download `google-services.json`
2. Place it in `android/app/` directory

## Step 4: Update Android Configuration

### Update android/app/build.gradle:
Add at the top (after existing plugins):
```gradle
id 'com.google.gms.google-services'
```

Add to dependencies:
```gradle
implementation 'com.google.android.gms:play-services-auth:20.7.0'
```

### Update android/build.gradle:
Add to dependencies:
```gradle
classpath 'com.google.gms:google-services:4.3.15'
```

## Step 5: Test
```bash
flutter clean
flutter pub get
flutter run
```

## Troubleshooting
- Make sure package name matches exactly
- SHA-1 fingerprint must be correct
- google-services.json must be in android/app/
- Internet connection required
- Restart app after configuration 