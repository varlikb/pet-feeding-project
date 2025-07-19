<<<<<<< HEAD
# Pet Feeder App

A Flutter application for managing pet feeding schedules and devices.

## Security Setup

Before running the application, you need to set up your environment securely:

1. Create a `.env` file in the root directory:
   ```
   SUPABASE_URL=your_supabase_project_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

2. **IMPORTANT: Never commit your `.env` file to version control!**
   - The `.gitignore` file is configured to exclude sensitive files
   - Always use environment variables for secrets
   - Never hardcode API keys or credentials

## Environment Setup

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Get your Supabase credentials:
   - Go to your Supabase project dashboard
   - Navigate to Project Settings > API
   - Copy the URL and anon/public key
   - Paste them into your `.env` file

## Security Best Practices

1. **Environment Variables**
   - All sensitive data should be stored in `.env`
   - Never commit real credentials to Git
   - Use different credentials for development and production

2. **API Keys**
   - Use separate API keys for development and production
   - Regularly rotate production keys
   - Set appropriate permissions in Supabase

3. **Authentication**
   - Email verification is enabled by default
   - Password requirements are enforced
   - Rate limiting is implemented for login attempts

## Development Setup

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Verify environment setup:
   ```bash
   flutter run
   ```

## Production Deployment

Before deploying to production:

1. Review security settings in Supabase dashboard
2. Enable email verification
3. Set up proper authentication rules
4. Configure row-level security (RLS) policies
5. Use production API keys
6. Enable SSL/TLS
7. Set up proper CORS policies

## Contributing

1. Never commit sensitive data
2. Use environment variables for configuration
3. Follow security best practices
4. Review code for security issues
5. Keep dependencies updated

## License

This project is licensed under the MIT License - see the LICENSE file for details.
=======
# pet-feeding-project
>>>>>>> myrepo/main
