import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_provider.dart';
import '../../core/constants.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  bool _saving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(title: const Text('Change password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppConstants.primaryLightColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppConstants.primaryBorderColor),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_reset_rounded, color: AppConstants.primaryDarkColor),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Use a strong password with at least 6 characters.',
                      style: TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppConstants.borderColor),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _PasswordField(
                      controller: _currentController,
                      label: 'Current password',
                      hidden: _hideCurrent,
                      onToggle: () => setState(() => _hideCurrent = !_hideCurrent),
                      validator: (value) => (value?.isEmpty ?? true) ? 'Enter current password' : null,
                    ),
                    const SizedBox(height: 12),
                    _PasswordField(
                      controller: _newController,
                      label: 'New password',
                      hidden: _hideNew,
                      onToggle: () => setState(() => _hideNew = !_hideNew),
                      validator: (value) {
                        final text = value ?? '';
                        if (text.length < 6) return 'Password must be at least 6 characters';
                        if (text == _currentController.text) return 'New password must be different';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _PasswordField(
                      controller: _confirmController,
                      label: 'Confirm new password',
                      hidden: _hideConfirm,
                      onToggle: () => setState(() => _hideConfirm = !_hideConfirm),
                      validator: (value) => value != _newController.text ? 'Passwords do not match' : null,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.verified_user_outlined),
                        label: const Text('Update password'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(authProvider.notifier).changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully')));
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      final message = ref.read(authProvider).error ?? 'Password update failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool hidden;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hidden,
    required this.onToggle,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: hidden,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: hidden ? 'Show password' : 'Hide password',
          onPressed: onToggle,
          icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        ),
      ),
    );
  }
}
