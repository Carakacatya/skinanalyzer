import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../models/product_model.dart';

class ProductProvider extends ChangeNotifier {
  final PocketBase pb = PocketBase('http://127.0.0.1:8090');
  
  List<Product> _products = [];
  List<Category> _categories = [];
  Map<String, List<ProductImage>> _productImages = {};
  Map<String, List<ProductVariant>> _productVariants = {};
  Map<String, List<ProductReview>> _productReviews = {};
  Set<String> _userFavorites = {};
  
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Product> get products => _products;
  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Set<String> get userFavorites => _userFavorites;

  // Get product images
  List<ProductImage> getProductImages(String productId) {
    return _productImages[productId] ?? [];
  }

  // Get product variants
  List<ProductVariant> getProductVariants(String productId) {
    return _productVariants[productId] ?? [];
  }

  // Get product reviews
  List<ProductReview> getProductReviews(String productId) {
    return _productReviews[productId] ?? [];
  }

  // Check if product is favorite
  bool isFavorite(String productId) {
    return _userFavorites.contains(productId);
  }

  // Load all categories
  Future<void> loadCategories() async {
    try {
      final resultList = await pb.collection('categories').getList(
        sort: 'sort_order,name',
        filter: 'is_active = true',
      );
      
      _categories = resultList.items.map((item) => Category.fromJson(item.toJson())).toList();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load categories: $e';
      notifyListeners();
    }
  }

  // Load products with optional category filter
  Future<void> loadProducts({String? categoryId}) async {
    try {
      _isLoading = true;
      notifyListeners();

      String filter = 'is_active = true';
      if (categoryId != null && categoryId.isNotEmpty) {
        filter += ' && category = "$categoryId"';
      }

      final resultList = await pb.collection('products').getList(
        sort: '-is_featured,-created',
        filter: filter,
        expand: 'category',
      );
      
      _products = resultList.items.map((item) => Product.fromJson(item.toJson())).toList();
      
    } catch (e) {
      _errorMessage = 'Failed to load products: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load product details (images, variants, reviews)
  Future<void> loadProductDetails(String productId) async {
    try {
      // Load product images
      final imagesResult = await pb.collection('product_images').getList(
        filter: 'product_id = "$productId"',
        sort: 'sort_order',
      );
      _productImages[productId] = imagesResult.items
          .map((item) => ProductImage.fromJson(item.toJson()))
          .toList();

      // Load product variants
      final variantsResult = await pb.collection('product_variants').getList(
        filter: 'product_id = "$productId" && is_active = true',
        sort: 'variant_type,variant_value',
      );
      _productVariants[productId] = variantsResult.items
          .map((item) => ProductVariant.fromJson(item.toJson()))
          .toList();

      // Load product reviews
      final reviewsResult = await pb.collection('product_reviews').getList(
        filter: 'product_id = "$productId" && is_approved = true',
        sort: '-created',
        expand: 'user_id',
        perPage: 50,
      );
      _productReviews[productId] = reviewsResult.items
          .map((item) => ProductReview.fromJson(item.toJson()))
          .toList();

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load product details: $e';
      notifyListeners();
    }
  }

  // Load user favorites
  Future<void> loadUserFavorites(String userId) async {
    try {
      final resultList = await pb.collection('user_favorites').getList(
        filter: 'user_id = "$userId"',
      );
      
      _userFavorites = resultList.items
          .map((item) => item.data['product_id'].toString())
          .toSet();
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load favorites: $e';
      notifyListeners();
    }
  }

  // Toggle favorite
  Future<void> toggleFavorite(String userId, String productId) async {
    try {
      if (_userFavorites.contains(productId)) {
        // Remove from favorites
        final existingFavorites = await pb.collection('user_favorites').getList(
          filter: 'user_id = "$userId" && product_id = "$productId"',
        );
        
        if (existingFavorites.items.isNotEmpty) {
          await pb.collection('user_favorites').delete(existingFavorites.items.first.id);
          _userFavorites.remove(productId);
        }
      } else {
        // Add to favorites
        await pb.collection('user_favorites').create(body: {
          'user_id': userId,
          'product_id': productId,
        });
        _userFavorites.add(productId);
      }
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to toggle favorite: $e';
      notifyListeners();
    }
  }

  // Add product review
  Future<bool> addReview(String userId, String productId, int rating, String title, String comment) async {
    try {
      await pb.collection('product_reviews').create(body: {
        'user_id': userId,
        'product_id': productId,
        'rating': rating,
        'title': title,
        'comment': comment,
        'is_verified_purchase': false, // You can implement purchase verification
      });

      // Reload reviews for this product
      await loadProductDetails(productId);
      
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add review: $e';
      notifyListeners();
      return false;
    }
  }

  // Search products
  Future<void> searchProducts(String query) async {
    try {
      _isLoading = true;
      notifyListeners();

      final resultList = await pb.collection('products').getList(
        filter: 'is_active = true && (name ~ "$query" || description ~ "$query" || brand ~ "$query")',
        sort: '-is_featured,-created',
      );
      
      _products = resultList.items.map((item) => Product.fromJson(item.toJson())).toList();
      
    } catch (e) {
      _errorMessage = 'Failed to search products: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get product by ID
  Product? getProductById(String productId) {
    try {
      return _products.firstWhere((product) => product.id == productId);
    } catch (e) {
      return null;
    }
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
