import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/app_language.dart';
import '../../core/auth_provider.dart';
import '../../core/constants.dart';
import 'account_info_screen.dart';

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendTicket() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      _showSnack('Please enter subject and message');
      return;
    }
    setState(() => _sending = true);
    try {
      await ApiService.post('/support', data: {
        'subject': subject,
        'message': message,
        'category': 'other',
        'priority': 'medium',
        'contactEmail': ref.read(authProvider).user?.email ?? '',
      });
      _subjectController.clear();
      _messageController.clear();
      _showSnack('Support ticket submitted');
    } catch (_) {
      _showSnack('Support ticket could not be submitted. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(appLanguageProvider);
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(title: Text(tr(language, 'help_support')), backgroundColor: AppConstants.backgroundColor),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AccountInfoScreen(
            title: tr(language, 'help_support'),
            icon: Icons.help_outline_rounded,
            items: [
              AccountInfoItem(tr(language, 'help_1_title'), tr(language, 'help_1_body')),
              AccountInfoItem(tr(language, 'help_2_title'), tr(language, 'help_2_body')),
              AccountInfoItem(tr(language, 'help_3_title'), tr(language, 'help_3_body')),
            ],
          ).bodyOnly(context),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppConstants.borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Contact support', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 12),
                TextField(controller: _subjectController, decoration: const InputDecoration(labelText: 'Subject', prefixIcon: Icon(Icons.title_rounded))),
                const SizedBox(height: 10),
                TextField(controller: _messageController, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Message', prefixIcon: Icon(Icons.message_outlined))),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _sendTicket,
                    icon: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
                    label: const Text('Submit ticket'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

extension _AccountInfoBody on AccountInfoScreen {
  Widget bodyOnly(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppConstants.borderColor)),
          child: Row(
            children: [
              Icon(icon, color: AppConstants.primaryDarkColor),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final item in items)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppConstants.borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.heading, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 7),
                Text(item.body, style: const TextStyle(color: AppConstants.textSecondaryColor, height: 1.45, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }
}
