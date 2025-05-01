import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/pet/providers/pet_provider.dart';
import 'features/device/providers/device_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'package:pet_feeder/features/home/screens/home_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/pet/screens/register_pet_screen.dart';
import 'features/pet/screens/pets_list_screen.dart';
import 'package:pet_feeder/core/services/supabase_service.dart';
import 'package:pet_feeder/core/screens/loading_screen.dart';
import 'core/services/feeding_scheduler_service.dart';
import 'features/settings/screens/edit_profile_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/device/screens/pair_device_screen.dart';
import 'features/device/screens/manage_devices_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppInitializer());
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _initialized = false;
  String _loadingMessage = 'Initializing app...';
  bool _hasError = false;
  String _errorMessage = '';
  String _errorDetails = '';
  int _retryCount = 0;
  
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    try {
      setState(() {
        _loadingMessage = 'Connecting to Supabase...';
        _hasError = false;
        _errorMessage = '';
        _errorDetails = '';
      });
      
      await SupabaseService.initialize();
      
      // Start the feeding scheduler after Supabase is initialized
      FeedingSchedulerService().startScheduler();
      
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      debugPrint('Primary initialization failed: $e');
      
      // Try with development credentials
      setState(() {
        _loadingMessage = 'Setting up development environment...';
      });
      
      try {
        // Wait a moment to avoid rapid retry
        await Future.delayed(const Duration(milliseconds: 500));
        await SupabaseService.createDummyConfig();
        
        setState(() {
          _initialized = true;
        });
      } catch (e) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Unable to connect to the database';
          _errorDetails = e.toString();
          _retryCount++;
        });
      }
    }
  }

  @override
  void dispose() {
    // Stop the feeding scheduler when the app is disposed
    FeedingSchedulerService().stopScheduler();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 24),
                  const Text(
                    'Error Initializing App',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Technical details:\n$_errorDetails',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'This error can occur when you haven\'t set up your Supabase credentials yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _initializeApp,
                    child: const Text('Retry Connection'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _initialized = true; // Force continue without backend
                      });
                    },
                    child: const Text('Continue in Offline Mode (Limited Functionality)'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    if (!_initialized) {
      return MaterialApp(
        home: LoadingScreen(message: _loadingMessage),
      );
    }
    
    return const MyApp();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PetProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
      ],
      child: MaterialApp(
        title: 'Pet Feeder',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFFA07A),
            primary: const Color(0xFFFFA07A),
            secondary: const Color(0xFF87CEEB),
          ),
          textTheme: GoogleFonts.poppinsTextTheme(),
          useMaterial3: true,
        ),
        home: const AppStartScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/home': (context) => const HomeScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/edit-profile': (context) => const EditProfileScreen(),
          '/register-pet': (context) => const RegisterPetScreen(),
          '/pets': (context) => const PetsListScreen(),
          '/admin-dashboard': (context) => const AdminDashboardScreen(),
          '/pair-device': (context) => const PairDeviceScreen(),
          '/devices': (context) => const ManageDevicesScreen(),
        },
      ),
    );
  }
}

class AppStartScreen extends StatefulWidget {
  const AppStartScreen({super.key});

  @override
  State<AppStartScreen> createState() => _AppStartScreenState();
}

class _AppStartScreenState extends State<AppStartScreen> {
  @override
  void initState() {
    super.initState();
    // Check login status after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).checkLoginStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isCheckingAdmin) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (auth.isAuthenticated) {
          return const HomeScreen();
        }
        
        return const LoginScreen();
      },
    );
  }
}
