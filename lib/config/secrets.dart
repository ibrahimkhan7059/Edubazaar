// This file should be added to .gitignore
// Create a secrets.template.dart file for reference

class Secrets {
  // Supabase
  static const String productionSupabaseUrl =
      'https://jpsgjzprweboqnbjlfhh.supabase.co';
  static const String productionSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impwc2dqenByd2Vib3FuYmpsZmhoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE3NzgyNzAsImV4cCI6MjA2NzM1NDI3MH0.PDHfHkHOd9ftd0sNs0xghLPGy_WNYkIJA9i7XyNcmFw';

  // Firebase
  static const String firebaseApiKey =
      'AIzaSyBn75OeDFhyk1l3l-22ONQVf7wAGYwvATM';
  static const String firebaseAppId =
      '1:159821446914:android:f9142056a801867eaccc1b';
  static const String firebaseMessagingSenderId = '159821446914';
  static const String firebaseProjectId = 'edubazaar-467505';

  // Google Sign In
  static const String googleClientId =
      '159821446914-0rl4dgg8rl1g36vg4gnss90mc3ghhksa.apps.googleusercontent.com';
  static const String googleClientSecret = 'YOUR_GOOGLE_CLIENT_SECRET';

  // Storage
  static const String storageAccessKey = 'YOUR_STORAGE_ACCESS_KEY';
  static const String storageSecretKey = 'YOUR_STORAGE_SECRET_KEY';

  // Push Notifications
  static const String fcmServerKey = 'YOUR_FCM_SERVER_KEY';

  // API Keys
  static const String mapApiKey = 'YOUR_MAP_API_KEY';
  static const String analyticsApiKey = 'YOUR_ANALYTICS_API_KEY';

  // Other Services
  static const String resendApiKey = 'YOUR_RESEND_API_KEY';
}
