import 'package:flutter/material.dart';
import '../constants/colors.dart';

class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBFA),
      appBar: AppBar(
        title: const Text('Artikel Kecantikan'),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Text(
            '5 Cara Merawat Kulit Agar Glowing Alami 🌟',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Montserrat',
            ),
          ),
          SizedBox(height: 20),
          Text(
            '1. Rutin Membersihkan Wajah\n'
            'Cuci wajah 2 kali sehari untuk mengangkat kotoran, minyak, dan sisa makeup.\n\n'
            '2. Gunakan Pelembap yang Sesuai\n'
            'Kulit lembap membantu menjaga elastisitas dan mencegah penuaan dini.\n\n'
            '3. Jangan Lupa Sunscreen\n'
            'Gunakan tabir surya minimal SPF 30 setiap hari, bahkan saat mendung.\n\n'
            '4. Minum Air yang Cukup\n'
            'Hidrasi dari dalam membantu kulit tetap kenyal dan bercahaya.\n\n'
            '5. Konsumsi Makanan Sehat\n'
            'Sayur, buah, dan omega-3 membantu memperbaiki tekstur kulit secara alami.',
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      ),
    );
  }
}
