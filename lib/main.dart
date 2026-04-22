import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'core/theme.dart';
import 'core/auth_provider.dart';

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
    final authState = ref.watch(authProvider);

    // Check auth status on start
    ref.read(authProvider.notifier).checkAuthStatus();

    return MaterialApp(
      title: 'DealKro',
      theme: appTheme(),
        home: authState.isAuthenticated 
          ? const HomeScreen() 
          : const LoginScreen(),
        routes: {
          '/register': (context) => const RegisterScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/chat': (context) => const ChatListScreen(),
          '/create-product': (context) => const CreateProductScreen(),
        },


      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DealKro Home')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome to DealKro!', style: TextStyle(fontSize: 24)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: null, // TODO: logout
              child: Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('DealKro', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 48),
              TextField(decoration: InputDecoration(labelText: 'Email')),
              const SizedBox(height: 16),
              TextField(decoration: InputDecoration(labelText: 'Password'), obscureText: true),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {}, // TODO: login
                child: const Text('Login'),
              ),
              TextButton(
                onPressed: () {}, // TODO: register
                child: const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

