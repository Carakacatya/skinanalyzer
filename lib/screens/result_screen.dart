import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import 'main_nav_screen.dart';

class ResultScreen extends StatefulWidget {
  final String skinType;
  final Map<String, dynamic> analysisResult;

  const ResultScreen({
    super.key,
    required this.skinType,
    required this.analysisResult,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _recommendedProducts = [];
  bool _isLoadingProducts = true;
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

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
    
    _saveSkinTypeResult();
    _loadRecommendedProducts();
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
    super.dispose();
  }

  Future<void> _saveSkinTypeResult() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('skinType', widget.skinType);
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isLoggedIn) {
        final userId = authProvider.pb.authStore.model?.id;
        if (userId != null) {
          await authProvider.pb.collection('users').update(userId, body: {
            'skin_type': widget.skinType,
          });
        }
      }
    } catch (e) {
      debugPrint('Error saving skin type: $e');
    }
  }

  Future<void> _loadRecommendedProducts() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final pb = authProvider.pb;
      
      // Get skin type keywords for better matching
      final skinTypeKeywords = _getSkinTypeKeywords(widget.skinType);
      
      // Fetch all products first
      final allProducts = await pb.collection('products').getList(
        page: 1,
        perPage: 100,
        sort: '-created',
      );
      
      List<Map<String, dynamic>> matchedProducts = [];
      
      for (var record in allProducts.items) {
        final product = {
          'id': record.id,
          'name': record.data['name'] ?? '',
          'price': record.data['price'] ?? 0,
          'image_url': record.data['image_url'] ?? '',
          'description': record.data['description'] ?? '',
          'rating': record.data['rating'] ?? 0,
          'skin_type': record.data['skin_type'] ?? [],
          'brand': record.data['brand'] ?? '',
        };
        
        // Check if product matches user's skin type
        bool isMatch = false;
        final productSkinTypes = product['skin_type'];
        
        if (productSkinTypes is List) {
          for (var productType in productSkinTypes) {
            final normalizedProductType = productType.toString().toLowerCase().trim();
            for (var keyword in skinTypeKeywords) {
              if (normalizedProductType == keyword.toLowerCase() || 
                  normalizedProductType.contains(keyword.toLowerCase())) {
                isMatch = true;
                break;
              }
            }
            if (isMatch) break;
          }
        } else if (productSkinTypes is String && productSkinTypes.isNotEmpty) {
          final normalizedProductType = productSkinTypes.toLowerCase().trim();
          for (var keyword in skinTypeKeywords) {
            if (normalizedProductType == keyword.toLowerCase() || 
                normalizedProductType.contains(keyword.toLowerCase())) {
              isMatch = true;
              break;
            }
          }
        }
        
        // Also check product name and description for keywords
        if (!isMatch) {
          final name = product['name']?.toString().toLowerCase() ?? '';
          final description = product['description']?.toString().toLowerCase() ?? '';
          final contentKeywords = _getContentKeywords(widget.skinType);
          
          for (var keyword in contentKeywords) {
            if (name.contains(keyword.toLowerCase()) || 
                description.contains(keyword.toLowerCase())) {
              isMatch = true;
              break;
            }
          }
        }
        
        if (isMatch) {
          matchedProducts.add(product);
        }
      }
      
      // Limit to 4 products for compact display
      if (matchedProducts.length > 4) {
        matchedProducts = matchedProducts.sublist(0, 4);
      }
      
      setState(() {
        _recommendedProducts = matchedProducts;
        _isLoadingProducts = false;
      });
      
    } catch (e) {
      debugPrint('Error loading recommended products: $e');
      setState(() {
        _isLoadingProducts = false;
      });
    }
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

  String _getSkinTypeDescription(String skinType) {
    switch (skinType.toLowerCase()) {
      case 'kering':
      case 'dry':
        return 'Kulit kering membutuhkan hidrasi ekstra dan produk yang dapat mempertahankan kelembaban alami kulit.';
      case 'berminyak':
      case 'oily':
        return 'Kulit berminyak memerlukan produk yang dapat mengontrol produksi minyak berlebih tanpa membuat kulit kering.';
      case 'sensitif':
      case 'sensitive':
        return 'Kulit sensitif membutuhkan produk yang lembut, bebas dari bahan kimia keras dan pewangi yang dapat menyebabkan iritasi.';
      case 'kombinasi':
      case 'combination':
        return 'Kulit kombinasi memerlukan perawatan yang seimbang untuk area berminyak dan kering pada wajah.';
      default:
        return 'Jenis kulit Anda memerlukan perawatan khusus sesuai dengan karakteristiknya.';
    }
  }

  List<String> _getSkinCareTips(String skinType) {
    switch (skinType.toLowerCase()) {
      case 'kering':
      case 'dry':
        return [
          'Gunakan pembersih yang lembut dan tidak mengandung alkohol',
          'Aplikasikan pelembab segera setelah mandi saat kulit masih lembab',
          'Gunakan humidifier di ruangan untuk menjaga kelembaban udara',
          'Hindari air panas saat mandi atau mencuci wajah',
          'Pilih produk dengan kandungan hyaluronic acid dan ceramide'
        ];
      case 'berminyak':
      case 'oily':
        return [
          'Bersihkan wajah 2 kali sehari dengan pembersih yang mengandung salicylic acid',
          'Gunakan toner bebas alkohol untuk menyeimbangkan pH kulit',
          'Pilih pelembab yang ringan dan oil-free',
          'Gunakan clay mask 1-2 kali seminggu untuk mengontrol minyak',
          'Jangan skip pelembab meski kulit berminyak'
        ];
      case 'sensitif':
      case 'sensitive':
        return [
          'Pilih produk yang hypoallergenic dan bebas pewangi',
          'Lakukan patch test sebelum menggunakan produk baru',
          'Gunakan pembersih yang sangat lembut dan bebas sulfat',
          'Hindari scrub atau exfoliating yang kasar',
          'Gunakan sunscreen mineral dengan SPF minimal 30'
        ];
      case 'kombinasi':
      case 'combination':
        return [
          'Gunakan produk yang berbeda untuk area T-zone dan pipi',
          'Bersihkan wajah dengan gentle cleanser 2 kali sehari',
          'Aplikasikan pelembab ringan di seluruh wajah',
          'Gunakan clay mask hanya di area berminyak',
          'Pilih produk dengan kandungan niacinamide untuk menyeimbangkan kulit'
        ];
      default:
        return [
          'Konsultasikan dengan dermatologist untuk perawatan yang tepat',
          'Selalu gunakan sunscreen setiap hari',
          'Jaga kebersihan wajah dengan rutin',
          'Minum air yang cukup untuk hidrasi dari dalam',
          'Hindari menyentuh wajah dengan tangan kotor'
        ];
    }
  }

  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 70, // COMPACT SIZE FOR MOBILE
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
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
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUrl,
        width: 70, // COMPACT SIZE FOR MOBILE
        height: 70,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          
          return Container(
            width: 70,
            height: 70,
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
            child: Center(
              child: CircularProgressIndicator(
                color: const Color(0xFFEC407A),
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
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

  String _formatPrice(double price) {
    return price.toStringAsFixed(0);
  }

  void _goToAllProducts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MainNavScreen(initialIndex: 1),
      ),
    );
  }

  void _goBackToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const MainNavScreen(initialIndex: 0),
      ),
      (route) => false,
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
            'Hasil Analisis',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
        ),
        backgroundColor: const Color(0xFFF8BBD0),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _goBackToHome,
        ),
      ),
      body: _isLoadingProducts
          ? Center( // CENTERED LOADING STATE FOR MOBILE
              child: Padding(
                padding: const EdgeInsets.all(20), // MOBILE PADDING
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
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
                        Icons.analytics,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Memproses hasil analisis...',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center, // CENTERED TEXT FOR MOBILE
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16), // COMPACT MOBILE PADDING
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Result Card - MOBILE OPTIMIZED
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20), // COMPACT PADDING
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFF48FB1),
                            const Color(0xFFEC407A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16), // COMPACT RADIUS
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEC407A).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 70, // COMPACT SIZE
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.face,
                              size: 35, // COMPACT ICON
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12), // COMPACT SPACING
                          Text(
                            'Jenis Kulit Anda',
                            style: GoogleFonts.poppins(
                              fontSize: 14, // COMPACT FONT
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center, // CENTERED
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.skinType.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 24, // COMPACT FONT
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center, // CENTERED
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _getSkinTypeDescription(widget.skinType),
                            style: GoogleFonts.poppins(
                              fontSize: 12, // COMPACT FONT
                              color: Colors.white.withOpacity(0.9),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center, // CENTERED
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20), // COMPACT SPACING

                  // Tips Section - MOBILE OPTIMIZED
                  SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16), // COMPACT PADDING
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            const Color(0xFFFCE4EC).withOpacity(0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16), // COMPACT RADIUS
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEC407A).withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFEC407A).withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40, // COMPACT SIZE
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFF48FB1),
                                      const Color(0xFFEC407A),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEC407A).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.lightbulb_outline,
                                  color: Colors.white,
                                  size: 20, // COMPACT ICON
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tips Perawatan',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16, // COMPACT FONT
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF333333),
                                      ),
                                    ),
                                    Text(
                                      'Khusus untuk kulit ${widget.skinType.toLowerCase()}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10, // COMPACT FONT
                                        color: const Color(0xFFEC407A),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...(_getSkinCareTips(widget.skinType).asMap().entries.map((entry) {
                            final index = entry.key;
                            final tip = entry.value;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8), // COMPACT MARGIN
                              padding: const EdgeInsets.all(12), // COMPACT PADDING
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFEC407A).withOpacity(0.1),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24, // COMPACT SIZE
                                    height: 24,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFFF48FB1),
                                          const Color(0xFFEC407A),
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 10, // COMPACT FONT
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      tip,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11, // COMPACT FONT
                                        color: Colors.grey[800],
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList()),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Recommended Products Section - MOBILE OPTIMIZED
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16), // COMPACT PADDING
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6), // COMPACT PADDING
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEC407A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.shopping_bag_outlined,
                                  color: Color(0xFFEC407A),
                                  size: 18, // COMPACT ICON
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Produk Rekomendasi',
                                style: GoogleFonts.poppins(
                                  fontSize: 16, // COMPACT FONT
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF333333),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          if (_recommendedProducts.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 40, // COMPACT SIZE
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Belum ada produk yang cocok untuk jenis kulit Anda',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12, // COMPACT FONT
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Column(
                              children: [
                                ..._recommendedProducts.map((product) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8), // COMPACT MARGIN
                                    padding: const EdgeInsets.all(10), // COMPACT PADDING
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/productDetail',
                                          arguments: {'id': product['id']},
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Row(
                                        children: [
                                          _buildProductImage(product['image_url']),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  product['name'],
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12, // COMPACT FONT
                                                    color: Colors.grey[800],
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  product['description'],
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10, // COMPACT FONT
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Rp ${_formatPrice(product['price'].toDouble())}',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12, // COMPACT FONT
                                                    color: const Color(0xFFEC407A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                                
                                const SizedBox(height: 12),
                                
                                // View All Products Button - MOBILE OPTIMIZED
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _goToAllProducts,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEC407A),
                                      padding: const EdgeInsets.symmetric(vertical: 12), // COMPACT PADDING
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: Text(
                                      'Lihat Semua Produk',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14, // COMPACT FONT
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons - MOBILE OPTIMIZED
                  SlideTransition(
                    position: _slideAnimation,
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/quiz');
                            },
                            icon: const Icon(Icons.refresh, color: Colors.white, size: 18), // COMPACT ICON
                            label: Text(
                              'Ulangi Quiz',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12, // COMPACT FONT
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[600],
                              padding: const EdgeInsets.symmetric(vertical: 12), // COMPACT PADDING
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _goBackToHome,
                            icon: const Icon(Icons.home, color: Colors.white, size: 18), // COMPACT ICON
                            label: Text(
                              'Beranda',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12, // COMPACT FONT
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEC407A),
                              padding: const EdgeInsets.symmetric(vertical: 12), // COMPACT PADDING
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20), // BOTTOM PADDING FOR MOBILE
                ],
              ),
            ),
    );
  }
}