import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCart();
    });
  }

  Future<void> _refreshCart() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    await cartProvider.refreshCart();
  }

  void _goToCheckout(BuildContext context, List<Map<String, dynamic>> selectedItems) {
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pilih produk terlebih dahulu',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.pushNamed(context, '/checkout', arguments: selectedItems);
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
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 60,
              height: 60,
              color: Colors.grey[200],
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

  Future<void> _updateQuantity(CartProvider cartProvider, int index, int change) async {
    final item = cartProvider.items[index];
    final newQuantity = item['quantity'] + change;

    if (newQuantity <= 0) {
      await cartProvider.removeFromCart(index);
    } else {
      item['quantity'] = newQuantity;
      cartProvider.notifyListeners();
      await cartProvider.syncWithPocketBase();
    }
  }

  Future<void> _deleteItem(CartProvider cartProvider, int index) async {
    final item = cartProvider.items[index];
    
    // Show confirmation snackbar with undo option
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${item['name']} dihapus dari keranjang',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () {
            // Re-add the item
            cartProvider.addToCart(item);
          },
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    
    await cartProvider.removeFromCart(index);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CartProvider, AuthProvider>(
      builder: (context, cartProvider, authProvider, child) {
        final cart = cartProvider.items;
        final isLoading = cartProvider.isLoading;
        final isSyncing = cartProvider.isSyncing;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Keranjang',
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
            actions: [
              if (isSyncing)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (cart.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          'Hapus Semua',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        content: Text(
                          'Yakin ingin menghapus semua item dari keranjang?',
                          style: GoogleFonts.poppins(),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              'Batal',
                              style: GoogleFonts.poppins(),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              'Hapus',
                              style: GoogleFonts.poppins(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await cartProvider.clearCart();
                    }
                  },
                ),
            ],
          ),
          body: isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Loading cart...',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : cart.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.shopping_cart_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Keranjang kosong',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tambahkan produk ke keranjang untuk melanjutkan',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/products'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Mulai Belanja',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: _refreshCart,
                              color: AppColors.primary,
                              child: ListView.builder(
                                itemCount: cart.length,
                                itemBuilder: (context, index) {
                                  final item = cart[index];
                                  return Dismissible(
                                    key: Key('cart_item_${item['id']}_$index'),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      margin: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.delete,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Hapus',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    confirmDismiss: (direction) async {
                                      return await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(
                                            'Hapus Item',
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                          ),
                                          content: Text(
                                            'Yakin ingin menghapus ${item['name']} dari keranjang?',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: Text(
                                                'Batal',
                                                style: GoogleFonts.poppins(),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: Text(
                                                'Hapus',
                                                style: GoogleFonts.poppins(color: Colors.red),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    onDismissed: (direction) {
                                      _deleteItem(cartProvider, index);
                                    },
                                    child: Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                      margin: const EdgeInsets.symmetric(vertical: 8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Checkbox(
                                              value: item['isSelected'] ?? false,
                                              onChanged: (_) {
                                                cartProvider.toggleSelection(index);
                                              },
                                              activeColor: AppColors.primary,
                                            ),
                                            _buildProductImage(item),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item['name'] ?? 'Unknown Product',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Rp ${_formatPrice(item['price'])} x ${item['quantity']}',
                                                    style: GoogleFonts.poppins(
                                                      color: AppColors.primary,
                                                      fontWeight: FontWeight.w500,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Total: Rp ${_formatPrice(_getItemPrice(item) * item['quantity'])}',
                                                    style: GoogleFonts.poppins(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.add_circle_outline),
                                                  onPressed: () => _updateQuantity(cartProvider, index, 1),
                                                  color: AppColors.primary,
                                                ),
                                                Text(
                                                  '${item['quantity']}',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.remove_circle_outline),
                                                  onPressed: () => _updateQuantity(cartProvider, index, -1),
                                                  color: Colors.grey[600],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Harga Terpilih:',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Rp ${_formatPrice(cartProvider.selectedTotalPrice)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: cartProvider.selectedItems.isEmpty
                                        ? null
                                        : () => _goToCheckout(context, cartProvider.selectedItems),
                                    icon: const Icon(Icons.payment),
                                    label: Text(
                                      'Checkout (${cartProvider.selectedItems.length} item)',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      disabledBackgroundColor: Colors.grey[300],
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
      },
    );
  }

  double _getItemPrice(Map<String, dynamic> item) {
    final price = item['price'];
    if (price is String) {
      return double.tryParse(price) ?? 0.0;
    }
    return (price ?? 0).toDouble();
  }

  String _formatPrice(dynamic price) {
    double priceValue;
    if (price is String) {
      priceValue = double.tryParse(price) ?? 0.0;
    } else {
      priceValue = (price ?? 0).toDouble();
    }
    return priceValue.toStringAsFixed(0);
  }
}
