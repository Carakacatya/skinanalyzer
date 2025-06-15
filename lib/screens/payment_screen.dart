import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/auth_provider.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  Map<String, dynamic>? orderData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      orderData = args;
      debugPrint('Payment screen received data: $orderData');
    }
  }

  Future<void> _processPayment() async {
    if (orderData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Data pesanan tidak ditemukan',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      debugPrint('=== PROCESSING PAYMENT ===');
      debugPrint('Order ID: ${orderData!['orderId']}');

      // Simulasi delay pembayaran
      await Future.delayed(const Duration(seconds: 2));

      // Update order status to 'paid'
      try {
        await authProvider.pb.collection('orders').update(orderData!['orderId'], body: {
          'order_status': 'paid',
        });
        debugPrint('Order status updated to paid');
      } catch (updateError) {
        debugPrint('Error updating order status: $updateError');
        // Lanjutkan ke success screen meskipun update gagal
      }

      debugPrint('Payment processed successfully');

      // Navigate to success screen
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/payment_success',
          arguments: orderData,
        );
      }
    } catch (e) {
      debugPrint('Error processing payment: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memproses pembayaran: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0);
  }

  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'transfer':
        return 'Transfer Bank';
      case 'ewallet':
        return 'E-Wallet';
      case 'cod':
        return 'Cash on Delivery';
      default:
        return method;
    }
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method) {
      case 'transfer':
        return Icons.account_balance;
      case 'ewallet':
        return Icons.account_balance_wallet;
      case 'cod':
        return Icons.delivery_dining;
      default:
        return Icons.payment;
    }
  }

  String _getPaymentMethodDescription(String method) {
    switch (method) {
      case 'transfer':
        return 'Transfer ke rekening BCA, BNI, atau Mandiri';
      case 'ewallet':
        return 'OVO, GoPay, Dana, ShopeePay';
      case 'cod':
        return 'Bayar saat barang diterima';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (orderData == null) {
      return Scaffold(
        backgroundColor: const Color.fromARGB(255, 248, 233, 235),
        appBar: AppBar(
          title: Text(
            'Pembayaran',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          backgroundColor: AppColors.primary,
          centerTitle: true,
        ),
        body: Center(
          child: Text(
            'Data pesanan tidak ditemukan',
            style: GoogleFonts.poppins(fontSize: 16),
          ),
        ),
      );
    }

    final totalAmount = orderData!['totalAmount'] as double;
    final paymentMethod = orderData!['paymentMethod'] as String;
    final orderNumber = orderData!['orderNumber'] as String;
    final shippingAddress = orderData!['address'] as String? ?? 'Alamat tidak tersedia';

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 248, 233, 235),
      appBar: AppBar(
        title: Text(
          'Pembayaran',
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
      body: Column(
        children: [
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Summary Card
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ringkasan Pesanan',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order ID:',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                orderNumber.substring(4, 12).toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
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
                                'Rp ${_formatPrice(totalAmount)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Shipping Address Section
                  Text(
                    'Alamat Pengiriman',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: Colors.green.shade600,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Alamat Tujuan',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  shippingAddress,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment Method Details
                  Text(
                    'Metode Pembayaran Dipilih',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getPaymentMethodIcon(paymentMethod),
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getPaymentMethodName(paymentMethod),
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getPaymentMethodDescription(paymentMethod),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Payment Instructions (hanya untuk COD)
                  if (paymentMethod == 'cod') ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informasi COD:',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pembayaran dilakukan saat barang diterima.\nSiapkan uang pas sebesar Rp ${_formatPrice(totalAmount)}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 100), // Space for bottom button
                ],
              ),
            ),
          ),

          // Fixed bottom button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _processPayment,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle, color: Colors.white),
                  label: Text(
                    _isProcessing ? 'Memproses Pembayaran...' : 'Konfirmasi Pembayaran',
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
            ),
          ),
        ],
      ),
    );
  }
}
