import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../constants/colors.dart';

class AllProductsScreen extends StatefulWidget {
  const AllProductsScreen({super.key});

  @override
  State<AllProductsScreen> createState() => _AllProductsScreenState();
}

class _AllProductsScreenState extends State<AllProductsScreen> {
  List<Map<String, dynamic>> allProducts = [];
  List<Map<String, dynamic>> filteredProducts = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _errorMessage;
  TextEditingController _searchController = TextEditingController();
  Map<String, bool> _likedProducts = {};
  Map<String, int> _likesCount = {};

  @override
  void initState() {
    super.initState();
    _fetchAllProducts();
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _isSearching = false;
        filteredProducts = allProducts;
      });
    } else {
      _performSearch(_searchController.text);
    }
  }
  
  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        filteredProducts = allProducts;
      });
      return;
    }
    
    final lowercaseQuery = query.toLowerCase();
    
    final results = allProducts.where((product) {
      final name = product['name'].toString().toLowerCase();
      final description = product['description'].toString().toLowerCase();
      
      return name.contains(lowercaseQuery) || 
             description.contains(lowercaseQuery);
    }).toList();
    
    setState(() {
      _isSearching = true;
      filteredProducts = results;
    });
  }

  Future<void> _fetchAllProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final pb = authProvider.pb;
      
      // Fetch all products
      final resultList = await pb.collection('products').getList(
        page: 1,
        perPage: 100,
        sort: '-created',
      );
      
      print('Total products fetched: ${resultList.items.length}');
      
      // Convert to the format we need
      final fetchedProducts = resultList.items.map((record) {
        return {
          'id': record.id,
          'name': record.data['name'] ?? '',
          'price': record.data['price'] ?? 0,
          'image_url': record.data['image_url'] ?? '',
          'description': record.data['description'] ?? '',
          'rating': record.data['rating'] ?? 0,
          'skin_type': record.data['skin_type'] ?? [],
          'likes_count': 0, // Will be updated later
        };
      }).toList();
      
      setState(() {
        allProducts = fetchedProducts;
        filteredProducts = fetchedProducts;
        _isLoading = false;
      });
      
      // Fetch user liked products
      await _fetchUserLikedProducts();
    } catch (e) {
      print('Error fetching products: $e');
      setState(() {
        _errorMessage = 'Failed to load products: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _fetchUserLikedProducts() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final pb = authProvider.pb;
      
      if (!authProvider.isLoggedIn) {
        print('User not logged in, skipping liked products fetch');
        return;
      }
      
      final userId = pb.authStore.model.id;
      
      // Fetch user liked products
      final likedResult = await pb.collection('user_liked_products').getList(
        filter: 'user_id = "$userId"',
      );
      
      print('Fetched ${likedResult.items.length} liked products for current user');
      
      // Create a map of product_id -> liked status for current user
      Map<String, bool> likedMap = {};
      
      for (var item in likedResult.items) {
        final productId = item.data['product_id'];
        likedMap[productId] = true;
      }
      
      // Fetch ALL liked products to count likes per product
      final allLikesResult = await pb.collection('user_liked_products').getList(
        perPage: 1000, // Adjust based on your data size
      );
      
      print('Fetched ${allLikesResult.items.length} total liked products');
      
      // Count likes for each product
      Map<String, int> likesCount = {};
      
      for (var item in allLikesResult.items) {
        final productId = item.data['product_id'];
        likesCount[productId] = (likesCount[productId] ?? 0) + 1;
      }
      
      // Update products with likes count
      final updatedProducts = allProducts.map((product) {
        final productId = product['id'];
        return {
          ...product,
          'likes_count': likesCount[productId] ?? 0,
        };
      }).toList();
      
      setState(() {
        _likedProducts = likedMap;
        _likesCount = likesCount;
        allProducts = updatedProducts;
        filteredProducts = _isSearching ? filteredProducts : updatedProducts;
      });
    } catch (e) {
      print('Error fetching liked products: $e');
    }
  }
  
  Future<void> _toggleLikeProduct(String productId) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final pb = authProvider.pb;
      
      if (!authProvider.isLoggedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login to like products'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final userId = pb.authStore.model.id;
      final isCurrentlyLiked = _likedProducts[productId] ?? false;
      
      // Optimistic update for UI
      setState(() {
        if (isCurrentlyLiked) {
          _likedProducts.remove(productId);
          _likesCount[productId] = (_likesCount[productId] ?? 1) - 1;
        } else {
          _likedProducts[productId] = true;
          _likesCount[productId] = (_likesCount[productId] ?? 0) + 1;
        }
        
        // Update the likes_count in products list
        allProducts = allProducts.map((product) {
          if (product['id'] == productId) {
            return {
              ...product,
              'likes_count': _likesCount[productId] ?? 0,
            };
          }
          return product;
        }).toList();
        
        // Update filtered products too if needed
        if (_isSearching) {
          filteredProducts = filteredProducts.map((product) {
            if (product['id'] == productId) {
              return {
                ...product,
                'likes_count': _likesCount[productId] ?? 0,
              };
            }
            return product;
          }).toList();
        } else {
          filteredProducts = allProducts;
        }
      });
      
      if (isCurrentlyLiked) {
        // Unlike: delete the record
        final records = await pb.collection('user_liked_products').getList(
          filter: 'user_id = "$userId" && product_id = "$productId"',
        );
        
        if (records.items.isNotEmpty) {
          await pb.collection('user_liked_products').delete(records.items[0].id);
          print('Unliked product: $productId');
        }
      } else {
        // Like: create a new record
        await pb.collection('user_liked_products').create(body: {
          'user_id': userId,
          'product_id': productId,
          'liked_at': DateTime.now().toIso8601String(),
        });
        print('Liked product: $productId');
      }
      
      // Refresh liked products to get updated counts
      await _fetchUserLikedProducts();
    } catch (e) {
      print('Error toggling like: $e');
      // Revert optimistic update on error
      await _fetchUserLikedProducts();
    }
  }

  void _addToCart(Map<String, dynamic> product, BuildContext context) {
    Provider.of<CartProvider>(context, listen: false).addToCart(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['name']} added to cart!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
  
  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: 120,
        color: Colors.grey[200],
        child: const Icon(
          Icons.image_not_supported,
          size: 50,
          color: Colors.grey,
        ),
      );
    }

    return Image.network(
      imageUrl,
      height: 120,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: double.infinity,
          height: 120,
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
          height: 120,
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
        title: const Text('All Products'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAllProducts,
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.pushNamed(context, '/cart');
            },
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
                        onPressed: _fetchAllProducts,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : Container(
                  color: const Color(0xFFFDEDF4),
                  child: Column(
                    children: [
                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search any Product...',
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                            suffixIcon: const Icon(Icons.mic, color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.grey, width: 0.5),
                            ),
                          ),
                        ),
                      ),
                      
                      // Search results count
                      if (_isSearching)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Search results: ${filteredProducts.length} products',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      
                      // Products grid
                      Expanded(
                        child: filteredProducts.isEmpty
                            ? const Center(
                                child: Text(
                                  'No products available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: filteredProducts.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.75,
                                ),
                                itemBuilder: (context, index) {
                                  final product = filteredProducts[index];
                                  final productId = product['id'];
                                  final isLiked = _likedProducts[productId] ?? false;
                                  
                                  return Card(
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
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
                                              child: GestureDetector(
                                                onTap: () => _toggleLikeProduct(productId),
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.8),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    isLiked ? Icons.favorite : Icons.favorite_border,
                                                    color: AppColors.primary,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (product['likes_count'] > 0)
                                              Positioned(
                                                top: 8,
                                                left: 8,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.6),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.favorite,
                                                        color: Colors.white,
                                                        size: 12,
                                                      ),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        '${product['likes_count']}',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product['name'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                product['description'],
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                'Rp ${product['price']}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () => _addToCart(product, context),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.primary.withOpacity(0.9),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                              ),
                                              child: const Text(
                                                'Add to Cart',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}