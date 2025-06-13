import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocketbase/pocketbase.dart';
import '../constants/colors.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';

class ResultScreen extends StatefulWidget {
  final String skinType;

  const ResultScreen({super.key, required this.skinType});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<Map<String, dynamic>> recommendedProducts = [];
  List<String> skinTips = [];
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _skinTypeData;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _saveSkinType();
    await _fetchSkinTypeData();
    await _fetchRecommendedProducts();
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveSkinType() async {
    final prefs = await SharedPreferences.getInstance();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Save skin type to SharedPreferences
    await prefs.setString('skinType', widget.skinType);
    
    // Check if user is logged in
    if (!authProvider.isLoggedIn) {
      print('User not logged in, skipping profile update');
      return;
    }

    try {
      print('Updating user profile with skin type: ${widget.skinType}');
      final updatedUser = authProvider.currentUser!.copyWith(skinType: widget.skinType);
      await authProvider.updateProfile(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jenis kulit berhasil disimpan')),
        );
      }
    } catch (e) {
      print('Error saving skin type: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving skin type: $e')),
        );
      }
    }
  }

  // Fungsi untuk mengambil data skin type dari PocketBase
  Future<void> _fetchSkinTypeData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final pb = authProvider.pb;
      
      print('Fetching skin type data for: ${widget.skinType}');
      
      // Cari skin type berdasarkan nama
      final resultList = await pb.collection('skin_types').getList(
        filter: 'nama = "${widget.skinType}"',
        page: 1,
        perPage: 1,
      );
      
      if (resultList.items.isEmpty) {
        print('Skin type not found, trying case-insensitive search');
        // Coba pencarian case-insensitive jika tidak ditemukan
        final resultListCaseInsensitive = await pb.collection('skin_types').getList(
          filter: 'nama ~ "${widget.skinType}"',
          page: 1,
          perPage: 1,
        );
        
        if (resultListCaseInsensitive.items.isEmpty) {
          print('Skin type still not found');
          setState(() {
            _skinTypeData = null;
            skinTips = [];
          });
          return;
        }
        
        _processSkinTypeData(resultListCaseInsensitive.items[0]);
      } else {
        _processSkinTypeData(resultList.items[0]);
      }
    } catch (e) {
      print('Error fetching skin type data: $e');
      setState(() {
        skinTips = [];
      });
    }
  }
  
  // Proses data skin type dari PocketBase
  void _processSkinTypeData(RecordModel record) {
    print('Processing skin type data: ${record.id}');
    
    final description = record.data['description'] as String? ?? '';
    
    // Ekstrak tips dari deskripsi (asumsikan tips dipisahkan dengan titik)
    final tipsList = description
        .split('.')
        .where((tip) => tip.trim().isNotEmpty)
        .map((tip) => tip.trim())
        .toList();
    
    setState(() {
      _skinTypeData = {
        'id': record.id,
        'nama': record.data['nama'] ?? '',
        'description': description,
      };
      
      skinTips = tipsList;
    });
    
    print('Extracted ${skinTips.length} tips from description');
  }

  // Konversi nama skin type ke format yang sesuai dengan PocketBase
  String _normalizeSkinType(String skinType) {
    // Konversi ke lowercase dan hapus spasi
    final normalized = skinType.toLowerCase().trim();
    
    // Map nama skin type ke nilai yang disimpan di PocketBase
    switch (normalized) {
      case 'kering':
        return 'dry';
      case 'berminyak':
        return 'oily';
      case 'sensitif':
        return 'sensitive';
      case 'kombinasi':
        return 'combination';
      default:
        return normalized;
    }
  }

  Future<void> _fetchRecommendedProducts() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final pb = authProvider.pb;
      
      // Normalize skin type untuk query
      final normalizedSkinType = _normalizeSkinType(widget.skinType);
      print('Fetching products for normalized skin type: $normalizedSkinType');
      
      // Buat filter untuk skin_type yang merupakan array/multiple select
      // Gunakan operator "?~" untuk mencari nilai dalam array
      final filter = 'skin_type ?~ "$normalizedSkinType"';
      print('Using filter: $filter');
      
      // Fetch products dengan filter skin_type
      final resultList = await pb.collection('products').getList(
        filter: filter,
        sort: '-created',
        page: 1,
        perPage: 10,
      );
      
      print('Products found with filter: ${resultList.items.length}');
      
      // Debug: Print semua produk yang ditemukan
      for (var item in resultList.items) {
        print('Product: ${item.id} - ${item.data['name']} - Skin Types: ${item.data['skin_type']}');
      }
      
      // Jika tidak ada produk yang ditemukan dengan filter, coba ambil semua produk
      if (resultList.items.isEmpty) {
        print('No products found with filter, fetching all products');
        final allProducts = await pb.collection('products').getList(
          page: 1,
          perPage: 50,
        );
        
        // Filter secara manual berdasarkan nama dan deskripsi
        final filteredProducts = allProducts.items.where((record) {
          final name = record.data['name']?.toString().toLowerCase() ?? '';
          final description = record.data['description']?.toString().toLowerCase() ?? '';
          
          // Map skin types to keywords
          Map<String, List<String>> skinTypeKeywords = {
            'kering': ['kering', 'dry', 'moisturizer', 'hydrating', 'soy'],
            'berminyak': ['berminyak', 'oily', 'acne', 'matte', 'oil-free'],
            'sensitif': ['sensitif', 'sensitive', 'gentle', 'calm', 'soothe'],
            'kombinasi': ['kombinasi', 'combination', 'balance', 'dual']
          };
          
          // Get keywords for the user's skin type
          List<String> keywords = skinTypeKeywords[widget.skinType.toLowerCase()] ?? [];
          
          // Check if product name or description contains any of the keywords
          for (var keyword in keywords) {
            if (name.contains(keyword) || description.contains(keyword)) {
              return true;
            }
          }
          
          return false;
        }).toList();
        
        print('Manually filtered products: ${filteredProducts.length}');
        
        // Ambil maksimal 2 produk
        final limitedProducts = filteredProducts.take(2).toList();
        
        // Jika masih tidak cukup, ambil produk acak
        if (limitedProducts.length < 2 && allProducts.items.isNotEmpty) {
          final remainingCount = 2 - limitedProducts.length;
          final randomProducts = allProducts.items
              .where((record) => !limitedProducts.contains(record))
              .take(remainingCount)
              .toList();
          limitedProducts.addAll(randomProducts);
        }
        
        final mappedProducts = limitedProducts.map((record) {
          return {
            'id': record.id,
            'name': record.data['name'] ?? '',
            'price': record.data['price'] ?? 0,
            'description': record.data['description'] ?? '',
            'image_url': record.data['image_url'] ?? '',
            'rating': record.data['rating'] ?? 0,
            'skin_type': record.data['skin_type'] ?? [],
          };
        }).toList();
        
        setState(() {
          recommendedProducts = mappedProducts;
          _isLoading = false;
        });
        return;
      }
      
      // Ambil maksimal 2 produk dari hasil filter
      final limitedRecords = resultList.items.take(2).toList();
      
      final fetchedProducts = limitedRecords.map((record) {
        return {
          'id': record.id,
          'name': record.data['name'] ?? '',
          'price': record.data['price'] ?? 0,
          'description': record.data['description'] ?? '',
          'image_url': record.data['image_url'] ?? '',
          'rating': record.data['rating'] ?? 0,
          'skin_type': record.data['skin_type'] ?? [],
        };
      }).toList();
      
      setState(() {
        recommendedProducts = fetchedProducts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching recommended products: $e');
      setState(() {
        _errorMessage = 'Gagal memuat produk: $e';
        _isLoading = false;
      });
    }
  }

  void _goToProductScreen() {
    Navigator.pushNamed(context, '/products');
  }

  void _goBackToHome() {
    Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
  }

  void _goToCart() {
    Navigator.pushNamed(context, '/cart');
  }

  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 50,
        height: 50,
        color: Colors.grey[200],
        child: const Icon(
          Icons.image_not_supported,
          size: 25,
          color: Colors.grey,
        ),
      );
    }

    return Image.network(
      imageUrl,
      width: 50,
      height: 50,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 50,
          height: 50,
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
          width: 50,
          height: 50,
          color: Colors.grey[200],
          child: const Icon(
            Icons.broken_image,
            size: 25,
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
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBackToHome,
        ),
        title: const Text('Hasil Kuis'),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRecommendedProducts,
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: _goToCart,
          ),
        ],
      ),
      body: _isLoading
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
                        onPressed: _fetchRecommendedProducts,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      Text(
                        'Jenis kulitmu: ${widget.skinType}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tips untuk jenis kulitmu:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      skinTips.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Text(
                                  'Tidak ada tips tersedia untuk jenis kulit ini',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              children: skinTips.map((tip) => ListTile(
                                leading: const Icon(Icons.check_circle_outline, color: AppColors.primary),
                                title: Text(tip),
                                visualDensity: VisualDensity.compact,
                                contentPadding: EdgeInsets.zero,
                              )).toList(),
                            ),
                      const SizedBox(height: 24),
                      const Text(
                        'Rekomendasi Produk:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      recommendedProducts.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Text(
                                  'Tidak ada rekomendasi produk untuk jenis kulit ini',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              children: recommendedProducts.map(
                                (product) => Card(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 3,
                                  child: ListTile(
                                    leading: _buildProductImage(product['image_url']),
                                    title: Text(product['name']),
                                    subtitle: Text('Rp ${product['price']}'),
                                    trailing: ElevatedButton(
                                      onPressed: _goToProductScreen,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Checkout'),
                                    ),
                                  ),
                                ),
                              ).toList(),
                            ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: _goToProductScreen,
          icon: const Icon(Icons.shopping_bag),
          label: const Text('Lihat Semua Produk'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}