import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/colors.dart';
import '../providers/cart_provider.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  String? skinType;

  final Map<String, List<Map<String, dynamic>>> productData = {
    'Kering': [
      {
        'name': 'Finally Found You! SOY BRIGHT! Gel Moisturizer',
        'price': 129000,
        'image': 'assets/images/moisturizer.png',
        'description': 'Gel pelembap ringan yang melembapkan kulit kering dan menenangkan iritasi.'
      },
      {
        'name': 'Finally Found You! SOY GENTLE! Face Cleanser',
        'price': 99000,
        'image': 'assets/images/cleanser.png',
        'description': 'Pembersih wajah lembut untuk kulit kering tanpa membuat kulit terasa tertarik.'
      },
      {
        'name': 'Finally Found You! SOY CLEAR Brightening & Dark Spot Serum',
        'price': 137000,
        'image': 'assets/images/serum.png',
        'description': 'Serum untuk mencerahkan kulit dan mengurangi noda hitam pada wajah.'
      },
    ],
    'Berminyak': [
      {
        'name': 'Bundle Acne Serum + B12 Serum',
        'price': 248000,
        'image': 'assets/images/oilfree.png',
        'description': 'Paket serum untuk mengatasi jerawat dan menyeimbangkan minyak di wajah.'
      },
      {
        'name': 'Rice Up! Peel-off Mask 50gr',
        'price': 99000,
        'image': 'assets/images/claymask.png',
        'description': 'Masker peel-off untuk mengangkat kotoran dan sebum berlebih.'
      },
      {
        'name': 'Hydriceing & Brightening Essence Booster 100ml',
        'price': 149000,
        'image': 'assets/images/toner.png',
        'description': 'Essence booster untuk mencerahkan wajah dan menghidrasi kulit berminyak.'
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadSkinType();
  }

  Future<void> _loadSkinType() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      skinType = prefs.getString('skinType');
    });
  }

  void _addToCart(Map<String, dynamic> product, BuildContext context) {
    Provider.of<CartProvider>(context, listen: false).addToCart(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['name']} ditambahkan ke keranjang!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _goToCart() {
    Navigator.pushNamed(context, '/cart');
  }

  @override
  Widget build(BuildContext context) {
    final products = productData[skinType] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekomendasi Produk'),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: _goToCart,
          ),
        ],
      ),
      body: skinType == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Jenis Kulit: $skinType',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: products.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.68,
                    ),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return GestureDetector(
                        onTap: () async {
                          final addedProduct = await Navigator.pushNamed(
                            context,
                            '/productDetail',
                            arguments: product,
                          );
                          if (addedProduct != null) {
                            _addToCart(addedProduct as Map<String, dynamic>, context);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: Image.asset(
                                    product['image'],
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Rp ${product['price']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () => _addToCart(product, context),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.accent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                          child: const Text('Add to Cart'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _goToCart,
                          icon: const Icon(Icons.payment),
                          label: const Text('Lanjut ke Checkout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('skinType');
                            Navigator.pushReplacementNamed(context, '/quiz');
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.grey.shade100,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Ulangi Kuis',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
