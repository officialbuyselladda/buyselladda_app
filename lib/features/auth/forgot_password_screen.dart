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
  final _otpController = TextEditingController();
  bool _loading = false;
  bool _otpSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Reset password',
      subtitle: _otpSent
          ? 'Enter the OTP sent to your email to continue.'
          : 'Enter your registered email and we will send a reset OTP if your account exists.',
      badgeIcon: Icons.lock_reset_rounded,
      badgeText: 'Secure account recovery',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_otpSent)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppConstants.primaryLightColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppConstants.primaryBorderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mark_email_read_outlined, color: AppConstants.primaryDarkColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'OTP sent to ${_emailController.text.trim().toLowerCase()}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppConstants.primaryDarkColor),
                      ),
                    ),
                  ],
                ),
              ),
            if (!_otpSent)
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => (value?.trim().contains('@') ?? false) ? null : 'Enter valid email',
              )
            else
              TextFormField(
                controller: _otpController,
                decoration: const InputDecoration(
                  labelText: 'Reset OTP',
                  hintText: '6 digit code',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                validator: (value) => RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '') ? null : 'Enter 6 digit OTP',
              ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _loading ? null : (_otpSent ? _verifyOtp : _sendOtp),
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_otpSent ? 'Verify OTP' : 'Send reset OTP'),
            ),
            if (_otpSent) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loading ? null : _sendOtp,
                child: const Text('Resend OTP'),
              ),
            ],
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

  Future<void> _sendOtp() async {
    if (!_otpSent && !_formKey.currentState!.validate()) return;
    if (_emailController.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await ApiService.post(
        '${AppConstants.authPath}/forgot-password',
        data: {'email': _emailController.text.trim().toLowerCase()},
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _otpSent = true;
        _otpController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset OTP sent to your email')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to send reset OTP')),
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final response = await ApiService.post(
        '${AppConstants.authPath}/verify-reset-otp',
        data: {
          'email': _emailController.text.trim().toLowerCase(),
          'otp': _otpController.text.trim(),
        },
      );
      final payload = response.data['data'] ?? response.data;
      final token = payload['resetToken']?.toString() ?? '';
      if (token.isEmpty) throw Exception('Reset token missing');
      if (!mounted) return;
      Navigator.pushNamed(context, '/reset-password', arguments: {'token': token});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid or expired OTP')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
