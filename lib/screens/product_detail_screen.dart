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
  // State variables
  int _quantity = 1;
  int _selectedImageIndex = 0;
  int _selectedVariantIndex = 0;
  bool _isLoading = true;
  bool _isLiked = false;
  bool _isSubmittingReview = false;
  String? _errorMessage;
  
  // Product data
  Map<String, dynamic>? _product;
  List<Map<String, dynamic>> _allImages = [];
  List<Map<String, dynamic>> _productVariants = [];
  List<Map<String, dynamic>> _productReviews = [];
  
  // Review form controllers
  final TextEditingController _reviewTitleController = TextEditingController();
  final TextEditingController _reviewCommentController = TextEditingController();
  int _selectedRating = 5;
  bool _showReviewForm = false;
  
  // Animation controllers untuk efek visual yang indah
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _bounceController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadProductData();
    _startAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic)
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut)
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack)
    );
  }
  
  void _startAnimations() {
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
    _bounceController.dispose();
    _scaleController.dispose();
    _reviewTitleController.dispose();
    _reviewCommentController.dispose();
    super.dispose();
  }

  // Fungsi utama untuk memuat semua data produk
  Future<void> _loadProductData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final pb = authProvider.pb;

      // 1. Ambil data produk utama dengan ekspansi skin_type
      await _loadMainProduct(pb);
      
      // 2. Muat semua gambar dari kedua tabel
      await _loadAllImages(pb);
      
      // 3. Muat varian produk
      await _loadVariants(pb);
      
      // 4. Muat review produk
      await _loadReviews(pb);
      
      // 5. Cek status like
      await _checkIfLiked(pb, authProvider);

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      debugPrint('Error loading product data: $e');
      setState(() {
        _errorMessage = 'Gagal memuat data produk: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Memuat data produk utama dengan relasi skin_type
  Future<void> _loadMainProduct(PocketBase pb) async {
    final productRecord = await pb.collection('products').getOne(
      widget.productId,
      expand: 'skin_type',
    );
    
    setState(() {
      _product = {
        'id': productRecord.id,
        'name': productRecord.data['name'] ?? '',
        'price': productRecord.data['price'] ?? 0,
        'image_url': productRecord.data['image_url'] ?? '',
        'description': productRecord.data['description'] ?? '',
        'rating': productRecord.data['rating'] ?? 0.0,
        'skin_type': productRecord.data['skin_type'] ?? [],
        'brand': productRecord.data['brand'] ?? '',
        'expanded_skin_types': productRecord.expand?['skin_type'] ?? [],
      };
    });
  }

  // Memuat semua gambar dari tabel products dan product_images
Future<void> _loadAllImages(PocketBase pb) async {
  List<Map<String, dynamic>> combinedImages = [];
  
  // 1. Tambahkan gambar utama dari tabel products (selalu pertama)
  if (_product != null && _product!['image_url'] != null && _product!['image_url'].toString().isNotEmpty) {
    combinedImages.add({
      'id': 'main_product',
      'product_id': widget.productId,
      'image_url': _product!['image_url'].toString(),
      'sort_order': 0,
      'source': 'products',
    });
  }
  
  // 2. Tambahkan gambar tambahan dari tabel product_images
  try {
    final imagesResult = await pb.collection('product_images').getList(
      page: 1,
      perPage: 10,
      filter: 'product_id = "${widget.productId}"',
      sort: 'sort_order',
    );
    
    debugPrint('Gambar tambahan ditemukan: ${imagesResult.items.length}');
    
    for (var record in imagesResult.items) {
      final imageUrl = record.data['image_url'];
      if (imageUrl != null && imageUrl.toString().isNotEmpty) {
        combinedImages.add({
          'id': record.id,
          'product_id': record.data['product_id'],
          'image_url': imageUrl.toString(),
          'sort_order': record.data['sort_order'] ?? (combinedImages.length + 1),
          'source': 'product_images',
        });
      }
    }
  } catch (e) {
    debugPrint('Error mengambil gambar tambahan: $e');
  }
  
  // Urutkan berdasarkan sort_order
  combinedImages.sort((a, b) => (a['sort_order'] as int).compareTo(b['sort_order'] as int));
  
  setState(() {
    _allImages = combinedImages;
  });
  
  debugPrint('Total gambar dimuat: ${_allImages.length}');
  for (var img in _allImages) {
    debugPrint('Gambar: ${img['source']} - ${img['image_url']}');
  }
}

  // Memuat varian produk dari tabel product_variants
  Future<void> _loadVariants(PocketBase pb) async {
    try {
      final variantsResult = await pb.collection('product_variants').getList(
        filter: 'product_id = "${widget.productId}"',
        sort: 'variant_size',
      );
      
      setState(() {
        _productVariants = variantsResult.items.map((record) => {
          'id': record.id,
          'product_id': record.data['product_id'],
          'variant_size': record.data['variant_size'] ?? '',
        }).toList();
      });
      
      debugPrint('Varian produk dimuat: ${_productVariants.length}');
    } catch (e) {
      debugPrint('Error mengambil varian: $e');
    }
  }

  // Memuat review produk dari tabel product_reviews
  Future<void> _loadReviews(PocketBase pb) async {
    try {
      final reviewsResult = await pb.collection('product_reviews').getList(
        filter: 'product_id = "${widget.productId}"',
        sort: '-created',
        expand: 'user_id',
        perPage: 20,
      );
      
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
      
      debugPrint('Review dimuat: ${_productReviews.length}');
    } catch (e) {
      debugPrint('Error mengambil review: $e');
    }
  }

  // Cek apakah produk disukai user
  Future<void> _checkIfLiked(PocketBase pb, AuthProvider authProvider) async {
    if (!authProvider.isLoggedIn) return;
    
    try {
      final userModel = authProvider.pb.authStore.model;
      final userId = userModel?.id;
      
      if (userId != null) {
        final likedResult = await pb.collection('user_liked_products').getList(
          filter: 'user_id = "$userId" && product_id = "${widget.productId}"',
        );
        
        setState(() {
          _isLiked = likedResult.items.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error mengecek status like: $e');
    }
  }

  // Helper function untuk mendapatkan nama user dari expand
  String _getUserNameFromExpand(dynamic record) {
    try {
      if (record.expand != null && record.expand['user_id'] != null) {
        final userData = record.expand['user_id'];
        if (userData.data != null && userData.data['name'] != null) {
          return userData.data['name'].toString();
        }
      }
      return 'Pengguna Anonim';
    } catch (e) {
      return 'Pengguna Anonim';
    }
  }

  // Mendapatkan nama jenis kulit dari relasi yang di-expand
  String _getSkinTypeNames() {
    if (_product == null) return 'Semua Jenis Kulit';
    
    List<String> typeNames = [];
    
    if (_product!['expanded_skin_types'] != null && _product!['expanded_skin_types'].isNotEmpty) {
      for (var skinType in _product!['expanded_skin_types']) {
        if (skinType.data != null && skinType.data['nama'] != null) {
          typeNames.add(skinType.data['nama'].toString());
        }
      }
    }
    
    return typeNames.isNotEmpty ? typeNames.join(', ') : 'Semua Jenis Kulit';
  }

  // Mendapatkan deskripsi jenis kulit
  String _getSkinTypeDescriptions() {
    if (_product == null) return '';
    
    List<String> descriptions = [];
    
    if (_product!['expanded_skin_types'] != null && _product!['expanded_skin_types'].isNotEmpty) {
      for (var skinType in _product!['expanded_skin_types']) {
        if (skinType.data != null && skinType.data['description'] != null) {
          descriptions.add(skinType.data['description'].toString());
        }
      }
    }
    
    return descriptions.isNotEmpty ? descriptions.join(' • ') : '';
  }

  // Format harga ke Rupiah
  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]}.'
    );
  }

  double _getCurrentPrice() {
    if (_product == null) return 0.0;
    return _product!['price'].toDouble();
  }

  // Fungsi untuk submit review baru
  Future<void> _submitReview() async {
    if (_reviewTitleController.text.trim().isEmpty || 
        _reviewCommentController.text.trim().isEmpty) {
      _showSnackBar('Mohon isi semua field review', isError: true);
      return;
    }

    setState(() {
      _isSubmittingReview = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (!authProvider.isLoggedIn) {
        _showSnackBar('Silakan login terlebih dahulu untuk memberikan review', isError: true);
        return;
      }

      final userModel = authProvider.pb.authStore.model;
      final userId = userModel?.id;

      if (userId == null) {
        _showSnackBar('User ID tidak ditemukan', isError: true);
        return;
      }

      await authProvider.pb.collection('product_reviews').create(body: {
        'user_id': userId,
        'product_id': widget.productId,
        'rating': _selectedRating,
        'title': _reviewTitleController.text.trim(),
        'comment': _reviewCommentController.text.trim(),
      });

      _showSnackBar('Review berhasil dikirim!');
      
      // Reset form
      _reviewTitleController.clear();
      _reviewCommentController.clear();
      _selectedRating = 5;
      setState(() {
        _showReviewForm = false;
      });
      
      // Reload reviews
      await _loadReviews(authProvider.pb);

    } catch (e) {
      debugPrint('Error submitting review: $e');
      _showSnackBar('Gagal mengirim review: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isSubmittingReview = false;
      });
    }
  }

  // Fungsi untuk toggle like/unlike
  Future<void> _toggleLike() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!authProvider.isLoggedIn) {
      _showSnackBar('Silakan login untuk menyukai produk', isError: true);
      return;
    }

    try {
      final userModel = authProvider.pb.authStore.model;
      final userId = userModel?.id;

      if (userId == null) return;

      if (_isLiked) {
        // Hapus like
        final likedResult = await authProvider.pb.collection('user_liked_products').getList(
          filter: 'user_id = "$userId" && product_id = "${widget.productId}"',
        );
        
        if (likedResult.items.isNotEmpty) {
          await authProvider.pb.collection('user_liked_products').delete(likedResult.items.first.id);
        }
      } else {
        // Tambah like
        await authProvider.pb.collection('user_liked_products').create(body: {
          'user_id': userId,
          'product_id': widget.productId,
        });
      }

      setState(() {
        _isLiked = !_isLiked;
      });

    } catch (e) {
      debugPrint('Error toggling like: $e');
      _showSnackBar('Gagal mengubah status like', isError: true);
    }
  }

  // Fungsi untuk menambah ke keranjang
  Future<void> _addToCart() async {
    if (_product == null) return;
    
    // Animasi bounce untuk feedback
    _bounceController.forward().then((_) => _bounceController.reverse());
    
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
      
      _showSnackBar('${_product!['name']} successfully added to cart');

    } catch (e) {
      _showSnackBar('Gagal menambahkan ke keranjang', isError: true);
    }
  }

  // Helper function untuk menampilkan snackbar
  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // Widget untuk carousel gambar yang indah
Widget _buildImageCarousel() {
  // Pastikan ada gambar untuk ditampilkan
  List<Map<String, dynamic>> images = [];
  
  if (_allImages.isNotEmpty) {
    images = _allImages;
  } else if (_product != null && _product!['image_url'] != null && _product!['image_url'].toString().isNotEmpty) {
    // Fallback ke gambar utama jika tidak ada gambar di _allImages
    images = [
      {
        'id': 'fallback',
        'product_id': widget.productId,
        'image_url': _product!['image_url'].toString(),
        'sort_order': 0,
        'source': 'products',
      }
    ];
  } else {
    // Placeholder jika tidak ada gambar sama sekali
    images = [
      {
        'id': 'placeholder',
        'product_id': widget.productId,
        'image_url': 'https://via.placeholder.com/400x400/FFB6C1/FFFFFF?text=No+Image',
        'sort_order': 0,
        'source': 'placeholder',
      }
    ];
  }
  
  return Container(
    height: 320,
    width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 25,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          // PageView untuk swipe gambar
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() => _selectedImageIndex = index);
            },
            itemBuilder: (context, index) {
              final imageUrl = images[index]['image_url'].toString();
              
              return Hero(
                tag: 'product_image_${images[index]['id']}',
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFEC407A).withOpacity(0.08),
                        const Color(0xFFF48FB1).withOpacity(0.08),
                      ],
                    ),
                  ),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.grey[100]!,
                              Colors.grey[50]!,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  color: const Color(0xFFEC407A),
                                  strokeWidth: 3,
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Loading image...',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.grey[100]!,
                              Colors.grey[50]!,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, size: 56, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'Image not available',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          
          // Indikator gambar yang indah (hanya tampil jika ada lebih dari 1 gambar)
          if (images.length > 1)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: images.asMap().entries.map((entry) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _selectedImageIndex == entry.key ? 28 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _selectedImageIndex == entry.key
                          ? const Color(0xFFEC407A)
                          : Colors.white.withOpacity(0.7),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    ),
  );
}

  // Widget untuk selector varian yang indah
  Widget _buildVariantSelector() {
    if (_productVariants.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFEC407A).withOpacity(0.15),
                      const Color(0xFFF48FB1).withOpacity(0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.straighten_rounded,
                  color: const Color(0xFFEC407A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Ukuran',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    Text(
                      'Tersedia ${_productVariants.length} pilihan ukuran',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _productVariants.asMap().entries.map((entry) {
              final index = entry.key;
              final variant = entry.value;
              final isSelected = index == _selectedVariantIndex;
              
              return GestureDetector(
                onTap: () => setState(() => _selectedVariantIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isSelected ? LinearGradient(
                      colors: [const Color(0xFFEC407A), const Color(0xFFF48FB1)],
                    ) : null,
                    color: isSelected ? null : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : Colors.grey[300]!,
                      width: 1.5,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: const Color(0xFFEC407A).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ] : null,
                  ),
                  child: Text(
                    variant['variant_size'],
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Widget untuk form review
  Widget _buildReviewForm() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFEC407A).withOpacity(0.08),
            const Color(0xFFF48FB1).withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEC407A).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tulis Review Anda',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          
          // Rating selector
          Text(
            'Rating',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => setState(() => _selectedRating = index + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.star_rounded,
                    size: 32,
                    color: index < _selectedRating 
                        ? Colors.amber 
                        : Colors.grey[300],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          
          // Title input
          Text(
            'Judul Review',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reviewTitleController,
            decoration: InputDecoration(
              hintText: 'Berikan judul untuk review Anda',
              hintStyle: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[500],
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          const SizedBox(height: 16),
          
          // Comment input
          Text(
            'Komentar',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reviewCommentController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Bagikan pengalaman Anda menggunakan produk ini',
              hintStyle: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[500],
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          const SizedBox(height: 20),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmittingReview ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC407A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmittingReview
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Kirim Review',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showReviewForm = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEC407A),
                    side: BorderSide(color: const Color(0xFFEC407A)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF48FB1), Color(0xFFEC407A)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              Text(
                'Memuat detail produk...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFEC407A)),
                ),
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
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          backgroundColor: const Color(0xFFF8BBD0),
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.error_outline_rounded, size: 40, color: Colors.red[400]),
                ),
                const SizedBox(height: 24),
                Text(
                  'Terjadi Kesalahan',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.poppins(color: Colors.red[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadProductData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    'Coba Lagi',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC407A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
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
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
          ),
          backgroundColor: const Color(0xFFF8BBD0),
          elevation: 0,
        ),
        body: const Center(child: Text('Produk tidak ditemukan')),
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
        elevation: 0,
        actions: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: IconButton(
              icon: Icon(
                _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isLiked ? Colors.red : Colors.white,
                size: 24,
              ),
              onPressed: _toggleLike,
            ),
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Consumer<CartProvider>(
              builder: (context, cartProvider, child) {
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 24),
                      onPressed: () => Navigator.pushNamed(context, '/cart'),
                    ),
                    if (cartProvider.items.isNotEmpty)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
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
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                
                // Carousel gambar yang indah
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildImageCarousel(),
                ),
                
                const SizedBox(height: 24),
                
                // Info produk utama
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _product!['brand'],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Nama produk
                      Text(
                        _product!['name'],
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Rating dan review count
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: index < _product!['rating'] 
                                  ? Colors.amber 
                                  : Colors.grey[300],
                            );
                          }),
                          const SizedBox(width: 8),
                          Text(
                            '(${_productReviews.length} ulasan)',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Harga dengan desain menarik
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFEC407A).withOpacity(0.12),
                              const Color(0xFFF48FB1).withOpacity(0.12),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFEC407A).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [const Color(0xFFEC407A), const Color(0xFFF48FB1)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Harga',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Rp ${_formatPrice(_getCurrentPrice())}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFEC407A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Quantity selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jumlah',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF333333),
                                ),
                              ),
                              Text(
                                'Pilih jumlah yang diinginkan',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                                  icon: const Icon(Icons.remove_rounded, size: 20),
                                  color: _quantity > 1 ? const Color(0xFFEC407A) : Colors.grey,
                                  padding: const EdgeInsets.all(8),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Text(
                                    _quantity.toString(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF333333),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => setState(() => _quantity++),
                                  icon: const Icon(Icons.add_rounded, size: 20),
                                  color: const Color(0xFFEC407A),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Selector varian
                _buildVariantSelector(),
                
                const SizedBox(height: 20),
                
                // Deskripsi produk dan info jenis kulit
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFEC407A).withOpacity(0.15),
                                  const Color(0xFFF48FB1).withOpacity(0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.description_rounded,
                              color: const Color(0xFFEC407A),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
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
                                Text(
                                  'Detail lengkap tentang produk',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _product!['description'],
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Info jenis kulit
                      Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFFEC407A).withOpacity(0.08),
        const Color(0xFFF48FB1).withOpacity(0.08),
      ],
    ),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: const Color(0xFFEC407A).withOpacity(0.2),
    ),
  ),
  child: Row(
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFEC407A), const Color(0xFFF48FB1)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.face_rounded, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cocok untuk Jenis Kulit',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _getSkinTypeNames(),
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFFEC407A),
                fontWeight: FontWeight.w600,
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
                
                const SizedBox(height: 20),
                
                // Bagian Review
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFEC407A).withOpacity(0.15),
                                      const Color(0xFFF48FB1).withOpacity(0.15),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.star_rounded,
                                  color: const Color(0xFFEC407A),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ulasan Produk',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF333333),
                                    ),
                                  ),
                                  Text(
                                    '${_productReviews.length} ulasan',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          OutlinedButton(
                            onPressed: () => setState(() => _showReviewForm = !_showReviewForm),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEC407A),
                              side: BorderSide(color: const Color(0xFFEC407A).withOpacity(0.5)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: Text(
                              'Tulis Ulasan',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Daftar review
                      if (_productReviews.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.rate_review_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada ulasan',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Jadilah yang pertama memberikan ulasan untuk produk ini!',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        ...List.generate(_productReviews.length, (index) {
                          final review = _productReviews[index];
                          return Container(
                            padding: const EdgeInsets.only(bottom: 20),
                            margin: EdgeInsets.only(bottom: index < _productReviews.length - 1 ? 20 : 0),
                            decoration: BoxDecoration(
                              border: index < _productReviews.length - 1
                                  ? Border(bottom: BorderSide(color: Colors.grey[200]!))
                                  : null,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFEC407A).withOpacity(0.2),
                                        const Color(0xFFF48FB1).withOpacity(0.2),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: const Color(0xFFEC407A),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              review['user_name'],
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: const Color(0xFF333333),
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: List.generate(5, (starIndex) {
                                              return Icon(
                                                Icons.star_rounded,
                                                size: 14,
                                                color: starIndex < review['rating'] 
                                                    ? Colors.amber 
                                                    : Colors.grey[300],
                                              );
                                            }),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        review['title'],
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: const Color(0xFF333333),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        review['comment'],
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        DateTime.parse(review['created']).toString().split(' ')[0],
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Form review (jika ditampilkan)
                if (_showReviewForm) ...[
                  _buildReviewForm(),
                  const SizedBox(height: 20),
                ],
                
                const SizedBox(height: 120), // Space untuk bottom button
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _bounceController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _bounceAnimation.value,
                  child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF48FB1), Color(0xFFEC407A)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEC407A).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _addToCart,
                      icon: const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.white, size: 22),
                      label: Text(
                        'Add to Cart - Rp ${_formatPrice(_getCurrentPrice() * _quantity)}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
