import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_provider.dart';
import '../../core/constants.dart';
import 'auth_layout.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String token;

  const ResetPasswordScreen({super.key, required this.token});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Set new password',
      subtitle: 'Create a fresh password for your BuySellAdda account.',
      badgeIcon: Icons.verified_user_rounded,
      badgeText: 'OTP verified',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _passwordController,
              obscureText: _hidePassword,
              decoration: InputDecoration(
                labelText: 'New password',
                hintText: 'Enter new password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hidePassword = !_hidePassword),
                ),
              ),
              validator: (value) => (value?.length ?? 0) >= 6 ? null : 'Password must be at least 6 characters',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _hideConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                hintText: 'Confirm new password',
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                suffixIcon: IconButton(
                  tooltip: _hideConfirmPassword ? 'Show password' : 'Hide password',
                  icon: Icon(_hideConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hideConfirmPassword = !_hideConfirmPassword),
                ),
              ),
              validator: (value) => value == _passwordController.text ? null : 'Passwords do not match',
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Update password'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loading ? null : () => Navigator.pushReplacementNamed(context, '/login'),
              child: const Text('Back to sign in'),
            ),
            const SizedBox(height: 18),
            const PolicyText(prefix: 'Account recovery follows BuySellAdda '),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).resetPassword(
            token: widget.token,
            password: _passwordController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } catch (_) {
      if (!mounted) return;
      final message = ref.read(authProvider).error ?? 'Password reset failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
