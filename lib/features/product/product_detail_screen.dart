import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../core/constants.dart';
import '../../core/product_provider.dart';
import '../../models/product_model.dart';
import '../chat/chat_room_screen.dart';
import '../shared/product_card.dart';

// ─── Theme tokens ────────────────────────────────────────────────────────────
class _T {
  // Brand
  static const orange     = Color(0xFFFF8200);
  static const orangeDark = Color(0xFFE86F00);
  static const orangeLight= Color(0xFFFFF3E4);
  static const orangeMid  = Color(0xFFFFCC99);

  // Blues (accent)
  static const blue       = Color(0xFF0B63E5);
  static const blueLight  = Color(0xFFEAF2FF);

  // Neutrals
  static const bg         = Color(0xFFF5F7FA);
  static const surface    = Color(0xFFFFFFFF);
  static const border     = Color(0xFFDDE5F0);
  static const text       = Color(0xFF17233C);
  static const textMuted  = Color(0xFF5D6B82);
  static const textSubtle = Color(0xFF95A1B2);

  // Status
  static const green      = Color(0xFF12A642);
  static const greenLight = Color(0xFFEAF8EF);
  static const red        = Color(0xFFEF4444);
  static const redLight   = Color(0xFFFEF2F2);

  // Shadows
  static const shadowSm = [BoxShadow(color: Color(0x0A000000), blurRadius: 4,  offset: Offset(0, 1))];
  static const shadowMd = [BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4))];
  static const shadowLg = [BoxShadow(color: Color(0x18000000), blurRadius: 28, offset: Offset(0, 8))];
  static const shadowOrange = [BoxShadow(color: Color(0x22FF8200), blurRadius: 20, offset: Offset(0, 6))];

  // Radius
  static final r8  = BorderRadius.circular(8);
  static final r12 = BorderRadius.circular(12);
  static final r16 = BorderRadius.circular(16);
  static final r20 = BorderRadius.circular(20);
  static final r24 = BorderRadius.circular(24);

  // Typography
  static const fontDisplay = 'ClashDisplay';   // fallback to system if not loaded
  static const fontBody    = 'Figtree';

  static TextStyle display(double size, {Color color = text, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: fontDisplay, fontSize: size, fontWeight: weight, color: color, letterSpacing: 0);

  static TextStyle body(double size, {Color color = text, FontWeight weight = FontWeight.w400, double height = 1.0}) =>
      TextStyle(fontFamily: fontBody, fontSize: size, fontWeight: weight, color: color, height: height);
}

// ─── Utility ─────────────────────────────────────────────────────────────────
Map<String, dynamic>? _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

List<Map<String, dynamic>> _productList(dynamic payload) {
  final raw = payload is List
      ? payload
      : payload is Map
          ? (payload['products'] ?? payload['data'] ?? payload['items'] ?? <dynamic>[])
          : <dynamic>[];
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .where((item) => '${item['_id'] ?? item['id'] ?? ''}'.isNotEmpty)
      .toList();
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class ProductDetailScreen extends ConsumerStatefulWidget {
  static const routeName = '/product-detail';
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int  _imageIndex  = 0;
  bool _contacting  = false;
  bool _favoriting  = false;
  bool _isFavorited = false;
  bool _showPhone   = false;

  Future<List<Product>>? _relatedFuture;
  String? _relatedCategory;
  String? _recentSavedId;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productProvider.notifier).fetchProductDetail(widget.productId);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state   = ref.watch(productProvider);
    final product = state.selectedProduct;

    if (product != null &&
        product.id == widget.productId &&
        _relatedCategory != product.category) {
      _relatedCategory = product.category;
      _relatedFuture   = _fetchRelated(product);
      _fadeCtrl.forward(from: 0);
      _saveRecentlyViewed(product.id);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _T.bg,
        extendBodyBehindAppBar: true,
        body: state.isLoading && product == null
            ? const _DetailSkeleton()
            : product == null
                ? _ErrorState(
                    message: state.error ?? 'Product not found',
                    onBack: () => Navigator.pop(context),
                  )
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: CustomScrollView(
                      slivers: [
                        _GalleryAppBar(
                          product:    product,
                          controller: _pageController,
                          imageIndex: _imageIndex,
                          isFavorited: _isFavorited,
                          favoriting:  _favoriting,
                          onChanged:  (i) => setState(() => _imageIndex = i),
                          onFavorite: _favoriting ? null : () => _toggleFavorite(product),
                          onShare:    () => _shareProduct(product),
                        ),
                        SliverToBoxAdapter(
                          child: _DetailBody(
                            product:       product,
                            imageIndex:    _imageIndex,
                            onImageSelect: _selectImage,
                            showPhone:     _showPhone,
                            contacting:    _contacting,
                            onChat:        () => _contactSeller(product),
                            onShowPhone:   () { if (!_ensureLogin()) return; setState(() => _showPhone = true); },
                            relatedFuture: _relatedFuture,
                          ),
                        ),
                      ],
                    ),
                  ),
        bottomNavigationBar: product == null
            ? null
            : _ContactBar(
                product:    product,
                contacting: _contacting,
                isFavorited: _isFavorited,
                onFavorite: () => _toggleFavorite(product),
                onChat:     () => _contactSeller(product),
              ),
      ),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────────────
  Future<List<Product>> _fetchRelated(Product p) async {
    if (p.category.trim().isEmpty) return [];
    final res     = await ApiService.get(AppConstants.productPath, query: {'category': p.category, 'limit': 8, 'page': 1});
    final payload = res.data['data'] ?? res.data;
    return _productList(payload)
        .map(Product.fromJson)
        .where((x) => x.id.isNotEmpty && x.id != p.id)
        .take(6)
        .toList();
  }

  Future<void> _saveRecentlyViewed(String id) async {
    if (id.isEmpty || _recentSavedId == id) return;
    _recentSavedId = id;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList('deal_recently_viewed_products') ?? [];
    final next = [id, ...current.where((item) => item != id)].take(8).toList();
    await prefs.setStringList('deal_recently_viewed_products', next);
  }

  void _selectImage(int i) {
    setState(() => _imageIndex = i);
    _pageController.animateToPage(i, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  Future<void> _toggleFavorite(Product p) async {
    if (!_ensureLogin()) return;
    setState(() => _favoriting = true);
    try {
      await ApiService.post('/favorites/toggle', data: {'productId': p.id});
      setState(() => _isFavorited = !_isFavorited);
      _showSnack(_isFavorited ? '❤️ Added to favorites' : 'Removed from favorites');
    } catch (_) {
      _showSnack('Could not update favorite');
    } finally {
      if (mounted) setState(() => _favoriting = false);
    }
  }

  Future<void> _contactSeller(Product p) async {
    if (!_ensureLogin()) return;
    setState(() => _contacting = true);
    try {
      final res     = await ApiService.post('${AppConstants.productPath}/${p.id}/contact');
      final payload = res.data['data'] ?? res.data;
      final chat    = _asMap(payload?['chat']);
      final chatId  = '${chat?['_id'] ?? chat?['id'] ?? ''}';
      if (chatId.isEmpty) throw Exception('Chat id missing');

      if (_shouldSendDefault(chat)) {
        try { await ApiService.post('${AppConstants.chatPath}/$chatId/send', data: {'text': 'Hi, is this available?'}); } catch (_) {}
      }
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatRoomScreen(chatId: chatId, initialChat: chat)));
    } catch (_) {
      _showSnack('Could not start seller chat. Please try again.');
    } finally {
      if (mounted) setState(() => _contacting = false);
    }
  }

  bool _shouldSendDefault(Map<String, dynamic>? chat) {
    if (chat == null) return false;
    final lm = chat['lastMessage'];
    if (lm == null) return true;
    if (lm is String) return lm.trim().isEmpty;
    if (lm is Map) return lm.isEmpty;
    return false;
  }

  Future<void> _shareProduct(Product p) async {
    final link = _productWebLink(p.id);
    final price = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 0).format(p.price);
    final text = [
      'BuySellAdda',
      p.title,
      price,
      if (p.location.trim().isNotEmpty) p.location.trim(),
      link,
    ].join('\n');
    try {
      await const MethodChannel('buyselladda/share').invokeMethod('shareText', {
        'title': 'Share ${p.title}',
        'text': text,
      });
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      _showSnack('Product link copied. Share it with anyone.');
    }
  }

  bool _ensureLogin() {
    if (ref.read(authProvider).isAuthenticated) return true;
    Navigator.pushNamed(context, '/login');
    return false;
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: _T.body(13, color: Colors.white, weight: FontWeight.w600)),
        backgroundColor: _T.text,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: _T.r12),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ─── Gallery AppBar ───────────────────────────────────────────────────────────
class _GalleryAppBar extends StatelessWidget {
  final Product        product;
  final PageController controller;
  final int            imageIndex;
  final bool           isFavorited;
  final bool           favoriting;
  final ValueChanged<int> onChanged;
  final VoidCallback?  onFavorite;
  final VoidCallback   onShare;

  const _GalleryAppBar({
    required this.product,
    required this.controller,
    required this.imageIndex,
    required this.isFavorited,
    required this.favoriting,
    required this.onChanged,
    required this.onFavorite,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final h = w >= 1000 ? 560.0 : w >= 700 ? 480.0 : w < 380 ? 320.0 : 380.0;

    return SliverAppBar(
      expandedHeight: h,
      pinned: true,
      elevation: 0,
      backgroundColor: _T.text,
      foregroundColor: Colors.white,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: _CircleAction(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.pop(context),
        ),
      ),
      actions: [
        _CircleAction(
          icon: isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFavorited ? const Color(0xFFFF4D6D) : Colors.white,
          onTap: onFavorite,
          loading: favoriting,
        ),
        const SizedBox(width: 4),
        _CircleAction(icon: Icons.ios_share_rounded, onTap: onShare),
        const SizedBox(width: 10),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _ImagePager(
          product:    product,
          controller: controller,
          imageIndex: imageIndex,
          onChanged:  onChanged,
        ),
      ),
    );
  }
}

// ── Circle action button ─────────────────────────────────────────────────────
class _CircleAction extends StatelessWidget {
  final IconData    icon;
  final Color       color;
  final VoidCallback? onTap;
  final bool        loading;

  const _CircleAction({
    required this.icon,
    this.color   = Colors.white,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.52),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: loading
            ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
            : Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ── Image pager ──────────────────────────────────────────────────────────────
class _ImagePager extends StatelessWidget {
  final Product        product;
  final PageController controller;
  final int            imageIndex;
  final ValueChanged<int> onChanged;

  const _ImagePager({required this.product, required this.controller, required this.imageIndex, required this.onChanged});

  void _jump(int requested) {
    final count = product.images.length;
    if (count == 0) return;
    final next = (requested + count) % count;
    onChanged(next);
    controller.animateToPage(next, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final images = product.images;
    if (images.isEmpty) {
      return Container(
        color: _T.text,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_not_supported_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
              const SizedBox(height: 10),
              Text('No images', style: _T.body(13, color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Dark bg
        Container(color: const Color(0xFF0F172A)),

        // PageView
        PageView.builder(
          controller: controller,
          itemCount:  images.length,
          onPageChanged: onChanged,
          itemBuilder: (_, i) => InteractiveViewer(
            minScale: 1.0, maxScale: 3.5,
            child: SizedBox.expand(
              child: CachedNetworkImage(
                imageUrl: images[i],
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white30, strokeWidth: 1.5)),
                errorWidget: (_, __, ___) => Icon(Icons.image_not_supported_outlined, color: Colors.white.withOpacity(0.25), size: 48),
              ),
            ),
          ),
        ),

        // Gradient overlay bottom
        Positioned(
          left: 0, right: 0, bottom: 0,
          height: 80,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
              ),
            ),
          ),
        ),

        // Arrows
        if (images.length > 1) ...[
          _ArrowBtn(icon: Icons.chevron_left_rounded,  alignment: Alignment.centerLeft,  onTap: () => _jump(imageIndex - 1)),
          _ArrowBtn(icon: Icons.chevron_right_rounded, alignment: Alignment.centerRight, onTap: () => _jump(imageIndex + 1)),
        ],

        // Counter pill
        Positioned(
          right: 14, bottom: 16,
          child: _GlassPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_library_outlined, size: 13, color: _T.text),
                const SizedBox(width: 4),
                Text('${imageIndex + 1} / ${images.length}', style: _T.body(12, weight: FontWeight.w800)),
              ],
            ),
          ),
        ),

        // Dot indicators
        if (images.length > 1 && images.length <= 10)
          Positioned(
            bottom: 18, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width:  imageIndex == i ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: imageIndex == i ? _T.orange : Colors.white.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
            ),
          ),
      ],
    );
  }
}

class _ArrowBtn extends StatelessWidget {
  final IconData  icon;
  final Alignment alignment;
  final VoidCallback onTap;
  const _ArrowBtn({required this.icon, required this.alignment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              shape: BoxShape.circle,
              boxShadow: _T.shadowSm,
            ),
            child: Icon(icon, color: _T.text, size: 22),
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final Widget child;
  const _GlassPill({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.92),
      borderRadius: BorderRadius.circular(999),
      boxShadow: _T.shadowSm,
    ),
    child: child,
  );
}

// ─── Detail Body ──────────────────────────────────────────────────────────────
class _DetailBody extends StatelessWidget {
  final Product product;
  final int     imageIndex;
  final ValueChanged<int> onImageSelect;
  final bool    showPhone;
  final bool    contacting;
  final VoidCallback onChat;
  final VoidCallback onShowPhone;
  final Future<List<Product>>? relatedFuture;

  const _DetailBody({
    required this.product,
    required this.imageIndex,
    required this.onImageSelect,
    required this.showPhone,
    required this.contacting,
    required this.onChat,
    required this.onShowPhone,
    required this.relatedFuture,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ThumbnailStrip(product: product, imageIndex: imageIndex, onSelected: onImageSelect),
        const SizedBox(height: 14),
        _HeroCard(product: product),
        const SizedBox(height: 12),
        _DetailGridCard(product: product),
        const SizedBox(height: 12),
        _MapCard(product: product),
        const SizedBox(height: 12),
        _DescriptionCard(product: product),
      ],
    );

    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SellerCard(
          product:     product,
          showPhone:   showPhone,
          contacting:  contacting,
          onChat:      onChat,
          onShowPhone: onShowPhone,
        ),
        const SizedBox(height: 12),
        const _SafetyCard(),
        const SizedBox(height: 12),
        const _TrustBadgesCard(),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 150),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: wide
              ? Column(children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 7, child: main),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: side),
                  ]),
                  const SizedBox(height: 28),
                  _RelatedAds(future: relatedFuture, category: product.category),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  main,
                  const SizedBox(height: 12),
                  side,
                  const SizedBox(height: 24),
                  _RelatedAds(future: relatedFuture, category: product.category),
                ]),
        ),
      ),
    );
  }
}

// ─── Thumbnail strip ──────────────────────────────────────────────────────────
class _ThumbnailStrip extends StatelessWidget {
  final Product product;
  final int     imageIndex;
  final ValueChanged<int> onSelected;

  const _ThumbnailStrip({required this.product, required this.imageIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    if (product.images.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: product.images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = imageIndex == i;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 76,
              decoration: BoxDecoration(
                borderRadius: _T.r12,
                border: Border.all(
                  color: active ? _T.orange : _T.border,
                  width: active ? 2.5 : 1.5,
                ),
                boxShadow: active ? _T.shadowOrange : _T.shadowSm,
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: product.images[i],
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported_outlined, size: 20),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Hero Card ────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final Product product;
  const _HeroCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final priceFormatter = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 0);

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pill row
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Tag(label: product.condition, bg: _T.orangeLight, fg: _T.orangeDark,
                 icon: Icons.sell_outlined),
            _Tag(label: product.category,  bg: _T.blueLight,   fg: _T.blue,
                 icon: Icons.layers_outlined),
            _Tag(label: '${product.views} views', bg: const Color(0xFFF1F5F9),
                 fg: _T.textMuted, icon: Icons.visibility_outlined),
          ]),

          const SizedBox(height: 16),

          // Price row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  priceFormatter.format(product.price),
                  style: _T.display(30, color: _T.orangeDark),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
              // Price badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _T.greenLight, borderRadius: _T.r20),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.trending_down_rounded, size: 14, color: _T.green),
                  const SizedBox(width: 4),
                  Text('Best Price', style: _T.body(11, color: _T.green, weight: FontWeight.w800)),
                ]),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Title
          Text(
            product.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: _T.display(18, color: _T.text),
          ),

          if (product.location.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _T.orangeLight,
                borderRadius: _T.r20,
                border: Border.all(color: _T.orangeMid),
              ),
              child: Row(children: [
                const Icon(Icons.place_outlined, size: 16, color: _T.orangeDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    product.location.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _T.body(13, color: _T.orangeDark, weight: FontWeight.w700),
                  ),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 14),

          // Divider
          const Divider(color: _T.border, height: 1),
          const SizedBox(height: 12),

          // Location + date row
          Row(children: [
            const Icon(Icons.place_outlined, size: 16, color: _T.orange),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                product.location.trim().isEmpty ? 'India' : product.location.trim(),
                style: _T.body(13, color: _T.textMuted, weight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.schedule_outlined, size: 15, color: _T.textSubtle),
            const SizedBox(width: 5),
            Text(
              DateFormat('dd MMM yyyy').format(product.createdAt),
              style: _T.body(12, color: _T.textSubtle, weight: FontWeight.w600),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Seller Card ─────────────────────────────────────────────────────────────
class _SellerCard extends StatelessWidget {
  final Product      product;
  final bool         showPhone;
  final bool         contacting;
  final VoidCallback onChat;
  final VoidCallback onShowPhone;

  const _SellerCard({
    required this.product,
    required this.showPhone,
    required this.contacting,
    required this.onChat,
    required this.onShowPhone,
  });

  @override
  Widget build(BuildContext context) {
    final seller = product.user;
    final phone  = seller?.phone;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              width: 4, height: 18,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_T.orange, _T.orangeDark], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text('Seller Info', style: _T.display(14, color: _T.text)),
          ]),

          const SizedBox(height: 16),

          // Seller row
          Row(children: [
            // Avatar
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _T.orangeMid, width: 2.5),
                boxShadow: _T.shadowOrange,
              ),
              child: ClipOval(
                child: seller?.avatar != null
                    ? CachedNetworkImage(imageUrl: seller!.avatar!, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _DefaultAvatar(name: seller.name))
                    : _DefaultAvatar(name: seller?.name),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(seller?.name ?? 'Seller',
                    style: _T.display(16, color: _T.text),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.verified_rounded, size: 14, color: _T.orange),
                  const SizedBox(width: 4),
                  Text('Verified Seller', style: _T.body(11, color: _T.orange, weight: FontWeight.w800)),
                ]),
                if (product.location.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.place_outlined, size: 14, color: _T.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(product.location.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _T.body(12, color: _T.textSubtle, weight: FontWeight.w600)),
                    ),
                  ]),
                ],
              ]),
            ),
            // Rating chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: _T.r20,
                border: Border.all(color: const Color(0xFFFDE68A))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                const SizedBox(width: 3),
                Text('4.9', style: _T.body(11, color: const Color(0xFF92400E), weight: FontWeight.w800)),
              ]),
            ),
          ]),

          const SizedBox(height: 18),

          // CTA buttons
          Row(children: [
            Expanded(
              child: _PrimaryBtn(
                label: 'Chat Now',
                icon: Icons.chat_bubble_rounded,
                loading: contacting,
                onTap: contacting ? null : onChat,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _OutlineBtn(
                label: 'Call',
                icon: Icons.call_rounded,
                onTap: onShowPhone,
              ),
            ),
          ]),

          // Phone reveal
          if (showPhone) ...[
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: _T.orangeLight,
                borderRadius: _T.r12,
                border: Border.all(color: _T.orangeMid),
              ),
              child: Row(children: [
                const Icon(Icons.call_rounded, color: _T.orange, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    phone == null || phone.isEmpty ? 'Number not available' : phone,
                    style: _T.display(16, color: _T.orangeDark),
                    textAlign: TextAlign.center,
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  final String? name;
  const _DefaultAvatar({this.name});

  @override
  Widget build(BuildContext context) => Container(
    color: _T.text,
    child: Center(
      child: Text(
        (name?.isNotEmpty == true) ? name![0].toUpperCase() : 'S',
        style: _T.display(22, color: Colors.white),
      ),
    ),
  );
}

// ─── Detail Grid Card ─────────────────────────────────────────────────────────
class _DetailGridCard extends StatelessWidget {
  final Product product;
  const _DetailGridCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final rows = [
      _Row('Category',  product.category,                              Icons.layers_outlined),
      if (product.location.trim().isNotEmpty)
        _Row('Location',  product.location.trim(),                            Icons.place_outlined),
      _Row('Condition', product.condition,                             Icons.sell_outlined),
      _Row('Posted',    DateFormat('dd MMM yyyy').format(product.createdAt), Icons.calendar_today_outlined),
      _Row('Ad ID',     '#${product.id.length > 8 ? product.id.substring(product.id.length - 8) : product.id}', Icons.tag_outlined),
    ];

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 4, height: 18,
              decoration: BoxDecoration(color: _T.blue, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text('Ad Details', style: _T.display(14, color: _T.text)),
          ]),
          const SizedBox(height: 14),
          ...rows.map((r) => _DetailRow(row: r)),
        ],
      ),
    );
  }
}

class _Row {
  final String label, value;
  final IconData icon;
  const _Row(this.label, this.value, this.icon);
}

class _DetailRow extends StatelessWidget {
  final _Row row;
  const _DetailRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: _T.bg, borderRadius: _T.r8,
            border: Border.all(color: _T.border)),
          child: Icon(row.icon, size: 15, color: _T.textMuted),
        ),
        const SizedBox(width: 10),
        Text(row.label, style: _T.body(13, color: _T.textMuted, weight: FontWeight.w600)),
        const Spacer(),
        Flexible(
          flex: 2,
          child: Text(
            row.value.isEmpty ? 'N/A' : row.value,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: _T.body(13, color: _T.text, weight: FontWeight.w800),
          ),
        ),
      ]),
    );
  }
}

// ─── Map Card ─────────────────────────────────────────────────────────────────
class _MapCard extends StatelessWidget {
  final Product product;
  const _MapCard({required this.product});

  String _staticMapUrl(double lat, double lng) {
    final query = Uri(queryParameters: {
      'center': '$lat,$lng',
      'zoom': '15',
      'size': '640x360',
      'maptype': 'mapnik',
      'markers': '$lat,$lng,red-pushpin',
    }).query;
    return 'https://staticmap.openstreetmap.de/staticmap.php?$query';
  }

  String get _locationLabel {
    final location = product.location.trim();
    if (location.isNotEmpty) return location;
    if (product.hasCoordinates) {
      return '${product.latitude!.toStringAsFixed(5)}, ${product.longitude!.toStringAsFixed(5)}';
    }
    return 'Location unavailable';
  }

  String get _accuracyLabel => product.hasCoordinates ? 'Pinned location' : 'Approximate area';

  Future<void> _openDirections() async {
    final query = product.hasCoordinates
        ? '${product.latitude},${product.longitude}'
        : product.location.trim();
    if (query.trim().isEmpty) return;
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (product.location.trim().isEmpty && !product.hasCoordinates) return const SizedBox.shrink();

    return _SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 4, height: 18,
              decoration: BoxDecoration(color: _T.orange, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            const Expanded(child: Text('Location & map', style: TextStyle(fontFamily: _T.fontDisplay, fontSize: 14, fontWeight: FontWeight.w700, color: _T.text, letterSpacing: 0))),
            GestureDetector(
              onTap: _openDirections,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: _T.orangeLight, borderRadius: BorderRadius.circular(999), border: Border.all(color: _T.orangeMid)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.directions_rounded, size: 14, color: _T.orangeDark),
                  const SizedBox(width: 4),
                  Text('Directions', style: _T.body(11.5, color: _T.orangeDark, weight: FontWeight.w800)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _openDirections,
            child: ClipRRect(
              borderRadius: _T.r12,
              child: SizedBox(
                height: 196,
                width: double.infinity,
                child: product.hasCoordinates
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            _staticMapUrl(product.latitude!, product.longitude!),
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) => progress == null
                                ? child
                                : Container(color: _T.bg, child: const Center(child: CircularProgressIndicator(color: _T.orange, strokeWidth: 2))),
                            errorBuilder: (_, __, ___) => _MapFallback(product: product),
                          ),
                          const _MapOverlayGrid(),
                          Center(
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _T.orange,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: _T.shadowOrange,
                              ),
                              child: const Icon(Icons.place_rounded, color: Colors.white, size: 24),
                            ),
                          ),
                          Positioned(
                            right: 8, bottom: 8,
                            child: _GlassPill(
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.open_in_new_rounded, size: 12, color: _T.text),
                                const SizedBox(width: 4),
                                Text('Open in Maps', style: _T.body(11, weight: FontWeight.w800)),
                              ]),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            bottom: 8,
                            child: _GlassPill(
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.my_location_rounded, size: 12, color: _T.green),
                                const SizedBox(width: 4),
                                Text(_accuracyLabel, style: _T.body(11, color: _T.text, weight: FontWeight.w800)),
                              ]),
                            ),
                          ),
                        ],
                      )
                    : _MapFallback(product: product),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _MapAddressRow(
            label: _locationLabel,
            status: _accuracyLabel,
            hasCoordinates: product.hasCoordinates,
          ),
        ],
      ),
    );
  }
}

class _MapAddressRow extends StatelessWidget {
  final String label;
  final String status;
  final bool hasCoordinates;

  const _MapAddressRow({
    required this.label,
    required this.status,
    required this.hasCoordinates,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _T.bg,
        borderRadius: _T.r12,
        border: Border.all(color: _T.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: hasCoordinates ? _T.greenLight : _T.orangeLight,
            shape: BoxShape.circle,
          ),
          child: Icon(
            hasCoordinates ? Icons.verified_rounded : Icons.info_rounded,
            size: 17,
            color: hasCoordinates ? _T.green : _T.orangeDark,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: _T.body(13, color: _T.text, weight: FontWeight.w900, height: 1.25)),
            const SizedBox(height: 3),
            Text(
              '$status. Confirm exact meeting point in chat before visiting.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _T.body(11.5, color: _T.textMuted, weight: FontWeight.w700, height: 1.25),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _MapFallback extends StatelessWidget {
  final Product product;
  const _MapFallback({required this.product});

  @override
  Widget build(BuildContext context) {
    final location = product.location.trim();
    final hasLocation = location.isNotEmpty;
    final label = hasLocation ? location : 'Seller location';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEAF2FF), Color(0xFFFFF3E4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _MapOverlayGrid(),
          Positioned(
            left: 18,
            top: 18,
            right: 18,
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _T.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: _T.shadowOrange,
                  ),
                  child: const Icon(Icons.place_rounded, color: Colors.white, size: 23),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Approximate location', style: _T.display(15, color: _T.text)),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _T.body(12, color: _T.textMuted, weight: FontWeight.w700, height: 1.25),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.88),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white),
                boxShadow: _T.shadowSm,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.search_rounded, size: 13, color: _T.blue),
                const SizedBox(width: 5),
                Text('Tap to view route', style: _T.body(11.5, color: _T.text, weight: FontWeight.w800)),
              ]),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: _GlassPill(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.directions_rounded, size: 13, color: _T.orangeDark),
                const SizedBox(width: 5),
                Text('Open in Maps', style: _T.body(11.5, color: _T.orangeDark, weight: FontWeight.w900)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapOverlayGrid extends StatelessWidget {
  const _MapOverlayGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MapGridPainter());
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withOpacity(0.58)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final minorPaint = Paint()
      ..color = const Color(0xFFCBD5E1).withOpacity(0.52)
      ..strokeWidth = 1;

    for (var x = 24.0; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x + 18, size.height), minorPaint);
    }
    for (var y = 22.0; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 8), minorPaint);
    }

    final path = Path()
      ..moveTo(-20, size.height * 0.72)
      ..cubicTo(size.width * 0.22, size.height * 0.52, size.width * 0.48, size.height * 0.88, size.width + 20, size.height * 0.42);
    canvas.drawPath(path, roadPaint);

    final path2 = Path()
      ..moveTo(size.width * 0.18, -10)
      ..cubicTo(size.width * 0.34, size.height * 0.28, size.width * 0.24, size.height * 0.58, size.width * 0.55, size.height + 10);
    canvas.drawPath(path2, roadPaint..strokeWidth = 6);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Description Card ─────────────────────────────────────────────────────────
class _DescriptionCard extends StatelessWidget {
  final Product product;
  const _DescriptionCard({required this.product});

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 4, height: 18,
          decoration: BoxDecoration(color: _T.green, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text('Description', style: _T.display(14, color: _T.text)),
      ]),
      const SizedBox(height: 12),
      Text(
        product.description.isEmpty ? 'No description provided.' : product.description,
        style: _T.body(14, color: _T.textMuted, height: 1.65),
      ),
    ]),
  );
}

// ─── Safety Card ─────────────────────────────────────────────────────────────
class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFEAF2FF), Color(0xFFFFF3E4)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: _T.r12,
      border: Border.all(color: _T.orangeMid),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(color: _T.orangeLight, shape: BoxShape.circle,
          border: Border.all(color: _T.orangeMid)),
        child: const Icon(Icons.shield_rounded, color: _T.orange, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Safety Tips', style: _T.display(13, color: _T.orangeDark)),
          const SizedBox(height: 4),
          Text(
            'Meet in a public place, inspect before paying, and avoid advance payments.',
            style: _T.body(12, color: const Color(0xFF9A3412), height: 1.45),
          ),
        ]),
      ),
    ]),
  );
}

// ─── Trust Badges Card ────────────────────────────────────────────────────────
class _TrustBadgesCard extends StatelessWidget {
  const _TrustBadgesCard();

  static const _badges = [
    (Icons.verified_user_rounded,  'Verified Sellers', _T.blue),
    (Icons.lock_outline_rounded,   'Secure Chat',      _T.green),
    (Icons.support_agent_rounded,  '24/7 Support',     _T.orange),
  ];

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Why BuySellAdda?', style: _T.display(13, color: _T.text)),
          const SizedBox(height: 12),
          ..._badges.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: b.$3.withOpacity(0.1),
                  borderRadius: _T.r8,
                ),
                child: Icon(b.$1, size: 16, color: b.$3),
              ),
              const SizedBox(width: 10),
              Text(b.$2, style: _T.body(13, color: _T.textMuted, weight: FontWeight.w600)),
            ]),
          )),
        ],
      ),
    );
  }
}

// ─── Related Ads ─────────────────────────────────────────────────────────────
class _RelatedAds extends StatelessWidget {
  final Future<List<Product>>? future;
  final String category;

  const _RelatedAds({required this.future, required this.category});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Section header
      Row(children: [
        Text('Related Ads', style: _T.display(18, color: _T.text)),
        const Spacer(),
        TextButton(
          onPressed: () {},
          child: Text('See all', style: _T.body(13, color: _T.orange, weight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 2),
      Text(
        'More in ${category.isEmpty ? "similar categories" : category}',
        style: _T.body(13, color: _T.textMuted),
      ),
      const SizedBox(height: 14),

      FutureBuilder<List<Product>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _RelatedSkeleton();
          }
          final related = snapshot.data ?? [];
          if (related.isEmpty) {
            return _SurfaceCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.search_off_rounded, size: 40, color: _T.textSubtle.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text('No related ads found', style: _T.body(13, color: _T.textSubtle)),
                  ]),
                ),
              ),
            );
          }

          final w = MediaQuery.sizeOf(context).width;
          final cols = w >= 1000 ? 4 : w >= 680 ? 3 : 2;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: related.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              childAspectRatio: w < 380 ? 0.62 : 0.68,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (_, i) => ProductCard(product: related[i]),
          );
        },
      ),
    ]);
  }
}

// ─── Contact Bottom Bar ───────────────────────────────────────────────────────
class _ContactBar extends StatelessWidget {
  final Product      product;
  final bool         contacting;
  final bool         isFavorited;
  final VoidCallback onFavorite;
  final VoidCallback onChat;

  const _ContactBar({
    required this.product,
    required this.contacting,
    required this.isFavorited,
    required this.onFavorite,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compactCurrency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 0);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: _T.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _T.border),
          boxShadow: const [BoxShadow(color: Color(0x160B63E5), blurRadius: 24, offset: Offset(0, -8))],
        ),
        child: Row(children: [
          // Price info
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fmt.format(product.price),
                  style: _T.display(20, color: _T.orangeDark),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(product.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: _T.body(12, color: _T.textMuted)),
            ]),
          ),
          const SizedBox(width: 10),

          // Favorite
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onFavorite,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: isFavorited ? const Color(0xFFFFF0F3) : _T.bg,
                borderRadius: _T.r8,
                border: Border.all(color: isFavorited ? const Color(0xFFFF4D6D) : _T.border),
              ),
              child: Icon(
                isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFavorited ? const Color(0xFFFF4D6D) : _T.textMuted,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Chat button
          _PrimaryBtn(
            label: 'Chat Now',
            icon: Icons.chat_bubble_rounded,
            loading: contacting,
            onTap: contacting ? null : onChat,
            width: 130,
          ),
        ]),
      ),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────
class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SurfaceCard({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: _T.surface,
      borderRadius: _T.r16,
      border: Border.all(color: _T.border),
      boxShadow: _T.shadowMd,
    ),
    child: child,
  );
}

class _Tag extends StatelessWidget {
  final String  label;
  final IconData? icon;
  final Color   bg, fg;

  const _Tag({required this.label, required this.bg, required this.fg, this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
      Text(label.isEmpty ? 'N/A' : label, style: _T.body(11, color: fg, weight: FontWeight.w800)),
    ]),
  );
}

class _PrimaryBtn extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final bool       loading;
  final VoidCallback? onTap;
  final double?    width;

  const _PrimaryBtn({required this.label, required this.icon, required this.onTap, this.loading = false, this.width});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width ?? 150,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient: onTap == null
              ? LinearGradient(colors: [_T.orange.withOpacity(0.5), _T.orangeDark.withOpacity(0.5)])
              : const LinearGradient(colors: [_T.orange, _T.orangeDark],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: _T.r12,
          boxShadow: onTap == null ? [] : _T.shadowOrange,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 7),
          Text(label, style: _T.body(13, color: Colors.white, weight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final VoidCallback onTap;

  const _OutlineBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      height: 50,
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: _T.r12,
        border: Border.all(color: _T.border, width: 1.5),
        boxShadow: _T.shadowSm,
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: _T.textMuted, size: 16),
        const SizedBox(width: 7),
        Text(label, style: _T.body(13, color: _T.text, weight: FontWeight.w700)),
      ]),
    ),
  );
}

// ─── Skeleton states ──────────────────────────────────────────────────────────
class _SkeletonBox extends StatefulWidget {
  final double width, height;
  final BorderRadius? borderRadius;
  const _SkeletonBox({required this.width, required this.height, this.borderRadius});

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: widget.width, height: widget.height,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius ?? _T.r8,
        color: Color.lerp(const Color(0xFFE2E8F0), const Color(0xFFF1F5F9), _anim.value),
      ),
    ),
  );
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          height: 380, color: _T.text,
          child: const Center(child: CircularProgressIndicator(color: Colors.white30, strokeWidth: 1.5)),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            _SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _SkeletonBox(width: 200, height: 14),
              const SizedBox(height: 16),
              const _SkeletonBox(width: double.infinity, height: 28),
              const SizedBox(height: 10),
              const _SkeletonBox(width: double.infinity, height: 18),
              const SizedBox(height: 8),
              _SkeletonBox(width: 160, height: 14, borderRadius: _T.r8),
            ])),
            const SizedBox(height: 12),
            _SurfaceCard(child: Column(children: List.generate(3, (_) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                _SkeletonBox(width: 32, height: 32),
                SizedBox(width: 10),
                _SkeletonBox(width: 80, height: 13),
                Spacer(),
                _SkeletonBox(width: 100, height: 13),
              ]),
            )))),
          ]),
        ),
      ],
    );
  }
}

class _RelatedSkeleton extends StatelessWidget {
  const _RelatedSkeleton();

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: 4,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2, childAspectRatio: 0.68,
      crossAxisSpacing: 10, mainAxisSpacing: 10,
    ),
    itemBuilder: (_, __) => _SurfaceCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _SkeletonBox(width: double.infinity, height: double.infinity, borderRadius: _T.r8)),
      const SizedBox(height: 10),
      const _SkeletonBox(width: double.infinity, height: 12),
      const SizedBox(height: 6),
      const _SkeletonBox(width: 80, height: 12),
    ])),
  );
}

// ─── Error state ─────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onBack;
  const _ErrorState({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: _T.redLight, shape: BoxShape.circle),
          child: const Icon(Icons.error_outline_rounded, size: 36, color: _T.red),
        ),
        const SizedBox(height: 16),
        Text('Oops!', style: _T.display(22, color: _T.text)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center, style: _T.body(14, color: _T.textMuted, height: 1.5)),
        const SizedBox(height: 24),
        _PrimaryBtn(label: 'Go Back', icon: Icons.arrow_back_rounded, onTap: onBack),
      ]),
    ),
  );
}

String _productWebLink(String productId) {
  final configured = dotenv.env['WEBSITE_URL']?.trim().isNotEmpty == true
      ? dotenv.env['WEBSITE_URL']!.trim()
      : dotenv.env['WEB_URL']?.trim();
  final base = (configured == null || configured.isEmpty) ? AppConstants.websiteUrl : configured;
  final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  return '$cleanBase/products/${Uri.encodeComponent(productId)}';
}
