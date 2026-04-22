import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'core/theme.dart';
import 'core/auth_provider.dart';
import 'features/home/home_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/chat/chat_list_screen.dart';
import 'features/product/create_product_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await _requestLocationPermission();
  runApp(
    const ProviderScope(
      child: DealKroApp(),
    ),
  );
}

Future<void> _requestLocationPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
}

class DealKroApp extends ConsumerWidget {
  const DealKroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'DealKro',
      theme: appTheme(),
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
      routes: {
        '/register': (context) => const RegisterScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/chat': (context) => const ChatListScreen(),
        '/create-product': (context) => const CreateProductScreen(),
      },
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Init auth check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).checkAuthStatus();
    });

    if (authState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return authState.isAuthenticated ? const HomeScreen() : const LoginScreen();
  }
}

