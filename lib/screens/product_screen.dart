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
  String? skinTypeId;
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
      await _fetchSkinTypeId();
      await _fetchProducts();
    } else {
      print('No skin type found in SharedPreferences');
      setState(() {
        _errorMessage = 'Jenis kulit tidak ditemukan. Silakan lakukan kuis terlebih dahulu.';
        _isLoading = false;
      });
    }
  }
  
  // Fungsi untuk mendapatkan ID skin type dari PocketBase
  Future<void> _fetchSkinTypeId() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final pb = authProvider.pb;
      
      print('Fetching skin type ID for: $skinType');
      
      // Cari skin type berdasarkan nama
      final resultList = await pb.collection('skin_types').getList(
        filter: 'nama = "$skinType"',
        page: 1,
        perPage: 1,
      );
      
      if (resultList.items.isEmpty) {
        print('Skin type not found, trying case-insensitive search');
        // Coba pencarian case-insensitive jika tidak ditemukan
        final resultListCaseInsensitive = await pb.collection('skin_types').getList(
          filter: 'nama ~ "$skinType"',
          page: 1,
          perPage: 1,
        );
        
        if (resultListCaseInsensitive.items.isEmpty) {
          print('Skin type still not found');
          return;
        }
        
        setState(() {
          skinTypeId = resultListCaseInsensitive.items[0].id;
        });
        print('Found skin type ID: $skinTypeId');
      } else {
        setState(() {
          skinTypeId = resultList.items[0].id;
        });
        print('Found skin type ID: $skinTypeId');
      }
    } catch (e) {
      print('Error fetching skin type ID: $e');
    }
  }

  // Konversi nama skin type ke format yang sesuai dengan PocketBase
  List<String> _getSkinTypeKeywords(String skinType) {
    // Konversi ke lowercase dan hapus spasi
    final normalized = skinType.toLowerCase().trim();
    
    // Map nama skin type ke nilai yang mungkin disimpan di PocketBase
    switch (normalized) {
      case 'kering':
        return ['kering', 'dry'];
      case 'berminyak':
        return ['berminyak', 'oily'];
      case 'sensitif':
        return ['sensitif', 'sensitive'];
      case 'kombinasi':
        return ['kombinasi', 'combination'];
      default:
        return [normalized];
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
      
      if (skinType == null) {
        setState(() {
          _errorMessage = 'Jenis kulit tidak ditemukan. Silakan lakukan kuis terlebih dahulu.';
          _isLoading = false;
        });
        return;
      }
      
      print('Fetching products for skin type: $skinType');
      
      // Dapatkan semua produk terlebih dahulu
      final allProducts = await pb.collection('products').getList(
        page: 1,
        perPage: 100,
      );
      
      print('Total products found: ${allProducts.items.length}');
      
      // Debug: Print semua produk dan skin type mereka
      for (var item in allProducts.items) {
        print('Product: ${item.id} - ${item.data['name']} - Skin Types: ${item.data['skin_type']}');
      }
      
      // Dapatkan keywords untuk skin type
      final skinTypeKeywords = _getSkinTypeKeywords(skinType!);
      print('Skin type keywords: $skinTypeKeywords');
      
      // Filter produk secara manual
      final filteredProducts = <Map<String, dynamic>>[];
      
      for (var record in allProducts.items) {
        bool matchFound = false;
        
        // Cek apakah skin_type adalah array
        if (record.data['skin_type'] is List) {
          final productSkinTypes = List<String>.from(record.data['skin_type']);
          
          // Cek apakah ada keyword yang cocok dengan salah satu skin type produk
          for (var keyword in skinTypeKeywords) {
            for (var productType in productSkinTypes) {
              if (productType.toLowerCase().contains(keyword.toLowerCase())) {
                matchFound = true;
                break;
              }
            }
            if (matchFound) break;
          }
        } 
        // Cek apakah skin_type adalah string
        else if (record.data['skin_type'] is String) {
          final productSkinType = record.data['skin_type'].toString().toLowerCase();
          
          // Cek apakah ada keyword yang cocok dengan skin type produk
          for (var keyword in skinTypeKeywords) {
            if (productSkinType.contains(keyword.toLowerCase())) {
              matchFound = true;
              break;
            }
          }
        }
        
        // Jika tidak ada skin_type, cek nama dan deskripsi
        if (!matchFound && record.data.containsKey('name') && record.data.containsKey('description')) {
          final name = record.data['name']?.toString().toLowerCase() ?? '';
          final description = record.data['description']?.toString().toLowerCase() ?? '';
          
          // Map skin types to keywords for checking in name/description
          Map<String, List<String>> skinTypeContentKeywords = {
            'kering': ['kering', 'dry', 'moisturizer', 'hydrating', 'soy'],
            'berminyak': ['berminyak', 'oily', 'acne', 'matte', 'oil-free'],
            'sensitif': ['sensitif', 'sensitive', 'gentle', 'calm', 'soothe'],
            'kombinasi': ['kombinasi', 'combination', 'balance', 'dual']
          };
          
          // Get extended keywords for the user's skin type
          List<String> contentKeywords = skinTypeContentKeywords[skinType!.toLowerCase()] ?? [];
          
          // Check if product name or description contains any of the keywords
          for (var keyword in contentKeywords) {
            if (name.contains(keyword) || description.contains(keyword)) {
              matchFound = true;
              break;
            }
          }
        }
        
        // Jika cocok, tambahkan ke hasil
        if (matchFound) {
          filteredProducts.add({
            'id': record.id,
            'name': record.data['name'] ?? '',
            'price': record.data['price'] ?? 0,
            'description': record.data['description'] ?? '',
            'image_url': record.data['image_url'] ?? '',
            'rating': record.data['rating'] ?? 0,
            'skin_type': record.data['skin_type'] ?? [],
          });
        }
      }
      
      print('Filtered products count: ${filteredProducts.length}');
      
      // Jika tidak ada produk yang cocok, tampilkan pesan
      if (filteredProducts.isEmpty) {
        print('No matching products found for skin type: $skinType');
        setState(() {
          products = [];
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        products = filteredProducts;
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
        title: const Text('Produk untuk Jenis Kulitmu'),
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
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.help_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Jenis kulit belum ditentukan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Silakan lakukan kuis untuk menentukan jenis kulit Anda',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/quiz');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('Mulai Kuis'),
                  ),
                ],
              ),
            )
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            color: Colors.grey.shade50,
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Produk yang cocok untuk jenis kulit $skinType',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${products.length} produk',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: products.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.search_off,
                                          size: 64,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Tidak ada produk untuk jenis kulit $skinType',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 24),
                                        ElevatedButton(
                                          onPressed: () async {
                                            final prefs = await SharedPreferences.getInstance();
                                            await prefs.remove('skinType');
                                            Navigator.pushReplacementNamed(context, '/quiz');
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                          ),
                                          child: const Text('Ulangi Kuis'),
                                        ),
                                      ],
                                    ),
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.all(16),
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
                                              Stack(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                                    child: _buildProductImage(product['image_url']),
                                                  ),
                                                  Positioned(
                                                    top: 8,
                                                    right: 8,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primary,
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: const Text(
                                                        'Rekomendasi',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
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
                          Padding(
                            padding: const EdgeInsets.all(16),
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}