import 'package:flutter/material.dart';
import '../../core/constants.dart';

class AccountInfoScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<AccountInfoItem> items;

  const AccountInfoScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(title: Text(title), backgroundColor: AppConstants.backgroundColor),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppConstants.borderColor)),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: AppConstants.primaryLightColor, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: AppConstants.primaryDarkColor),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final item in items)
            Container(
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
      ),
    );
  }
}

class AccountInfoItem {
  final String heading;
  final String body;

  const AccountInfoItem(this.heading, this.body);
}
