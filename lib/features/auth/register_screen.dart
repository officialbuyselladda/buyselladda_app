import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_provider.dart';
import '../../core/constants.dart';
import 'auth_layout.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _hidePassword = true;
  bool _acceptedPolicies = true;
  String _userType = 'normal';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    if (authState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      });
    }

    return AuthShell(
      title: 'Create account',
      subtitle: 'Create one account for posting ads, chatting, saving listings, and support.',
      badgeIcon: Icons.verified_user_outlined,
      badgeText: 'Verified marketplace account',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full name', hintText: 'Your name', prefixIcon: Icon(Icons.person_outline_rounded)),
              textInputAction: TextInputAction.next,
              validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Enter your full name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email address', hintText: 'you@example.com', prefixIcon: Icon(Icons.email_outlined)),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (value) => (value?.trim().contains('@') ?? false) ? null : 'Enter valid email',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone number', hintText: 'Mobile number', prefixIcon: Icon(Icons.phone_outlined)),
              keyboardType: TextInputType.phone,
              maxLength: 10,
              textInputAction: TextInputAction.next,
              validator: (value) => RegExp(r'^[6-9]\d{9}$').hasMatch(value?.trim() ?? '') ? null : 'Enter a valid 10 digit mobile number',
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _userType,
              decoration: const InputDecoration(labelText: 'Account type', prefixIcon: Icon(Icons.storefront_outlined)),
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('Normal user')),
                DropdownMenuItem(value: 'dealer', child: Text('Dealer')),
              ],
              onChanged: (value) => setState(() => _userType = value ?? 'normal'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Create a password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
              obscureText: _hidePassword,
              validator: (value) => (value?.length ?? 0) < 6 ? 'Password must be at least 6 characters' : null,
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              value: _acceptedPolicies,
              onChanged: (value) => setState(() => _acceptedPolicies = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I agree to the Terms of Use and Privacy Policy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
            if (authState.error != null) _ErrorBanner(message: authState.error!),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: authState.isLoading ? null : _register,
              child: authState.isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create account'),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
              child: const Text('Already have account? Sign in'),
            ),
            const SizedBox(height: 18),
            const PolicyText(prefix: 'By creating an account, you agree to BuySellAdda '),
          ],
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (!_acceptedPolicies) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept Terms and Privacy Policy.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    try {
      final message = await ref.read(authProvider.notifier).register(
            _nameController.text.trim(),
            _emailController.text.trim(),
            _passwordController.text,
            _phoneController.text.trim(),
            userType: _userType,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.pushReplacementNamed(context, '/login');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration failed. Please try again.')),
      );
    }
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFECACA))),
      child: Text(message, style: const TextStyle(color: AppConstants.errorColor, fontWeight: FontWeight.w700)),
    );
  }
}
