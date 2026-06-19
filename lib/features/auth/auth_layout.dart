import 'package:flutter/material.dart';
import '../../core/constants.dart';

class AuthShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData badgeIcon;
  final String badgeText;
  final Widget child;

  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badgeIcon,
    required this.badgeText,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 820;

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConstants.backgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppConstants.borderColor),
                  boxShadow: const [
                    BoxShadow(color: Color(0x12002F34), blurRadius: 32, offset: Offset(0, 16)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: desktop
                    ? Row(
                        children: [
                          Expanded(child: _BrandPanel(badgeIcon: badgeIcon, badgeText: badgeText)),
                          SizedBox(width: 460, child: _FormPanel(title: title, subtitle: subtitle, child: child)),
                        ],
                      )
                    : _FormPanel(title: title, subtitle: subtitle, child: child, showLogo: true),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  final IconData badgeIcon;
  final String badgeText;

  const _BrandPanel({required this.badgeIcon, required this.badgeText});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 610),
      padding: const EdgeInsets.all(34),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8FFFC), Color(0xFFFFFFFF), Color(0xFFFFF7ED)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/images/logo.png', width: 178, fit: BoxFit.contain),
              const SizedBox(height: 10),
              const Text(AppConstants.appName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF002F34))),
              const SizedBox(height: 3),
              const Text(AppConstants.tagline, style: TextStyle(color: AppConstants.textSecondaryColor, fontWeight: FontWeight.w800)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFD8F1EF)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 18, color: const Color(0xFF008F88)),
                    const SizedBox(width: 8),
                    Text(badgeText, style: const TextStyle(color: Color(0xFF006B66), fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Manage ads, chats, favorites, and support from one secure marketplace account.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF002F34),
                      fontWeight: FontWeight.w900,
                      height: 1.18,
                    ),
              ),
              const SizedBox(height: 12),
              const Text(
                'BuySellAdda keeps buying and selling simple with verified profiles, safer conversations, and local listings near you.',
                style: TextStyle(color: AppConstants.textSecondaryColor, height: 1.55),
              ),
            ],
          ),
          const Row(
            children: [
              Expanded(child: _TrustChip(text: 'Post ads fast')),
              SizedBox(width: 10),
              Expanded(child: _TrustChip(text: 'Chat safely')),
              SizedBox(width: 10),
              Expanded(child: _TrustChip(text: 'Track listings')),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool showLogo;

  const _FormPanel({required this.title, required this.subtitle, required this.child, this.showLogo = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showLogo) ...[
            Center(child: Image.asset('assets/images/logo.png', width: 168, fit: BoxFit.contain)),
            const SizedBox(height: 10),
            const Center(child: Text(AppConstants.appName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
            const SizedBox(height: 4),
            const Center(child: Text(AppConstants.tagline, textAlign: TextAlign.center, style: TextStyle(color: AppConstants.textSecondaryColor, fontWeight: FontWeight.w800))),
            const SizedBox(height: 18),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF002F34),
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 7),
          Text(subtitle, style: const TextStyle(color: AppConstants.textSecondaryColor, height: 1.35)),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  final String text;

  const _TrustChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class PolicyText extends StatelessWidget {
  final String prefix;

  const PolicyText({super.key, required this.prefix});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prefix, style: const TextStyle(color: AppConstants.textSecondaryColor, fontSize: 12, height: 1.5)),
        TextButton(
          onPressed: () => showPolicySheet(context, PolicyKind.terms),
          child: const Text('Terms of Use'),
        ),
        const Text('and', style: TextStyle(color: AppConstants.textSecondaryColor, fontSize: 12)),
        TextButton(
          onPressed: () => showPolicySheet(context, PolicyKind.privacy),
          child: const Text('Privacy Policy'),
        ),
      ],
    );
  }
}

enum PolicyKind { terms, privacy }

void showPolicySheet(BuildContext context, PolicyKind kind) {
  final isTerms = kind == PolicyKind.terms;
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.92,
      minChildSize: 0.45,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        children: [
          Center(
            child: Container(width: 42, height: 4, decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(99))),
          ),
          const SizedBox(height: 18),
          Text(isTerms ? 'Terms of Use' : 'Privacy Policy', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          for (final section in (isTerms ? _termsSections : _privacySections)) _PolicySection(title: section.$1, body: section.$2),
        ],
      ),
    ),
  );
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String body;

  const _PolicySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: AppConstants.textSecondaryColor, height: 1.5)),
        ],
      ),
    );
  }
}

const _termsSections = [
  (
    'Marketplace use',
    'BuySellAdda lets users list, discover, and discuss local products. Users are responsible for accurate listings, fair communication, and lawful transactions.',
  ),
  (
    'Account safety',
    'Keep your password private and report suspicious activity. BuySellAdda may restrict accounts that misuse chats, listings, or buyer/seller trust.',
  ),
  (
    'Listings and payments',
    'Inspect products before payment and avoid advance transfers. BuySellAdda can moderate ads that are unsafe, misleading, duplicate, or prohibited.',
  ),
];

const _privacySections = [
  (
    'Information collected',
    'We use account details such as name, email, phone, location, listings, favorites, and chats to run the marketplace experience.',
  ),
  (
    'How data is used',
    'Your data helps with login, ad posting, buyer-seller chat, safety checks, notifications, support, and personalized local results.',
  ),
  (
    'Your choices',
    'You can update profile information, choose location access, manage language preferences, and logout anytime from account settings.',
  ),
];
