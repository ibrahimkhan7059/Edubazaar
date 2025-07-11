# 🚀 EduBazaar Supabase Setup Guide

This guide will help you connect your EduBazaar Flutter app to Supabase for authentication and database functionality.

## 📋 Prerequisites

- Flutter development environment set up
- A Supabase account (free tier available)
- Google Cloud Console account (for Google Sign-In)

## 🔧 Step 1: Create Supabase Project

1. **Go to [Supabase](https://supabase.com)**
2. **Sign up/Login** to your account
3. **Click "New Project"**
4. **Fill in project details:**
   - Name: `EduBazaar`
   - Database Password: (create a strong password)
   - Region: (choose closest to your users)
5. **Click "Create new project"**
6. **Wait for setup to complete** (takes ~2 minutes)

## 🔑 Step 2: Get Supabase Credentials

1. **Go to your project dashboard**
2. **Click "Settings" → "API"**
3. **Copy these values:**
   - **Project URL**: `https://your-project-id.supabase.co`
   - **Anon Key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

## 📝 Step 3: Update Flutter App Configuration

1. **Open `lib/config/supabase_config.dart`**
2. **Replace the placeholder values:**

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://your-project-id.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
}
```

## 🗄️ Step 4: Create Database Tables

1. **Go to Supabase Dashboard → "SQL Editor"**
2. **Run this SQL to create the profiles table:**

```sql
-- Create profiles table
CREATE TABLE profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  avatar_url TEXT,
  email TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (id)
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Create policy for users to see their own profile
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

-- Create policy for users to update their own profile
CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Create policy for users to insert their own profile
CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Create a trigger to automatically create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, avatar_url, email)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'avatar_url', NEW.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

## 🔐 Step 5: Configure Google Sign-In

### 5.1 Google Cloud Console Setup

1. **Go to [Google Cloud Console](https://console.cloud.google.com)**
2. **Create a new project or select existing**
3. **Enable Google+ API:**
   - Go to "APIs & Services" → "Library"
   - Search for "Google+ API"
   - Click "Enable"

### 5.2 Create OAuth 2.0 Credentials

1. **Go to "APIs & Services" → "Credentials"**
2. **Click "Create Credentials" → "OAuth 2.0 Client IDs"**
3. **Configure consent screen** (if not done):
   - User Type: External
   - App name: EduBazaar
   - User support email: your email
   - Developer contact: your email
4. **Create credentials for each platform:**

#### Android:
- Application type: Android
- Name: EduBazaar Android
- Package name: `com.example.edubazaar` (from android/app/build.gradle)
- SHA-1 certificate: Get from terminal:
  ```bash
  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
  ```

#### iOS:
- Application type: iOS
- Name: EduBazaar iOS
- Bundle ID: `com.example.edubazaar` (from ios/Runner/Info.plist)

#### Web:
- Application type: Web application
- Name: EduBazaar Web
- Authorized redirect URIs: `https://your-project-id.supabase.co/auth/v1/callback`

### 5.3 Configure Supabase Auth

1. **Go to Supabase Dashboard → "Authentication" → "Providers"**
2. **Enable Google provider**
3. **Add your Google OAuth credentials:**
   - Client ID: (from Google Cloud Console)
   - Client Secret: (from Google Cloud Console)
4. **Save configuration**

## 📱 Step 6: Platform-Specific Configuration

### Android Configuration

1. **Add to `android/app/build.gradle`:**
```gradle
android {
    // ... existing code ...
    
    defaultConfig {
        // ... existing code ...
        minSdkVersion 21  // Required for Google Sign-In
    }
}
```

2. **Add Google Services (if not already added):**
   - Download `google-services.json` from Firebase Console
   - Place in `android/app/` directory
   - Add to `android/app/build.gradle`:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

### iOS Configuration

1. **Add to `ios/Runner/Info.plist`:**
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>REVERSED_CLIENT_ID</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

## 🧪 Step 7: Test the Setup

1. **Run the app:**
   ```bash
   flutter run
   ```

2. **Test features:**
   - ✅ Splash screen with animations
   - ✅ Login screen appears
   - ✅ Email/password signup
   - ✅ Email/password login
   - ✅ Google Sign-In
   - ✅ Navigation to home screen
   - ✅ Logout functionality

## 🎨 Step 8: Add Your Logo

1. **Save your logo as `assets/images/logo.png`**
2. **Recommended specs:**
   - Format: PNG with transparent background
   - Size: 512x512px or 1024x1024px
   - Clean, modern design

## 🔧 Troubleshooting

### Common Issues:

1. **"Invalid API key" error:**
   - Check your Supabase URL and anon key
   - Ensure no extra spaces or characters

2. **Google Sign-In not working:**
   - Verify SHA-1 certificate fingerprint
   - Check package name matches exactly
   - Ensure Google+ API is enabled

3. **Database errors:**
   - Check if profiles table exists
   - Verify RLS policies are set up correctly

4. **Build errors:**
   - Run `flutter clean && flutter pub get`
   - Check minimum SDK versions

## 📚 Additional Resources

- [Supabase Flutter Documentation](https://supabase.com/docs/reference/dart/introduction)
- [Google Sign-In Flutter Plugin](https://pub.dev/packages/google_sign_in)
- [Flutter Authentication Best Practices](https://docs.flutter.dev/cookbook/networking/authenticated-requests)

## 🎯 Next Steps

After successful setup, you can:
- Add user profile management
- Implement marketplace features
- Add community/forum functionality
- Set up real-time notifications
- Add file upload for user avatars

## 🆘 Need Help?

If you encounter issues:
1. Check the Flutter logs: `flutter logs`
2. Verify all credentials are correct
3. Test on different devices/platforms
4. Check Supabase dashboard for auth logs

---

**🎉 Congratulations! Your EduBazaar app is now connected to Supabase with full authentication support!** 