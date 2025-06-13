import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/auth_provider.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  String? skinType;
  bool isLoading = true;

  final Map<String, List<String>> tipsBySkinType = {
    'Kering': [
      'Gunakan pelembap intensif setiap hari.',
      'Hindari mandi air panas terlalu lama.',
      'Gunakan sabun pembersih yang lembut dan bebas alkohol.',
    ],
    'Berminyak': [
      'Gunakan pembersih wajah dua kali sehari.',
      'Gunakan masker tanah liat 1–2 kali seminggu.',
      'Pilih produk bebas minyak (oil-free) dan non-comedogenic.',
    ],
    'Sensitif': [
      'Gunakan produk tanpa pewangi atau alkohol.',
      'Coba patch test sebelum menggunakan produk baru.',
      'Hindari eksfoliasi terlalu sering.',
    ],
    'Kombinasi': [
      'Gunakan pelembap ringan untuk seluruh wajah.',
      'Gunakan produk khusus untuk area T-zone jika berminyak.',
      'Cuci muka dua kali sehari dengan pembersih ringan.',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadSkinType();
  }

  Future<void> _loadSkinType() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.initialize();

    if (mounted) {
      if (authProvider.currentUser == null || authProvider.currentUser!.skinType == 'Belum dianalisis') {
        Navigator.pushReplacementNamed(context, '/quiz');
      } else {
        setState(() {
          skinType = authProvider.currentUser!.skinType;
          isLoading = false;
        });
      }
    }
  }

  Future<void> _resetSkinType() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser != null) {
      try {
        final updatedUser = authProvider.currentUser!.copyWith(skinType: 'Belum dianalisis');
        await authProvider.updateProfile(updatedUser);
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/quiz');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error resetting skin type: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tips = tipsBySkinType[skinType!] ?? ['Tidak ada tips tersedia.'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tips Perawatan Kulit'),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Kembali ke Profil',
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/profile');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSkinType,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(
                'Jenis kulitmu: $skinType',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 16),
              ...tips.map(
                (tip) => ListTile(
                  leading: const Icon(Icons.check_circle, color: AppColors.accent),
                    title: Text(tip),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: const VisualDensity(vertical: -3),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _resetSkinType,
                icon: const Icon(Icons.restart_alt, color: Colors.white),
                label: const Text('Ulangi Kuis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}