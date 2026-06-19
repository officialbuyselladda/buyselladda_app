import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_language.dart';
import '../../core/constants.dart';
import 'account_info_screen.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appLanguageProvider);
    return AccountInfoScreen(
      title: tr(language, 'privacy'),
      icon: Icons.privacy_tip_outlined,
      items: [
        AccountInfoItem(tr(language, 'privacy_1_title'), tr(language, 'privacy_1_body')),
        AccountInfoItem(tr(language, 'privacy_2_title'), tr(language, 'privacy_2_body')),
        AccountInfoItem(tr(language, 'privacy_3_title'), tr(language, 'privacy_3_body')),
        const AccountInfoItem('Data control', 'Logout clears the active session from this device. Expired sessions are removed automatically.'),
      ],
    );
  }
}

class PrivacyQuickCard extends StatelessWidget {
  const PrivacyQuickCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppConstants.borderColor)),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: AppConstants.primaryDarkColor),
          SizedBox(width: 10),
          Expanded(child: Text('Your account, chat and listing details stay protected.', style: TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
