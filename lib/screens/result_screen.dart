import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';

class ResultScreen extends StatefulWidget {
  final String skinType;

  const ResultScreen({super.key, required this.skinType});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late List<Map<String, dynamic>> recommendedProducts;
  late List<String> skinTips;

  @override
  void initState() {
    super.initState();
    _saveSkinType();
    _loadRecommendedProducts();
    _loadSkinTips();
  }

  Future<void> _saveSkinType() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('skinType', widget.skinType);
  }

  void _loadRecommendedProducts() {
    final allProducts = {
      'Kering': [
        {
          'name': 'Hydrating Moisturizer',
          'price': 85000,
          'image': 'assets/images/moisturizer.png',
        },
        {
          'name': 'Gentle Cleanser',
          'price': 65000,
          'image': 'assets/images/cleanser.png',
        },
      ],
      'Berminyak': [
        {
          'name': 'Oil-Free Face Wash',
          'price': 72000,
          'image': 'assets/images/oilfree.png',
        },
        {
          'name': 'Clay Mask',
          'price': 59000,
          'image': 'assets/images/claymask.png',
        },
      ],
      'Sensitif': [
        {
          'name': 'Soothing Serum',
          'price': 99000,
          'image': 'assets/images/serum.png',
        },
        {
          'name': 'Sensitive Toner',
          'price': 74000,
          'image': 'assets/images/toner.png',
        },
      ],
      'Kombinasi': [
        {
          'name': 'Balancing Gel',
          'price': 87000,
          'image': 'assets/images/gel.png',
        },
        {
          'name': 'Dual Cleanser',
          'price': 68000,
          'image': 'assets/images/dualcleanser.png',
        },
      ],
    };

    recommendedProducts = allProducts[widget.skinType] ?? [];
  }

  void _loadSkinTips() {
    final tips = {
      'Kering': [
        'Gunakan pelembap berbahan dasar krim.',
        'Hindari sabun wajah yang mengandung alkohol.',
        'Minum air putih yang cukup setiap hari.',
      ],
      'Berminyak': [
        'Gunakan pembersih wajah yang mengontrol minyak.',
        'Pilih produk non-komedogenik.',
        'Gunakan clay mask seminggu sekali.',
      ],
      'Sensitif': [
        'Gunakan produk tanpa pewangi dan alkohol.',
        'Uji coba produk di area kecil dulu.',
        'Gunakan serum yang menenangkan kulit.',
      ],
      'Kombinasi': [
        'Gunakan produk berbeda untuk area berbeda wajah.',
        'Hindari scrub kasar.',
        'Gunakan toner untuk menyeimbangkan pH.',
      ],
    };

    skinTips = tips[widget.skinType] ?? [];
  }

  void _goToProductScreen() {
    Navigator.pushNamed(context, '/products');
  }

  void _goBackToHome() {
    Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
  }

  void _goToCart() {
    Navigator.pushNamed(context, '/cart');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBackToHome,
        ),
        title: const Text('Hasil Kuis'),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: _goToCart,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              'Jenis kulitmu: ${widget.skinType}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tips untuk jenis kulitmu:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...skinTips.map((tip) => ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: AppColors.primary),
                  title: Text(tip),
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.zero,
                )),
            const SizedBox(height: 24),
            const Text(
              'Rekomendasi Produk:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...recommendedProducts.map(
              (product) => Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                child: ListTile(
                  leading: Image.asset(
                    product['image'],
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                  title: Text(product['name']),
                  subtitle: Text('Rp ${product['price']}'),
                  trailing: ElevatedButton(
                    onPressed: _goToProductScreen,
                    child: const Text('Checkout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 80), // untuk beri ruang di atas tombol bawah
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: _goToProductScreen,
          icon: const Icon(Icons.shopping_bag),
          label: const Text('Lihat Semua Produk'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
