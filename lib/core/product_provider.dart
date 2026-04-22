import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_service.dart';
import '../constants.dart';
import '../models/product_model.dart';

final productProvider = StateNotifierProvider<ProductNotifier, ProductState>((ref) {
  return ProductNotifier();
});

class ProductState {
  final List<Product> products;
  final bool isLoading;
  final Product? selectedProduct;
  final String? error;
  
  const ProductState({
    this.products = const [],
    this.isLoading = false,
    this.selectedProduct,
    this.error,
  });
  
  ProductState copyWith({
    List<Product>? products,
    bool? isLoading,
    Product? selectedProduct,
    String? error,
  }) {
    return ProductState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      selectedProduct: selectedProduct ?? this.selectedProduct,
      error: error ?? this.error,
    );
  }
}

class ProductNotifier extends StateNotifier<ProductState> {
  ProductNotifier() : super(const ProductState());
  
  Future<void> fetchProducts({Map<String, dynamic>? query}) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await ApiService.get(AppConstants.productPath, query: query);
      final products = (response.data as List).map((json) => Product.fromJson(json)).toList();
      state = state.copyWith(products: products, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
  
  Future<void> fetchProductDetail(String id) async {
    try {
      final response = await ApiService.get('\${AppConstants.productPath}/\$id');
      state = state.copyWith(
        selectedProduct: Product.fromJson(response.data),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
  
  Future<void> createProduct(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true);
    try {
      await ApiService.post(AppConstants.productPath, data: data);
      state = state.copyWith(isLoading: false);
      // Refresh list
      fetchProducts();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

