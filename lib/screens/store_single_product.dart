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
  final List<bool> _likedProducts = List.filled(5, false); // Untuk produk di grid
  final List<bool> _likedCollections = List.filled(3, false); // Untuk produk di koleksi

  // Data produk untuk grid
  final List<Map<String, dynamic>> _products = [
    {
      'name': 'Nutrishe Intensive Bright & Glow Serum',
      'price': 195200,
      'image': 'assets/images/serum.png',
      'description': 'Mencerahkan kulit, mengurangi dark spot, dan menjaga skin barrier.',
      'category': 'Trending',
      'discount': '20% Rp.166.000',
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

  // Data produk untuk koleksi
  final List<Map<String, dynamic>> _collections = [
    {
      'name': 'Labore GentileBiome Skin Nutrition Gel',
      'price': 127000,
      'image': 'assets/images/moisturizer.png',
      'description': '50 ml',
    },
    {
      'name': 'Hydriceing & Brightening Essence Booster',
      'price': 149000,
      'image': 'assets/images/toner.png',
      'description': '100 ml',
    },
    {
      'name': 'Rice Up! Peel-off Mask 50gr',
      'price': 99000,
      'image': 'assets/images/claymask.png',
      'description': '50 gr',
    },
  ];

  final List<String> _categories = ['Trending', 'New Products', 'Highly Rated'];

  void _addToCart(Map<String, dynamic> product, BuildContext context) {
    Provider.of<CartProvider>(context, listen: false).addToCart(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product['name']} ditambahkan ke keranjang!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _toggleLike(int index, bool isCollection) {
    setState(() {
      if (isCollection) {
        _likedCollections[index] = !_likedCollections[index];
      } else {
        _likedProducts[index] = !_likedProducts[index];
      }
    });
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
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.shopping_cart),
              onPressed: () {
                Navigator.pushNamed(context, '/cart');
              },
            ),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFFDEDF4), // Latar belakang pink pastel
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
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
              // Kategori Tabs
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
              // Daftar Produk
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredProducts.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
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
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => _toggleLike(index, false),
                                child: Icon(
                                  _likedProducts[index]
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.pink,
                                ),
                              ),
                            ),
                          ],
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
              const SizedBox(height: 12),
              // Product Collections
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Product Collections',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AllProductsScreen(),
                          ),
                        );
                      },
                      child: const Text('View all', style: TextStyle(color: Colors.pink)),
                    ),
                  ],
                ),
              ),
              Column(
                children: List.generate(_collections.length, (index) {
                  final collection = _collections[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(8.0),
                        leading: Image.asset(
                          collection['image'],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                        title: Text(
                          collection['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              collection['description'],
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              'Rp ${collection['price']}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => _toggleLike(index, true),
                              child: Icon(
                                _likedCollections[index]
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: Colors.pink,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _addToCart(collection, context),
                              child: const Icon(
                                Icons.add_shopping_cart,
                                color: Colors.pink,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 80), // Spacer untuk mencegah overflow dengan navbar
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
        'description': '100 ml',
      },
      {
        'name': 'Rice Up! Peel-off Mask 50gr',
        'price': 99000,
        'image': 'assets/images/claymask.png',
        'description': '50 gr',
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