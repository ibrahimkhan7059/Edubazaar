# 🛒 EduBazaar Marketplace - Supabase Database Setup

This guide will help you set up the Supabase database tables for the EduBazaar marketplace functionality.

## 📋 Prerequisites

1. ✅ Supabase project created and configured (follow `SUPABASE_SETUP.md`)
2. ✅ Flutter app connected to Supabase
3. ✅ User authentication working

## 🗄️ Database Setup

### Step 1: Run the SQL Script

1. **Open your Supabase Dashboard**
2. **Go to SQL Editor**
3. **Copy and paste the contents of `SUPABASE_LISTINGS_TABLE.sql`**
4. **Click "Run"**

This will create:
- ✅ `listings` table with all necessary columns
- ✅ `favorites` table for user favorites
- ✅ Row Level Security (RLS) policies
- ✅ Database functions and triggers
- ✅ Sample data

### Step 2: Set Up Storage (Optional)

If you want image upload functionality:

1. **Go to Storage in Supabase Dashboard**
2. **Create a new bucket called `listing-images`**
3. **Make it public**
4. **Set up RLS policies for the bucket**

```sql
-- Allow authenticated users to upload images
CREATE POLICY "Allow authenticated uploads" ON storage.objects
  FOR INSERT WITH CHECK (auth.uid()::text = (storage.foldername(name))[1]);

-- Allow public read access
CREATE POLICY "Allow public read" ON storage.objects
  FOR SELECT USING (bucket_id = 'listing-images');
```

## 🧪 Testing the Setup

### Test 1: Check Tables Created

Run this query in SQL Editor:
```sql
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('listings', 'favorites');
```

Should return both table names.

### Test 2: Check Sample Data

```sql
SELECT title, type, category, price FROM listings;
```

Should return sample listings.

### Test 3: Test App Connection

1. **Run your Flutter app**: `flutter run`
2. **Navigate to Marketplace tab**
3. **You should see sample listings**
4. **Try creating a new listing**

## 🔧 Troubleshooting

### Issue: "Table doesn't exist"
- ✅ Make sure you ran the SQL script
- ✅ Check table name spelling in queries
- ✅ Verify RLS policies are set up

### Issue: "Permission denied"
- ✅ Check RLS policies
- ✅ Make sure user is authenticated
- ✅ Verify user ID in auth.users table

### Issue: "No listings showing"
- ✅ Check if sample data was inserted
- ✅ Verify status = 'active' on listings
- ✅ Check network connection

### Issue: "Can't create listings"
- ✅ User must be logged in
- ✅ Check RLS policies
- ✅ Verify all required fields are provided

## 📱 App Features Now Available

After setup, your app will have:

✅ **View Listings**: Browse all active marketplace listings
✅ **Search & Filter**: Search by title/description and filter by type/category
✅ **Create Listings**: Authenticated users can create new listings
✅ **Favorites**: Users can favorite/unfavorite listings
✅ **User Listings**: View your own listings
✅ **Real-time Updates**: Listings update in real-time
✅ **View Counts**: Track how many times a listing was viewed

## 🚀 Next Steps

1. **Customize the UI** to match your design
2. **Add image upload** functionality
3. **Implement messaging** between users
4. **Add payment integration**
5. **Set up push notifications**

## 📊 Database Schema

### Listings Table Structure:
```
id (UUID, PK)
user_id (UUID, FK to auth.users)
title (TEXT)
description (TEXT)
price (DECIMAL, nullable for donations)
type (TEXT: book, notes, equipment, etc.)
category (TEXT: mathematics, physics, etc.)
condition (TEXT: excellent, good, etc.)
images (TEXT[])
tags (TEXT[])
... and more fields
```

### Key Features:
- 🔒 **Row Level Security**: Users can only modify their own listings
- 📈 **Auto-incrementing views**: View count increases automatically
- ❤️ **Favorites system**: With automatic count updates
- 🕒 **Timestamps**: Created/updated timestamps managed automatically

## 🆘 Need Help?

If you run into issues:
1. Check the Supabase logs in Dashboard > Logs
2. Enable realtime debugging in your Flutter app
3. Verify your RLS policies are correct
4. Make sure authentication is working properly 