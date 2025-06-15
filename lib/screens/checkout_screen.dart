import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';

class CheckoutScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cart;

  const CheckoutScreen({super.key, required this.cart});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isProcessing = false;
  String _selectedPaymentMethod = 'transfer';
  List<Map<String, dynamic>> _userAddresses = [];
  String? _selectedAddressId;
  bool _isLoadingAddresses = true;

  @override
  void initState() {
    super.initState();
    _loadUserAddresses();
  }

  Future<void> _loadUserAddresses() async {
    setState(() {
      _isLoadingAddresses = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.pb.authStore.model?.id;

      debugPrint('Loading addresses for user: $userId');

      final records = await authProvider.pb.collection('user_addresses').getFullList(
        filter: 'user_id = "$userId"',
        sort: '-created',
      );

      debugPrint('Found ${records.length} addresses');

      List<Map<String, dynamic>> addresses = [];
      
      for (var record in records) {
        // Check if address has meaningful data
        final jalan = record.data['Jalan']?.toString() ?? '';
        final kecamatan = record.data['Kecamatan']?.toString() ?? '';
        final kota = record.data['Kota']?.toString() ?? '';
        final provinsi = record.data['Provinsi']?.toString() ?? '';
        final kodePos = record.data['Kode_pos']?.toString() ?? '';
        
        // Only add addresses that have at least some data
        if (jalan.isNotEmpty || kecamatan.isNotEmpty || kota.isNotEmpty) {
          addresses.add({
            'id': record.id,
            'jalan': jalan,
            'kecamatan': kecamatan,
            'kota': kota,
            'provinsi': provinsi,
            'kode_pos': kodePos,
            'full_address': _buildFullAddress(record.data),
          });
        }
      }

      setState(() {
        _userAddresses = addresses;
        
        // Auto select first address if available
        if (_userAddresses.isNotEmpty) {
          _selectedAddressId = _userAddresses.first['id'];
        }
        
        _isLoadingAddresses = false;
      });

      debugPrint('Processed ${_userAddresses.length} valid addresses');
    } catch (e) {
      debugPrint('Error loading addresses: $e');
      setState(() {
        _userAddresses = [];
        _isLoadingAddresses = false;
      });
    }
  }

  String _buildFullAddress(Map<String, dynamic> data) {
    List<String> addressParts = [];
    
    if (data['Jalan'] != null && data['Jalan'].toString().trim().isNotEmpty && data['Jalan'].toString() != 'N/A') {
      addressParts.add(data['Jalan'].toString());
    }
    if (data['Kecamatan'] != null && data['Kecamatan'].toString().trim().isNotEmpty && data['Kecamatan'].toString() != 'N/A') {
      addressParts.add('Kec. ${data['Kecamatan']}');
    }
    if (data['Kota'] != null && data['Kota'].toString().trim().isNotEmpty && data['Kota'].toString() != 'N/A') {
      addressParts.add(data['Kota'].toString());
    }
    if (data['Provinsi'] != null && data['Provinsi'].toString().trim().isNotEmpty && data['Provinsi'].toString() != 'N/A') {
      addressParts.add(data['Provinsi'].toString());
    }
    if (data['Kode_pos'] != null && data['Kode_pos'].toString().trim().isNotEmpty && data['Kode_pos'].toString() != 'N/A') {
      addressParts.add(data['Kode_pos'].toString());
    }
    
    return addressParts.isNotEmpty ? addressParts.join(', ') : 'Alamat tidak lengkap';
  }

  double _calculateTotal() {
    return widget.cart.fold(0.0, (sum, item) {
      final price = _parsePrice(item['price']);
      final quantity = (item['quantity'] ?? 1).toInt();
      return sum + (price * quantity);
    });
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

  Widget _buildProductImage(Map<String, dynamic> item) {
    final imageUrl = item['image_url']?.toString() ?? '';
    
    if (imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 60,
              height: 60,
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
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.broken_image,
                size: 30,
                color: Colors.grey,
              ),
            );
          },
        ),
      );
    } else {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.image_not_supported,
          size: 30,
          color: Colors.grey,
        ),
      );
    }
  }

  Future<void> _processOrder() async {
    // Validasi alamat
    if (_selectedAddressId == null) {
      _showError('Mohon pilih alamat pengiriman');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      
      if (!authProvider.isLoggedIn) {
        throw Exception('User not logged in');
      }

      final userId = authProvider.pb.authStore.model?.id;
      final totalAmount = _calculateTotal();

      debugPrint('=== CREATING ORDER ===');
      debugPrint('User ID: $userId');
      debugPrint('Selected Address ID: $_selectedAddressId');
      debugPrint('Total Amount: $totalAmount');
      debugPrint('Cart Items: ${widget.cart.length}');

      // 1. Get payment method
      final paymentMethods = await authProvider.pb.collection('payment_methods').getFullList();
      final selectedPaymentMethod = paymentMethods.firstWhere(
        (pm) => pm.data['name'].toLowerCase().contains(_selectedPaymentMethod),
        orElse: () => paymentMethods.first,
      );

      debugPrint('Payment method: ${selectedPaymentMethod.data['name']}');

      // 2. Generate order number
      final orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch}';

      // 3. Create order
      final orderRecord = await authProvider.pb.collection('orders').create(body: {
        'user': userId,
        'address_id': _selectedAddressId,
        'payment_method': selectedPaymentMethod.id,
        'total': totalAmount,
        'order_status': 'pending',
        'order_number': orderNumber,
        'notes': 'Order created from mobile app',
      });

      debugPrint('Order created: ${orderRecord.id}');

      // 4. Create order items
      for (var item in widget.cart) {
        final price = _parsePrice(item['price']);
        final quantity = (item['quantity'] ?? 1).toInt();
        final subtotal = price * quantity;

        try {
          await authProvider.pb.collection('order_items').create(body: {
            'order_id': orderRecord.id,
            'product': item['id'],
            'quantity': quantity,
            'price': price,
            'subtotal': subtotal,
          });

          debugPrint('Order item created: ${item['name']} x$quantity = Rp$subtotal');
        } catch (itemError) {
          debugPrint('Error creating order item: $itemError');
          // Continue with other items instead of failing completely
        }
      }

      // 5. PERBAIKAN: Gunakan method baru untuk menghapus hanya item yang di-checkout
      await cartProvider.removeCheckedOutItems(widget.cart);

      debugPrint('Order processing completed successfully');

      // Get selected address for payment screen
      final selectedAddress = _userAddresses.firstWhere(
        (addr) => addr['id'] == _selectedAddressId,
        orElse: () => {'full_address': 'Unknown Address'},
      );

      // Navigate to payment screen
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/payment',
          arguments: {
            'orderId': orderRecord.id,
            'orderNumber': orderNumber,
            'totalAmount': totalAmount,
            'paymentMethod': _selectedPaymentMethod,
            'orderItems': widget.cart,
            'address': selectedAddress['full_address'],
          },
        );
      }
    } catch (e) {
      debugPrint('Error processing order: $e');
      _showError('Gagal memproses pesanan: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = _calculateTotal();

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 248, 233, 235),
      appBar: AppBar(
        title: Text(
          'Checkout',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Items Section
            Text(
              'Pesanan Anda',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...widget.cart.map((item) {
              final price = _parsePrice(item['price']);
              final quantity = (item['quantity'] ?? 1).toInt();
              final subtotal = price * quantity;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _buildProductImage(item),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'] ?? 'Unknown Product',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rp ${_formatPrice(price)} x $quantity',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Subtotal: Rp ${_formatPrice(subtotal)}',
                              style: GoogleFonts.poppins(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
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
            
            const SizedBox(height: 24),
            
            // Shipping Address Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Alamat Pengiriman',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final result = await Navigator.pushNamed(context, '/edit_profile');
                    if (result == true) {
                      // Reload addresses if user added/updated address
                      _loadUserAddresses();
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    'Tambah',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            _isLoadingAddresses
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _userAddresses.isEmpty
                    ? Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.location_off,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Belum ada alamat tersimpan',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.pushNamed(context, '/edit_profile');
                                  if (result == true) {
                                    _loadUserAddresses();
                                  }
                                },
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(
                                  'Tambah Alamat',
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: _userAddresses.map((address) {
                          final isSelected = address['id'] == _selectedAddressId;
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected ? AppColors.primary : Colors.grey[300]!,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: RadioListTile<String>(
                              title: Text(
                                address['full_address'],
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                              value: address['id'],
                              groupValue: _selectedAddressId,
                              onChanged: (value) {
                                setState(() {
                                  _selectedAddressId = value;
                                });
                              },
                              activeColor: AppColors.primary,
                            ),
                          );
                        }).toList(),
                      ),
            
            const SizedBox(height: 24),
            
            // Payment Method Section
            Text(
              'Metode Pembayaran',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: Text(
                      'Transfer Bank',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    value: 'transfer',
                    groupValue: _selectedPaymentMethod,
                    onChanged: (value) {
                      setState(() {
                        _selectedPaymentMethod = value!;
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: Text(
                      'E-Wallet',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    value: 'ewallet',
                    groupValue: _selectedPaymentMethod,
                    onChanged: (value) {
                      setState(() {
                        _selectedPaymentMethod = value!;
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: Text(
                      'Cash on Delivery (COD)',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    value: 'cod',
                    groupValue: _selectedPaymentMethod,
                    onChanged: (value) {
                      setState(() {
                        _selectedPaymentMethod = value!;
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Total and Payment Button
            Container(
              padding: const EdgeInsets.all(20),
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
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Pembayaran:',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Rp ${_formatPrice(totalPrice)}',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _processOrder,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.payment, color: Colors.white),
                      label: Text(
                        _isProcessing ? 'Memproses...' : 'Proses Pesanan',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey[400],
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
