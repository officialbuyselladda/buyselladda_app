import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/app_language.dart';
import '../../core/api_service.dart';
import '../../core/auth_provider.dart';
import '../../core/constants.dart';
import '../../core/product_provider.dart';
import '../../models/product_model.dart';
import '../chat/chat_list_screen.dart';
import '../product/product_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../shared/product_card.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _T {
  static const orange      = Color(0xFFF97316);
  static const orangeDark  = Color(0xFFEA6A05);
  static const orangeLight = Color(0xFFFFF7ED);
  static const orangeMid   = Color(0xFFFED7AA);
  static const blue        = Color(0xFF2563EB);
  static const blueLight   = Color(0xFFEFF6FF);
  static const bg          = Color(0xFFF8FAFF);
  static const surface     = Color(0xFFFFFFFF);
  static const border      = Color(0xFFE2E8F0);
  static const text        = Color(0xFF1E293B);
  static const textMuted   = Color(0xFF64748B);
  static const textSubtle  = Color(0xFF94A3B8);
  static const green       = Color(0xFF10B981);
  static const greenLight  = Color(0xFFECFDF5);
  static const amber       = Color(0xFFF59E0B);
  static const amberLight  = Color(0xFFFEF3C7);
  static const red         = Color(0xFFEF4444);
  static const redLight    = Color(0xFFFEF2F2);

  static const shadowSm  = [BoxShadow(color: Color(0x0A000000), blurRadius: 4,  offset: Offset(0, 1))];
  static const shadowMd  = [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4))];
  static const shadowLg  = [BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8))];
  static const shadowOr  = [BoxShadow(color: Color(0x28F97316), blurRadius: 16, offset: Offset(0, 4))];

  static final r8  = BorderRadius.circular(8);
  static final r10 = BorderRadius.circular(10);
  static final r12 = BorderRadius.circular(12);
  static final r14 = BorderRadius.circular(14);
  static final r16 = BorderRadius.circular(16);
  static final r20 = BorderRadius.circular(20);
  static final r99 = BorderRadius.circular(99);

  static TextStyle display(double sz, {Color c = text, FontWeight w = FontWeight.w700}) =>
      TextStyle(fontSize: sz, fontWeight: w, color: c, letterSpacing: -0.3, height: 1.2);

  static TextStyle body(double sz, {Color c = text, FontWeight w = FontWeight.w400, double h = 1.4}) =>
      TextStyle(fontSize: sz, fontWeight: w, color: c, height: h);
}

// ─── Location prefs keys ──────────────────────────────────────────────────────
const _kAddress  = 'deal_location_address';
const _kLat      = 'deal_location_lat';
const _kLng      = 'deal_location_lng';
const _kPrompted = 'deal_location_prompted';
const _kRecentProducts = 'deal_recently_viewed_products';

// ─── Static fallback categories ───────────────────────────────────────────────
class _CatItem {
  final String label, category;
  final IconData icon;
  final int? count;
  final String? image;
  final List<_CatItem> children;
  final List<_HomeSlide> slides;
  const _CatItem(this.label, this.category, this.icon, {this.count, this.image, this.children = const [], this.slides = const []});
}

class _HomeSlide {
  final String image, title, subtitle, category, subCategory;
  const _HomeSlide({required this.image, required this.title, required this.subtitle, required this.category, this.subCategory = ''});
}

const _staticCats = [
  _CatItem('All',       '',           Icons.apps_rounded),
  _CatItem('Stationary', 'Stationary', Icons.menu_book_outlined),
  _CatItem('Electronics', 'Electronics', Icons.devices_rounded),
  _CatItem('Jobs', 'Jobs', Icons.work_outline_rounded),
  _CatItem('Clothes', 'Clothes', Icons.checkroom_outlined),
  _CatItem('Room', 'Room', Icons.meeting_room_outlined),
  _CatItem('Flat,Building', 'Flat,Building', Icons.apartment_rounded),
  _CatItem('Cars', 'Cars', Icons.directions_car_rounded),
  _CatItem('Motorcycle', 'Motorcycle', Icons.two_wheeler_rounded),
  _CatItem('For Sale: Houses & Apartments', 'For Sale: Houses & Apartments', Icons.home_work_outlined),
  _CatItem('For Rent: Houses & Apartments', 'For Rent: Houses & Apartments', Icons.key_rounded),
];

class _NavItem {
  final IconData icon, activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  final _searchCtrl  = TextEditingController();
  final _scrollCtrl  = ScrollController();
  Timer? _debounce;

  int     _tabIndex         = 0;
  String? _category;
  String? _subCategory;
  String  _address          = 'Select location';
  double? _lat, _lng;
  bool    _detectingLoc     = false;
  double? _minPrice, _maxPrice;
  String  _sortBy = 'latest';

  late final AnimationController _navAnim;

  @override
  void initState() {
    super.initState();
    _navAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productProvider.notifier).fetchProducts();
      ref.read(authProvider.notifier).checkAuthStatus();
      _restoreLocation();
    });
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _navAnim.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_tabIndex != 0 || !_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels > _scrollCtrl.position.maxScrollExtent - 600) {
      ref.read(productProvider.notifier).fetchProducts(reset: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth     = ref.watch(authProvider);
    final language = ref.watch(appLanguageProvider);

    final pages = [
      _MarketplaceView(
        language:          language,
        searchController:  _searchCtrl,
        scrollController:  _scrollCtrl,
        selectedCategory:  _category,
        selectedSubCategory: _subCategory,
        address:           _address,
        detectingLocation: _detectingLoc,
        onSearch:          _applyFilters,
        onSearchChanged:   _onSearchChanged,
        onClearSearch:     _clearSearch,
        onCategory: (cat, subCat) {
          setState(() {
            final sameMain = cat.isEmpty || (_category == cat && (subCat == null || _subCategory == subCat));
            _category = sameMain ? null : cat;
            _subCategory = sameMain ? null : subCat;
          });
          _applyFilters();
        },
        onLocationTap:   _openLocationSheet,
        onWishlist:      () => _guardedNav('/favorites'),
        onNotifications: () => _guardedNav('/notifications'),
        onVoiceSearch: _startVoiceSearch,
        onFilter: _openFilterSheet,
      ),
      auth.isAuthenticated
          ? _MyAdsView(userId: auth.user?.id ?? '')
          : LoginRequiredScreen(title: tr(language, 'my_ads')),
      const SizedBox.shrink(),
      auth.isAuthenticated ? const ChatListScreen() : const LoginRequiredScreen(title: 'Chats'),
      auth.isAuthenticated ? const ProfileScreen()  : LoginRequiredScreen(title: tr(language, 'account')),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _T.bg,
        body: IndexedStack(index: _tabIndex == 2 ? 0 : _tabIndex, children: pages),
        bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
            ? const SizedBox.shrink()
            : _BottomNav(
                selectedIndex: _tabIndex,
                language: language,
                onSelected: (i) {
                  if (i == 2) {
                    _guardedNav('/create-product');
                    return;
                  }
                  setState(() => _tabIndex = i);
                },
              ),
      ),
    );
  }

  // ── helpers ─────────────────────────────────────────────────────────────────
  void _guardedNav(String route) {
    if (!ref.read(authProvider).isAuthenticated) { Navigator.pushNamed(context, '/login'); return; }
    Navigator.pushNamed(context, route);
  }

  void _applyFilters() {
    _debounce?.cancel();
    if (_scrollCtrl.hasClients && _tabIndex == 0) {
      _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    }
    ref.read(productProvider.notifier).fetchProducts(
      search: _searchCtrl.text, category: _category ?? '', lat: _lat, lng: _lng,
      subCategory: _subCategory ?? '', minPrice: _minPrice, maxPrice: _maxPrice, sortBy: _sortBy,
    );
  }

  Future<void> _openFilterSheet() async {
    final minController = TextEditingController(text: _minPrice?.toStringAsFixed(0) ?? '');
    final maxController = TextEditingController(text: _maxPrice?.toStringAsFixed(0) ?? '');
    var selectedSort = _sortBy;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Filter listings', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(controller: minController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min price'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: maxController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max price'))),
          ]),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: selectedSort,
            decoration: const InputDecoration(labelText: 'Sort by'),
            items: const [
              DropdownMenuItem(value: 'latest', child: Text('Newest first')),
              DropdownMenuItem(value: 'oldest', child: Text('Oldest first')),
              DropdownMenuItem(value: 'price_low', child: Text('Price: low to high')),
              DropdownMenuItem(value: 'price_high', child: Text('Price: high to low')),
            ],
            onChanged: (value) => setSheetState(() => selectedSort = value ?? 'latest'),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apply filters')),
        ]),
      )),
    );
    if (applied != true || !mounted) return;
    setState(() {
      _minPrice = double.tryParse(minController.text.trim());
      _maxPrice = double.tryParse(maxController.text.trim());
      _sortBy = selectedSort;
    });
    _applyFilters();
  }

  void _onSearchChanged(String v) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _applyFilters);
  }

  void _clearSearch() {
    if (_searchCtrl.text.isEmpty) return;
    _searchCtrl.clear(); setState(() {}); _applyFilters();
  }

  Future<void> _startVoiceSearch() async {
    try {
      final text = await const MethodChannel('buyselladda/voice').invokeMethod<String>('listen');
      final query = text?.trim();
      if (query == null || query.isEmpty) return;
      _searchCtrl.text = query;
      setState(() {});
      _applyFilters();
    } catch (_) {
      _showSnack('Voice search is not available on this device.');
    }
  }

  Future<void> _openLocationSheet() async {
    final ctrl = TextEditingController(text: _address == 'Select location' ? '' : _address);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LocationSheet(
        controller: ctrl,
        detecting: _detectingLoc,
        onUseGPS: () async {
          Navigator.pop(ctx);
          await _useCurrentLocation();
        },
        onApply: (val) {
          setState(() { _address = val; _lat = null; _lng = null; });
          _saveLocation(address: val);
          _applyFilters();
        },
      ),
    );
    ctrl.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _detectingLoc = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _showSnack('Location permission required'); return;
      }
      final pos   = await Geolocator.getCurrentPosition();
      var   label = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      try {
        final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (marks.isNotEmpty) {
          final p = marks.first;
          label = [p.locality, p.administrativeArea, p.country]
              .where((x) => x != null && x.trim().isNotEmpty).join(', ');
        }
      } catch (_) {}
      setState(() { _lat = pos.latitude; _lng = pos.longitude; _address = label; });
      await _saveLocation(address: label, lat: pos.latitude, lng: pos.longitude);
      _applyFilters();
    } finally {
      if (mounted) setState(() => _detectingLoc = false);
    }
  }

  Future<void> _restoreLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kAddress);
    if (saved != null && saved.trim().isNotEmpty) {
      if (!mounted) return;
      setState(() { _address = saved; _lat = prefs.getDouble(_kLat); _lng = prefs.getDouble(_kLng); });
      _applyFilters();
      return;
    }
    final prompted = prefs.getBool(_kPrompted) ?? false;
    if (prompted) return;
    await prefs.setBool(_kPrompted, true);
    await _useCurrentLocation();
  }

  Future<void> _saveLocation({required String address, double? lat, double? lng}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAddress, address);
    if (lat == null || lng == null) { await p.remove(_kLat); await p.remove(_kLng); }
    else { await p.setDouble(_kLat, lat); await p.setDouble(_kLng, lng); }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: _T.body(13, c: Colors.white, w: FontWeight.w600)),
      backgroundColor: _T.text,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: _T.r12),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }
}

// ─── Marketplace View ─────────────────────────────────────────────────────────
class _MarketplaceView extends ConsumerWidget {
  final String language;
  final TextEditingController searchController;
  final ScrollController scrollController;
  final String? selectedCategory;
  final String? selectedSubCategory;
  final String address;
  final bool detectingLocation;
  final VoidCallback onSearch, onClearSearch, onLocationTap, onWishlist, onNotifications, onVoiceSearch, onFilter;
  final ValueChanged<String> onSearchChanged;
  final void Function(String category, String? subCategory) onCategory;

  const _MarketplaceView({
    required this.language,        required this.searchController,
    required this.scrollController,required this.selectedCategory, required this.selectedSubCategory,
    required this.address,         required this.detectingLocation,
    required this.onSearch,        required this.onSearchChanged,
    required this.onClearSearch,   required this.onCategory,
    required this.onLocationTap,   required this.onWishlist,
    required this.onNotifications, required this.onVoiceSearch, required this.onFilter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productProvider);

    return SafeArea(
      child: RefreshIndicator(
        color: _T.orange,
        onRefresh: () => ref.read(productProvider.notifier).fetchProducts(),
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            // ── Pinned header ──────────────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyHeaderDelegate(
                child: _TopBar(
                  address:   address,
                  loading:   detectingLocation,
                  language:  language,
                  controller: searchController,
                  onLocationTap:   onLocationTap,
                  onSearch:        onSearch,
                  onSearchChanged: onSearchChanged,
                  onClearSearch:   onClearSearch,
                  onWishlist:      onWishlist,
                  onNotifications: onNotifications,
                  onVoiceSearch:   onVoiceSearch,
                  onFilter:        onFilter,
                ),
              ),
            ),

            // ── Body ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.warning != null) ...[
                      _NoticeBanner(text: state.warning!), const SizedBox(height: 10),
                    ],
                    const _HomeHeroBanner(),
                    const SizedBox(height: 12),
                    _HomeQuickStats(total: state.total == 0 ? state.products.length : state.total),
                    const SizedBox(height: 12),
                    _CategoryRail(selected: selectedCategory, selectedSubCategory: selectedSubCategory, onSelected: onCategory),
                    const SizedBox(height: 14),
                    const _RecentlyViewedSection(),
                    const SizedBox(height: 14),
                    _SectionTitle(
                      title: state.isLoading
                          ? tr(language, 'loading_ads')
                          : tr(language, 'fresh_ads'),
                      subtitle: '${state.total == 0 ? state.products.length : state.total} ${tr(language, 'ads_near_you')}',
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // ── Grid ──────────────────────────────────────────────────────
            if (state.isLoading && state.products.isEmpty)
              const _SkeletonGrid()
            else if (state.products.isEmpty && state.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load listings',
                  message: state.error!,
                  buttonText: 'Retry',
                  onClear: () => ref.read(productProvider.notifier).fetchProducts(
                        search: searchController.text,
                        category: selectedCategory ?? '',
                      ),
                ),
              )
            else if (state.products.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(onClear: () {
                  searchController.clear();
                  onCategory('', null);
                }),
              )
            else
              _ProductGrid(products: state.products),

            if (state.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: _T.orange, strokeWidth: 2)),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ─── Sticky header delegate ───────────────────────────────────────────────────
class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _StickyHeaderDelegate({required this.child});

  @override double get minExtent => 142;
  @override double get maxExtent => 142;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Material(color: _T.bg, elevation: shrinkOffset > 4 ? 2 : 0, child: child);

  @override
  bool shouldRebuild(_StickyHeaderDelegate old) => old.child != child;
}

// ─── Top Bar (Logo + Location + Search + Icons) ───────────────────────────────
class _TopBar extends StatelessWidget {
  final String address, language;
  final bool loading;
  final TextEditingController controller;
  final VoidCallback onLocationTap, onSearch, onClearSearch, onWishlist, onNotifications, onVoiceSearch, onFilter;
  final ValueChanged<String> onSearchChanged;

  const _TopBar({
    required this.address,        required this.language,
    required this.loading,        required this.controller,
    required this.onLocationTap,  required this.onSearch,
    required this.onSearchChanged,required this.onClearSearch,
    required this.onWishlist,     required this.onNotifications,
    required this.onVoiceSearch, required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _T.bg,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Logo + Location
          Row(
            children: [
              Image.asset('assets/images/logo.png', width: 116, height: 40, fit: BoxFit.contain),
              const Spacer(),
              _LocationChip(address: address, loading: loading, onTap: onLocationTap),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SearchBar(
                  controller: controller,
                  language:   language,
                  onSearch:   onSearch,
                  onChanged:  onSearchChanged,
                  onClear:    onClearSearch,
                ),
              ),
              const SizedBox(width: 8),
              _IconPill(icon: Icons.mic_none_rounded, tooltip: 'Voice search', onTap: onVoiceSearch, highlighted: true),
              const SizedBox(width: 7),
              _IconPill(icon: Icons.favorite_border_rounded, tooltip: 'Wishlist', onTap: onWishlist),
              const SizedBox(width: 7),
              _IconPill(icon: Icons.notifications_none_rounded, tooltip: 'Alerts', onTap: onNotifications),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  final String address;
  final bool loading;
  final VoidCallback onTap;
  const _LocationChip({required this.address, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _T.orangeLight,
        borderRadius: _T.r99,
        border: Border.all(color: _T.orangeMid),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          loading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8, color: _T.orange))
              : const Icon(Icons.location_on_rounded, size: 14, color: _T.orange),
          const SizedBox(width: 5),
          Flexible(child: Text(address, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: _T.body(11, c: _T.orangeDark, w: FontWeight.w700))),
          const SizedBox(width: 3),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: _T.orange),
        ],
      ),
    ),
  );
}

class _IconPill extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool highlighted;
  const _IconPill({required this.icon, required this.tooltip, required this.onTap, this.highlighted = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 46,
      decoration: BoxDecoration(
        color: highlighted ? _T.orange : _T.surface, borderRadius: _T.r12,
        border: Border.all(color: highlighted ? _T.orange : _T.border),
        boxShadow: highlighted ? _T.shadowOr : _T.shadowSm,
      ),
      child: Icon(icon, size: 19, color: highlighted ? Colors.white : _T.textMuted),
    ),
  );
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String language;
  final VoidCallback onSearch, onClear;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.language,
      required this.onSearch, required this.onChanged, required this.onClear});

  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    decoration: BoxDecoration(
      color: _T.surface,
      borderRadius: _T.r12,
      border: Border.all(color: _T.border, width: 1.5),
      boxShadow: _T.shadowSm,
    ),
    child: Row(
      children: [
        const SizedBox(width: 12),
        const Icon(Icons.search_rounded, color: _T.textMuted, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onChanged: onChanged,
            onSubmitted: (_) => onSearch(),
            style: _T.body(14, c: _T.text),
            decoration: InputDecoration(
              hintText: tr(language, 'search_hint'),
              hintStyle: _T.body(14, c: _T.textSubtle),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (controller.text.isNotEmpty)
          GestureDetector(onTap: onClear,
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.close_rounded, size: 18, color: _T.textMuted))),
        GestureDetector(onTap: onSearch,
          child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.search_rounded, color: _T.orange, size: 20))),
      ],
    ),
  );
}

// ─── Category Rail ────────────────────────────────────────────────────────────
class _CategoryRail extends StatefulWidget {
  final String? selected;
  final String? selectedSubCategory;
  final void Function(String category, String? subCategory) onSelected;
  const _CategoryRail({required this.selected, required this.selectedSubCategory, required this.onSelected});

  @override
  State<_CategoryRail> createState() => _CategoryRailState();
}

class _CategoryRailState extends State<_CategoryRail> {
  late Future<List<_CatItem>> _future;
  bool _expanded = false;

  @override
  void initState() { super.initState(); _future = _fetch(); }

  Future<List<_CatItem>> _fetch() async {
    try {
      final res   = await ApiService.get('/categories/tree');
      final data  = res.data['data'] ?? res.data;
      final roots = data is List
          ? data
          : data is Map
              ? (data['categories'] ?? data['data'] ?? data['items'] ?? <dynamic>[])
              : <dynamic>[];
      final list  = <_CatItem>[_staticCats.first];
      for (final r in roots) {
        final m   = Map<String, dynamic>.from(r as Map);
        final name = '${m['name'] ?? ''}'.trim();
        if (name.isEmpty) continue;
        final cat = '${m['slug'] ?? ''}'.trim().isNotEmpty ? '${m['slug']}'.trim() : _backendCat(name);
        if (list.any((x) => x.label.toLowerCase() == name.toLowerCase() && x.category == cat)) continue;
        final children = (m['children'] is List ? m['children'] as List : const <dynamic>[])
            .whereType<Map>()
            .map((child) {
              final cm = Map<String, dynamic>.from(child);
              final childName = '${cm['name'] ?? ''}'.trim();
              final childCat = '${cm['slug'] ?? ''}'.trim().isNotEmpty ? '${cm['slug']}'.trim() : _backendCat(childName);
              return _CatItem(
                childName,
                childCat,
                _iconFor('$childName ${cm['icon'] ?? ''}'),
                count: _toInt(cm['productsCount'] ?? cm['productCount']),
                image: '${cm['image'] ?? ''}'.trim().isEmpty ? null : '${cm['image']}'.trim(),
              );
            })
            .where((child) => child.label.isNotEmpty)
            .toList();
        final meta = m['meta'] is Map ? Map<String, dynamic>.from(m['meta']) : <String, dynamic>{};
        final slides = meta['showOnHome'] == false
            ? <_HomeSlide>[]
            : (meta['carouselImages'] is List ? meta['carouselImages'] as List : const <dynamic>[])
                .whereType<Map>()
                .map((slide) {
                  final sm = Map<String, dynamic>.from(slide);
                  final image = '${sm['image'] ?? ''}'.trim();
                  if (image.isEmpty) return null;
                  return _HomeSlide(
                    image: image,
                    title: '${sm['title'] ?? meta['carouselTitle'] ?? name}'.trim(),
                    subtitle: '${sm['subtitle'] ?? meta['carouselSubtitle'] ?? m['description'] ?? ''}'.trim(),
                    category: cat,
                  );
                })
                .whereType<_HomeSlide>()
                .toList();
        list.add(_CatItem(
          name,
          cat,
          _iconFor('$name ${m['icon'] ?? ''}'),
          count: _toInt(m['productsCount'] ?? m['productCount']),
          image: '${m['image'] ?? ''}'.trim().isEmpty ? null : '${m['image']}'.trim(),
          children: children,
          slides: slides,
        ));
      }
      return list.length > 1 ? list : _staticCats;
    } catch (_) { return _staticCats; }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_CatItem>>(
      future: _future,
      builder: (context, snap) {
        final items   = (snap.data?.isNotEmpty == true) ? snap.data! : _staticCats;
        final visible = items.where((item) => item.category.trim().isNotEmpty).toList();
        final tileW   = MediaQuery.sizeOf(context).width >= 700 ? 100.0 : 86.0;
        final activeParent = items.firstWhere(
          (item) => item.category == widget.selected,
          orElse: () => const _CatItem('', '', Icons.apps_rounded),
        );
        final activeChildren = activeParent.children;

        return _Card(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // Left accent bar
                Container(width: 3, height: 16,
                    decoration: BoxDecoration(color: _T.orange, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Expanded(child: Text('Categories', style: _T.display(14, c: _T.text))),
                if (false && items.length > 8)
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: _T.orangeLight, borderRadius: _T.r99,
                          border: Border.all(color: _T.orangeMid)),
                      child: Text(_expanded ? 'Less' : 'See All',
                          style: _T.body(11, c: _T.orangeDark, w: FontWeight.w800)),
                    ),
                  ),
              ]),
              const SizedBox(height: 14),
              SizedBox(
                height: 112,
                child: snap.connectionState == ConnectionState.waiting
                    ? ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 8,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, __) => _ShimmerCatTile(width: tileW),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final item   = visible[i];
                          final active = item.category == widget.selected ||
                              (item.category.isEmpty && widget.selected == null);
                          return SizedBox(width: tileW,
                              child: _CatTile(item: item, active: active,
                                  onTap: () => widget.onSelected(item.category, null)));
                        },
                      ),
              ),
              if (activeChildren.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: activeChildren.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final child = activeChildren[i];
                      final active = child.category == widget.selectedSubCategory;
                      return _SubCatChip(
                        label: child.label,
                        active: active,
                        onTap: () => widget.onSelected(activeParent.category, child.category),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CatTile extends StatelessWidget {
  final _CatItem item;
  final bool active;
  final VoidCallback onTap;
  const _CatTile({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _T.orangeLight : const Color(0xFFF8FAFC),
          borderRadius: _T.r12,
          border: Border.all(color: active ? _T.orange : _T.border, width: active ? 1.8 : 1),
          boxShadow: active ? _T.shadowOr : _T.shadowSm,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 50, height: 50,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: active ? _T.orange.withOpacity(0.12) : _T.surface,
                borderRadius: _T.r10,
                border: Border.all(color: active ? _T.orangeMid : _T.border),
              ),
              child: item.image == null
                  ? Icon(item.icon, color: active ? _T.orangeDark : _T.textMuted, size: 28)
                  : CachedNetworkImage(imageUrl: item.image!, fit: BoxFit.cover),
            ),
            const SizedBox(height: 7),
            Text(item.label, textAlign: TextAlign.center, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _T.body(10.5, c: active ? _T.orangeDark : _T.text, w: FontWeight.w800)),
            if (item.count != null && item.count! > 0) ...[
              const SizedBox(height: 2),
              Text('${item.count}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: _T.body(9.5, c: _T.textSubtle)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShimmerCatTile extends StatelessWidget {
  final double width;
  const _ShimmerCatTile({required this.width});

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFE2E8F0), highlightColor: _T.surface,
    child: Container(width: width, decoration: BoxDecoration(color: _T.surface, borderRadius: _T.r12)),
  );
}

class _SubCatChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SubCatChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? _T.orange : _T.orangeLight,
        borderRadius: _T.r99,
        border: Border.all(color: active ? _T.orange : _T.orangeMid),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _T.body(11.5, c: active ? Colors.white : _T.orangeDark, w: FontWeight.w800),
      ),
    ),
  );
}

// ─── Home Hero ────────────────────────────────────────────────────────────────
class _HomeHeroBanner extends StatelessWidget {
  const _HomeHeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: _T.r20,
        border: Border.all(color: _T.border),
        boxShadow: _T.shadowMd,
      ),
      child: AspectRatio(
        aspectRatio: 2048 / 999,
        child: Image.asset(
          'assets/images/mobile_banner.png',
          width: double.infinity,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => Container(
            color: _T.orangeLight,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(18),
            child: Text(
              'Buy Smart. Sell Fast. Connect Easily.',
              textAlign: TextAlign.center,
              style: _T.display(18, c: _T.orangeDark),
            ),
          ),
        ),
      ),
    );

    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _T.surface,
        borderRadius: _T.r20,
        border: Border.all(color: _T.border),
        boxShadow: _T.shadowMd,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            bottom: -56,
            child: Container(
              width: wide ? 240 : 170,
              height: wide ? 240 : 170,
              decoration: BoxDecoration(
                color: _T.blue.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -18,
            top: -34,
            child: Container(
              width: wide ? 132 : 96,
              height: wide ? 132 : 96,
              decoration: BoxDecoration(
                color: _T.orange.withOpacity(0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(wide ? 22 : 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _T.orangeLight,
                          borderRadius: _T.r99,
                          border: Border.all(color: _T.orangeMid),
                        ),
                        child: Text('BUY • SELL • CONNECT',
                            style: _T.body(11, c: _T.orangeDark, w: FontWeight.w900)),
                      ),
                      const SizedBox(height: 12),
                      Text('Har Deal,\nEk Nayi Shuruaat',
                          style: _T.display(wide ? 26 : 22, c: _T.text, w: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text('Find trusted local deals, chat safely, and post your ad in minutes.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _T.body(13, c: _T.textMuted, w: FontWeight.w600, h: 1.35)),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          _HeroChip(icon: Icons.verified_user_outlined, label: 'Trusted'),
                          _HeroChip(icon: Icons.chat_bubble_outline_rounded, label: 'Real Chat'),
                          _HeroChip(icon: Icons.local_offer_outlined, label: 'Best Deals'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: wide ? 150 : 108,
                  height: wide ? 150 : 124,
                  decoration: BoxDecoration(
                    color: _T.bg,
                    borderRadius: _T.r20,
                    border: Border.all(color: _T.border),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 14,
                        child: Image.asset('assets/images/logo.png',
                            width: wide ? 116 : 88, fit: BoxFit.contain),
                      ),
                      Positioned(
                        bottom: 18,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_T.blue, _T.orange, _T.green],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: _T.r16,
                            boxShadow: _T.shadowSm,
                          ),
                          child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 34),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: _T.bg,
      borderRadius: _T.r99,
      border: Border.all(color: _T.border),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: _T.blue),
      const SizedBox(width: 5),
      Text(label, style: _T.body(11, c: _T.text, w: FontWeight.w800)),
    ]),
  );
}

class _HomeQuickStats extends StatelessWidget {
  final int total;
  const _HomeQuickStats({required this.total});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.shopping_bag_outlined, '${total > 0 ? total : 'Live'}', 'Active Ads', _T.blueLight, _T.blue),
      (Icons.location_on_outlined, 'Near You', 'Local Deals', _T.greenLight, _T.green),
      (Icons.security_outlined, 'Safe', 'Chat First', _T.orangeLight, _T.orange),
    ];

    return Row(
      children: items.map((item) => Expanded(
        child: Container(
          margin: EdgeInsets.only(right: item == items.last ? 0 : 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: _T.surface,
            borderRadius: _T.r14,
            border: Border.all(color: _T.border),
            boxShadow: _T.shadowSm,
          ),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: item.$4, borderRadius: _T.r10),
              child: Icon(item.$1, color: item.$5, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${item.$2}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: _T.body(12, c: _T.text, w: FontWeight.w900)),
              const SizedBox(height: 1),
              Text(item.$3, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: _T.body(10, c: _T.textMuted, w: FontWeight.w700)),
            ])),
          ]),
        ),
      )).toList(),
    );
  }
}

// ─── Section Title ────────────────────────────────────────────────────────────
class _RecentlyViewedSection extends StatefulWidget {
  const _RecentlyViewedSection();

  @override
  State<_RecentlyViewedSection> createState() => _RecentlyViewedSectionState();
}

class _RecentlyViewedSectionState extends State<_RecentlyViewedSection> {
  late Future<List<Product>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<Product>> _fetch() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_kRecentProducts) ?? [];
    final products = <Product>[];
    for (final id in ids.take(8)) {
      try {
        final res = await ApiService.get('${AppConstants.productPath}/$id');
        final payload = res.data['data'] ?? res.data;
        products.add(Product.fromJson(Map<String, dynamic>.from(payload as Map)));
      } catch (_) {}
    }
    return products.where((product) => product.id.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: _future,
      builder: (context, snap) {
        final products = snap.data ?? [];
        if (snap.connectionState != ConnectionState.waiting && products.isEmpty) {
          return const SizedBox.shrink();
        }

        return _Card(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 3, height: 16,
                    decoration: BoxDecoration(color: _T.blue, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Expanded(child: Text('Recently Viewed', style: _T.display(14, c: _T.text))),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                height: 126,
                child: snap.connectionState == ConnectionState.waiting
                    ? ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 4,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, __) => const _RecentSkeleton(),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => _RecentProductTile(product: products[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentProductTile extends StatelessWidget {
  final Product product;
  const _RecentProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final price = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 0).format(product.price);
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, ProductDetailScreen.routeName, arguments: product.id),
      child: Container(
        width: 150,
        decoration: BoxDecoration(color: _T.bg, borderRadius: _T.r12, border: Border.all(color: _T.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: product.images.isEmpty
                ? Container(color: _T.border.withOpacity(0.4), child: const Center(child: Icon(Icons.image_outlined, color: _T.textSubtle)))
                : CachedNetworkImage(imageUrl: product.images.first, width: double.infinity, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: _T.body(11, c: _T.text, w: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(price, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: _T.body(11, c: _T.orangeDark, w: FontWeight.w900)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _RecentSkeleton extends StatelessWidget {
  const _RecentSkeleton();

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: const Color(0xFFE2E8F0),
    highlightColor: _T.surface,
    child: Container(width: 150, decoration: BoxDecoration(color: _T.surface, borderRadius: _T.r12)),
  );
}

class _SectionTitle extends StatelessWidget {
  final String title, subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 3, height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_T.orange, _T.orangeDark],
                begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(2),
          )),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: _T.display(15, c: _T.text)),
        const SizedBox(height: 2),
        Text(subtitle, style: _T.body(12, c: _T.textMuted)),
      ])),
    ],
  );
}

// ─── Product Grid ─────────────────────────────────────────────────────────────
class _ProductGrid extends StatelessWidget {
  final List<Product> products;
  const _ProductGrid({required this.products});

  @override
  Widget build(BuildContext context) {
    final w    = MediaQuery.sizeOf(context).width;
    final cols = w >= 1000 ? 4 : w >= 680 ? 3 : 2;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      sliver: SliverGrid.builder(
        itemCount: products.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:  cols,
          childAspectRatio: w < 380 ? 0.62 : 0.68,
          crossAxisSpacing: 10, mainAxisSpacing: 10,
        ),
        itemBuilder: (_, i) => ProductCard(product: products[i]),
      ),
    );
  }
}

// ─── My Ads View ──────────────────────────────────────────────────────────────
class _MyAdsView extends ConsumerStatefulWidget {
  final String userId;
  const _MyAdsView({required this.userId});

  @override
  ConsumerState<_MyAdsView> createState() => _MyAdsViewState();
}

class _MyAdsViewState extends ConsumerState<_MyAdsView> {
  late Future<List<Product>> _future;
  String _statusFilter = 'all';

  @override
  void initState() { super.initState(); _future = _fetch(); }

  Future<List<Product>> _fetch() async {
    final res     = await ApiService.get('${AppConstants.productPath}/my-products', query: {'limit': 50});
    final payload = res.data['data'] ?? res.data;
    final list    = payload is List ? payload : (payload['data'] ?? payload['products'] ?? []);
    return (list as List).map((j) => Product.fromJson(Map<String, dynamic>.from(j as Map))).toList();
  }

  Future<void> _refresh() async { setState(() => _future = _fetch()); await _future; }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<Product>>(
        future: _future,
        builder: (context, snap) {
          final ads = snap.data ?? [];
          final visibleAds = _filterAds(ads);
          return RefreshIndicator(
            color: _T.orange,
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('My Ads', style: _T.display(22, c: _T.text)),
                        const SizedBox(height: 3),
                        Text('${visibleAds.length} of ${ads.length} ads - ${ads.fold<int>(0, (s, a) => s + a.views)} total views',
                            style: _T.body(12, c: _T.textMuted)),
                      ])),
                      _GradBtn(
                        label: 'Post Ad',
                        icon: Icons.add_rounded,
                        onTap: () => Navigator.pushNamed(context, '/create-product').then((_) => _refresh()),
                      ),
                    ]),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: _HomeStatusTabs(
                      selected: _statusFilter,
                      counts: _statusCounts(ads),
                      onChanged: (status) => setState(() => _statusFilter = status),
                    ),
                  ),
                ),

                if (snap.connectionState == ConnectionState.waiting)
                  const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator(color: _T.orange)))
                else if (snap.hasError)
                  SliverFillRemaining(hasScrollBody: false,
                    child: _EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load',
                        message: '${snap.error}', buttonText: 'Retry', onClear: _refresh))
                else if (ads.isEmpty)
                  SliverFillRemaining(hasScrollBody: false,
                    child: _EmptyState(icon: Icons.inventory_2_outlined, title: 'No ads posted yet',
                        message: 'Start selling by posting your first product.',
                        buttonText: 'Post an ad',
                        onClear: () => Navigator.pushNamed(context, '/create-product').then((_) => _refresh())))
                else if (visibleAds.isEmpty)
                  SliverFillRemaining(hasScrollBody: false,
                    child: _EmptyState(icon: Icons.filter_alt_off_outlined, title: 'No ${_statusLabel(_statusFilter).toLowerCase()} ads',
                        message: 'Try another status tab to see your listings.',
                        buttonText: 'Show all',
                        onClear: () => setState(() => _statusFilter = 'all')))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
                    sliver: SliverList.builder(
                      itemCount: visibleAds.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MyAdCard(
                          product: visibleAds[i],
                          onEdit:        () => Navigator.pushNamed(context, '/create-product', arguments: visibleAds[i]).then((_) => _refresh()),
                          onPauseToggle: () => _setStatus(visibleAds[i], visibleAds[i].status == 'paused' ? 'approved' : 'paused'),
                          onSold:        () => _setStatus(visibleAds[i], 'sold'),
                          onDelete:      () => _deleteAd(visibleAds[i]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _setStatus(Product p, String status) async {
    try {
      await ApiService.put('${AppConstants.productPath}/${p.id}', data: {'status': status});
      await _refresh();
      _snack(status == 'paused' ? 'Ad paused' : status == 'approved' ? 'Ad resumed' : 'Marked as sold');
    } catch (e) { _snack('Action failed'); }
  }

  Future<void> _deleteAd(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(title: 'Delete ad?', body: 'Delete "${p.title}" permanently?'),
    );
    if (ok != true) return;
    try {
      await ApiService.delete('${AppConstants.productPath}/${p.id}');
      await _refresh(); _snack('Ad deleted');
    } catch (_) { _snack('Delete failed'); }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: _T.body(13, c: Colors.white, w: FontWeight.w600)),
      backgroundColor: _T.text, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: _T.r12),
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
    ));
  }

  List<Product> _filterAds(List<Product> ads) {
    if (_statusFilter == 'all') return ads;
    return ads.where((ad) => ad.status.toLowerCase() == _statusFilter).toList();
  }

  Map<String, int> _statusCounts(List<Product> ads) {
    final counts = <String, int>{'all': ads.length};
    for (final ad in ads) {
      final status = ad.status.toLowerCase();
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }
}

class _HomeStatusTabs extends StatelessWidget {
  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onChanged;

  const _HomeStatusTabs({required this.selected, required this.counts, required this.onChanged});

  static const statuses = ['all', 'pending', 'approved', 'paused', 'sold', 'rejected', 'suspicious'];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: statuses.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final status = statuses[i];
        final active = selected == status;
        return GestureDetector(
          onTap: () => onChanged(status),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active ? _T.orangeLight : _T.surface,
              borderRadius: _T.r99,
              border: Border.all(color: active ? _T.orangeMid : _T.border),
            ),
            child: Text(
              '${_statusLabel(status)} ${counts[status] ?? 0}',
              style: _T.body(12, c: active ? _T.orangeDark : _T.textMuted, w: FontWeight.w900),
            ),
          ),
        );
      },
    ),
  );
}

// ─── My Ad Card ───────────────────────────────────────────────────────────────
class _MyAdCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit, onPauseToggle, onSold, onDelete;

  const _MyAdCard({required this.product, required this.onEdit,
      required this.onPauseToggle, required this.onSold, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return _Card(
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thumbnail
          Container(
            width: 90, height: 90,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: _T.r12),
            child: product.images.isEmpty
                ? Icon(Icons.image_not_supported_outlined, color: _T.textSubtle.withOpacity(0.5))
                : CachedNetworkImage(imageUrl: product.images.first, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Icon(Icons.image_not_supported_outlined, color: _T.textSubtle.withOpacity(0.4))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: _T.body(14, c: _T.text, w: FontWeight.w700))),
              const SizedBox(width: 6),
              _StatusTag(status: product.status),
            ]),
            const SizedBox(height: 6),
            Text(fmt.format(product.price),
                style: _T.display(17, c: _T.orangeDark)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.visibility_outlined, size: 14, color: _T.textMuted),
              const SizedBox(width: 4),
              Text('${product.views} views', style: _T.body(12, c: _T.textMuted, w: FontWeight.w600)),
              const SizedBox(width: 10),
              const Icon(Icons.place_outlined, size: 14, color: _T.textMuted),
              const SizedBox(width: 4),
              Expanded(child: Text(product.location, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: _T.body(12, c: _T.textMuted))),
            ]),
          ])),
        ]),

        const SizedBox(height: 12),
        const Divider(color: _T.border, height: 1),
        const SizedBox(height: 10),

        // Action row
        Row(children: [
          _AdActionBtn(
            icon: product.status == 'paused' ? Icons.play_arrow_rounded : Icons.pause_rounded,
            label: product.status == 'paused' ? 'Resume' : 'Pause',
            onTap: onPauseToggle,
          ),
          const SizedBox(width: 8),
          _AdActionBtn(icon: Icons.edit_outlined, label: 'Edit', onTap: onEdit),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (v) { if (v == 'sold') onSold(); if (v == 'delete') onDelete(); },
            shape: RoundedRectangleBorder(borderRadius: _T.r12),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'sold', child: Row(children: [
                const Icon(Icons.check_circle_outline_rounded, size: 16, color: _T.green),
                const SizedBox(width: 8), const Text('Mark as sold')])),
              PopupMenuItem(value: 'delete', child: Row(children: [
                const Icon(Icons.delete_outline_rounded, size: 16, color: _T.red),
                const SizedBox(width: 8), Text('Delete', style: _T.body(14, c: _T.red))])),
            ],
            child: Container(
              width: 38, height: 36,
              decoration: BoxDecoration(color: _T.bg, borderRadius: _T.r10,
                  border: Border.all(color: _T.border)),
              child: const Icon(Icons.more_horiz_rounded, size: 18, color: _T.textMuted),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _AdActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AdActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(color: _T.bg, borderRadius: _T.r10, border: Border.all(color: _T.border)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: _T.textMuted),
          const SizedBox(width: 5),
          Text(label, style: _T.body(12, c: _T.text, w: FontWeight.w700)),
        ]),
      ),
    ),
  );
}

class _StatusTag extends StatelessWidget {
  final String status;
  const _StatusTag({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      'approved'  => (_T.greenLight, _T.green),
      'paused'    => (_T.amberLight, _T.amber),
      'sold'      => (_T.blueLight,  _T.blue),
      'rejected'  => (_T.redLight,   _T.red),
      _           => (const Color(0xFFF1F5F9), _T.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: _T.r99),
      child: Text(status.toUpperCase(), style: _T.body(9, c: fg, w: FontWeight.w900)),
    );
  }
}

// ─── Bottom Nav ───────────────────────────────────────────────────────────────
String _statusLabel(String status) {
  return switch (status) {
    'all' => 'All',
    'pending' => 'Pending',
    'approved' => 'Approved',
    'paused' => 'Paused',
    'sold' => 'Sold',
    'rejected' => 'Rejected',
    'suspicious' => 'Review',
    _ => status,
  };
}

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final String language;
  final ValueChanged<int> onSelected;

  const _BottomNav({required this.selectedIndex, required this.language, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final bottomGap = bottomInset > 0 ? bottomInset + 10.0 : 14.0;
    final items = [
      _NavItem(Icons.home_outlined,         Icons.home_rounded,         tr(language, 'home')),
      _NavItem(Icons.assignment_outlined,   Icons.assignment_rounded,   tr(language, 'my_ads')),
      _NavItem(Icons.add_rounded,            Icons.add_rounded,          'Sell'),
      _NavItem(Icons.chat_bubble_outline,   Icons.chat_bubble_rounded,  'Chats'),
      _NavItem(Icons.person_outline_rounded,Icons.person_rounded,       tr(language, 'account')),
    ];

    return SizedBox(
      height: 88 + bottomGap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            margin: EdgeInsets.fromLTRB(12, 0, 12, bottomGap),
            decoration: BoxDecoration(
              color: _T.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _T.border),
              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 26, offset: Offset(0, 10))],
            ),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  Expanded(child: _NavBtn(item: items[0], active: selectedIndex == 0, onTap: () => onSelected(0))),
                  Expanded(child: _NavBtn(item: items[1], active: selectedIndex == 1, onTap: () => onSelected(1))),
                  const Expanded(child: SizedBox()),
                  Expanded(child: _NavBtn(item: items[3], active: selectedIndex == 3, onTap: () => onSelected(3))),
                  Expanded(child: _NavBtn(item: items[4], active: selectedIndex == 4, onTap: () => onSelected(4))),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: _SellFab(onTap: () => onSelected(2)),
          ),
        ],
      ),
    );
  }
}

class _SellFab extends StatefulWidget {
  final VoidCallback onTap;
  const _SellFab({required this.onTap});

  @override
  State<_SellFab> createState() => _SellFabState();
}

class _SellFabState extends State<_SellFab> {
  bool _pressed = false;

  void _setPressed(bool v) => setState(() => _pressed = v);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            duration: const Duration(milliseconds: 140),
            scale: _pressed ? 0.9 : 1,
            curve: Curves.easeOut,
            child: Container(
              width: 58, height: 58,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: _T.surface,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFEDD5), width: 2),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [_T.orange, _T.orangeDark],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: Color(0x40F97316), blurRadius: 18, offset: Offset(0, 8))],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text('Sell', style: _T.body(10.5, c: _T.orangeDark, w: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final VoidCallback onTap;
  const _NavBtn({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color fg = active ? _T.orange : _T.textMuted;

    return GestureDetector(
      onTap: () {
        if (!active) HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _T.orangeLight : Colors.transparent,
          borderRadius: _T.r14,
          border: active ? Border.all(color: _T.orangeMid) : null,
        ),
        child: SizedBox(
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: active ? 32 : 30,
                height: active ? 28 : 27,
                decoration: BoxDecoration(
                  color: active ? _T.orange : Colors.transparent,
                  borderRadius: _T.r10,
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1, end: active ? 1.06 : 1.0),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                  child: Icon(
                    active ? item.activeIcon : item.icon,
                    color: active ? Colors.white : fg,
                    size: active ? 19 : 21,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _T.body(10, c: fg, w: active ? FontWeight.w900 : FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Location Sheet ───────────────────────────────────────────────────────────
class _LocationSheet extends StatelessWidget {
  final TextEditingController controller;
  final bool detecting;
  final VoidCallback onUseGPS;
  final ValueChanged<String> onApply;

  const _LocationSheet({required this.controller, required this.detecting,
      required this.onUseGPS, required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: _T.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: _T.border, borderRadius: _T.r99))),
          const SizedBox(height: 18),
          Text('Set Location', style: _T.display(18, c: _T.text)),
          const SizedBox(height: 4),
          Text('See ads from your selected area', style: _T.body(13, c: _T.textMuted)),
          const SizedBox(height: 16),
          // Text field
          Container(
            decoration: BoxDecoration(
              color: _T.bg, borderRadius: _T.r12, border: Border.all(color: _T.border, width: 1.5),
            ),
            child: TextField(
              controller: controller,
              style: _T.body(14, c: _T.text),
              decoration: InputDecoration(
                hintText: 'City, area or landmark',
                hintStyle: _T.body(14, c: _T.textSubtle),
                prefixIcon: const Icon(Icons.place_outlined, color: _T.orange, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // GPS button
          GestureDetector(
            onTap: detecting ? null : onUseGPS,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: _T.blueLight, borderRadius: _T.r12,
                border: Border.all(color: _T.blue.withOpacity(0.3)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                detecting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _T.blue))
                    : const Icon(Icons.my_location_rounded, color: _T.blue, size: 18),
                const SizedBox(width: 8),
                Text(detecting ? 'Detecting…' : 'Use current location',
                    style: _T.body(14, c: _T.blue, w: FontWeight.w700)),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          // Apply
          GestureDetector(
            onTap: () {
              final v = controller.text.trim();
              if (v.isEmpty) return;
              onApply(v);
              Navigator.pop(context);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_T.orange, _T.orangeDark]),
                borderRadius: _T.r12, boxShadow: _T.shadowOr,
              ),
              child: Center(child: Text('Apply Location',
                  style: _T.body(14, c: Colors.white, w: FontWeight.w800))),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Notice Banner ────────────────────────────────────────────────────────────
class _NoticeBanner extends StatelessWidget {
  final String text;
  const _NoticeBanner({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: _T.amberLight, borderRadius: _T.r10,
        border: Border.all(color: _T.amber.withOpacity(0.4))),
    child: Row(children: [
      const Icon(Icons.info_outline_rounded, size: 16, color: _T.amber),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: _T.body(12, c: const Color(0xFF92400E)))),
    ]),
  );
}

// ─── Skeleton Grid ────────────────────────────────────────────────────────────
class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    final w    = MediaQuery.sizeOf(context).width;
    final cols = w >= 1000 ? 4 : w >= 680 ? 3 : 2;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      sliver: SliverGrid.builder(
        itemCount: 8,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols, childAspectRatio: 0.68,
          crossAxisSpacing: 10, mainAxisSpacing: 10,
        ),
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: const Color(0xFFE2E8F0), highlightColor: _T.surface,
          child: Container(decoration: BoxDecoration(color: _T.surface, borderRadius: _T.r12)),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, message, buttonText;
  final VoidCallback onClear;

  const _EmptyState({
    this.icon       = Icons.search_off_rounded,
    this.title      = 'No listings found',
    this.message    = 'Try another search or category.',
    this.buttonText = 'Clear filters',
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: _T.orangeLight, shape: BoxShape.circle,
              border: Border.all(color: _T.orangeMid, width: 2)),
          child: Icon(icon, size: 36, color: _T.orange),
        ),
        const SizedBox(height: 16),
        Text(title, style: _T.display(17, c: _T.text)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center, style: _T.body(13, c: _T.textMuted)),
        const SizedBox(height: 20),
        _GradBtn(label: buttonText, onTap: onClear),
      ]),
    ),
  );
}

// ─── Login Required ───────────────────────────────────────────────────────────
class LoginRequiredScreen extends StatelessWidget {
  final String title;
  const LoginRequiredScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _T.bg,
    appBar: AppBar(backgroundColor: _T.surface, title: Text(title, style: _T.display(16, c: _T.text))),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: _T.orangeLight, shape: BoxShape.circle,
                border: Border.all(color: _T.orangeMid, width: 2)),
            child: const Icon(Icons.lock_outline_rounded, size: 36, color: _T.orange),
          ),
          const SizedBox(height: 18),
          Text('Login required', style: _T.display(20, c: _T.text)),
          const SizedBox(height: 8),
          Text('Post ads, chat with sellers, and manage your account after login.',
              textAlign: TextAlign.center, style: _T.body(13, c: _T.textMuted, h: 1.5)),
          const SizedBox(height: 22),
          _GradBtn(label: 'Login / Register', onTap: () => Navigator.pushNamed(context, '/login')),
        ]),
      ),
    ),
  );
}

// ─── Confirm Dialog ───────────────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final String title, body;
  const _ConfirmDialog({required this.title, required this.body});

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: _T.r16),
    title: Text(title, style: _T.display(16, c: _T.text)),
    content: Text(body, style: _T.body(14, c: _T.textMuted)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: _T.body(14, c: _T.textMuted, w: FontWeight.w700))),
      GestureDetector(
        onTap: () => Navigator.pop(context, true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(color: _T.red, borderRadius: _T.r10),
          child: Text('Delete', style: _T.body(14, c: Colors.white, w: FontWeight.w800)),
        ),
      ),
      const SizedBox(width: 4),
    ],
  );
}

// ─── Shared widgets ───────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: padding,
    decoration: BoxDecoration(color: _T.surface, borderRadius: _T.r14,
        border: Border.all(color: _T.border), boxShadow: _T.shadowMd),
    child: child,
  );
}

class _GradBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final double? width;
  const _GradBtn({required this.label, required this.onTap, this.icon, this.width});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_T.orange, _T.orangeDark]),
        borderRadius: _T.r12, boxShadow: _T.shadowOr,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        if (icon != null) ...[Icon(icon, color: Colors.white, size: 16), const SizedBox(width: 6)],
        Text(label, style: _T.body(14, c: Colors.white, w: FontWeight.w800)),
      ]),
    ),
  );
}

// ─── Utility functions ────────────────────────────────────────────────────────
IconData _iconFor(String v) {
  final n = v.toLowerCase();
  if (n == 'all') return Icons.apps_rounded;
  if (n.contains('stationary') || n.contains('stationery') || n.contains('book')) return Icons.menu_book_outlined;
  if (n.contains('mobile') || n.contains('phone') || n.contains('elect') || n.contains('laptop')) return Icons.devices_rounded;
  if (n.contains('car') || n.contains('vehicle')) return Icons.directions_car_rounded;
  if (n.contains('motorcycle') || n.contains('bike') || n.contains('scooter')) return Icons.two_wheeler_rounded;
  if (n.contains('rent')) return Icons.key_rounded;
  if (n.contains('flat') || n.contains('building') || n.contains('apartment')) return Icons.apartment_rounded;
  if (n.contains('property') || n.contains('house') || n.contains('room') || n.contains('real')) return Icons.home_work_outlined;
  if (n.contains('job'))                                                   return Icons.work_outline_rounded;
  if (n.contains('cloth') || n.contains('fashion')) return Icons.checkroom_outlined;
  if (n.contains('service'))                                               return Icons.handyman_outlined;
  if (n.contains('furniture'))                                             return Icons.chair_outlined;
  if (n.contains('pet'))                                                   return Icons.pets_outlined;
  return Icons.category_outlined;
}

String _backendCat(String v) {
  final raw = v.trim();
  if (raw.isEmpty) return '';
  return raw;
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}
