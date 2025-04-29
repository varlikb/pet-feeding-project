# Pet Feeder App

A Flutter application to control and schedule feedings for your pet feeder device.

## Setup

### Prerequisites

- Flutter SDK (3.7.2 or higher)
- Dart SDK (3.0.0 or higher)
- A Supabase account (optional but recommended)

### Installation

1. Clone this repository
2. Install dependencies:
```
flutter pub get
```

### Supabase Configuration

The app uses Supabase as its backend database. You can run the app without setting up Supabase (it will work in offline mode), but for the full experience, follow these steps:

1. Create a new project on [Supabase](https://supabase.com/)
2. Navigate to Settings > API in your Supabase dashboard
3. Copy your Supabase URL and anon/public key
4. Create a `.env` file in the root directory of your project with the following content:
```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```
5. Run the SQL script found in `supabase_setup.sql` in your Supabase SQL editor to set up the necessary tables and schema

For more detailed instructions, see the [Supabase Setup Guide](SUPABASE_SETUP.md).

## Features

- User authentication
- Pet registration and management
- Device connection and control
- Feeding schedule management
- Feeding history tracking

## Development Notes

### Offline Mode

The app will automatically switch to offline mode if it cannot connect to Supabase. In offline mode, you can still:

- Register and log in with dummy credentials (data is stored locally)
- Navigate the app and view the UI
- Test basic functionality

However, data will not be synchronized with the server in offline mode.

## Running the App

```
flutter run
```

## Building for Production

### Android

```
flutter build apk --release
```

### iOS

```
flutter build ios --release
```

## Troubleshooting

### Database Connection Issues

If you encounter database connection issues:

1. Verify your internet connection
2. Check that your `.env` file exists and contains the correct credentials
3. Ensure your Supabase project is active and running
4. Use the retry button on the error screen to attempt reconnection

## License

This project is licensed under the MIT License - see the LICENSE file for details.
