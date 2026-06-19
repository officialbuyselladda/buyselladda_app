import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_service.dart';
import '../../core/constants.dart';
import '../../core/product_provider.dart';
import '../../models/product_model.dart';

class CreateProductScreen extends ConsumerStatefulWidget {
  final Product? product;

  const CreateProductScreen({super.key, this.product});

  @override
  ConsumerState<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends ConsumerState<CreateProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  List<XFile> _images = [];
  String _category = AppConstants.categories.first;
  String _subCategory = '';
  String _condition = 'Used';
  String _location = '';
  List<String> _categories = AppConstants.categories;
  Map<String, List<String>> _subCategories = {};
  Position? _position;
  bool get _editing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product != null) {
      _titleController.text = product.title;
      _descriptionController.text = product.description;
      _priceController.text = product.price.toStringAsFixed(0);
      _category = product.category.trim().isNotEmpty ? product.category : AppConstants.categories.first;
      if (!_categories.contains(_category)) {
        _categories = [_category, ..._categories];
      }
      _condition = product.condition;
      _location = product.location;
      _locationController.text = product.location;
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? picked = await picker.pickMultiImage();
    if (picked != null) {
      setState(() {
        _images.addAll(picked);
      });
    }
  }

  Future<void> _getLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please allow location permission')),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    String address = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    try {
      final places = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (places.isNotEmpty) {
        final place = places.first;
        address = [
          place.street,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((part) => part != null && part.trim().isNotEmpty).join(', ');
      }
    } catch (_) {}

    setState(() {
      _position = position;
      _location = address;
      _locationController.text = address;
    });
  }

  Future<void> _loadCategories() async {
    try {
      final response = await ApiService.get('/categories/tree');
      final payload = response.data['data'] ?? response.data;
      final roots = payload is List ? payload : <dynamic>[];
      final names = roots
          .map((item) => item is Map ? '${item['name'] ?? ''}'.trim() : '')
          .where((name) => name.isNotEmpty)
          .toList();
      final childrenByParent = <String, List<String>>{};
      for (final item in roots) {
        if (item is! Map) continue;
        final parentName = '${item['name'] ?? ''}'.trim();
        final children = item['children'] is List ? item['children'] as List : const [];
        childrenByParent[parentName] = children
            .whereType<Map>()
            .map((child) => '${child['name'] ?? ''}'.trim())
            .where((name) => name.isNotEmpty)
            .toList();
      }
      if (names.isEmpty || !mounted) return;
      setState(() {
        _categories = [...names];
        _subCategories = childrenByParent;
        if (!_categories.contains(_category)) {
          _categories = [_category, ..._categories];
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productProvider);

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(_editing ? 'Edit Ad' : 'Post New Ad'),
        backgroundColor: AppConstants.backgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderCard(editing: _editing),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Photos',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(_images.isNotEmpty ? '${_images.length} images selected' : _editing ? 'Add new photos' : 'Add photos'),
                    ),
                    if (_images.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 96,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(File(_images[index].path), width: 96, height: 96, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: InkWell(
                                    onTap: () => setState(() => _images.removeAt(index)),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_editing && _images.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Existing photos will stay unchanged unless you add new ones.', style: TextStyle(color: AppConstants.textSecondaryColor, fontSize: 12)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Ad details',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title', hintText: 'iPhone 13, Honda Activa, Sofa set...'),
                      validator: (value) => (value?.trim().length ?? 0) < 3 ? 'Enter a clear title' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Price', prefixText: 'Rs '),
                      keyboardType: TextInputType.number,
                      validator: (value) => double.tryParse(value ?? '') == null ? 'Enter valid price' : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
                      onChanged: (value) => setState(() {
                        _category = value!;
                        _subCategory = '';
                      }),
                    ),
                    if ((_subCategories[_category] ?? const []).isNotEmpty) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: _subCategory.isEmpty ? null : _subCategory,
                        decoration: const InputDecoration(labelText: 'Sub category'),
                        hint: const Text('Select sub category'),
                        items: (_subCategories[_category] ?? const [])
                            .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                            .toList(),
                        onChanged: (value) => setState(() => _subCategory = value ?? ''),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Used', label: Text('Used'), icon: Icon(Icons.recycling_rounded)),
                        ButtonSegment(value: 'New', label: Text('New'), icon: Icon(Icons.auto_awesome_rounded)),
                      ],
                      selected: {_condition},
                      onSelectionChanged: (value) => setState(() => _condition = value.first),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description', hintText: 'Condition, reason for selling, pickup details...'),
                      maxLines: 5,
                      validator: (value) => (value?.trim().length ?? 0) < 10 ? 'Write at least 10 characters' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Location',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _getLocation,
                      icon: const Icon(Icons.my_location_rounded),
                      label: Text(_location.isEmpty ? 'Use current location' : _location, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(labelText: 'Or enter location manually'),
                      onChanged: (value) => _location = value.trim(),
                      validator: (_) => _location.trim().isEmpty ? 'Add location' : null,
                    ),
                  ],
                ),
              ),
              if (productState.error != null) ...[
                const SizedBox(height: 12),
                Text(productState.error!, style: const TextStyle(color: AppConstants.errorColor)),
              ],
            ],
          ),
        ),
      ),
      bottomSheet: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppConstants.borderColor))),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: productState.isLoading ? null : _submit,
              icon: productState.isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_editing ? Icons.save_outlined : Icons.publish_outlined),
              label: Text(_editing ? 'Save changes' : 'Post ad for review'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (!_editing && _images.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one image')),
        );
        return;
      }
      if (_location.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add exact location')),
        );
        return;
      }

      final uploadedImages = <Map<String, dynamic>>[];
      for (final image in _images) {
        final formData = FormData.fromMap({
          'image': await MultipartFile.fromFile(image.path, filename: image.name),
        });
        final response = await ApiService.post(AppConstants.uploadPath, formData: formData);
        final payload = response.data['data'] ?? response.data;
        uploadedImages.add({
          'public_id': payload['public_id'],
          'url': payload['url'],
        });
      }

      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'category': _category,
        if (_subCategory.isNotEmpty) 'subCategory': _subCategory,
        'condition': _condition,
        'location': _location,
        if (!_editing || uploadedImages.isNotEmpty) 'images': uploadedImages,
        if (_position != null)
          'locationCoords': {
            'type': 'Point',
            'coordinates': [_position!.longitude, _position!.latitude],
          },
      };
      if (_editing) {
        await ApiService.put('${AppConstants.productPath}/${widget.product!.id}', data: data);
        await ref.read(productProvider.notifier).fetchProducts();
      } else {
        await ref.read(productProvider.notifier).createProduct(data);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editing ? 'Ad updated and sent for review' : 'Ad submitted for admin approval')),
      );
      Navigator.pop(context);
    }
  }
}

class _HeaderCard extends StatelessWidget {
  final bool editing;

  const _HeaderCard({required this.editing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFED7AA))),
      child: Row(
        children: [
          const Icon(Icons.campaign_outlined, color: AppConstants.primaryDarkColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              editing ? 'Update your ad details. Major edits go back to review.' : 'Create a clean listing with photos, price, description and exact location.',
              style: const TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppConstants.borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

