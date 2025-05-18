import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../constants/colors.dart';

class AllProductsScreen extends StatelessWidget {
  const AllProductsScreen({super.key});

  void _addToCart(Map<String, dynamic> product, BuildContext context) {
    Provider.of<CartProvider>(context, listen: false).addToCart(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['name']} ditambahkan ke keranjang!'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> allProducts = [
      {
        'name': 'Nutrishe Intensive Bright & Glow Serum',
        'price': 195200,
        'image': 'assets/images/serum.png',
        'description': 'Mencerahkan kulit, mengurangi dark spot, dan menjaga skin barrier.',
        'discount': '20% Rp.166.000',
      },
      {
        'name': 'Finally Found You! SOY BRIGHT! Gel Moisturizer',
        'price': 129000,
        'image': 'assets/images/moisturizer.png',
        'description': 'Gel pelembap ringan yang melembapkan kulit kering.',
      },
      {
        'name': 'The Ordinary Lactic Acid 10% + HA',
        'price': 258000,
        'image': 'assets/images/serum.png',
        'description': 'Exfoliating serum untuk kulit cerah dan halus.',
      },
      {
        'name': 'Finally Found You! SOY GENTLE! Face Cleanser',
        'price': 99000,
        'image': 'assets/images/cleanser.png',
        'description': 'Pembersih wajah lembut untuk kulit kering.',
      },
      {
        'name': 'Labore GentileBiome Skin Nutrition Gel',
        'price': 127000,
        'image': 'assets/images/moisturizer.png',
        'description': 'Gel pelembap ringan untuk nutrisi kulit.',
      },
      {
        'name': 'Hydriceing & Brightening Essence Booster',
        'price': 149000,
        'image': 'assets/images/toner.png',
        'description': 'Essence booster untuk mencerahkan dan menghidrasi kulit.',
      },
      {
        'name': 'Rice Up! Peel-off Mask 50gr',
        'price': 99000,
        'image': 'assets/images/claymask.png',
        'description': 'Masker peel-off untuk mengangkat kotoran dan sebum.',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'All Products',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Container(
        color: const Color(0xFFFDEDF4), // Latar belakang pink pastel
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header dengan judul dekoratif
              const Padding(
                padding: EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'Explore All Products',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.pink,
                  ),
                ),
              ),
              // Grid Produk
              Expanded(
                child: GridView.builder(
                  itemCount: allProducts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    childAspectRatio: 0.75,
                  ),
                  itemBuilder: (context, index) {
                    final product = allProducts[index];
                    return Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            child: Image.asset(
                              product['image'],
                              height: 130,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  product['description'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (product['discount'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      product['discount'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Rp ${product['price']}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _addToCart(product, context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary.withOpacity(0.9),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: const Text(
                                  'Tambah ke Keranjang',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}