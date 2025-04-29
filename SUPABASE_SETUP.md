# Supabase Setup for Pet Feeder App

This document provides instructions for setting up Supabase as the backend database for the Pet Feeder application.

## Prerequisites

- A Supabase account (free tier is available at [supabase.com](https://supabase.com))
- Basic understanding of SQL and database concepts

## Setup Steps

### 1. Create a New Supabase Project

1. Log in to your Supabase account
2. Click "New Project"
3. Fill in the required details:
   - Name: Pet Feeder (or any name of your choice)
   - Database Password: Create a secure password
   - Region: Choose the region closest to your users
4. Click "Create new project"

### 2. Run the SQL Setup Script

1. In your Supabase project, navigate to "SQL Editor"
2. Create a "New query"
3. Paste the entire contents of the `supabase_setup.sql` file found in this project
4. Click "Run" to execute the SQL and create all necessary tables and security policies

### 3. Configure Authentication

1. Navigate to "Authentication" > "Settings" in your Supabase dashboard
2. Under "Email Auth", ensure that:
   - Email confirmations are enabled (optional, but recommended)
   - Password recovery is enabled

### 4. Obtain API Keys

1. Navigate to "Settings" > "API" in your Supabase dashboard
2. Copy the following values:
   - URL: Your project URL
   - Anon/Public key: The public API key

### 5. Configure App Environment

1. Create a `.env` file in the root of your Flutter project
2. Add the following lines, replacing with your actual values:
   ```
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

## Database Schema

The setup script creates the following tables:

- **profiles**: User profile information
- **devices**: Pet feeder devices registered by users
- **pets**: Pets owned by users
- **feeding_records**: Records of feeding events
- **feeding_schedules**: Scheduled feeding times for pets

Each table is protected with Row Level Security (RLS) to ensure users can only access their own data.

## Testing the Setup

After completing the setup:

1. Run your Flutter app
2. Register a new user
3. Verify that the user can:
   - Register new pets
   - Register new devices
   - Create feeding schedules
   - Record feeding events

## Troubleshooting

If you encounter issues with the database setup:

1. Check the SQL editor for any error messages
2. Verify that all tables were created correctly in the "Table Editor"
3. Test the Row Level Security policies by attempting to access data from another account

For authentication issues:

1. Check the Authentication logs in the Supabase dashboard
2. Verify your API keys in the `.env` file match those in the Supabase dashboard 