import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with TickerProviderStateMixin {
  int _quantity = 1;
  int _selectedImageIndex = 0;
  int _selectedVariantIndex = 0;
  bool _isExpanded = false;
  bool _isLoading = true;
  bool _isLiked = false;
  bool _isSubmittingReview = false;
  String? _errorMessage;
  
  // Product data
  Map<String, dynamic>? _product;
  List<Map<String, dynamic>> _allImages = []; // Combined images from both tables
  List<Map<String, dynamic>> _productVariants = [];
  List<Map<String, dynamic>> _productReviews = [];
  
  // Review form controllers
  final TextEditingController _reviewTitleController = TextEditingController();
  final TextEditingController _reviewCommentController = TextEditingController();
  int _selectedRating = 5;
  bool _showReviewForm = false;
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

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
    
    _loadProductData();
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
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    _reviewTitleController.dispose();
    _reviewCommentController.dispose();
    super.dispose();
  }

  Future<void> _loadProductData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final pb = authProvider.pb;

      debugPrint('Loading product data for ID: ${widget.productId}');

      // Fetch main product data
      final productRecord = await pb.collection('products').getOne(widget.productId);
      
      debugPrint('Product loaded: ${productRecord.data}');
      
      setState(() {
        _product = {
          'id': productRecord.id,
          'name': productRecord.data['name'] ?? '',
          'price': productRecord.data['price'] ?? 0,
          'image_url': productRecord.data['image_url'] ?? '',
          'description': productRecord.data['description'] ?? '',
          'rating': productRecord.data['rating'] ?? 0,
          'skin_type': productRecord.data['skin_type'] ?? [],
          'brand': productRecord.data['brand'] ?? '',
        };
      });

      // FIXED: Combine images from both products table and product_images table
      await _loadAllImages(pb);

      // Fetch product variants
      try {
        debugPrint('Fetching product variants for product_id: ${widget.productId}');
        
        final variantsResult = await pb.collection('product_variants').getList(
          filter: 'product_id ~ "${widget.productId}"',
        );
        
        debugPrint('Variants found: ${variantsResult.items.length}');
        
        setState(() {
          _productVariants = variantsResult.items.map((record) => {
            'id': record.id,
            'product_id': record.data['product_id'],
            'variant_size': record.data['variant_size'] ?? '',
          }).toList();
        });
        debugPrint('Product variants loaded: ${_productVariants.length}');
      } catch (e) {
        debugPrint('Error fetching product variants: $e');
      }

      // Fetch product reviews
      try {
        debugPrint('Fetching product reviews for product_id: ${widget.productId}');
        
        final reviewsResult = await pb.collection('product_reviews').getList(
          filter: 'product_id ~ "${widget.productId}"',
          sort: '-created',
          expand: 'user_id',
        );
        
        debugPrint('Reviews found: ${reviewsResult.items.length}');
        
        setState(() {
          _productReviews = reviewsResult.items.map((record) => {
            'id': record.id,
            'user_id': record.data['user_id'],
            'product_id': record.data['product_id'],
            'rating': record.data['rating'] ?? 0,
            'title': record.data['title'] ?? '',
            'comment': record.data['comment'] ?? '',
            'created': record.created,
            'user_name': _getUserNameFromExpand(record),
          }).toList();
        });
        debugPrint('Product reviews loaded: ${_productReviews.length}');
      } catch (e) {
        debugPrint('Error fetching product reviews: $e');
      }

      // Check if product is liked by current user
      if (authProvider.isLoggedIn) {
        try {
          final userModel = authProvider.pb.authStore.model;
          final userId = userModel?.id;
          
          if (userId != null) {
            final likedResult = await pb.collection('user_liked_products').getList(
              filter: 'user_id = "$userId" && product_id ~ "${widget.productId}"',
            );
            
            setState(() {
              _isLiked = likedResult.items.isNotEmpty;
            });
          }
        } catch (e) {
          debugPrint('Error checking liked status: $e');
        }
      }

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      debugPrint('Error loading product data: $e');
      setState(() {
        _errorMessage = 'Failed to load product: $e';
        _isLoading = false;
      });
    }
  }

  // FIXED: Load images from both products table and product_images table
  Future<void> _loadAllImages(PocketBase pb) async {
    List<Map<String, dynamic>> combinedImages = [];
    
    // 1. Add main product image from products table
    if (_product != null && _product!['image_url'].isNotEmpty) {
      combinedImages.add({
        'id': 'main_product',
        'product_id': widget.productId,
        'image_url': _product!['image_url'],
        'sort_order': 0,
        'source': 'products_table',
      });
    }
    
    // 2. Add additional images from product_images table
    try {
      debugPrint('Fetching additional product images for product_id: ${widget.productId}');
      
      final imagesResult = await pb.collection('product_images').getList(
        filter: 'product_id ~ "${widget.productId}"',
        sort: 'sort_order',
      );
      
      debugPrint('Additional images found: ${imagesResult.items.length}');
      
      for (var record in imagesResult.items) {
        combinedImages.add({
          'id': record.id,
          'product_id': record.data['product_id'],
          'image_url': record.data['image_url'] ?? '',
          'sort_order': record.data['sort_order'] ?? 1,
          'source': 'product_images_table',
        });
      }
    } catch (e) {
      debugPrint('Error fetching additional product images: $e');
    }
    
    // Sort by sort_order
    combinedImages.sort((a, b) => (a['sort_order'] as int).compareTo(b['sort_order'] as int));
    
    setState(() {
      _allImages = combinedImages;
    });
    
    debugPrint('Total images loaded: ${_allImages.length}');
    for (var img in _allImages) {
      debugPrint('Image: ${img['source']} - ${img['image_url']}');
    }
  }

  String _getUserNameFromExpand(dynamic record) {
    try {
      if (record.expand != null && record.expand['user_id'] != null) {
        final userData = record.expand['user_id'];
        if (userData is Map && userData['name'] != null) {
          return userData['name'].toString();
        }
        if (userData.data != null && userData.data['name'] != null) {
          return userData.data['name'].toString();
        }
      }
      return 'Anonymous';
    } catch (e) {
      debugPrint('Error getting user name from expand: $e');
      return 'Anonymous';
    }
  }

  String _getSkinTypeNames(dynamic skinTypes) {
    if (skinTypes == null) return '';
    
    List<String> typeNames = [];
    
    if (skinTypes is List) {
      for (var type in skinTypes) {
        String typeName = _convertSkinTypeIdToName(type.toString());
        if (typeName.isNotEmpty) {
          typeNames.add(typeName);
        }
      }
    } else {
      String typeName = _convertSkinTypeIdToName(skinTypes.toString());
      if (typeName.isNotEmpty) {
        typeNames.add(typeName);
      }
    }
    
    return typeNames.join(', ');
  }

  String _convertSkinTypeIdToName(String typeId) {
    final skinTypeMap = {
      'kering': 'Kulit Kering',
      'berminyak': 'Kulit Berminyak', 
      'sensitif': 'Kulit Sensitif',
      'kombinasi': 'Kulit Kombinasi',
      'dry': 'Kulit Kering',
      'oily': 'Kulit Berminyak',
      'sensitive': 'Kulit Sensitif',
      'combination': 'Kulit Kombinasi',
      'normal': 'Kulit Normal',
    };
    
    String lowerType = typeId.toLowerCase().trim();
    
    if (lowerType.contains('kulit') || lowerType.length > 10) {
      return typeId;
    }
    
    for (var entry in skinTypeMap.entries) {
      if (lowerType.contains(entry.key)) {
        return entry.value;
      }
    }
    
    if (typeId.isNotEmpty) {
      return typeId[0].toUpperCase() + typeId.substring(1);
    }
    
    return typeId;
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0);
  }

  double _getCurrentPrice() {
    if (_product == null) return 0.0;
    return _product!['price'].toDouble();
  }

  Future<void> _addToCart() async {
    if (_product == null) return;
    
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      
      final productWithQuantity = {
        'id': _product!['id'],
        'name': _product!['name'],
        'price': _getCurrentPrice(),
        'image_url': _allImages.isNotEmpty ? _allImages[_selectedImageIndex]['image_url'] : _product!['image_url'],
        'description': _product!['description'],
        'brand': _product!['brand'],
        'quantity': _quantity,
        'variant': _productVariants.isNotEmpty && _selectedVariantIndex < _productVariants.length 
            ? _productVariants[_selectedVariantIndex]['variant_size'] 
            : null,
      };
      
      cartProvider.addToCart(productWithQuantity);
      
      if (mounted) {
        _pulseController.forward().then((_) {
          _pulseController.reverse();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_product!['name']} ditambahkan ke keranjang',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_product == null) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please login to like products',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    try {
      final pb = authProvider.pb;
      final userModel = authProvider.pb.authStore.model;
      final userId = userModel?.id;
      
      if (userId == null) return;

      if (_isLiked) {
        final likedResult = await pb.collection('user_liked_products').getList(
          filter: 'user_id = "$userId" && product_id ~ "${widget.productId}"',
        );
        
        for (var record in likedResult.items) {
          await pb.collection('user_liked_products').delete(record.id);
        }
        
        setState(() {
          _isLiked = false;
        });
      } else {
        await pb.collection('user_liked_products').create(
          body: {
            'user_id': userId,
            'product_id': [widget.productId],
            'liked_at': DateTime.now().toIso8601String(),
          },
        );
        
        setState(() {
          _isLiked = true;
        });
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  // NEW: Submit review function
  Future<void> _submitReview() async {
    if (_product == null) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please login to submit a review',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_reviewTitleController.text.trim().isEmpty || _reviewCommentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill in all review fields',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isSubmittingReview = true;
    });

    try {
      final pb = authProvider.pb;
      final userModel = authProvider.pb.authStore.model;
      final userId = userModel?.id;
      
      if (userId == null) return;

      // Submit review to product_reviews table
      await pb.collection('product_reviews').create(
        body: {
          'user_id': userId,
          'product_id': [widget.productId], // Relation field
          'rating': _selectedRating,
          'title': _reviewTitleController.text.trim(),
          'comment': _reviewCommentController.text.trim(),
        },
      );

      // Clear form
      _reviewTitleController.clear();
      _reviewCommentController.clear();
      setState(() {
        _selectedRating = 5;
        _showReviewForm = false;
        _isSubmittingReview = false;
      });

      // Reload reviews
      await _loadProductData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Review berhasil dikirim!',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmittingReview = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mengirim review: $e',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Widget _buildImageCarousel() {
    final images = _allImages.isNotEmpty ? _allImages : [
      {
        'id': 'default',
        'product_id': widget.productId,
        'image_url': _product?['image_url'] ?? '',
        'sort_order': 0,
        'source': 'default',
      }
    ];
    
    return Column(
      children: [
        Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              itemCount: images.length,
              onPageChanged: (index) => setState(() => _selectedImageIndex = index),
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Image.network(
                      images[index]['image_url'],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.grey[200]!, Colors.grey[100]!, Colors.grey[200]!],
                            ),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(color: Color(0xFFEC407A)),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.grey[200]!, Colors.grey[300]!],
                            ),
                          ),
                          child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                        );
                      },
                    ),
                    // Image source indicator
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          images[index]['source'] == 'products_table' ? 'Main' : 'Gallery',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: images.asMap().entries.map((entry) {
              return Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _selectedImageIndex == entry.key
                      ? const Color(0xFFEC407A)
                      : Colors.grey[300],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildVariantSelector() {
    if (_productVariants.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UKURAN:',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _productVariants.asMap().entries.map((entry) {
            final index = entry.key;
            final variant = entry.value;
            final isSelected = index == _selectedVariantIndex;
            
            return GestureDetector(
              onTap: () => setState(() => _selectedVariantIndex = index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEC407A) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFEC407A) : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  variant['variant_size'],
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // NEW: Review form widget
  Widget _buildReviewForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tulis Review',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _showReviewForm = false),
                icon: const Icon(Icons.close, size: 20),
                color: Colors.grey[600],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Rating selector
          Text(
            'Rating:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => setState(() => _selectedRating = index + 1),
                child: Icon(
                  index < _selectedRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 28,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          
          // Title field
          Text(
            'Judul Review:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reviewTitleController,
            decoration: InputDecoration(
              hintText: 'Masukkan judul review...',
              hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEC407A)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          const SizedBox(height: 16),
          
          // Comment field
          Text(
            'Komentar:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reviewCommentController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Tulis pengalaman Anda dengan produk ini...',
              hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEC407A)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          const SizedBox(height: 16),
          
          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmittingReview ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC407A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isSubmittingReview
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Kirim Review',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    // Calculate average rating
    double averageRating = 0.0;
    if (_productReviews.isNotEmpty) {
      double totalRating = _productReviews.fold(0.0, (sum, review) => sum + review['rating']);
      averageRating = totalRating / _productReviews.length;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reviews (${_productReviews.length})',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
              ),
              if (_productReviews.isNotEmpty)
                Row(
                  children: [
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < averageRating.floor() ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 14,
                        );
                      }),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      averageRating.toStringAsFixed(1),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Add review button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _showReviewForm = !_showReviewForm),
              icon: Icon(
                _showReviewForm ? Icons.close : Icons.add,
                color: const Color(0xFFEC407A),
                size: 18,
              ),
              label: Text(
                _showReviewForm ? 'Tutup Form' : 'Tulis Review',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFEC407A),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEC407A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          
          if (_productReviews.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...(_productReviews.take(3).map((review) => _buildReviewItem(review))),
            if (_productReviews.length > 3)
              TextButton(
                onPressed: () {
                  // Navigate to full reviews screen
                },
                child: Text(
                  'Lihat semua review',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFEC407A),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
          ] else ...[
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Belum ada review untuk produk ini',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Jadilah yang pertama memberikan review!',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFEC407A),
                child: Text(
                  (review['user_name'] ?? 'U').substring(0, 1).toUpperCase(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['user_name'] ?? 'Anonymous',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (index) {
                            return Icon(
                              index < review['rating'] ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 10,
                            );
                          }),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          review['created'].toString().split('T')[0],
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review['title'].isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review['title'],
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (review['comment'].isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              review['comment'],
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey[700],
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFCE4EC),
        appBar: AppBar(
          title: Text(
            'Detail Produk',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFFF8BBD0),
          centerTitle: true,
        ),
        body: Center(
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
                'Memuat detail produk...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFCE4EC),
        appBar: AppBar(
          title: Text(
            'Detail Produk',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFF8BBD0),
        ),
        body: Center(
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
                onPressed: _loadProductData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC407A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Coba Lagi',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_product == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFCE4EC),
        appBar: AppBar(
          title: Text(
            'Detail Produk',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFF8BBD0),
        ),
        body: const Center(child: Text('Product not found')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      appBar: AppBar(
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            'Detail Produk',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ),
        backgroundColor: const Color(0xFFF8BBD0),
        centerTitle: true,
        actions: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: IconButton(
              icon: Icon(
                _isLiked ? Icons.favorite : Icons.favorite_border,
                color: _isLiked ? Colors.red : Colors.white,
              ),
              onPressed: _toggleFavorite,
            ),
          ),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Images - FIXED: Shows images from both tables
              SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildImageCarousel(),
                ),
              ),

              const SizedBox(height: 20),

              // Product Info
              SlideTransition(
                position: _slideAnimation,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _product!['name'],
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _product!['brand'],
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFEC407A).withOpacity(0.1),
                              const Color(0xFFF48FB1).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFEC407A).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          'Rp ${_formatPrice(_getCurrentPrice())}',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFEC407A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Variants
                      _buildVariantSelector(),
                      
                      // Quantity Selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Jumlah:',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                                  icon: const Icon(Icons.remove, size: 18),
                                  color: _quantity > 1 ? const Color(0xFFEC407A) : Colors.grey,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  child: Text(
                                    _quantity.toString(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => setState(() => _quantity++),
                                  icon: const Icon(Icons.add, size: 18),
                                  color: const Color(0xFFEC407A),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Product Details
              SlideTransition(
                position: _slideAnimation,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deskripsi Produk',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _product!['description'],
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Skin Type Info
                      if (_product!['skin_type'] != null && _product!['skin_type'].isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEC407A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFEC407A).withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEC407A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.face,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cocok untuk Jenis Kulit',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _getSkinTypeNames(_product!['skin_type']),
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // NEW: Review form (when shown)
              if (_showReviewForm) ...[
                SlideTransition(
                  position: _slideAnimation,
                  child: _buildReviewForm(),
                ),
                const SizedBox(height: 16),
              ],

              // Reviews Section - UPDATED: Now includes review submission
              SlideTransition(
                position: _slideAnimation,
                child: _buildReviewsSection(),
              ),

              const SizedBox(height: 80), // Space for floating button
            ],
          ),
        ),
      ),
      bottomNavigationBar: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFF48FB1),
                          const Color(0xFFEC407A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEC407A).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _addToCart,
                      icon: const Icon(Icons.shopping_cart_checkout, color: Colors.white, size: 18),
                      label: Text(
                        'Add to Cart',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}