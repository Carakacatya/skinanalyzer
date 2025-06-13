import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../constants/colors.dart';
import 'all_products_screen.dart';

class StoreSingleProduct extends StatefulWidget {
  const StoreSingleProduct({super.key});

  @override
  _StoreSingleProductState createState() => _StoreSingleProductState();
}

class _StoreSingleProductState extends State<StoreSingleProduct> {
  int _selectedCategoryIndex = 0;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _recommendedProducts = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _errorMessage;
  String? _skinType;
  String? _userId;
  TextEditingController _searchController = TextEditingController();
  
  final List<String> _categories = ['New Products', 'For Your Skin', 'Most Liked', 'All Products'];
  Map<String, bool> _likedProducts = {};
  Map<String, int> _likesCount = {};
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
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
        _filterProductsByCategory();
      });
    } else {
      _performSearch(_searchController.text);
    }
  }
  
  Future<void> _loadUserData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Check if user is logged in
    if (authProvider.isLoggedIn) {
      _userId = authProvider.pb.authStore.model.id;
      
      try {
        // Fetch user data to get skin type
        final userData = await authProvider.pb.collection('users').getOne(_userId!);
        setState(() {
          _skinType = userData.data['skin_type'];
        });
        print('Loaded skin type from user profile: $_skinType');
      } catch (e) {
        print('Error fetching user data: $e');
        // Fallback to SharedPreferences if user data fetch fails
        _loadSkinTypeFromPrefs();
      }
    } else {
      // If not logged in, try to get skin type from SharedPreferences
      _loadSkinTypeFromPrefs();
    }
    
    // Fetch products regardless of login status
    await _fetchProducts();
    await _fetchUserLikedProducts();
    _prepareRecommendedProducts();
  }
  
  Future<void> _loadSkinTypeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final type = prefs.getString('skinType');
    
    print('Loaded skin type from SharedPreferences: $type');
    
    setState(() {
      _skinType = type;
    });
  }
  
  void _prepareRecommendedProducts() {
    // Create a list of recommended products (different from the current category)
    // This ensures we always have recommendations regardless of the selected tab
    if (_products.length > 5) {
      // Get a mix of products for recommendations
      final recommended = List<Map<String, dynamic>>.from(_products);
      recommended.shuffle(); // Randomize for variety
      setState(() {
        _recommendedProducts = recommended.take(5).toList();
      });
    } else {
      setState(() {
        _recommendedProducts = _products;
      });
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
      
      // Fetch all products
      final resultList = await pb.collection('products').getList(
        page: 1,
        perPage: 100,
        sort: '-created',
      );
      
      print('Total products fetched: ${resultList.items.length}');
      
      // Convert to the format we need
      final fetchedProducts = resultList.items.map((record) {
        final createdStr = record.created;
        final created = DateTime.parse(createdStr);
        final now = DateTime.now();
        final daysSinceCreation = now.difference(created).inDays;
        
        // Determine if this is a new product (created in the last 30 days)
        final isNewProduct = daysSinceCreation < 30;
        
        return {
          'id': record.id,
          'name': record.data['name'] ?? '',
          'price': record.data['price'] ?? 0,
          'image_url': record.data['image_url'] ?? '',
          'description': record.data['description'] ?? '',
          'rating': record.data['rating'] ?? 0,
          'skin_type': record.data['skin_type'] ?? [],
          'likes_count': 0, // Will be updated later
          'is_new': isNewProduct,
        };
      }).toList();
      
      setState(() {
        _products = fetchedProducts;
        _filterProductsByCategory();
        _isLoading = false;
      });
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
      
      // Fetch ALL liked products to count likes per product regardless of login status
      final allLikesResult = await pb.collection('user_liked_products').getList(
        perPage: 1000, // Adjust based on your data size
      );
      
      print('Fetched ${allLikesResult.items.length} total liked products');
      
      // Count likes for each product
      Map<String, int> likesCount = {};
      Map<String, bool> likedMap = {};
      
      for (var item in allLikesResult.items) {
        final productId = item.data['product_id'];
        likesCount[productId] = (likesCount[productId] ?? 0) + 1;
      }
      
      // If user is logged in, fetch their specific likes
      if (authProvider.isLoggedIn) {
        final userId = pb.authStore.model.id;
        
        // Fetch user liked products
        final likedResult = await pb.collection('user_liked_products').getList(
          filter: 'user_id = "$userId"',
        );
        
        print('Fetched ${likedResult.items.length} liked products for current user');
        
        // Create a map of product_id -> liked status for current user
        for (var item in likedResult.items) {
          final productId = item.data['product_id'];
          likedMap[productId] = true;
        }
      }
      
      // Update products with likes count
      final updatedProducts = _products.map((product) {
        final productId = product['id'];
        return {
          ...product,
          'likes_count': likesCount[productId] ?? 0,
          'is_liked_by_user': likedMap[productId] ?? false,
        };
      }).toList();
      
      setState(() {
        _likedProducts = likedMap;
        _likesCount = likesCount;
        _products = updatedProducts;
        _filterProductsByCategory();
        _prepareRecommendedProducts();
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
        _products = _products.map((product) {
          if (product['id'] == productId) {
            return {
              ...product,
              'likes_count': _likesCount[productId] ?? 0,
              'is_liked_by_user': !isCurrentlyLiked,
            };
          }
          return product;
        }).toList();
        
        // Re-filter products if we're in the "Most Liked" category
        if (_selectedCategoryIndex == 2) { // Index 2 for "Most Liked"
          _filterProductsByCategory();
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
  
  void _filterProductsByCategory() {
    if (_isSearching) return; // Don't filter if searching
    
    final category = _categories[_selectedCategoryIndex];
    List<Map<String, dynamic>> filtered = [];
    
    switch (category) {
      case 'New Products':
        // Filter products that are marked as new
        filtered = _products.where((product) => product['is_new'] == true).toList();
        // Limit to 4 products
        if (filtered.length > 4) {
          filtered = filtered.sublist(0, 4);
        }
        break;
        
      case 'For Your Skin':
        if (_skinType != null) {
          // Normalize skin type
          final normalizedSkinType = _normalizeSkinType(_skinType!);
          
          print('Filtering for skin type: $normalizedSkinType');
          
          // Filter products for user's skin type
          filtered = _products.where((product) {
            final skinTypes = product['skin_type'];
            
            if (skinTypes is List) {
              return skinTypes.any((type) => 
                type.toString().toLowerCase().contains(normalizedSkinType.toLowerCase()));
            } else if (skinTypes is String) {
              return skinTypes.toLowerCase().contains(normalizedSkinType.toLowerCase());
            }
            return false;
          }).toList();
          
          print('For Your Skin filtered products: ${filtered.length} for skin type: $normalizedSkinType');
        } else {
          filtered = [];
          print('No skin type found, For Your Skin tab is empty');
        }
        break;
        
      case 'Most Liked':
        // Show products liked by the current user
        filtered = _products.where((product) => product['is_liked_by_user'] == true).toList();
        print('Most Liked filtered products (user likes): ${filtered.length}');
        break;
        
      case 'All Products':
      default:
        filtered = _products;
        break;
    }
    
    setState(() {
      _filteredProducts = filtered;
    });
  }
  
  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _filterProductsByCategory();
      });
      return;
    }
    
    final lowercaseQuery = query.toLowerCase();
    
    final results = _products.where((product) {
      final name = product['name'].toString().toLowerCase();
      final description = product['description'].toString().toLowerCase();
      
      return name.contains(lowercaseQuery) || 
             description.contains(lowercaseQuery);
    }).toList();
    
    setState(() {
      _isSearching = true;
      _searchResults = results;
    });
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
        height: 100,
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
    // Determine which products to display based on search state
    final displayProducts = _isSearching ? _searchResults : _filteredProducts;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skin Analyzer'),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.pushNamed(context, '/cart');
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFFDEDF4),
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
                        onPressed: _fetchProducts,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 12,
                    bottom: MediaQuery.of(context).padding.bottom + 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Bar
                      TextField(
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
                      const SizedBox(height: 12),

                      // Category Tabs (only show if not searching)
                      if (!_isSearching)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.pink[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: List.generate(_categories.length, (index) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategoryIndex = index;
                                    _filterProductsByCategory();
                                  });
                                },
                                child: Column(
                                  children: [
                                    Text(
                                      _categories[index],
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: _selectedCategoryIndex == index
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: _selectedCategoryIndex == index
                                            ? Colors.pink[300]
                                            : Colors.grey,
                                      ),
                                    ),
                                    if (_selectedCategoryIndex == index)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        height: 2,
                                        width: 40,
                                        color: Colors.pink[300],
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Search results title
                      if (_isSearching)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Search results: ${_searchResults.length} products',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      // Products grid based on category or search
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Display products based on selected category or search
                              displayProducts.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const SizedBox(height: 40),
                                          const Icon(
                                            Icons.inventory_2_outlined,
                                            size: 64,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            _isSearching
                                                ? 'No products match your search'
                                                : _selectedCategoryIndex == 1 && _skinType == null
                                                    ? 'Please take the quiz to determine your skin type'
                                                    : _selectedCategoryIndex == 2
                                                        ? 'You haven\'t liked any products yet'
                                                        : 'No products in ${_categories[_selectedCategoryIndex]} category',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          if (_selectedCategoryIndex == 1 && _skinType == null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 16),
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  Navigator.pushNamed(context, '/quiz');
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.primary,
                                                ),
                                                child: const Text('Start Quiz'),
                                              ),
                                            ),
                                          const SizedBox(height: 40),
                                        ],
                                      ),
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        GridView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          padding: const EdgeInsets.only(bottom: 16),
                                          itemCount: displayProducts.length,
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            mainAxisSpacing: 12,
                                            crossAxisSpacing: 12,
                                            childAspectRatio: 0.65,
                                          ),
                                          itemBuilder: (context, index) {
                                            final product = displayProducts[index];
                                            final productId = product['id'];
                                            final isLiked = _likedProducts[productId] ?? false;
                                            
                                            return Card(
                                              elevation: 4,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                              child: Column(
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
                                                      if (product['is_new'] == true)
                                                        Positioned(
                                                          bottom: 0,
                                                          right: 0,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: Colors.green,
                                                              borderRadius: const BorderRadius.only(
                                                                topLeft: Radius.circular(12),
                                                                bottomRight: Radius.circular(16),
                                                              ),
                                                            ),
                                                            child: const Text(
                                                              'NEW',
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
                                                  Expanded(
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(8),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            product['name'],
                                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            product['description'],
                                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          Text(
                                                            'Rp ${product['price']}',
                                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                                          ),
                                                          const Spacer(),
                                                          SizedBox(
                                                            width: double.infinity,
                                                            child: ElevatedButton(
                                                              onPressed: () => _addToCart(product, context),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: AppColors.primary,
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius: BorderRadius.circular(12),
                                                                ),
                                                              ),
                                                              child: const Text('Add to Cart', style: TextStyle(fontSize: 12)),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                              
                              // Recommendations section (show for all tabs except All Products and when not searching)
                              if (!_isSearching && _selectedCategoryIndex != 3 && _recommendedProducts.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                const Text(
                                  'Recommended For You',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                
                                ListView.builder(
                                  itemCount: _recommendedProducts.length > 5 ? 5 : _recommendedProducts.length,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    final product = _recommendedProducts[index];
                                    final productId = product['id'];
                                    final isLiked = _likedProducts[productId] ?? false;
                                    
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 5,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: SizedBox(
                                              width: 60,
                                              height: 60,
                                              child: _buildProductImage(product['image_url']),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  product['name'],
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                const Text("50 ml", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                                Text(
                                                  'Rp ${product['price']}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                                  color: AppColors.primary,
                                                  size: 20,
                                                ),
                                                onPressed: () => _toggleLikeProduct(productId),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.primary, size: 20),
                                                onPressed: () => _addToCart(product, context),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
