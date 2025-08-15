# Image Upload Permission Test Guide

## 🔧 What I Fixed:

### 1. Android Manifest Permissions
Added these permissions to `android/app/src/main/AndroidManifest.xml`:
- `READ_EXTERNAL_STORAGE`
- `WRITE_EXTERNAL_STORAGE` 
- `READ_MEDIA_IMAGES` (Android 13+)
- `READ_MEDIA_VIDEO` (Android 13+)
- `CAMERA`
- `MANAGE_EXTERNAL_STORAGE`

### 2. Permission Service
Enhanced debugging and Android 13+ support

## 📱 Test Steps:

### Step 1: Clean Build
```bash
flutter clean
flutter pub get
```

### Step 2: Run App
```bash
flutter run
```

### Step 3: Test Image Upload
1. Open chat screen
2. Tap image button (📷)
3. Choose "Gallery"
4. Check console logs for permission status

## 🔍 Expected Console Logs:

**Success:**
```
📱 Gallery option tapped
📱 Platform: android
📷 Photos permission status: PermissionStatus.granted
🔐 Gallery permission: true
📸 Selected image: /path/to/image.jpg
```

**Permission Denied:**
```
📷 Photos permission status: PermissionStatus.denied
🔐 Gallery permission: false
❌ Permission denied
```

## 🛠️ If Still Not Working:

### Option 1: Manual Permission Grant
1. Go to **Settings > Apps > EduBazaar**
2. Tap **Permissions**
3. Enable **Storage** and **Camera**

### Option 2: Check Android Version
- **Android 13+**: Uses `READ_MEDIA_IMAGES`
- **Android 12 and below**: Uses `READ_EXTERNAL_STORAGE`

### Option 3: Debug Permission Status
Add this to your code to check current permissions:
```dart
final status = await PermissionService.getPermissionStatus();
print('Permission Status: $status');
```

## 🚨 Common Issues:

1. **"No permissions found in manifest"** → Run `flutter clean` and rebuild
2. **"Permission permanently denied"** → Go to Settings and enable manually
3. **"Storage not configured"** → Run `FIX_IMAGE_UPLOAD.sql` in Supabase

## ✅ Success Indicators:
- Image picker dialog opens
- Gallery/camera options available
- Image selection works
- Upload progress shows
- Image appears in chat 