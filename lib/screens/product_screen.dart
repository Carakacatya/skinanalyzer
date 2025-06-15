import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  List<Map<String, dynamic>> _products = [];
  List<String> _categories = ['All Products'];
  String _selectedCategory = 'All Products';
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      Set<String> categories = {'All Products'};

      for (var record in records) {
        final product = {
          'id': record.id,
          'name': record.data['name'] ?? 'Unknown Product',
          'price': _parsePrice(record.data['price']),
          'image_url': record.data['image_url'] ?? '',
          'description': record.data['description'] ?? '',
          'category': record.data['category'] ?? 'Uncategorized',
        };

        products.add(product);
        categories.add(product['category']);
        
        debugPrint('Product: ${product['name']} - Rp${product['price']}');
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

  String _formatPrice(double price) {
    return price.toStringAsFixed(0);
  }

  List<Map<String, dynamic>> get _filteredProducts {
    List<Map<String, dynamic>> filtered = _products;

    // Filter by category
    if (_selectedCategory != 'All Products') {
      filtered = filtered.where((product) => 
        product['category'] == _selectedCategory).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) =>
        product['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
        product['description'].toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    return filtered;
  }

  Widget _buildProductImage(Map<String, dynamic> product) {
    final imageUrl = product['image_url']?.toString() ?? '';
    
    if (imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          width: double.infinity,
          height: 120,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: double.infinity,
              height: 120,
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.broken_image,
                size: 40,
                color: Colors.grey,
              ),
            );
          },
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.image_not_supported,
          size: 40,
          color: Colors.grey,
        ),
      );
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      await cartProvider.addToCart(product);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${product['name']} ditambahkan ke keranjang',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menambahkan ke keranjang: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 248, 233, 235),
      appBar: AppBar(
        title: Text(
          'Skin Analyzer',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search any Product...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : const Icon(Icons.mic, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Category Tabs
          if (_categories.length > 1)
            Container(
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey[300]!,
                        ),
                      ),
                      child: Text(
                        category,
                        style: GoogleFonts.poppins(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),

          // Products Grid
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text('Loading products...'),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading products',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
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
                                backgroundColor: AppColors.primary,
                              ),
                              child: Text(
                                'Retry',
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
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No products found for "$_searchQuery"'
                                      : 'No products in $_selectedCategory category',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _loadProducts,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                  ),
                                  child: Text(
                                    'Refresh',
                                    style: GoogleFonts.poppins(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadProducts,
                            color: AppColors.primary,
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: _filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = _filteredProducts[index];
                                
                                return Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 4,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/productDetail',
                                        arguments: product,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: _buildProductImage(product),
                                          ),
                                          const SizedBox(height: 8),
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  product['name'],
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Rp ${_formatPrice(product['price'])}',
                                                  style: GoogleFonts.poppins(
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const Spacer(),
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: ElevatedButton(
                                                    onPressed: () => _addToCart(product),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppColors.primary,
                                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      'Add to Cart',
                                                      style: GoogleFonts.poppins(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
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
    );
  }
}
