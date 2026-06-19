import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_service.dart';
import '../../core/constants.dart';
import '../../models/product_model.dart';

class MyAdsScreen extends StatefulWidget {
  const MyAdsScreen({super.key});

  @override
  State<MyAdsScreen> createState() => _MyAdsScreenState();
}

class _MyAdsScreenState extends State<MyAdsScreen> {
  late Future<List<Product>> _future;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _future = _fetchMyAds();
  }

  Future<List<Product>> _fetchMyAds() async {
    final response = await ApiService.get('${AppConstants.productPath}/my-products', query: {'limit': 50});
    final payload = response.data['data'] ?? response.data;
    final list = payload is List ? payload : (payload['data'] ?? payload['products'] ?? []);
    return (list as List).map((json) => Product.fromJson(Map<String, dynamic>.from(json as Map))).toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchMyAds());
    await _future;
  }

  Future<void> _setStatus(Product product, String status) async {
    try {
      await ApiService.put('${AppConstants.productPath}/${product.id}', data: {'status': status});
      await _refresh();
      _showSnack(status == 'paused' ? 'Ad paused' : status == 'approved' ? 'Ad resumed' : 'Ad marked as sold');
    } catch (error) {
      _showSnack('Action failed');
    }
  }

  Future<void> _deleteAd(Product product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete ad?'),
        content: Text('Delete "${product.title}" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.delete('${AppConstants.productPath}/${product.id}');
      await _refresh();
      _showSnack('Ad deleted');
    } catch (error) {
      _showSnack('Delete failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: const Text('My Ads'),
        backgroundColor: AppConstants.backgroundColor,
        actions: [
          IconButton(
            tooltip: 'Post ad',
            onPressed: () => Navigator.pushNamed(context, '/create-product').then((_) => _refresh()),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Product>>(
          future: _future,
          builder: (context, snapshot) {
            final ads = snapshot.data ?? [];
            final visibleAds = _filterAds(ads);
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
                          Text('${visibleAds.length} of ${ads.length} ads - ${ads.fold<int>(0, (sum, ad) => sum + ad.views)} total views', style: const TextStyle(color: AppConstants.textSecondaryColor, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          _StatusTabs(
                            selected: _statusFilter,
                            counts: _statusCounts(ads),
                            onChanged: (status) => setState(() => _statusFilter = status),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
                  else if (snapshot.hasError)
                    SliverFillRemaining(hasScrollBody: false, child: _MyAdsState(title: 'Could not load ads', message: '${snapshot.error}', onPressed: _refresh))
                  else if (ads.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _MyAdsState(
                        title: 'No ads posted yet',
                        message: 'Start selling by posting your first product.',
                        action: 'Post an ad',
                        onPressed: () => Navigator.pushNamed(context, '/create-product').then((_) => _refresh()),
                      ),
                    )
                  else if (visibleAds.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _MyAdsState(
                        title: 'No ${_statusLabel(_statusFilter).toLowerCase()} ads',
                        message: 'Try another status tab to see your listings.',
                        action: 'Show all',
                        onPressed: () => setState(() => _statusFilter = 'all'),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.builder(
                        itemCount: visibleAds.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MyAdRow(
                            product: visibleAds[index],
                            onEdit: () => Navigator.pushNamed(context, '/create-product', arguments: visibleAds[index]).then((_) => _refresh()),
                            onPauseToggle: () => _setStatus(visibleAds[index], visibleAds[index].status == 'paused' ? 'approved' : 'paused'),
                            onSold: () => _setStatus(visibleAds[index], 'sold'),
                            onDelete: () => _deleteAd(visibleAds[index]),
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

class _StatusTabs extends StatelessWidget {
  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onChanged;

  const _StatusTabs({required this.selected, required this.counts, required this.onChanged});

  static const statuses = ['all', 'pending', 'approved', 'paused', 'sold', 'rejected', 'suspicious'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final status = statuses[index];
          final active = selected == status;
          return ChoiceChip(
            selected: active,
            label: Text('${_statusLabel(status)} ${counts[status] ?? 0}'),
            onSelected: (_) => onChanged(status),
            selectedColor: AppConstants.primaryLightColor,
            side: BorderSide(color: active ? AppConstants.primaryBorderColor : AppConstants.borderColor),
            labelStyle: TextStyle(
              color: active ? AppConstants.primaryDarkColor : AppConstants.textSecondaryColor,
              fontWeight: FontWeight.w900,
            ),
          );
        },
      ),
    );
  }
}

class _MyAdRow extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onPauseToggle;
  final VoidCallback onSold;
  final VoidCallback onDelete;

  const _MyAdRow({required this.product, required this.onEdit, required this.onPauseToggle, required this.onSold, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppConstants.borderColor)),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 92,
                height: 92,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: AppConstants.backgroundColor, borderRadius: BorderRadius.circular(8)),
                child: product.images.isEmpty ? const Icon(Icons.image_not_supported_outlined) : CachedNetworkImage(imageUrl: product.images.first, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(product.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900))),
                        const SizedBox(width: 6),
                        _AdStatusPill(status: product.status),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(formatter.format(product.price), style: const TextStyle(color: AppConstants.primaryDarkColor, fontWeight: FontWeight.w900, fontSize: 17)),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(Icons.visibility_outlined, size: 15, color: AppConstants.textSecondaryColor),
                        const SizedBox(width: 4),
                        Text('${product.views} views', style: const TextStyle(color: AppConstants.textSecondaryColor, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 10),
                        const Icon(Icons.place_outlined, size: 15, color: AppConstants.textSecondaryColor),
                        const SizedBox(width: 4),
                        Expanded(child: Text(product.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppConstants.textSecondaryColor))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ActionButton(onPressed: onPauseToggle, icon: product.status == 'paused' ? Icons.play_arrow_rounded : Icons.pause_rounded, label: product.status == 'paused' ? 'Resume' : 'Pause'),
              _ActionButton(onPressed: onEdit, icon: Icons.edit_outlined, label: 'Edit'),
              SizedBox(
                width: 46,
                height: 42,
                child: PopupMenuButton<String>(
                  tooltip: 'More actions',
                  icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  if (value == 'sold') onSold();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'sold', child: Text('Mark as sold')),
                  PopupMenuItem(value: 'delete', child: Text('Delete ad')),
                ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _ActionButton({required this.onPressed, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _AdStatusPill extends StatelessWidget {
  final String status;

  const _AdStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => AppConstants.primaryDarkColor,
      'paused' => AppConstants.warningColor,
      'sold' => AppConstants.secondaryColor,
      'rejected' => AppConstants.errorColor,
      'suspicious' => AppConstants.warningColor,
      _ => AppConstants.textSecondaryColor,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(999)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}

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

class _MyAdsState extends StatelessWidget {
  final String title;
  final String message;
  final String action;
  final VoidCallback onPressed;

  const _MyAdsState({required this.title, required this.message, this.action = 'Retry', required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: AppConstants.textSecondaryColor),
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
