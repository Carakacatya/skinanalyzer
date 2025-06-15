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
  const StoreSingleProduct({super.key});

  @override
  _StoreSingleProductState createState() => _StoreSingleProductState();
}

class _StoreSingleProductState extends State<StoreSingleProduct>
    with TickerProviderStateMixin {
  int _selectedCategoryIndex = 0;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _recommendedProducts = [];
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
    _prepareRecommendedProducts();
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
  
  void _prepareRecommendedProducts() {
    if (_products.length > 5) {
      final recommended = List<Map<String, dynamic>>.from(_products);
      recommended.shuffle();
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
    // Start pulse animation for feedback
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
      
      // Optimistic update with animation
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
          // Revert optimistic update
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
          // Revert optimistic update
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
        filtered = _products.where((product) => product['is_new'] == true).toList();
        if (filtered.length > 4) {
          filtered = filtered.sublist(0, 4);
        }
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
    // Add scale animation for button feedback
    _scaleController.reset();
    _scaleController.forward();
    
    Provider.of<CartProvider>(context, listen: false).addToCart(product);
    _showSnackBar('${product['name']} added to cart!', AppColors.primary);
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
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.image_not_supported,
          size: 50,
          color: Colors.grey,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        width: double.infinity,
        height: 100,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          
          // Custom loading animation instead of CircularProgressIndicator
          return Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey[200]!,
                  Colors.grey[100]!,
                  Colors.grey[200]!,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Shimmer effect
                AnimatedBuilder(
                  animation: _fadeController,
                  builder: (context, child) {
                    return Positioned(
                      left: -100 + (_fadeController.value * 200),
                      top: 0,
                      bottom: 0,
                      width: 100,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.4),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Loading icon
                Center(
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Icon(
                          Icons.image,
                          size: 30,
                          color: Colors.grey[400],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.broken_image,
              size: 50,
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
          // Custom loading animation
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFF48FB1),
                        const Color(0xFFEC407A),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEC407A).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shopping_bag,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Text(
              'Loading amazing products...',
              style: GoogleFonts.poppins(
                color: Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SlideTransition(
            position: _slideAnimation,
            child: Container(
              width: 200,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(2),
              ),
              child: AnimatedBuilder(
                animation: _fadeController,
                builder: (context, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _fadeController.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFF48FB1),
                            const Color(0xFFEC407A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
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

  @override
  Widget build(BuildContext context) {
    // Start pulse animation for loading
    if (_isLoading) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
    }
    
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
            ),
          ),
        ),
        backgroundColor: const Color(0xFFF8BBD0),
        centerTitle: true,
        actions: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: IconButton(
              icon: const Icon(Icons.shopping_cart),
              onPressed: () {
                Navigator.pushNamed(context, '/cart');
              },
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFFCE4EC),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
              ? FadeTransition(
                  opacity: _fadeAnimation,
                  child: Center(
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
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: ElevatedButton(
                            onPressed: _fetchProducts,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF48FB1),
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
                        ),
                      ],
                    ),
                  ),
                )
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 12,
                      bottom: MediaQuery.of(context).padding.bottom + 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search Bar with animation
                        SlideTransition(
                          position: _slideAnimation,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Search any Product...',
                                hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                suffixIcon: AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _isListening ? _pulseAnimation.value : 1.0,
                                      child: GestureDetector(
                                        onTap: _listen,
                                        child: Icon(
                                          _isListening ? Icons.mic : Icons.mic_none,
                                          color: _isListening ? Colors.red : Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.grey.shade200, width: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Category Tabs with animation
                        if (!_isSearching)
                          SlideTransition(
                            position: _slideAnimation,
                            child: Container(
                              height: 40,
                              alignment: Alignment.centerLeft,
                              child: SingleChildScrollView(
                                controller: _tabScrollController,
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: List.generate(_categories.length, (index) {
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedCategoryIndex = index;
                                          _filterProductsByCategory();
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        margin: const EdgeInsets.only(right: 16),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _categories[index],
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: _selectedCategoryIndex == index
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                                color: _selectedCategoryIndex == index
                                                    ? const Color(0xFFEC407A)
                                                    : Colors.grey[600],
                                              ),
                                            ),
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 300),
                                              margin: const EdgeInsets.only(top: 4),
                                              height: 2,
                                              width: _selectedCategoryIndex == index ? 40 : 0,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEC407A),
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Info indicators with animation
                        if (!_isSearching && _selectedCategoryIndex == 1 && _skinType != null)
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
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
                                    const Icon(Icons.face, color: Color(0xFFEC407A)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Your skin type: $_skinType',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        if (!_isSearching && _selectedCategoryIndex == 2)
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
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
                                    const Icon(Icons.favorite, color: Color(0xFFEC407A)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Your liked products',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        if (_isSearching)
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'Search results: ${_searchResults.length} products',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),

                        // Products Grid with staggered animation
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () async {
                              await _fetchProducts();
                              await _fetchUserLikedProducts();
                              _filterProductsByCategory();
                            },
                            color: const Color(0xFFEC407A),
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  displayProducts.isEmpty
                                      ? FadeTransition(
                                          opacity: _fadeAnimation,
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const SizedBox(height: 40),
                                                ScaleTransition(
                                                  scale: _scaleAnimation,
                                                  child: const Icon(
                                                    Icons.inventory_2_outlined,
                                                    size: 64,
                                                    color: Colors.grey,
                                                  ),
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
                                                                  : 'No products in ${_categories[_selectedCategoryIndex]} category',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                if (_selectedCategoryIndex == 1 && _skinType == null)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 16),
                                                    child: ScaleTransition(
                                                      scale: _scaleAnimation,
                                                      child: ElevatedButton(
                                                        onPressed: () {
                                                          Navigator.pushNamed(context, '/quiz');
                                                        },
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFFEC407A),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          'Start Quiz',
                                                          style: GoogleFonts.poppins(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                const SizedBox(height: 40),
                                              ],
                                            ),
                                          ),
                                        )
                                      : GridView.builder(
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
                                            
                                            // Staggered animation for grid items
                                            return AnimatedBuilder(
                                              animation: _slideController,
                                              builder: (context, child) {
                                                final delay = index * 0.1;
                                                final animationValue = Curves.easeOutCubic.transform(
                                                  (_slideController.value - delay).clamp(0.0, 1.0)
                                                );
                                                
                                                return Transform.translate(
                                                  offset: Offset(0, 50 * (1 - animationValue)),
                                                  child: Opacity(
                                                    opacity: animationValue,
                                                    child: Card(
                                                      elevation: 2,
                                                      shadowColor: Colors.black.withOpacity(0.1),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(16)
                                                      ),
                                                      child: Column(
                                                        children: [
                                                          Stack(
                                                            children: [
                                                              ClipRRect(
                                                                borderRadius: const BorderRadius.vertical(
                                                                  top: Radius.circular(16)
                                                                ),
                                                                child: _buildProductImage(product['image_url']),
                                                              ),
                                                              Positioned(
                                                                top: 8,
                                                                right: 8,
                                                                child: AnimatedBuilder(
                                                                  animation: _pulseAnimation,
                                                                  builder: (context, child) {
                                                                    return GestureDetector(
                                                                      onTap: () => _toggleLikeProduct(productId),
                                                                      child: Container(
                                                                        padding: const EdgeInsets.all(4),
                                                                        decoration: BoxDecoration(
                                                                          color: Colors.white.withOpacity(0.8),
                                                                          shape: BoxShape.circle,
                                                                          boxShadow: [
                                                                            BoxShadow(
                                                                              color: Colors.black.withOpacity(0.1),
                                                                              blurRadius: 3,
                                                                              offset: const Offset(0, 1),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        child: Icon(
                                                                          isLiked ? Icons.favorite : Icons.favorite_border,
                                                                          color: const Color(0xFFEC407A),
                                                                          size: 18,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                ),
                                                              ),
                                                              if (product['likes_count'] > 0)
                                                                Positioned(
                                                                  top: 8,
                                                                  left: 8,
                                                                  child: Container(
                                                                    padding: const EdgeInsets.symmetric(
                                                                      horizontal: 6, 
                                                                      vertical: 2
                                                                    ),
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
                                                                          style: GoogleFonts.poppins(
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
                                                                    padding: const EdgeInsets.symmetric(
                                                                      horizontal: 8, 
                                                                      vertical: 4
                                                                    ),
                                                                    decoration: const BoxDecoration(
                                                                      color: Color(0xFF4CAF50),
                                                                      borderRadius: BorderRadius.only(
                                                                        topLeft: Radius.circular(12),
                                                                        bottomRight: Radius.circular(16),
                                                                      ),
                                                                    ),
                                                                    child: Text(
                                                                      'NEW',
                                                                      style: GoogleFonts.poppins(
                                                                        color: Colors.white,
                                                                        fontSize: 10,
                                                                        fontWeight: FontWeight.w600,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              if (!_isSearching && _selectedCategoryIndex == 1)
                                                                Positioned(
                                                                  bottom: 0,
                                                                  left: 0,
                                                                  child: Container(
                                                                    padding: const EdgeInsets.symmetric(
                                                                      horizontal: 8, 
                                                                      vertical: 4
                                                                    ),
                                                                    decoration: const BoxDecoration(
                                                                      color: Color(0xFFEC407A),
                                                                      borderRadius: BorderRadius.only(
                                                                        topRight: Radius.circular(12),
                                                                        bottomLeft: Radius.circular(16),
                                                                      ),
                                                                    ),
                                                                    child: Text(
                                                                      'RECOMMENDED',
                                                                      style: GoogleFonts.poppins(
                                                                        color: Colors.white,
                                                                        fontSize: 8,
                                                                        fontWeight: FontWeight.w600,
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
                                                                    style: GoogleFonts.poppins(
                                                                      fontWeight: FontWeight.w600,
                                                                      fontSize: 12,
                                                                    ),
                                                                    maxLines: 2,
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                  const SizedBox(height: 2),
                                                                  Text(
                                                                    product['description'],
                                                                    style: GoogleFonts.poppins(
                                                                      fontSize: 10,
                                                                      color: Colors.grey[600],
                                                                    ),
                                                                    maxLines: 2,
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                  const SizedBox(height: 4),
                                                                  Text(
                                                                    'Rp ${product['price']}',
                                                                    style: GoogleFonts.poppins(
                                                                      fontWeight: FontWeight.w600,
                                                                      fontSize: 12,
                                                                      color: const Color(0xFFEC407A),
                                                                    ),
                                                                  ),
                                                                  const Spacer(),
                                                                  SizedBox(
                                                                    width: double.infinity,
                                                                    child: AnimatedBuilder(
                                                                      animation: _scaleAnimation,
                                                                      builder: (context, child) {
                                                                        return Transform.scale(
                                                                          scale: _scaleAnimation.value,
                                                                          child: ElevatedButton(
                                                                            onPressed: () => _addToCart(product, context),
                                                                            style: ElevatedButton.styleFrom(
                                                                              backgroundColor: const Color(0xFFEC407A),
                                                                              shape: RoundedRectangleBorder(
                                                                                borderRadius: BorderRadius.circular(12),
                                                                              ),
                                                                              padding: const EdgeInsets.symmetric(vertical: 6),
                                                                            ),
                                                                            child: Text(
                                                                              'Add to Cart',
                                                                              style: GoogleFonts.poppins(
                                                                                color: Colors.white,
                                                                                fontSize: 11,
                                                                                fontWeight: FontWeight.w500,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        );
                                                                      },
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                  
                                  // Recommended section with animation
                                  if (!_isSearching && 
                                      (_selectedCategoryIndex == 0 || _selectedCategoryIndex == 3) && 
                                      _recommendedProducts.isNotEmpty) ...[
                                    const SizedBox(height: 24),
                                    FadeTransition(
                                      opacity: _fadeAnimation,
                                      child: Text(
                                        'Recommended For You',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF333333),
                                        ),
                                      ),
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
                                        
                                        return SlideTransition(
                                          position: Tween<Offset>(
                                            begin: Offset(1.0, 0.0),
                                            end: Offset.zero,
                                          ).animate(CurvedAnimation(
                                            parent: _slideController,
                                            curve: Interval(
                                              index * 0.1,
                                              1.0,
                                              curve: Curves.easeOutCubic,
                                            ),
                                          )),
                                          child: Container(
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
                                                        style: GoogleFonts.poppins(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 13,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        "50 ml",
                                                        style: GoogleFonts.poppins(
                                                          color: Colors.grey[600],
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Rp ${product['price']}',
                                                        style: GoogleFonts.poppins(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 13,
                                                          color: const Color(0xFFEC407A),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  children: [
                                                    AnimatedBuilder(
                                                      animation: _pulseAnimation,
                                                      builder: (context, child) {
                                                        return Transform.scale(
                                                          scale: isLiked ? _pulseAnimation.value : 1.0,
                                                          child: IconButton(
                                                            icon: Icon(
                                                              isLiked ? Icons.favorite : Icons.favorite_border,
                                                              color: const Color(0xFFEC407A),
                                                              size: 20,
                                                            ),
                                                            onPressed: () => _toggleLikeProduct(productId),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    ScaleTransition(
                                                      scale: _scaleAnimation,
                                                      child: IconButton(
                                                        icon: const Icon(
                                                          Icons.shopping_cart_outlined,
                                                          color: Color(0xFFEC407A),
                                                          size: 20,
                                                        ),
                                                        onPressed: () => _addToCart(product, context),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
