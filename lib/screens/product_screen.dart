import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import 'home_screen.dart';
import 'tips_screen.dart';
import 'profile_screen.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _products = [];
  List<String> _categories = ['Semua Produk', 'Untuk Saya'];
  String _selectedCategory = 'Untuk Saya';
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedIndex = 1; // Set to 1 for Shop tab
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ProductScreen(),
    const TipsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize Animation Controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // Initialize Animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _loadProducts();
    _startEntranceAnimations();
  }
  
  void _startEntranceAnimations() {
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/main', arguments: 0);
        break;
      case 1:
        // Already on product screen
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/main', arguments: 2);
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/main', arguments: 3);
        break;
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.pb == null) {
        throw Exception('PocketBase not initialized');
      }

      debugPrint('=== LOADING PRODUCTS ===');
      
      // Load products from PocketBase
      final records = await authProvider.pb.collection('products').getFullList(
        sort: '-created',
      );

      debugPrint('Found ${records.length} products');

      List<Map<String, dynamic>> products = [];
      Set<String> categories = {'Semua Produk', 'Untuk Saya'};

      for (var record in records) {
        final product = {
          'id': record.id,
          'name': record.data['name'] ?? 'Unknown Product',
          'price': _parsePrice(record.data['price']),
          'image_url': record.data['image_url'] ?? '',
          'description': record.data['description'] ?? '',
          'category': record.data['category'] ?? 'Uncategorized',
          'skin_type': record.data['skin_type'] ?? [],
          'rating': _parseRating(record.data['rating']),
          'brand': record.data['brand'] ?? '',
        };

        products.add(product);
        if (product['category'] != null && product['category'].isNotEmpty) {
          categories.add(product['category']);
        }
        
        debugPrint('Product: ${product['name']} - Rp${product['price']} - Skin Types: ${product['skin_type']}');
      }

      setState(() {
        _products = products;
        _categories = categories.toList();
        _isLoading = false;
      });

      debugPrint('Products loaded successfully: ${_products.length} items');
      debugPrint('Categories: $_categories');

    } catch (e) {
      debugPrint('Error loading products: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  double _parsePrice(dynamic price) {
    if (price == null) return 0.0;
    if (price is num) return price.toDouble();
    if (price is String) return double.tryParse(price) ?? 0.0;
    return 0.0;
  }

  double _parseRating(dynamic rating) {
    if (rating == null) return 0.0;
    if (rating is num) return rating.toDouble();
    if (rating is String) return double.tryParse(rating) ?? 0.0;
    return 0.0;
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0);
  }

  String _normalizeSkinType(String skinType) {
    final normalized = skinType.toLowerCase().trim();
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

  List<Map<String, dynamic>> get _filteredProducts {
    List<Map<String, dynamic>> filtered = _products;

    // Filter by category
    if (_selectedCategory == 'Untuk Saya') {
      // Filter berdasarkan skin type user
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userSkinType = authProvider.currentUser?.skinType;
      
      if (userSkinType != null && userSkinType != 'Belum dianalisis') {
        final normalizedUserSkinType = _normalizeSkinType(userSkinType);
        
        filtered = filtered.where((product) {
          final productSkinTypes = product['skin_type'] as List<dynamic>? ?? [];
          
          // Check if product skin types contain user's skin type
          for (var skinType in productSkinTypes) {
            if (skinType.toString().toLowerCase() == normalizedUserSkinType) {
              return true;
            }
          }
          
          // Fallback: check product name and description for keywords
          final name = product['name'].toString().toLowerCase();
          final description = product['description'].toString().toLowerCase();
          
          Map<String, List<String>> skinTypeKeywords = {
            'kering': ['kering', 'dry', 'moisturizer', 'hydrating', 'moisture'],
            'berminyak': ['berminyak', 'oily', 'acne', 'matte', 'oil-free', 'sebum'],
            'sensitif': ['sensitif', 'sensitive', 'gentle', 'calm', 'soothe', 'mild'],
            'kombinasi': ['kombinasi', 'combination', 'balance', 'dual', 'mixed']
          };
          
          List<String> keywords = skinTypeKeywords[userSkinType.toLowerCase()] ?? [];
          
          for (var keyword in keywords) {
            if (name.contains(keyword) || description.contains(keyword)) {
              return true;
            }
          }
          
          return false;
        }).toList();
      }
    } else if (_selectedCategory != 'Semua Produk') {
      filtered = filtered.where((product) => 
        product['category'] == _selectedCategory).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) =>
        product['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
        product['description'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
        product['brand'].toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    return filtered;
  }

  Widget _buildProductImage(Map<String, dynamic> product) {
    final imageUrl = product['image_url']?.toString() ?? '';
    
    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[100]!,
            Colors.grey[50]!,
          ],
        ),
      ),
      child: imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 140,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.grey[100],
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: const Color(0xFFEC407A),
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.grey[100],
                    ),
                    child: const Icon(
                      Icons.image_not_supported,
                      size: 40,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            )
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[100],
              ),
              child: const Icon(
                Icons.image_not_supported,
                size: 40,
                color: Colors.grey,
              ),
            ),
    );
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.addToCart(product);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${product['name']} ditambahkan ke keranjang',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gagal menambahkan ke keranjang: $e',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(
            Icons.star,
            size: 12,
            color: Colors.amber,
          );
        } else if (index < rating) {
          return const Icon(
            Icons.star_half,
            size: 12,
            color: Colors.amber,
          );
        } else {
          return const Icon(
            Icons.star_border,
            size: 12,
            color: Colors.grey,
          );
        }
      }),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    const Color(0xFFF48FB1),
                    const Color(0xFFEC407A),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      appBar: AppBar(
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            'Skin Analyzer',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
        ),
        backgroundColor: const Color(0xFFF8BBD0),
        centerTitle: true,
        automaticallyImplyLeading: false,
        elevation: 0,
        actions: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: Consumer<CartProvider>(
              builder: (context, cartProvider, child) {
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart, color: Colors.white),
                      onPressed: () => Navigator.pushNamed(context, '/cart'),
                    ),
                    if (cartProvider.items.isNotEmpty)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${cartProvider.items.length}',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Search Bar
            SlideTransition(
              position: _slideAnimation,
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari produk skincare...',
                    hintStyle: GoogleFonts.poppins(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFFEC407A),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : const Icon(Icons.tune, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: GoogleFonts.poppins(),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ),

            // Category Tabs
            SlideTransition(
              position: _slideAnimation,
              child: Container(
                height: 50,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = category == _selectedCategory;
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [
                                    const Color(0xFFF48FB1),
                                    const Color(0xFFEC407A),
                                  ],
                                )
                              : null,
                          color: isSelected ? null : Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          category,
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.white : Colors.grey[700],
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Products Grid
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFF48FB1),
                                  const Color(0xFFEC407A),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shopping_bag,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Memuat produk...',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.error_outline,
                                  size: 40,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Gagal memuat produk',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _loadProducts,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEC407A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Coba Lagi',
                                  style: GoogleFonts.poppins(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _filteredProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Tidak ada produk ditemukan'
                                        : _selectedCategory == 'Untuk Saya'
                                            ? 'Belum ada produk untuk jenis kulit Anda'
                                            : 'Tidak ada produk di kategori ini',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_selectedCategory == 'Untuk Saya')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Lakukan kuis untuk mendapatkan rekomendasi',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (_selectedCategory == 'Untuk Saya') {
                                        Navigator.pushNamed(context, '/quiz');
                                      } else {
                                        _loadProducts();
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEC407A),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      _selectedCategory == 'Untuk Saya'
                                          ? 'Mulai Kuis'
                                          : 'Refresh',
                                      style: GoogleFonts.poppins(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadProducts,
                              color: const Color(0xFFEC407A),
                              child: GridView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.7,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                                itemCount: _filteredProducts.length,
                                itemBuilder: (context, index) {
                                  final product = _filteredProducts[index];
                                  
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 15,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/productDetail',
                                          arguments: {'id': product['id']},
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: _buildProductImage(product),
                                            ),
                                            const SizedBox(height: 12),
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (product['brand'].isNotEmpty)
                                                    Text(
                                                      product['brand'],
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 10,
                                                        color: Colors.grey[600],
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  Text(
                                                    product['name'],
                                                    style: GoogleFonts.poppins(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13,
                                                      color: Colors.grey[800],
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  if (product['rating'] > 0)
                                                    Row(
                                                      children: [
                                                        _buildStarRating(product['rating']),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '(${product['rating'].toStringAsFixed(1)})',
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 10,
                                                            color: Colors.grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  const Spacer(),
                                                  Text(
                                                    'Rp ${_formatPrice(product['price'])}',
                                                    style: GoogleFonts.poppins(
                                                      color: const Color(0xFFEC407A),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: ElevatedButton(
                                                      onPressed: () => _addToCart(product),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: const Color(0xFFEC407A),
                                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        elevation: 0,
                                                      ),
                                                      child: Text(
                                                        'Tambah ke Keranjang',
                                                        style: GoogleFonts.poppins(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 'Beranda', 0),
            _buildNavItem(Icons.storefront, 'Shop', 1),
            _buildNavItem(Icons.tips_and_updates, 'Tips', 2),
            _buildNavItem(Icons.person, 'Profile', 3),
          ],
        ),
      ),
    );
  }
}
