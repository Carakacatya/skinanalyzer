import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketbase/pocketbase.dart';

import '../constants/colors.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  String? skinType;
  List<Map<String, dynamic>> products = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSkinType();
  }

  Future<void> _loadSkinType() async {
    final prefs = await SharedPreferences.getInstance();
    final type = prefs.getString('skinType');
    
    print('Loaded skin type from SharedPreferences: $type');
    
    setState(() {
      skinType = type;
    });
    
    if (skinType != null) {
      await _fetchProducts();
    }
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final pb = authProvider.pb;
      
      // Check if user is authenticated
      final isAuthenticated = await authProvider.isAuthenticated();
      print('User is authenticated: $isAuthenticated');
      
      if (!isAuthenticated) {
        setState(() {
          _errorMessage = 'User ID not found. Please log in again.';
          _isLoading = false;
        });
        return;
      }
      
      print('Fetching all products');
      
      // Fetch all products without filtering first
      final resultList = await pb.collection('products').getList(
        page: 1,
        perPage: 50,
      );
      
      print('Total products found: ${resultList.items.length}');
      
      // Print all products for debugging
      for (var item in resultList.items) {
        print('Product: ${item.id} - ${item.data['name']} - Skin Type: ${item.data['skin_type']}');
      }
      
      // If no skin_type field exists in products, we'll use a different approach
      // Let's check if any product has a skin_type field
      bool hasSkinTypeField = false;
      for (var item in resultList.items) {
        if (item.data.containsKey('skin_type')) {
          hasSkinTypeField = true;
          break;
        }
      }
      
      List<RecordModel> filteredRecords = [];
      
      if (hasSkinTypeField) {
        print('Products have skin_type field, filtering by skin type: $skinType');
        // Filter by skin_type if the field exists
        filteredRecords = resultList.items.where((record) {
          final productSkinType = record.data['skin_type']?.toString().toLowerCase() ?? '';
          final userSkinType = skinType?.toLowerCase() ?? '';
          
          return productSkinType.contains(userSkinType) || 
                 userSkinType.contains(productSkinType);
        }).toList();
      } else {
        print('Products do not have skin_type field, using alternative filtering');
        // Alternative filtering based on product name and description
        filteredRecords = resultList.items.where((record) {
          final name = record.data['name']?.toString().toLowerCase() ?? '';
          final description = record.data['description']?.toString().toLowerCase() ?? '';
          final userSkinType = skinType?.toLowerCase() ?? '';
          
          // Map skin types to keywords
          Map<String, List<String>> skinTypeKeywords = {
            'kering': ['kering', 'dry', 'moisturizer', 'hydrating', 'soy'],
            'berminyak': ['berminyak', 'oily', 'acne', 'matte', 'oil-free'],
            'sensitif': ['sensitif', 'sensitive', 'gentle', 'calm', 'soothe'],
            'kombinasi': ['kombinasi', 'combination', 'balance', 'dual']
          };
          
          // Get keywords for the user's skin type
          List<String> keywords = skinTypeKeywords[userSkinType] ?? [];
          
          // Check if product name or description contains any of the keywords
          for (var keyword in keywords) {
            if (name.contains(keyword) || description.contains(keyword)) {
              return true;
            }
          }
          
          return false;
        }).toList();
      }
      
      print('Filtered products count: ${filteredRecords.length}');
      
      // If no products match the filter, show all products
      if (filteredRecords.isEmpty) {
        print('No products match the filter, showing all products');
        filteredRecords = resultList.items;
      }
      
      final fetchedProducts = filteredRecords.map((record) {
        return {
          'id': record.id,
          'name': record.data['name'] ?? '',
          'price': record.data['price'] ?? 0,
          'description': record.data['description'] ?? '',
          'image_url': record.data['image_url'] ?? '',
          'rating': record.data['rating'] ?? 0,
          'skin_type': record.data['skin_type'] ?? '',
        };
      }).toList();
      
      setState(() {
        products = fetchedProducts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching products: ${e.toString()}');
      setState(() {
        _errorMessage = 'Gagal memuat produk: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _addToCart(Map<String, dynamic> product, BuildContext context) {
    Provider.of<CartProvider>(context, listen: false).addToCart(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['name']} ditambahkan ke keranjang!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _goToCart() {
    Navigator.pushNamed(context, '/cart');
  }

  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: 100,
        color: Colors.grey[200],
        child: const Icon(
          Icons.image_not_supported,
          size: 50,
          color: Colors.grey,
        ),
      );
    }

    print('Loading image from URL: $imageUrl');
    return Image.network(
      imageUrl,
      width: double.infinity,
      height: 100,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: double.infinity,
          height: 100,
          color: Colors.grey[200],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('Error loading image: $error');
        return Container(
          width: double.infinity,
          height: 100,
          color: Colors.grey[200],
          child: const Icon(
            Icons.broken_image,
            size: 50,
            color: Colors.grey,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekomendasi Produk'),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchProducts,
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: _goToCart,
          ),
        ],
      ),
      body: skinType == null
          ? const Center(child: CircularProgressIndicator())
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              final authProvider = Provider.of<AuthProvider>(context, listen: false);
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            child: const Text('Login Kembali'),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _fetchProducts,
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    )
                  : SafeArea(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Jenis Kulit: $skinType',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: products.isEmpty
                                ? const Center(
                                    child: Text('Tidak ada produk untuk jenis kulit ini'),
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: products.length,
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 16,
                                      crossAxisSpacing: 16,
                                      childAspectRatio: 0.70,
                                    ),
                                    itemBuilder: (context, index) {
                                      final product = products[index];
                                      return GestureDetector(
                                        onTap: () async {
                                          final addedProduct = await Navigator.pushNamed(
                                            context,
                                            '/productDetail',
                                            arguments: product,
                                          );
                                          if (addedProduct != null) {
                                            _addToCart(addedProduct as Map<String, dynamic>, context);
                                          }
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey.withOpacity(0.15),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              )
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              ClipRRect(
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                                child: _buildProductImage(product['image_url']),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      product['name'],
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      'Rp ${product['price']}',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                        color: AppColors.primary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    SizedBox(
                                                      width: double.infinity,
                                                      child: ElevatedButton(
                                                        onPressed: () => _addToCart(product, context),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: AppColors.accent,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                                        ),
                                                        child: const Text('Add to Cart'),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _goToCart,
                                    icon: const Icon(Icons.payment),
                                    label: const Text('Lanjut ke Checkout'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton(
                                    onPressed: () async {
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.remove('skinType');
                                      Navigator.pushReplacementNamed(context, '/quiz');
                                    },
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.grey.shade100,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'Ulangi Kuis',
                                      style: TextStyle(color: AppColors.primary),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}