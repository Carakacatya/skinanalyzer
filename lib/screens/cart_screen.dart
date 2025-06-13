import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/cart_provider.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  void _goToCheckout(BuildContext context, List<Map<String, dynamic>> selectedItems) {
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih produk terlebih dahulu')),
      );
      return;
    }

    Navigator.pushNamed(context, '/checkout', arguments: selectedItems);
  }

  Widget _buildProductImage(Map<String, dynamic> item) {
    // Check if the product has image_url (new structure from PocketBase)
    if (item.containsKey('image_url') && item['image_url'] != null && item['image_url'].toString().isNotEmpty) {
      print('Loading network image from: ${item['image_url']}');
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          item['image_url'],
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 60,
              height: 60,
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
            print('Error loading cart image: $error');
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
    } 
    // Fallback to the old structure with local assets
    else if (item.containsKey('image') && item['image'] != null) {
      print('Loading asset image from: ${item['image']}');
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          item['image'],
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Error loading asset image: $error');
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
    } 
    // If no image is available
    else {
      print('No image found for product: ${item['name']}');
      return Container(
        width: 60,
        height: 60,
        color: Colors.grey[200],
        child: const Icon(
          Icons.image_not_supported,
          size: 30,
          color: Colors.grey,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final cart = cartProvider.items;

    // Debug: Print cart items
    print('Cart items count: ${cart.length}');
    for (var item in cart) {
      print('Cart item: ${item['name']}, Image: ${item['image_url'] ?? item['image'] ?? 'No image'}');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang'),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: cart.isEmpty
          ? const Center(child: Text('Keranjang kosong'))
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: cart.length,
                      itemBuilder: (context, index) {
                        final item = cart[index];
                        return Card(
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
                                ),
                                _buildProductImage(item),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'],
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Rp ${item['price']} x ${item['quantity']}',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'Total: Rp ${item['price'] * item['quantity']}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: () {
                                        item['quantity'] += 1;
                                        cartProvider.notifyListeners();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: () {
                                        if (item['quantity'] > 1) {
                                          item['quantity'] -= 1;
                                        } else {
                                          cartProvider.removeFromCart(index);
                                        }
                                        cartProvider.notifyListeners();
                                      },
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => cartProvider.removeFromCart(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Harga Terpilih:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Rp ${cartProvider.selectedTotalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
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
                      onPressed: () => _goToCheckout(context, cartProvider.selectedItems),
                      icon: const Icon(Icons.payment),
                      label: const Text('Checkout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}