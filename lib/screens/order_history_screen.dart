import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import '../constants/colors.dart';
import '../providers/auth_provider.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _error;
  
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
    
    _loadOrders();
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
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.pb.authStore.model?.id;

      debugPrint('=== LOADING ORDERS ===');
      debugPrint('User ID: $userId');

      final records = await authProvider.pb.collection('orders').getFullList(
        filter: 'user = "$userId"',
        sort: '-created',
        expand: 'address_id,payment_method',
      );

      debugPrint('Found ${records.length} orders');

      List<Map<String, dynamic>> orders = [];

      for (var record in records) {
        debugPrint('Processing order: ${record.id}');
        
        // Get order items
        final orderItems = await authProvider.pb.collection('order_items').getFullList(
          filter: 'order_id = "${record.id}"',
          expand: 'product',
        );

        debugPrint('Found ${orderItems.length} order items');

        // Handle expanded relations safely
        String address = '';
        String paymentMethod = '';
        
        try {
          if (record.expand != null) {
            final addressExpand = record.expand!['address_id'];
            address = _extractAddressFromExpand(addressExpand);
            
            final paymentExpand = record.expand!['payment_method'];
            paymentMethod = _extractPaymentMethodFromExpand(paymentExpand);
          }
        } catch (e) {
          debugPrint('Error processing expand relations: $e');
        }

        // Process order items
        List<Map<String, dynamic>> items = [];
        for (var item in orderItems) {
          String productName = _extractProductNameFromExpand(item.expand);
          String productImage = _extractProductImageFromExpand(item.expand);
          
          items.add({
            'product_name': productName,
            'product_image': productImage,
            'quantity': item.data['quantity'] ?? 1,
            'price': item.data['price'] ?? 0,
            'subtotal': item.data['subtotal'] ?? 0,
          });
        }

        // Generate order number if missing
        String orderNumber = record.data['order_number']?.toString() ?? '';
        if (orderNumber.isEmpty || orderNumber == 'N/A') {
          final createdDate = DateTime.parse(record.created);
          orderNumber = 'ORD-${createdDate.year}${createdDate.month.toString().padLeft(2, '0')}${createdDate.day.toString().padLeft(2, '0')}-${record.id.substring(0, 6).toUpperCase()}';
        }

        orders.add({
          'id': record.id,
          'order_number': orderNumber,
          'total': record.data['total'] ?? 0,
          'order_status': record.data['order_status']?.toString() ?? 'pending',
          'created': record.created,
          'items': items,
          'address': address,
          'payment_method': paymentMethod,
        });

        debugPrint('Order processed: $orderNumber');
      }

      setState(() {
        _orders = orders;
        _isLoading = false;
      });

      debugPrint('Orders loaded successfully: ${_orders.length} orders');
    } catch (e) {
      debugPrint('Error loading orders: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _extractAddressFromExpand(dynamic addressExpand) {
    try {
      if (addressExpand == null) return '';
      
      if (addressExpand is List<RecordModel>) {
        if (addressExpand.isNotEmpty) {
          final addr = addressExpand.first.data;
          return '${addr['Jalan'] ?? ''}, ${addr['Kecamatan'] ?? ''}, ${addr['Kota'] ?? ''}'.replaceAll(RegExp(r'^,\s*|,\s*$'), '');
        }
      } else if (addressExpand is RecordModel) {
        final addr = addressExpand.data;
        return '${addr['Jalan'] ?? ''}, ${addr['Kecamatan'] ?? ''}, ${addr['Kota'] ?? ''}'.replaceAll(RegExp(r'^,\s*|,\s*$'), '');
      }
    } catch (e) {
      debugPrint('Error extracting address: $e');
    }
    return '';
  }

  String _extractPaymentMethodFromExpand(dynamic paymentExpand) {
    try {
      if (paymentExpand == null) return '';
      
      if (paymentExpand is List<RecordModel>) {
        if (paymentExpand.isNotEmpty) {
          return paymentExpand.first.data['name']?.toString() ?? '';
        }
      } else if (paymentExpand is RecordModel) {
        return paymentExpand.data['name']?.toString() ?? '';
      }
    } catch (e) {
      debugPrint('Error extracting payment method: $e');
    }
    return '';
  }

  String _extractProductNameFromExpand(Map<String, dynamic>? expand) {
    try {
      if (expand == null || expand['product'] == null) {
        return 'Unknown Product';
      }
      
      final productExpand = expand['product'];
      
      if (productExpand is List<RecordModel>) {
        if (productExpand.isNotEmpty) {
          return productExpand.first.data['name']?.toString() ?? 'Unknown Product';
        }
      } else if (productExpand is RecordModel) {
        return productExpand.data['name']?.toString() ?? 'Unknown Product';
      }
    } catch (e) {
      debugPrint('Error extracting product name: $e');
    }
    return 'Unknown Product';
  }
  
  String _extractProductImageFromExpand(Map<String, dynamic>? expand) {
    try {
      if (expand == null || expand['product'] == null) {
        return '';
      }
      
      final productExpand = expand['product'];
      
      if (productExpand is List<RecordModel>) {
        if (productExpand.isNotEmpty) {
          return productExpand.first.data['image_url']?.toString() ?? '';
        }
      } else if (productExpand is RecordModel) {
        return productExpand.data['image_url']?.toString() ?? '';
      }
    } catch (e) {
      debugPrint('Error extracting product image: $e');
    }
    return '';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.blue;
      case 'processing':
        return Colors.purple;
      case 'shipped':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu';
      case 'paid':
        return 'Dibayar';
      case 'processing':
        return 'Diproses';
      case 'shipped':
        return 'Dikirim';
      case 'delivered':
        return 'Diterima';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status.toUpperCase();
    }
  }

  String _formatPrice(dynamic price) {
    double priceValue = (price is String) ? double.tryParse(price) ?? 0.0 : (price ?? 0).toDouble();
    return priceValue.toStringAsFixed(0);
  }
  
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.image_not_supported,
          size: 24,
          color: Colors.grey,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          
          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.grey[200]!,
                  Colors.grey[100]!,
                  Colors.grey[200]!,
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Icon(
                      Icons.image,
                      size: 20,
                      color: Colors.grey[400],
                    ),
                  );
                },
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
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
    _pulseController.repeat(reverse: true);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
                    Icons.history,
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
              'Loading order history...',
              style: GoogleFonts.poppins(
                color: Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
            'Riwayat Pesanan',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
        ),
        backgroundColor: const Color(0xFFF8BBD0),
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Error: $_error',
                            style: GoogleFonts.poppins(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: ElevatedButton(
                            onPressed: _loadOrders,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEC407A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Retry',
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
              : _orders.isEmpty
                  ? FadeTransition(
                      opacity: _fadeAnimation,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.grey[300]!,
                                      Colors.grey[400]!,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Belum ada pesanan',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Mulai berbelanja untuk melihat\nriwayat pesanan Anda',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[600],
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.pushNamed(context, '/store_single_product'),
                                icon: const Icon(Icons.shopping_cart, color: Colors.white),
                                label: Text(
                                  'Mulai Belanja',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEC407A),
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
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
                      child: RefreshIndicator(
                        onRefresh: _loadOrders,
                        color: const Color(0xFFEC407A),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            final order = _orders[index];
                            
                            // Staggered animation for list items
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
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.08),
                                            blurRadius: 15,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Order Header
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        order['order_number'],
                                                        style: GoogleFonts.poppins(
                                                          fontWeight: FontWeight.w700,
                                                          fontSize: 16,
                                                          color: const Color(0xFF333333),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        _formatDate(order['created']),
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 12,
                                                          color: Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        _getStatusColor(order['order_status']).withOpacity(0.1),
                                                        _getStatusColor(order['order_status']).withOpacity(0.2),
                                                      ],
                                                    ),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(
                                                      color: _getStatusColor(order['order_status']),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    _getStatusText(order['order_status']),
                                                    style: GoogleFonts.poppins(
                                                      color: _getStatusColor(order['order_status']),
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            
                                            const SizedBox(height: 16),
                                            
                                            // Total Amount
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    const Color(0xFFF48FB1).withOpacity(0.1),
                                                    const Color(0xFFEC407A).withOpacity(0.1),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Total Pembayaran',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Rp ${_formatPrice(order['total'])}',
                                                    style: GoogleFonts.poppins(
                                                      color: const Color(0xFFEC407A),
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            
                                            const SizedBox(height: 16),
                                            
                                            // Payment Method & Address
                                            if (order['payment_method'].toString().isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 8),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.payment,
                                                      size: 16,
                                                      color: Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      order['payment_method'],
                                                      style: GoogleFonts.poppins(
                                                        color: Colors.grey[700],
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            
                                            if (order['address'].toString().isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 16),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Icon(
                                                      Icons.location_on,
                                                      size: 16,
                                                      color: Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        order['address'],
                                                        style: GoogleFonts.poppins(
                                                          color: Colors.grey[700],
                                                          fontSize: 13,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            
                                            // Divider
                                            Container(
                                              height: 1,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.grey[200]!,
                                                    Colors.grey[300]!,
                                                    Colors.grey[200]!,
                                                  ],
                                                ),
                                              ),
                                            ),
                                            
                                            const SizedBox(height: 16),
                                            
                                            // Items Header
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.shopping_bag,
                                                  size: 18,
                                                  color: const Color(0xFFEC407A),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Items (${order['items'].length})',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: const Color(0xFF333333),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            
                                            const SizedBox(height: 12),
                                            
                                            // Items List
                                            if (order['items'].isEmpty)
                                              Container(
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[50],
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    'No items found',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color: Colors.grey[500],
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            else
                                              ...order['items'].map<Widget>((item) => Container(
                                                margin: const EdgeInsets.only(bottom: 12),
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[50],
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.grey[200]!,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    _buildProductImage(item['product_image']),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            item['product_name'],
                                                            style: GoogleFonts.poppins(
                                                              fontWeight: FontWeight.w600,
                                                              fontSize: 13,
                                                            ),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              Text(
                                                                'Qty: ${item['quantity']}',
                                                                style: GoogleFonts.poppins(
                                                                  fontSize: 12,
                                                                  color: Colors.grey[600],
                                                                ),
                                                              ),
                                                              Text(
                                                                'Rp ${_formatPrice(item['subtotal'])}',
                                                                style: GoogleFonts.poppins(
                                                                  fontSize: 13,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: const Color(0xFFEC407A),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )).toList(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
    );
  }
}
