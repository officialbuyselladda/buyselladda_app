import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../../core/constants.dart';
import 'auth_layout.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Reset password',
      subtitle: 'Enter your registered email and we will send reset instructions if your account exists.',
      badgeIcon: Icons.lock_reset_rounded,
      badgeText: 'Secure account recovery',
      child: _submitted
          ? _SuccessState(email: _emailController.text.trim())
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => (value?.trim().contains('@') ?? false) ? null : 'Enter valid email',
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Send reset link'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
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
      await ApiService.post('${AppConstants.authPath}/forgot-password', data: {'email': _emailController.text.trim()});
    } catch (_) {
      // Some backends intentionally hide whether the email exists. The UI keeps the same safe response.
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _submitted = true;
        });
      }
    }
  }
}

class _SuccessState extends StatelessWidget {
  final String email;

  const _SuccessState({required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppConstants.primaryLightColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppConstants.primaryBorderColor),
          ),
          child: Column(
            children: [
              const Icon(Icons.mark_email_read_outlined, size: 44, color: AppConstants.primaryDarkColor),
              const SizedBox(height: 10),
              Text('Check your email', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                'If an account exists for $email, password reset instructions will arrive shortly.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppConstants.textSecondaryColor, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }
}
