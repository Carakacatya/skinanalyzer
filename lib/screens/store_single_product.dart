import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../constants/colors.dart';
import 'all_products_screen.dart'; // Tambahkan file baru untuk menampilkan semua produk

class StoreSingleProduct extends StatefulWidget {
  const StoreSingleProduct({super.key});

  @override
  _StoreSingleProductState createState() => _StoreSingleProductState();
}

class _StoreSingleProductState extends State<StoreSingleProduct> {
  int _selectedCategoryIndex = 0;

  final List<Map<String, dynamic>> _products = [
    {
      'name': 'Nutrishe Intensive Bright & Glow Serum',
      'price': 195200,
      'image': 'assets/images/serum.png',
      'description': 'Mencerahkan kulit, mengurangi dark spot, dan menjaga skin barrier.',
      'category': 'Trending',
    },
    {
      'name': 'Finally Found You! SOY BRIGHT! Gel Moisturizer',
      'price': 129000,
      'image': 'assets/images/moisturizer.png',
      'description': 'Gel pelembap ringan yang melembapkan kulit kering.',
      'category': 'Trending',
    },
    {
      'name': 'The Ordinary Lactic Acid 10% + HA',
      'price': 258000,
      'image': 'assets/images/serum.png',
      'description': 'Exfoliating serum untuk kulit cerah dan halus.',
      'category': 'Highly Rated',
    },
    {
      'name': 'Finally Found You! SOY GENTLE! Face Cleanser',
      'price': 99000,
      'image': 'assets/images/cleanser.png',
      'description': 'Pembersih wajah lembut untuk kulit kering.',
      'category': 'Highly Rated',
    },
    {
      'name': 'Labore GentileBiome Skin Nutrition Gel',
      'price': 127000,
      'image': 'assets/images/moisturizer.png',
      'description': 'Gel pelembap ringan untuk nutrisi kulit.',
      'category': 'New Products',
    },
  ];

  final List<bool> _likedProducts = List.filled(5, false);
  final List<String> _categories = ['Trending', 'New Products', 'Highly Rated'];

  void _addToCart(Map<String, dynamic> product, BuildContext context) {
    Provider.of<CartProvider>(context, listen: false).addToCart(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['name']} added to cart!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _products
        .where((product) => product['category'] == _categories[_selectedCategoryIndex])
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skin Analyzer'),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.pushNamed(context, '/cart');
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFFDEDF4),
      body: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12, // fixed pink area
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search any Product...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic, color: Colors.grey),
                      SizedBox(width: 8),
                      Icon(Icons.filter_list, color: Colors.grey),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.grey, width: 0.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Category Tabs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_categories.length, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategoryIndex = index;
                      });
                    },
                    child: Column(
                      children: [
                        Text(
                          _categories[index],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: _selectedCategoryIndex == index
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _selectedCategoryIndex == index
                                ? AppColors.primary
                                : Colors.grey,
                          ),
                        ),
                        if (_selectedCategoryIndex == index)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            height: 2,
                            width: 40,
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),

              // Grid Produk Utama
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredProducts.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.65,
                ),
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: Image.asset(
                            product['image'],
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  product['description'],
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (product['discount'] != null)
                                  Text(
                                    product['discount'],
                                    style: const TextStyle(fontSize: 12, color: Colors.red),
                                  ),
                                Text(
                                  'Rp ${product['price']}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => _addToCart(product, context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Add to Cart', style: TextStyle(fontSize: 12)),
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

              const SizedBox(height: 16),

              // Rekomendasi Vertikal Scroll
              const Text(
                'Rekomendasi untukmu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              ListView.builder(
                itemCount: _products.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final product = _products[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            product['image'],
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['name'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              const Text("50 ml", style: TextStyle(color: Colors.grey, fontSize: 12)),
                              Text(
                                'Rp ${product['price']}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              icon: Icon(
                                _likedProducts[index] ? Icons.favorite : Icons.favorite_border,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _likedProducts[index] = !_likedProducts[index];
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.shopping_cart_outlined, color: AppColors.primary, size: 20),
                              onPressed: () => _addToCart(product, context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// File baru: all_products_screen.dart
class AllProductsScreen extends StatelessWidget {
  const AllProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> allProducts = [
      {
        'name': 'Nutrishe Intensive Bright & Glow Serum',
        'price': 195200,
        'image': 'assets/images/serum.png',
        'description': 'Mencerahkan kulit, mengurangi dark spot, dan menjaga skin barrier.',
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
        'description': 'Diformulasikan untuk mencerahkan, menenangkan, dan menghidrasi kulit wajah',
      },
      {
        'name': 'Rice Up! Peel-off Mask',
        'price': 99000,
        'image': 'assets/images/claymask.png',
        'description': 'Diformulasikan untuk membantu menghidrasi dan mencerahkan kulit.',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Products'),
        backgroundColor: AppColors.primary,
      ),
      body: Container(
        color: const Color(0xFFFDEDF4),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: GridView.builder(
            itemCount: allProducts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemBuilder: (context, index) {
              final product = allProducts[index];
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Image.asset(
                        product['image'],
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
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
                            Text(
                              product['discount'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          Text(
                            'Rp ${product['price']}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
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
                            style: TextStyle(fontSize: 12),
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
      ),
    );
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
}