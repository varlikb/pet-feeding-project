import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/pet/providers/pet_provider.dart';
import 'features/device/providers/device_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'package:pet_feeder/features/home/screens/home_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/pet/screens/register_pet_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
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
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          // Check login status when app starts
          WidgetsBinding.instance.addPostFrameCallback((_) {
            authProvider.checkLoginStatus();
          });
          
          return MaterialApp(
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
            initialRoute: authProvider.isAuthenticated ? '/' : '/login',
            routes: {
              '/': (context) => const HomeScreen(),
              '/login': (context) => const LoginScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/register_pet': (context) => const RegisterPetScreen(),
            },
          );
        }
      ),
    );
  }
}
