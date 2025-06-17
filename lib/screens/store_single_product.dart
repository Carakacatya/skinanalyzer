import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_fonts/google_fonts.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../constants/colors.dart';

class StoreSingleProduct extends StatefulWidget {
  final int initialCategoryIndex;
  
  const StoreSingleProduct({super.key, this.initialCategoryIndex = 0});

  @override
  _StoreSingleProductState createState() => _StoreSingleProductState();
}

class _StoreSingleProductState extends State<StoreSingleProduct>
    with TickerProviderStateMixin {
  int _selectedCategoryIndex = 0;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isListening = false;
  String? _errorMessage;
  String? _skinType;
  String? _userId;
  TextEditingController _searchController = TextEditingController();
  late stt.SpeechToText _speech;
  final ScrollController _tabScrollController = ScrollController();
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  
  final List<String> _categories = ['New Products', 'For Your Skin', 'Most Liked', 'All Products'];
  Map<String, bool> _likedProducts = {};
  Map<String, int> _likesCount = {};
  
  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _selectedCategoryIndex = widget.initialCategoryIndex;
    
    // Initialize Animation Controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _loadUserData();
    _searchController.addListener(_onSearchChanged);
    
    // Start entrance animations
    _startEntranceAnimations();
  }
  
  void _startEntranceAnimations() {
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _scaleController.forward();
    });
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabScrollController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
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
    final prefs = await SharedPreferences.getInstance();
    
    final skinTypeFromPrefs = prefs.getString('skinType');
    debugPrint('Loaded skin type from SharedPreferences: $skinTypeFromPrefs');
    
    setState(() {
      _skinType = skinTypeFromPrefs;
    });
    
    if (authProvider.isLoggedIn) {
      _userId = authProvider.pb.authStore.model?.id;
      
      try {
        final userData = await authProvider.pb.collection('users').getOne(_userId!);
        final skinTypeFromProfile = userData.data['skin_type'];
        
        String? extractedSkinType;
        if (skinTypeFromProfile != null) {
          if (skinTypeFromProfile is List && skinTypeFromProfile.isNotEmpty) {
            extractedSkinType = skinTypeFromProfile[0].toString();
          } else if (skinTypeFromProfile is String && skinTypeFromProfile.isNotEmpty) {
            extractedSkinType = skinTypeFromProfile;
          } else if (skinTypeFromProfile.toString().isNotEmpty) {
            extractedSkinType = skinTypeFromProfile.toString();
          }
        }
        
        if (extractedSkinType != null && extractedSkinType.isNotEmpty) {
          await prefs.setString('skinType', extractedSkinType);
          setState(() {
            _skinType = extractedSkinType;
          });
        } else if (skinTypeFromPrefs != null && skinTypeFromPrefs.isNotEmpty) {
          await _saveSkinTypeToProfile(skinTypeFromPrefs);
        }
      } catch (e) {
        debugPrint('Error fetching user data: $e');
      }
    }
    
    await _fetchProducts();
    await _fetchUserLikedProducts();
    _filterProductsByCategory();
  }
  
  Future<void> _saveSkinTypeToProfile(String skinType) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isLoggedIn || skinType.trim().isEmpty) {
      return;
    }
    
    try {
      final userId = authProvider.pb.authStore.model?.id;
      if (userId == null) return;
      
      final userData = await authProvider.pb.collection('users').getOne(userId);
      final currentSkinType = userData.data['skin_type'];
      
      Map<String, dynamic> updateData;
      if (currentSkinType is List) {
        updateData = {"skin_type": [skinType]};
      } else {
        updateData = {"skin_type": skinType};
      }
      
      await authProvider.pb.collection('users').update(userId, body: updateData);
    } catch (e) {
      debugPrint('Error saving skin type to profile: $e');
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
      
      final resultList = await pb.collection('products').getList(
        page: 1,
        perPage: 100,
        sort: '-created',
      );
      
      final fetchedProducts = resultList.items.map((record) {
        final createdStr = record.created;
        final created = DateTime.parse(createdStr);
        final now = DateTime.now();
        final daysSinceCreation = now.difference(created).inDays;
        final isNewProduct = daysSinceCreation < 30;
        
        var skinType = record.data['skin_type'];
        
        return {
          'id': record.id,
          'name': record.data['name'] ?? '',
          'price': record.data['price'] ?? 0,
          'image_url': record.data['image_url'] ?? '',
          'description': record.data['description'] ?? '',
          'rating': record.data['rating'] ?? 0,
          'skin_type': skinType ?? [],
          'brand': record.data['brand'] ?? '',
          'likes_count': 0,
          'is_new': isNewProduct,
          'is_liked_by_user': false,
        };
      }).toList();
      
      setState(() {
        _products = fetchedProducts;
        _isLoading = false;
      });
    } catch (e) {
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
      
      Map<String, int> likesCount = {};
      Map<String, bool> likedMap = {};
      
      final allLikesResult = await pb.collection('user_liked_products').getFullList();
      
      for (var item in allLikesResult) {
        try {
          final productIdRaw = item.data['product_id'];
          String productId;
          
          if (productIdRaw is List && productIdRaw.isNotEmpty) {
            productId = productIdRaw[0].toString();
          } else if (productIdRaw is String) {
            productId = productIdRaw;
          } else {
            productId = productIdRaw.toString();
          }
          
          likesCount[productId] = (likesCount[productId] ?? 0) + 1;
        } catch (e) {
          debugPrint('Error processing product_id: ${item.data['product_id']} - $e');
        }
      }
      
      if (authProvider.isLoggedIn) {
        final userModel = authProvider.pb.authStore.model;
        final userId = userModel?.id;
        final userData = userModel?.data;
        
        List<String> possibleUserIds = [];
        
        if (userId != null && userId.isNotEmpty) {
          possibleUserIds.add(userId);
        }
        
        if (userData != null) {
          userData.forEach((key, value) {
            if (value != null && value.toString().isNotEmpty && value.toString() != 'null') {
              possibleUserIds.add(value.toString());
            }
          });
        }
        
        possibleUserIds = possibleUserIds.toSet().toList();
        
        for (var item in allLikesResult) {
          final itemUserId = item.data['user_id']?.toString() ?? '';
          
          for (String possibleId in possibleUserIds) {
            if (itemUserId == possibleId || itemUserId.toLowerCase() == possibleId.toLowerCase()) {
              try {
                final productIdRaw = item.data['product_id'];
                String productId;
                
                if (productIdRaw is List && productIdRaw.isNotEmpty) {
                  productId = productIdRaw[0].toString();
                } else if (productIdRaw is String) {
                  productId = productIdRaw;
                } else {
                  productId = productIdRaw.toString();
                }
                
                likedMap[productId] = true;
                break;
              } catch (e) {
                debugPrint('Error processing matched product: $e');
              }
            }
          }
        }
      }
      
      final updatedProducts = _products.map((product) {
        final productId = product['id'];
        final isLikedByUser = likedMap[productId] ?? false;
        final totalLikes = likesCount[productId] ?? 0;
        
        return {
          ...product,
          'likes_count': totalLikes,
          'is_liked_by_user': isLikedByUser,
        };
      }).toList();
      
      setState(() {
        _likedProducts = likedMap;
        _likesCount = likesCount;
        _products = updatedProducts;
      });
    } catch (e) {
      debugPrint('Error fetching liked products: $e');
    }
  }
  
  Future<void> _toggleLikeProduct(String productId) async {
    _pulseController.forward().then((_) {
      _pulseController.reverse();
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final pb = authProvider.pb;
      
      if (!authProvider.isLoggedIn) {
        _showSnackBar('Please login to like products', Colors.red);
        return;
      }
      
      final isCurrentlyLiked = _likedProducts[productId] ?? false;
      final userModel = authProvider.pb.authStore.model;
      final userIdentifier = userModel?.id;
      
      if (userIdentifier == null) return;
      
      setState(() {
        if (isCurrentlyLiked) {
          _likedProducts.remove(productId);
          _likesCount[productId] = (_likesCount[productId] ?? 1) - 1;
        } else {
          _likedProducts[productId] = true;
          _likesCount[productId] = (_likesCount[productId] ?? 0) + 1;
        }
        
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
        
        _filterProductsByCategory();
      });
      
      if (isCurrentlyLiked) {
        try {
          final allUserRecords = await pb.collection('user_liked_products').getList(
            filter: 'user_id = "$userIdentifier"',
          );
          
          for (var record in allUserRecords.items) {
            final recordProductIdRaw = record.data['product_id'];
            String recordProductId;
            
            if (recordProductIdRaw is List && recordProductIdRaw.isNotEmpty) {
              recordProductId = recordProductIdRaw[0].toString();
            } else if (recordProductIdRaw is String) {
              recordProductId = recordProductIdRaw;
            } else {
              recordProductId = recordProductIdRaw.toString();
            }
            
            if (recordProductId == productId) {
              await pb.collection('user_liked_products').delete(record.id);
              break;
            }
          }
        } catch (e) {
          setState(() {
            _likedProducts[productId] = true;
            _likesCount[productId] = (_likesCount[productId] ?? 0) + 1;
          });
        }
      } else {
        try {
          await pb.collection('user_liked_products').create(
            body: {
              'user_id': userIdentifier,
              'product_id': [productId],
              'liked_at': DateTime.now().toIso8601String(),
            },
          );
        } catch (e) {
          setState(() {
            _likedProducts.remove(productId);
            _likesCount[productId] = (_likesCount[productId] ?? 1) - 1;
          });
        }
      }
      
      await _fetchUserLikedProducts();
      _filterProductsByCategory();
    } catch (e) {
      await _fetchUserLikedProducts();
      _filterProductsByCategory();
    }
  }
  
  void _filterProductsByCategory() {
    if (_isSearching) return;
    
    final category = _categories[_selectedCategoryIndex];
    List<Map<String, dynamic>> filtered = [];
    
    switch (category) {
      case 'New Products':
        // Limit to 4 newest products only
        filtered = _products
            .where((product) => product['is_new'] == true)
            .take(4)
            .toList();
        break;
        
      case 'For Your Skin':
        if (_skinType != null && _skinType!.isNotEmpty) {
          final skinTypeKeywords = _getSkinTypeKeywords(_skinType!);
          
          filtered = _products.where((product) {
            final productSkinTypes = product['skin_type'];
            bool matchFound = false;
            
            if (productSkinTypes is List) {
              for (var productType in productSkinTypes) {
                final normalizedProductType = productType.toString().toLowerCase().trim();
                for (var keyword in skinTypeKeywords) {
                  if (normalizedProductType == keyword.toLowerCase() || 
                      normalizedProductType.contains(keyword.toLowerCase())) {
                    matchFound = true;
                    break;
                  }
                }
                if (matchFound) break;
              }
            } else if (productSkinTypes is String && productSkinTypes.isNotEmpty) {
              final normalizedProductType = productSkinTypes.toLowerCase().trim();
              for (var keyword in skinTypeKeywords) {
                if (normalizedProductType == keyword.toLowerCase() || 
                    normalizedProductType.contains(keyword.toLowerCase())) {
                  matchFound = true;
                  break;
                }
              }
            }
            
            if (!matchFound) {
              final name = product['name']?.toString().toLowerCase() ?? '';
              final description = product['description']?.toString().toLowerCase() ?? '';
              final contentKeywords = _getContentKeywords(_skinType!);
              
              for (var keyword in contentKeywords) {
                if (name.contains(keyword.toLowerCase()) || 
                    description.contains(keyword.toLowerCase())) {
                  matchFound = true;
                  break;
                }
              }
            }
            
            return matchFound;
          }).toList();
        } else {
          filtered = [];
        }
        break;
        
      case 'Most Liked':
        filtered = _products.where((product) {
          final productId = product['id'];
          return _likedProducts[productId] == true;
        }).toList();
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
  
  List<String> _getSkinTypeKeywords(String skinType) {
    final normalized = skinType.toLowerCase().trim();
    
    switch (normalized) {
      case 'kering':
        return ['kering', 'dry'];
      case 'berminyak':
        return ['berminyak', 'oily'];
      case 'sensitif':
        return ['sensitif', 'sensitive'];
      case 'kombinasi':
        return ['kombinasi', 'combination'];
      case 'dry':
        return ['dry', 'kering'];
      case 'oily':
        return ['oily', 'berminyak'];
      case 'sensitive':
        return ['sensitive', 'sensitif'];
      case 'combination':
        return ['combination', 'kombinasi'];
      default:
        return [normalized];
    }
  }
  
  List<String> _getContentKeywords(String skinType) {
    final normalized = skinType.toLowerCase().trim();
    
    Map<String, List<String>> contentKeywords = {
      'kering': ['moisturizer', 'hydrating', 'soy', 'hyaluronic', 'ceramide', 'dry', 'pelembab', 'lembab'],
      'berminyak': ['acne', 'matte', 'oil-free', 'salicylic', 'niacinamide', 'oily', 'jerawat', 'berminyak'],
      'sensitif': ['gentle', 'calm', 'soothe', 'fragrance-free', 'hypoallergenic', 'sensitive', 'lembut', 'sensitif'],
      'kombinasi': ['balance', 'dual', 'combination', 'lightweight', 'seimbang', 'kombinasi'],
      'dry': ['moisturizer', 'hydrating', 'soy', 'hyaluronic', 'ceramide', 'pelembab', 'lembab'],
      'oily': ['acne', 'matte', 'oil-free', 'salicylic', 'niacinamide', 'jerawat', 'berminyak'],
      'sensitive': ['gentle', 'calm', 'soothe', 'fragrance-free', 'hypoallergenic', 'lembut', 'sensitif'],
      'combination': ['balance', 'dual', 'lightweight', 'seimbang', 'kombinasi'],
    };
    
    return contentKeywords[normalized] ?? [];
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

  void _addToCart(Map<String, dynamic> product, BuildContext context) {
    try {
      _scaleController.reset();
      _scaleController.forward();
      
      final cartProduct = {
        'id': product['id'],
        'name': product['name'] ?? 'Unknown Product',
        'price': product['price'] ?? 0,
        'image_url': product['image_url'] ?? '',
        'description': product['description'] ?? '',
        'brand': product['brand'] ?? '',
        'quantity': 1,
      };
      
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.addToCart(cartProduct);
      
      _showSnackBar('${cartProduct['name']} added to cart!', const Color(0xFFEC407A));
      
    } catch (e) {
      debugPrint('Error adding to cart: $e');
      _showSnackBar('Failed to add product to cart', Colors.red);
    }
  }
  
  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (error) {
          setState(() {
            _isListening = false;
          });
        },
      );
      
      if (available) {
        setState(() {
          _isListening = true;
        });
        
        _speech.listen(
          onResult: (result) {
            setState(() {
              _searchController.text = result.recognizedWords;
              if (result.finalResult) {
                _isListening = false;
                _performSearch(result.recognizedWords);
              }
            });
          },
        );
      } else {
        _showSnackBar('Speech recognition not available on this device', Colors.red);
      }
    } else {
      setState(() {
        _isListening = false;
        _speech.stop();
      });
    }
  }
  
Widget _buildProductImage(String? imageUrl) {
  if (imageUrl == null || imageUrl.isEmpty) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[100]!,
            Colors.grey[50]!,
          ],
        ),
      ),
      child: const Icon(
        Icons.image_not_supported,
        size: 24,
        color: Colors.grey,
      ),
    );
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.network(
      imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: CircularProgressIndicator(
              color: const Color(0xFFEC407A),
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey[100]!,
                Colors.grey[50]!,
              ],
            ),
          ),
          child: const Icon(
            Icons.broken_image,
            size: 24,
            color: Colors.grey,
          ),
        );
      },
    ),
  );
}

  Widget _buildLoadingState() {
    return Center(
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
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0);
  }

  // Get category title with proper styling
  String _getCategoryTitle() {
    switch (_selectedCategoryIndex) {
      case 0:
        return 'Latest Products';
      case 1:
        return 'For Your Skin Type';
      case 2:
        return 'Most Liked Products';
      case 3:
        return 'All Products';
      default:
        return 'Products';
    }
  }

  // Get category icon
  IconData _getCategoryIcon() {
    switch (_selectedCategoryIndex) {
      case 0:
        return Icons.star;
      case 1:
        return Icons.face;
      case 2:
        return Icons.favorite;
      case 3:
        return Icons.grid_view;
      default:
        return Icons.shopping_bag;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayProducts = _isSearching ? _searchResults : _filteredProducts;
    
    return Scaffold(
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
        actions: [
          Consumer<CartProvider>(
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
        ],
      ),
      backgroundColor: const Color(0xFFFCE4EC),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchProducts,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEC407A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Try Again',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // PERFECT: Search bar with optimal spacing
                      Container(
                        margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: GoogleFonts.poppins(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search any Product..',
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFFEC407A), size: 20),
                            suffixIcon: GestureDetector(
                              onTap: _listen,
                              child: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: _isListening ? Colors.red : Colors.grey,
                                size: 20,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            isDense: true,
                          ),
                        ),
                      ),

                      // PERFECT: Category tabs with optimal positioning
                      if (!_isSearching)
                        Container(
                          height: 38, // Reduced height for more compact look
                          margin: const EdgeInsets.fromLTRB(16, 6, 16, 10), // Tighter margins
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Perfect center distribution
                            children: _categories.asMap().entries.map((entry) {
                              final index = entry.key;
                              final category = entry.value;
                              final isSelected = index == _selectedCategoryIndex;
                              
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedCategoryIndex = index;
                                      _filterProductsByCategory();
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 3), // Compact spacing
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: isSelected 
                                          ? LinearGradient(
                                              colors: [const Color(0xFFEC407A), const Color(0xFFF48FB1)],
                                            )
                                          : null,
                                      color: isSelected ? null : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected ? Colors.transparent : Colors.grey.shade300,
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isSelected 
                                              ? const Color(0xFFEC407A).withOpacity(0.25)
                                              : Colors.black.withOpacity(0.04),
                                          blurRadius: isSelected ? 6 : 3,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center( // Perfect centering
                                      child: Text(
                                        category,
                                        style: GoogleFonts.poppins(
                                          color: isSelected ? Colors.white : Colors.grey[700],
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                          fontSize: 10, // Slightly smaller for compact look
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      // PERFECT: Products grid with no overflow issues
                      Expanded(
                        child: displayProducts.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _isSearching
                                          ? 'No products match your search'
                                          : _selectedCategoryIndex == 1 && _skinType == null
                                              ? 'Please take the quiz to determine your skin type'
                                              : _selectedCategoryIndex == 1
                                                  ? 'No products found for your skin type ($_skinType)'
                                                  : _selectedCategoryIndex == 2
                                                      ? 'You haven\'t liked any products yet'
                                                      : 'No products available',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () async {
                                  await _fetchProducts();
                                  await _fetchUserLikedProducts();
                                  _filterProductsByCategory();
                                },
                                color: const Color(0xFFEC407A),
                                child: _buildPerfectGrid(displayProducts),
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }

  // PERFECT: Grid layout with no overflow issues
  Widget _buildPerfectGrid(List<Map<String, dynamic>> products) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 120), // PERFECT: Bottom padding for navigation
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PERFECT: Header section
          if (!_isSearching)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFEC407A), const Color(0xFFF48FB1)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEC407A).withOpacity(0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getCategoryIcon(), color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _selectedCategoryIndex == 0 ? 'NEW' : 
                          _selectedCategoryIndex == 1 ? 'SKIN' :
                          _selectedCategoryIndex == 2 ? 'LIKED' : 'ALL',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getCategoryTitle(),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // PERFECT: 2x2 grid with optimal spacing and no overflow
          GridView.builder(
            shrinkWrap: true, // PERFECT: Prevents overflow
            physics: const NeverScrollableScrollPhysics(), // PERFECT: Prevents scroll conflict
            itemCount: products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14, // PERFECT: Optimal spacing
              crossAxisSpacing: 14, // PERFECT: Optimal spacing
              childAspectRatio: 0.68, // PERFECT: More space for content and button
            ),
            itemBuilder: (context, index) {
              final product = products[index];
              return _buildPerfectProductCard(product, index);
            },
          ),
        ],
      ),
    );
  }

  // PERFECT: Product card with no overflow and perfect button placement
  Widget _buildPerfectProductCard(Map<String, dynamic> product, int index) {
    final productId = product['id'];
    final isLiked = _likedProducts[productId] ?? false;
    
    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 100)),
      curve: Curves.easeOutBack,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEC407A).withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
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
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(10), // PERFECT: Consistent padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PERFECT: Image section (45% of card height)
                Expanded(
                  flex: 45,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFEC407A).withOpacity(0.05),
                          const Color(0xFFF48FB1).withOpacity(0.05),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildProductImage(product['image_url']),
                        ),
                        // PERFECT: Like button
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () => _toggleLikeProduct(productId),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: const Color(0xFFEC407A),
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                        // PERFECT: Badge
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: product['is_new'] == true 
                                    ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)]
                                    : _selectedCategoryIndex == 1
                                        ? [const Color(0xFF2196F3), const Color(0xFF42A5F5)]
                                        : _selectedCategoryIndex == 2
                                            ? [const Color(0xFFE91E63), const Color(0xFFF06292)]
                                            : [const Color(0xFF9C27B0), const Color(0xFFBA68C8)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: (product['is_new'] == true 
                                      ? const Color(0xFF4CAF50)
                                      : _selectedCategoryIndex == 1
                                          ? const Color(0xFF2196F3)
                                          : _selectedCategoryIndex == 2
                                              ? const Color(0xFFE91E63)
                                              : const Color(0xFF9C27B0)).withOpacity(0.25),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              product['is_new'] == true 
                                  ? 'NEW'
                                  : _selectedCategoryIndex == 1
                                      ? 'SKIN'
                                      : _selectedCategoryIndex == 2
                                          ? 'LIKED'
                                          : 'PROD',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 8), // PERFECT: Spacing between sections
                
                // PERFECT: Product info section (55% of card height)
                Expanded(
                  flex: 55,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // PERFECT: Product name (2 lines max)
                      Text(
                        product['name'],
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: const Color(0xFF333333),
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 1), // REDUCED: Much tighter spacing

                      // PERFECT: Brand
                      Text(
                        product['brand'],
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 2), // REDUCED: Tighter spacing before description
                      
                      // PERFECT: Description (2 lines max)
                      Text(
                        product['description'] ?? 'Premium skincare product',
                        style: GoogleFonts.poppins(
                          fontSize: 8,
                          color: Colors.grey[500],
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const Spacer(), // PERFECT: Push price and button to bottom
                      
                      // PERFECT: Price
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFEC407A).withOpacity(0.1),
                              const Color(0xFFF48FB1).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFEC407A).withOpacity(0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          'Rp ${_formatPrice(product['price'].toDouble())}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color: const Color(0xFFEC407A),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 6), // PERFECT: Spacing before button
                      
                      // PERFECT: Add to cart button - NO OVERFLOW!
                      SizedBox(
                        width: double.infinity,
                        height: 28, // PERFECT: Fixed height that fits perfectly
                        child: ElevatedButton(
                          onPressed: () => _addToCart(product, context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEC407A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.zero, // PERFECT: No extra padding
                            elevation: 2,
                            shadowColor: const Color(0xFFEC407A).withOpacity(0.3),
                          ),
                          child: Text(
                            'Add to Cart',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
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
      ),
    );
  }
}
