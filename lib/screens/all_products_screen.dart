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
        'description': 'Gel pelembap ringan yang melembapkan kulit kering dan menenangkan iritasi.',
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
        'description': 'Pembersih wajah lembut untuk kulit kering tanpa membuat kulit terasa tertarik.',
      },
      {
        'name': 'Labore GentileBiome Skin Nutrition Gel',
        'price': 127000,
        'image': 'assets/images/moisturizer.png',
        'description': 'Gel pelembap ringan untuk nutrisi kulit.',
      },
      {
        'name': 'Hydriceing & Brightening Essence Booster 100ml',
        'price': 149000,
        'image': 'assets/images/toner.png',
        'description': 'Essence booster untuk mencerahkan wajah dan menghidrasi kulit berminyak.',
      },
      {
        'name': 'Rice Up! Peel-off Mask 50gr',
        'price': 99000,
        'image': 'assets/images/claymask.png',
        'description': 'Masker peel-off untuk mengangkat kotoran dan sebum berlebih.',
      },
      {
        'name': 'Finally Found You! SOY CLEAR Brightening & Dark Spot Serum',
        'price': 137000,
        'image': 'assets/images/serum.png',
        'description': 'Serum untuk mencerahkan kulit dan mengurangi noda hitam pada wajah.',
      },
      {
        'name': 'Bundle Acne Serum + B12 Serum',
        'price': 248000,
        'image': 'assets/images/oilfree.png',
        'description': 'Paket serum untuk mengatasi jerawat dan menyeimbangkan minyak di wajah.',
      },
      {
        'name': 'Calm & Soothe! Hypoallergenic Moisturizer',
        'price': 115000,
        'image': 'assets/images/sensitive_moisturizer.png',
        'description': 'Pelembap hipoalergenik untuk kulit sensitif, menenangkan kemerahan.',
      },
      {
        'name': 'Gentle Touch! Fragrance-Free Cleanser',
        'price': 89000,
        'image': 'assets/images/sensitive_cleanser.png',
        'description': 'Pembersih wajah tanpa pewangi untuk kulit sensitif, lembut dan tidak mengiritasi.',
      },
      {
        'name': 'Barrier Boost! Soothing Serum',
        'price': 125000,
        'image': 'assets/images/sensitive_serum.png',
        'description': 'Serum untuk memperkuat lapisan kulit dan mengurangi iritasi pada kulit sensitif.',
      },
      {
        'name': 'Balance It! Lightweight Moisturizer',
        'price': 110000,
        'image': 'assets/images/combination_moisturizer.png',
        'description': 'Pelembap ringan untuk kulit kombinasi, melembapkan tanpa berminyak.',
      },
      {
        'name': 'Pure Clean! Dual-Phase Cleanser',
        'price': 95000,
        'image': 'assets/images/combination_cleanser.png',
        'description': 'Pembersih wajah untuk kulit kombinasi, mengontrol minyak dan menjaga kelembapan.',
      },
      {
        'name': 'Even Tone! Balancing Serum',
        'price': 130000,
        'image': 'assets/images/combination_serum.png',
        'description': 'Serum untuk menyeimbangkan kulit kombinasi dan mencerahkan warna kulit.',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Semua Produk'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.65,
          ),
          itemCount: allProducts.length,
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
                      width: double.infinity,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product['description'],
                            style: const TextStyle(
                              fontSize: 11,
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
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _addToCart(product, context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary.withOpacity(0.9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                              ),
                              child: const Text(
                                'Tambah ke Keranjang',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
