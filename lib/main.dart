import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/app_language.dart';
import 'core/app_config_provider.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'core/theme_mode.dart';
import 'core/auth_provider.dart';
import 'features/home/home_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/reset_password_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/chat/chat_list_screen.dart';
import 'features/product/create_product_screen.dart';
import 'features/product/product_detail_screen.dart';
import 'features/product/my_ads_screen.dart';
import 'features/favorites/favorites_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/profile/change_password_screen.dart';
import 'features/profile/privacy_screen.dart';
import 'features/profile/help_support_screen.dart';
import 'features/profile/language_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}
  runApp(
    const ProviderScope(
      child: BuySellAddaApp(),
    ),
  );
}

class BuySellAddaApp extends ConsumerWidget {
  const BuySellAddaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appLanguageProvider);
    final appConfig = ref.watch(appConfigProvider).valueOrNull ?? DealAppConfig.fallback();
    final themeMode = ref.watch(appThemeModeProvider);
    return MaterialApp(
      title: appConfig.appName.isNotEmpty ? appConfig.appName : tr(language, 'app_title'),
      theme: appTheme(),
      darkTheme: appDarkTheme(),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/reset-password': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final token = args is Map ? '${args['token'] ?? ''}' : '';
          return ResetPasswordScreen(token: token);
        },
        '/profile': (context) => const ProfileScreen(),
        '/chat': (context) => const ChatListScreen(),
        '/favorites': (context) => const FavoritesScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/my-ads': (context) => const MyAdsScreen(),
        '/edit-profile': (context) => const EditProfileScreen(),
        '/change-password': (context) => const ChangePasswordScreen(),
        '/privacy': (context) => const PrivacyScreen(),
        '/help-support': (context) => const HelpSupportScreen(),
        '/language': (context) => const LanguageScreen(),
        '/create-product': (context) => CreateProductScreen(
              product: ModalRoute.of(context)?.settings.arguments as dynamic,
            ),
      },
      onGenerateRoute: (settings) {
        if (settings.name == ProductDetailScreen.routeName) {
          final productId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => ProductDetailScreen(productId: productId),
          );
        }
        return null;
      },
    );
  }
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _barAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _barAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _boot();
  }

  Future<void> _boot() async {
    final results = await Future.wait([
      ref.read(appConfigProvider.future),
      ref.read(authProvider.notifier).checkAuthStatus(),
      Future.delayed(const Duration(milliseconds: 1200)),
    ]);
    if (!mounted) return;
    final appConfig = results.first as DealAppConfig;
    if (appConfig.maintenanceMode || appConfig.forceUpdate) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appConfig = ref.watch(appConfigProvider).valueOrNull ?? DealAppConfig.fallback();
    if (appConfig.maintenanceMode || appConfig.forceUpdate) {
      return _SplashGateMessage(config: appConfig);
    }

    return Scaffold(
      backgroundColor: appConfig.splashBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 680;
            return Stack(
              children: [
                Positioned(
                  top: -72,
                  right: -46,
                  child: _SplashAccentCircle(
                    size: compact ? 154 : 188,
                    color: const Color(0x1400A49F),
                  ),
                ),
                Positioned(
                  left: -58,
                  bottom: 78,
                  child: _SplashAccentCircle(
                    size: compact ? 124 : 158,
                    color: const Color(0x14F97316),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(22, compact ? 14 : 24, 22, compact ? 16 : 24),
                  child: Column(
                    children: [
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _SplashHeader(config: appConfig),
                      ),
                      const Spacer(),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: _SplashBrandMark(config: appConfig, compact: compact),
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 26 : 42),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _SplashLoading(
                          animation: _barAnimation,
                          color: appConfig.accentColor,
                          text: appConfig.splashLoadingText,
                        ),
                      ),
                      const Spacer(),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: _SplashCategoryPreview(config: appConfig),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SplashHeader extends StatelessWidget {
  final DealAppConfig config;

  const _SplashHeader({required this.config});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppConstants.borderColor),
          ),
          child: _AppLogo(url: config.splashLogoUrl),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            config.previewLocationText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FFFE),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFB7ECE8)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF008F88)),
              SizedBox(width: 5),
              Text(
                'Verified',
                style: TextStyle(
                  color: Color(0xFF006B66),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SplashBrandMark extends StatelessWidget {
  final DealAppConfig config;
  final bool compact;

  const _SplashBrandMark({required this.config, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 128 : 150,
          height: compact ? 128 : 150,
          padding: EdgeInsets.all(compact ? 18 : 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: const Color(0xFFE2F7F5), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x16008F88),
                blurRadius: 34,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: _AppLogo(url: config.splashLogoUrl),
        ),
        SizedBox(height: compact ? 18 : 24),
        Text(
          config.splashTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: const Color(0xFF002F34),
                fontSize: compact ? 28 : 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 290),
          child: Text(
            config.splashSubtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5F7477),
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
          ),
        ),
        SizedBox(height: compact ? 16 : 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: config.splashChips.take(3).map((chip) => _SplashChip(label: chip)).toList(),
        ),
      ],
    );
  }
}

class _SplashLoading extends StatelessWidget {
  final Animation<double> animation;
  final Color color;
  final String text;

  const _SplashLoading({
    required this.animation,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 230),
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4F3),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.antiAlias,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) => FractionallySizedBox(
              widthFactor: 0.18 + (animation.value * 0.82),
              child: child,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        const SizedBox(height: 13),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF5F7477),
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _SplashAccentCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _SplashAccentCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _SplashCategoryPreview extends StatelessWidget {
  final DealAppConfig config;

  const _SplashCategoryPreview({required this.config});

  @override
  Widget build(BuildContext context) {
    final icons = [
      Icons.phone_iphone_rounded,
      Icons.directions_car_rounded,
      Icons.apartment_rounded,
      Icons.chair_outlined,
    ];

    final categoryCount = config.featuredCategories.take(4).length;
    if (categoryCount == 0) return const SizedBox.shrink();

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppConstants.borderColor),
        boxShadow: const [
          BoxShadow(color: Color(0x0A002F34), blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(categoryCount, (index) {
          return Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
            child: _SplashMiniCategory(icon: icons[index % icons.length]),
          );
        }),
      ),
    );
  }
}

class _SplashMiniCategory extends StatelessWidget {
  final IconData icon;

  const _SplashMiniCategory({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF7FFFE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8F1EF)),
      ),
      child: Icon(icon, size: 20, color: const Color(0xFF002F34)),
    );
  }
}

class _SplashChip extends StatelessWidget {
  final String label;

  const _SplashChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FFFE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD8F1EF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF008F88)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF002F34),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  final String url;

  const _AppLogo({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.trim().isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Image.asset('assets/images/logo.png', fit: BoxFit.contain),
      );
    }
    return Image.asset('assets/images/logo.png', fit: BoxFit.contain);
  }
}

class _SplashGateMessage extends StatelessWidget {
  final DealAppConfig config;

  const _SplashGateMessage({required this.config});

  @override
  Widget build(BuildContext context) {
    final isUpdate = config.forceUpdate;
    return Scaffold(
      backgroundColor: config.splashBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 104,
                  height: 104,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(color: Color(0x14111827), blurRadius: 24, offset: Offset(0, 12)),
                    ],
                  ),
                  child: _AppLogo(url: config.splashLogoUrl),
                ),
                const SizedBox(height: 24),
                Text(
                  isUpdate ? 'Update Required' : 'Maintenance Mode',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF111827),
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  isUpdate ? config.updateMessage : config.maintenanceMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

