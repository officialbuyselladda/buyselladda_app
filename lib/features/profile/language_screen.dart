import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_language.dart';
import '../../core/constants.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  static const languages = ['English', 'Hindi', 'Marathi', 'Gujarati', 'Tamil', 'Telugu', 'Bengali'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appLanguageProvider);
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(title: Text(tr(current, 'select_language')), backgroundColor: AppConstants.backgroundColor),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (final language in languages)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: language == current ? AppConstants.primaryColor : AppConstants.borderColor)),
              child: RadioListTile<String>(
                value: language,
                groupValue: current,
                title: Text(language, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(_subtitle(language), maxLines: 1, overflow: TextOverflow.ellipsis),
                onChanged: (value) async {
                  if (value == null) return;
                  await ref.read(appLanguageProvider.notifier).setLanguage(value);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$value selected')));
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  String _subtitle(String language) {
    return switch (language) {
      'Hindi' => 'Hindi mode',
      'Marathi' => 'Marathi mode',
      'Gujarati' => 'Gujarati mode',
      'Tamil' => 'Tamil mode',
      'Telugu' => 'Telugu mode',
      'Bengali' => 'Bengali mode',
      _ => 'English mode',
    };
  }
}
