import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../core/api_service.dart';
import '../../core/constants.dart';
import '../../models/product_model.dart';
import '../product/product_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _searchController = TextEditingController();
  late Future<List<Product>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Product>> _fetchFavorites() async {
    final response = await ApiService.get(
      '/favorites',
      query: {
        'limit': 50,
        if (_searchController.text.trim().isNotEmpty) 'search': _searchController.text.trim(),
      },
    );
    final payload = response.data['data'] ?? response.data;
    final favorites = payload is List
        ? payload
        : payload is Map
            ? (payload['favorites'] ?? payload['items'] ?? [])
            : [];
    if (favorites is! List) return [];
    return favorites
        .map((item) {
          if (item is! Map) return null;
          final map = Map<String, dynamic>.from(item);
          final product = map['product'] ?? map;
          if (product is! Map) return null;
          return Product.fromJson(Map<String, dynamic>.from(product as Map));
        })
        .whereType<Product>()
        .where((product) => product.id.isNotEmpty)
        .toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchFavorites());
    await _future;
  }

  Future<void> _remove(Product product) async {
    try {
      await ApiService.post('/favorites/toggle', data: {'productId': product.id});
      await _refresh();
      _showSnack('Removed from wishlist');
    } catch (error) {
      _showSnack('Wishlist update failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('Wishlist'),
        backgroundColor: AppConstants.backgroundColor,
      ),
      body: SafeArea(
        child: FutureBuilder<List<Product>>(
          future: _future,
          builder: (context, snapshot) {
            final products = snapshot.data ?? [];
            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${products.length} saved ads', style: const TextStyle(color: AppConstants.textSecondaryColor, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _refresh(),
                            decoration: InputDecoration(
                              hintText: 'Search wishlist',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: IconButton(
                                tooltip: _searchController.text.trim().isEmpty ? 'Search' : 'Clear',
                                onPressed: () {
                                  if (_searchController.text.trim().isNotEmpty) {
                                    _searchController.clear();
                                  }
                                  _refresh();
                                },
                                icon: Icon(_searchController.text.trim().isEmpty ? Icons.search_rounded : Icons.close_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
                  else if (snapshot.hasError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _WishlistState(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load wishlist',
                        message: '${snapshot.error}',
                        action: 'Retry',
                        onPressed: _refresh,
                      ),
                    )
                  else if (products.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _WishlistState(
                        icon: Icons.favorite_border_rounded,
                        title: 'No saved ads yet',
                        message: 'Tap the heart on ads you like. They will appear here.',
                        action: 'Browse ads',
                        onPressed: () => Navigator.pop(context),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.builder(
                        itemCount: products.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _FavoriteRow(
                            product: products[index],
                            onRemove: () => _remove(products[index]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FavoriteRow extends StatelessWidget {
  final Product product;
  final VoidCallback onRemove;

  const _FavoriteRow({required this.product, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 0);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.pushNamed(context, ProductDetailScreen.routeName, arguments: product.id),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppConstants.surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppConstants.borderColor),
            boxShadow: const [BoxShadow(color: Color(0x0D0B63E5), blurRadius: 16, offset: Offset(0, 6))],
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _FavoriteImage(url: product.images.isNotEmpty ? product.images.first : null),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text(
                      formatter.format(product.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppConstants.primaryDarkColor, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MiniIconButton(
                    tooltip: 'Remove',
                    icon: Icons.favorite_rounded,
                    color: const Color(0xFFE11D48),
                    onTap: onRemove,
                  ),
                ]),
                const SizedBox(height: 5),
                Text(product.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, height: 1.22)),
                const SizedBox(height: 8),
                _MetaLine(icon: Icons.place_outlined, text: product.location.isEmpty ? product.category : product.location),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: _MetaLine(icon: Icons.visibility_outlined, text: '${product.views} views')),
                  Text(
                    DateFormat('dd MMM').format(product.createdAt),
                    style: const TextStyle(color: AppConstants.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _StatusPill(text: product.condition),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      product.category.isEmpty ? 'Ad' : product.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppConstants.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppConstants.textSubtleColor),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _FavoriteImage extends StatelessWidget {
  final String? url;

  const _FavoriteImage({this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 104,
        height: 118,
        child: url == null || url!.isEmpty
            ? Container(
                color: AppConstants.backgroundColor,
                child: const Icon(Icons.image_not_supported_outlined, color: AppConstants.textSubtleColor),
              )
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (context, _) => Container(color: AppConstants.backgroundColor),
                errorWidget: (context, _, __) => Container(
                  color: AppConstants.backgroundColor,
                  child: const Icon(Icons.image_not_supported_outlined, color: AppConstants.textSubtleColor),
                ),
              ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniIconButton({required this.tooltip, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.18)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: AppConstants.textSubtleColor),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          text.isEmpty ? 'Not available' : text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppConstants.textSecondaryColor, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    ]);
  }
}

class _StatusPill extends StatelessWidget {
  final String text;

  const _StatusPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppConstants.primaryLightColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppConstants.primaryBorderColor),
      ),
      child: Text(
        text.isEmpty ? 'Saved' : text,
        style: const TextStyle(color: AppConstants.primaryDarkColor, fontSize: 10.5, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _WishlistState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback onPressed;

  const _WishlistState({required this.icon, required this.title, required this.message, required this.action, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppConstants.textSecondaryColor),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppConstants.textSecondaryColor)),
            const SizedBox(height: 18),
            FilledButton(onPressed: onPressed, child: Text(action)),
          ],
        ),
      ),
    );
  }
}
