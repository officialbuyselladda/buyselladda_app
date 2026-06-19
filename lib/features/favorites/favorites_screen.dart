import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_service.dart';
import '../../core/constants.dart';
import '../../models/product_model.dart';
import '../shared/product_card.dart';

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
    final favorites = payload is List ? payload : (payload['favorites'] ?? []);
    return (favorites as List)
        .map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          final product = map['product'] ?? map;
          return Product.fromJson(Map<String, dynamic>.from(product as Map));
        })
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
                            onSubmitted: (_) => _refresh(),
                            decoration: InputDecoration(
                              hintText: 'Search wishlist',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: IconButton(
                                tooltip: 'Search',
                                onPressed: _refresh,
                                icon: const Icon(Icons.tune_rounded),
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
                          child: _FavoriteRow(product: products[index], onRemove: () => _remove(products[index])),
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
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppConstants.borderColor)),
      child: Row(
        children: [
          SizedBox(width: 112, height: 132, child: ProductCard(product: product)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatter.format(product.price), style: const TextStyle(color: AppConstants.primaryDarkColor, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(product.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                Text(product.location.isEmpty ? product.category : product.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppConstants.textSecondaryColor)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onRemove,
                        icon: const Icon(Icons.favorite_rounded),
                        label: const Text('Remove'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
