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
  bool _findingLocation = false;
  bool _submitting = false;
  String? _submitStatus;
  String? _submitError;
  int _uploadedCount = 0;
  int _totalUploadCount = 0;
  bool get _editing => widget.product != null;
  bool get _isBusy => _submitting || ref.read(productProvider).isLoading;

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
      final remainingSlots = 8 - _images.length;
      if (remainingSlots <= 0) {
        _showMessage('You can add up to 8 photos');
        return;
      }
      final selected = picked.take(remainingSlots).toList();
      for (final image in selected) {
        final size = await image.length();
        if (size > 5 * 1024 * 1024) {
          _showMessage('${image.name} is larger than 5MB. Please choose a smaller photo.');
          return;
        }
      }
      setState(() {
        _images.addAll(selected);
      });
      if (picked.length > selected.length) {
        _showMessage('Only 8 photos are allowed for one ad');
      }
    }
  }

  Future<void> _getLocation() async {
    setState(() {
      _findingLocation = true;
    });
    try {
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
    } finally {
      if (mounted) {
        setState(() {
          _findingLocation = false;
        });
      }
    }
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

    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

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
                      label: Text(_images.isNotEmpty ? '${_images.length}/8 photos selected' : _editing ? 'Add new photos' : 'Add photos'),
                    ),
                    const SizedBox(height: 8),
                    const Text('Add clear real photos. Max 8 photos, 5MB each.', style: TextStyle(color: AppConstants.textSecondaryColor, fontSize: 12)),
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
                      validator: (value) {
                        final price = double.tryParse((value ?? '').trim());
                        if (price == null) return 'Enter valid price';
                        if (price < 1) return 'Price must be at least Rs 1';
                        if (price > 100000000) return 'Price is too high';
                        return null;
                      },
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF8F8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF8AD8D8)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current location for this ad', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text(
                            _location.isNotEmpty
                                ? _location
                                : 'No location attached yet. Tap the button to use your current location.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF256D6D)),
                          ),
                          if (_position != null) ...[
                            const SizedBox(height: 6),
                            Text('Lat: ${''}${_position!.latitude.toStringAsFixed(5)}, Lng: ${_position!.longitude.toStringAsFixed(5)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF1F4D4D))),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _findingLocation ? null : _getLocation,
                      icon: const Icon(Icons.my_location_rounded),
                      label: Text(_findingLocation ? 'Fetching location...' : (_location.isEmpty ? 'Use current location' : 'Update current location')),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(labelText: 'Or enter location manually'),
                      onChanged: (value) {
                        _location = value.trim();
                        _position = null;
                      },
                      validator: (_) => _locationController.text.trim().isEmpty ? 'Add location' : null,
                    ),
                  ],
                ),
              ),
              if (productState.error != null) ...[
                const SizedBox(height: 12),
                Text(productState.error!, style: const TextStyle(color: AppConstants.errorColor)),
              ],
              if (_submitError != null) ...[
                const SizedBox(height: 12),
                Text(_submitError!, style: const TextStyle(color: AppConstants.errorColor, fontWeight: FontWeight.w700)),
              ],
              if (_submitStatus != null) ...[
                const SizedBox(height: 12),
                _PostingStatusCard(
                  text: _submitStatus!,
                  uploaded: _uploadedCount,
                  total: _totalUploadCount,
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: keyboardOpen
          ? const SizedBox.shrink()
          : SafeArea(
              minimum: const EdgeInsets.only(bottom: 10),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppConstants.borderColor),
                  boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, -6))],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: (productState.isLoading || _submitting) ? null : _submit,
                    icon: (productState.isLoading || _submitting)
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_editing ? Icons.save_outlined : Icons.publish_outlined),
                    label: Text(_editing ? 'Save changes' : 'Post ad for review'),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_isBusy) return;

    if (!_editing && _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image')),
      );
      return;
    }

    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add exact location')),
      );
      return;
    }

    setState(() {
      _submitError = null;
      _submitStatus = _editing ? 'Saving ad details...' : 'Checking posting eligibility...';
      _submitting = true;
      _uploadedCount = 0;
      _totalUploadCount = _images.length;
    });

    final uploadedImages = <Map<String, String>>[];

    try {
      if (!_editing) {
        final eligibilityResponse = await ApiService.get('${AppConstants.productPath}/posting-eligibility');
        final eligibilityPayload = eligibilityResponse.data['data'] ?? eligibilityResponse.data;
        if (eligibilityPayload is Map && eligibilityPayload['canPost'] == false) {
          final monthly = eligibilityPayload['monthly'] is Map ? eligibilityPayload['monthly'] as Map : null;
          final daily = eligibilityPayload['daily'] is Map ? eligibilityPayload['daily'] as Map : null;
          throw Exception('Posting limit reached. Daily remaining: ${daily?['remaining'] ?? 0}, monthly remaining: ${monthly?['remaining'] ?? 0}.');
        }
      }

      for (final image in _images) {
        if (!mounted) return;
        setState(() {
          _submitStatus = 'Uploading photo ${_uploadedCount + 1} of $_totalUploadCount...';
        });
        final formData = FormData.fromMap({
          'image': await MultipartFile.fromFile(image.path, filename: image.name),
        });
        final response = await ApiService.post(AppConstants.uploadPath, formData: formData);
        final payload = response.data['data'] ?? response.data;
        final url = payload is Map ? '${payload['url'] ?? ''}'.trim() : '';
        if (url.isEmpty) {
          throw Exception('Photo upload failed. Please try another image.');
        }
        uploadedImages.add({
          'public_id': payload is Map ? '${payload['public_id'] ?? ''}' : '',
          'url': url,
        });
        if (!mounted) return;
        setState(() {
          _uploadedCount += 1;
        });
      }

      if (!mounted) return;
      setState(() {
        _submitStatus = _editing ? 'Sending updated ad for review...' : 'Creating your ad...';
      });

      final data = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'category': _category.trim(),
        if (_subCategory.trim().isNotEmpty) 'subCategory': _subCategory.trim(),
        'condition': _condition,
        'location': _locationController.text.trim(),
        if (!_editing || uploadedImages.isNotEmpty) 'images': uploadedImages,
        if (_position != null)
          'locationCoords': {
            'type': 'Point',
            'coordinates': [_position!.longitude, _position!.latitude],
          },
      };

      final original = widget.product;
      final sameLocation = original != null && original.location.trim() == _locationController.text.trim();
      if (original != null && _position == null && _editing && sameLocation && original.hasCoordinates) {
        data['locationCoords'] = {
          'type': 'Point',
          'coordinates': [original.longitude, original.latitude],
        };
      }

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
      Navigator.pushNamedAndRemoveUntil(context, '/my-ads', (route) => route.settings.name == '/home');
    } catch (error) {
      if (!mounted) return;
      final errorMessage = _readSubmitError(error);
      setState(() {
        _submitStatus = null;
        _submitError = errorMessage;
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _readSubmitError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) return '${data['message']}';
      return error.message ?? 'Could not post ad. Please try again.';
    }
    final providerError = ref.read(productProvider).error;
    if (providerError != null && providerError.trim().isNotEmpty) return providerError;
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    return text.isEmpty ? 'Could not post ad. Please try again.' : text;
  }
}

class _PostingStatusCard extends StatelessWidget {
  final String text;
  final int uploaded;
  final int total;

  const _PostingStatusCard({
    required this.text,
    required this.uploaded,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0 ? null : uploaded / total;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.secondaryLightColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: AppConstants.textPrimaryColor))),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress.clamp(0.0, 1.0).toDouble()),
          ],
        ],
      ),
    );
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
