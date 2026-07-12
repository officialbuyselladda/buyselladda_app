import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';
import 'constants.dart';
import '../models/product_model.dart';

final productProvider = StateNotifierProvider<ProductNotifier, ProductState>((ref) {
  return ProductNotifier();
});

class ProductState {
  final List<Product> products;
  final bool isLoading;
  final bool isLoadingMore;
  final Product? selectedProduct;
  final String? error;
  final int page;
  final int total;
  final bool hasMore;
  final String? search;
  final String? category;
  final String? subCategory;
  final double? minPrice;
  final double? maxPrice;
  final String sortBy;
  final double? lat;
  final double? lng;
  final String? warning;
  
  const ProductState({
    this.products = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.selectedProduct,
    this.error,
    this.page = 1,
    this.total = 0,
    this.hasMore = true,
    this.search,
    this.category,
    this.subCategory,
    this.minPrice,
    this.maxPrice,
    this.sortBy = 'latest',
    this.lat,
    this.lng,
    this.warning,
  });
  
  ProductState copyWith({
    List<Product>? products,
    bool? isLoading,
    bool? isLoadingMore,
    Product? selectedProduct,
    String? error,
    int? page,
    int? total,
    bool? hasMore,
    String? search,
    String? category,
    String? subCategory,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
    double? lat,
    double? lng,
    String? warning,
  }) {
    return ProductState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      selectedProduct: selectedProduct ?? this.selectedProduct,
      error: error,
      page: page ?? this.page,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      search: search ?? this.search,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      sortBy: sortBy ?? this.sortBy,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      warning: warning,
    );
  }
}

class ProductNotifier extends StateNotifier<ProductState> {
  ProductNotifier() : super(const ProductState());
  
  Future<void> fetchProducts({
    String? search,
    String? category,
    String? subCategory,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
    double? lat,
    double? lng,
    bool reset = true,
  }) async {
    final nextPage = reset ? 1 : state.page + 1;
    if (!reset && (!state.hasMore || state.isLoadingMore)) return;

    state = state.copyWith(
      isLoading: reset,
      isLoadingMore: !reset,
      error: null,
      search: search,
      category: category,
      subCategory: subCategory,
      minPrice: minPrice,
      maxPrice: maxPrice,
      sortBy: sortBy,
      lat: lat,
      lng: lng,
      page: reset ? 1 : state.page,
    );
    try {
      final query = <String, dynamic>{
        'page': nextPage,
        'limit': 20,
        if ((search ?? state.search)?.trim().isNotEmpty == true) 'search': (search ?? state.search)!.trim(),
        if ((category ?? state.category)?.trim().isNotEmpty == true) 'category': category ?? state.category,
        if ((subCategory ?? state.subCategory)?.trim().isNotEmpty == true) 'subCategory': subCategory ?? state.subCategory,
        if ((minPrice ?? state.minPrice) != null) 'minPrice': minPrice ?? state.minPrice,
        if ((maxPrice ?? state.maxPrice) != null) 'maxPrice': maxPrice ?? state.maxPrice,
        'sortBy': sortBy ?? state.sortBy,
        if ((lat ?? state.lat) != null) 'lat': lat ?? state.lat,
        if ((lng ?? state.lng) != null) 'lng': lng ?? state.lng,
        if ((lat ?? state.lat) != null && (lng ?? state.lng) != null) 'radius': 25,
      };
      final response = await ApiService.get(AppConstants.productPath, query: query);
      final payload = _responsePayload(response.data);
      final list = _productList(payload);
      final products = list.map((json) => Product.fromJson(json)).toList();
      final pagination = payload is Map ? _asMap(payload['pagination']) : null;
      state = state.copyWith(
        products: reset ? products : [...state.products, ...products],
        isLoading: false,
        isLoadingMore: false,
        page: nextPage,
        total: pagination?['total'] ?? products.length,
        hasMore: pagination?['hasMore'] ?? products.length == 20,
        warning: payload is Map ? payload['warning'] : null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, isLoadingMore: false, error: _readError(e));
    }
  }
  
  Future<void> fetchProductDetail(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await ApiService.get('${AppConstants.productPath}/$id');
      final payload = response.data['data'] ?? response.data;
      state = state.copyWith(
        selectedProduct: Product.fromJson(Map<String, dynamic>.from(payload as Map)),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _readError(e));
    }
  }
  
  Future<void> createProduct(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ApiService.post(AppConstants.productPath, data: data);
      state = state.copyWith(isLoading: false);
      fetchProducts();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _readError(e));
      rethrow;
    }
  }
}

dynamic _responsePayload(dynamic data) {
  if (data is Map && data.containsKey('data')) return data['data'];
  return data;
}

List<Map<String, dynamic>> _productList(dynamic payload) {
  dynamic raw;
  if (payload is List) {
    raw = payload;
  } else if (payload is Map) {
    raw = payload['products'] ?? payload['data'] ?? payload['items'] ?? [];
  } else {
    raw = [];
  }

  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .where((item) => '${item['_id'] ?? item['id'] ?? ''}'.isNotEmpty)
      .toList();
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String _readError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) return '${data['message']}';
    return error.message ?? 'Could not connect to server';
  }
  return error.toString();
}
