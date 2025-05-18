import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'article_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final List<Map<String, String>> beautyArticles = const [
    {
      'title': '5 Tips Merawat Kulit Kering',
      'image': 'assets/images/article1.jpg',
      'content': 'Kulit kering memerlukan hidrasi ekstra. Gunakan pelembap yang mengandung hyaluronic acid dan hindari sabun dengan alkohol...'
    },
    {
      'title': 'Cara Mengontrol Minyak di Wajah',
      'image': 'assets/images/article2.jpg',
      'content': 'Untuk kulit berminyak, gunakan cleanser berbahan dasar gel dan hindari produk yang membuat wajah terasa kesat...'
    },
    {
      'title': 'Rutinitas Skincare untuk Kulit Sensitif',
      'image': 'assets/images/article3.jpg',
      'content': 'Kulit sensitif butuh perawatan lembut. Pilih produk tanpa parfum dan lakukan patch test sebelum pemakaian...'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skin Analyzer'),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Center(
              child: Column(
                children: [
                  Text(
                    'Selamat Datang di Skin Analyzer!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Temukan jenis kulitmu & dapatkan rekomendasi terbaik.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Image.asset('assets/images/login_illustration.png', height: 180),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/quiz'),
                    icon: const Icon(Icons.quiz),
                    label: const Text('Mulai Kuis'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 233, 171, 190),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/tips'),
                    icon: const Icon(Icons.lightbulb),
                    label: const Text('Lihat Tips Skincare'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Artikel Kecantikan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: beautyArticles.length,
              itemBuilder: (context, index) {
                final article = beautyArticles[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ArticleDetailScreen(article: article),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                          ),
                          child: Image.asset(
                            article['image']!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              article['title']!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}
