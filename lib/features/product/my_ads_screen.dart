import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api_service.dart';
import '../../core/constants.dart';
import '../../models/product_model.dart';
import 'product_detail_screen.dart';

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
    final response = await ApiService.get(
      '${AppConstants.productPath}/my-products',
      query: {'limit': 50},
    );
    final payload = response.data['data'] ?? response.data;
    final list = payload is List
        ? payload
        : payload is Map
            ? (payload['data'] ?? payload['products'] ?? payload['items'] ?? [])
            : [];
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((json) => Product.fromJson(Map<String, dynamic>.from(json)))
        .where((product) => product.id.isNotEmpty)
        .toList();
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetchMyAds());
    await _future;
  }

  Future<void> _setStatus(Product product, String status) async {
    try {
      await ApiService.put('${AppConstants.productPath}/${product.id}', data: {'status': status});
      await _refresh();
      _showSnack(status == 'paused'
          ? 'Ad paused'
          : status == 'approved'
              ? 'Ad resumed'
              : 'Ad marked as sold');
    } catch (error) {
      _showSnack(_readError(error, fallback: 'Action failed'));
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
      _showSnack(_readError(error, fallback: 'Delete failed'));
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
                            onView: () => Navigator.pushNamed(
                              context,
                              ProductDetailScreen.routeName,
                              arguments: visibleAds[index].id,
                            ),
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

  String _readError(Object error, {required String fallback}) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isEmpty ? fallback : text;
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
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onPauseToggle;
  final VoidCallback onSold;
  final VoidCallback onDelete;

  const _MyAdRow({
    required this.product,
    required this.onView,
    required this.onEdit,
    required this.onPauseToggle,
    required this.onSold,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 0);
    final canPauseToggle = product.status == 'approved' || product.status == 'paused';
    final isSold = product.status == 'sold';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onView,
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppConstants.borderColor),
            boxShadow: const [BoxShadow(color: Color(0x0A1E293B), blurRadius: 18, offset: Offset(0, 8))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _AdImage(url: product.images.isNotEmpty ? product.images.first : null),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, height: 1.2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _AdStatusPill(status: product.status),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    formatter.format(product.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppConstants.primaryDarkColor, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  _AdMetaLine(icon: Icons.place_outlined, text: product.location.isEmpty ? product.category : product.location),
                  const SizedBox(height: 7),
                  Row(children: [
                    Expanded(child: _AdMetaLine(icon: Icons.visibility_outlined, text: '${product.views} views')),
                    Text(
                      DateFormat('dd MMM yyyy').format(product.createdAt),
                      style: const TextStyle(color: AppConstants.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ]),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ActionButton(onPressed: onView, icon: Icons.open_in_new_rounded, label: 'View'),
                _ActionButton(
                  onPressed: isSold ? null : onEdit,
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                ),
                _ActionButton(
                  onPressed: canPauseToggle ? onPauseToggle : null,
                  icon: product.status == 'paused' ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  label: product.status == 'paused' ? 'Resume' : 'Pause',
                ),
                SizedBox(
                  width: 46,
                  height: 42,
                  child: PopupMenuButton<String>(
                    tooltip: 'More actions',
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (value) {
                      if (value == 'sold' && !isSold) onSold();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'sold',
                        enabled: !isSold,
                        child: const Text('Mark as sold'),
                      ),
                      const PopupMenuItem(value: 'delete', child: Text('Delete ad')),
                    ],
                  ),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
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

class _AdImage extends StatelessWidget {
  final String? url;

  const _AdImage({this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 96,
        height: 108,
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

class _AdMetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _AdMetaLine({required this.icon, required this.text});

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
