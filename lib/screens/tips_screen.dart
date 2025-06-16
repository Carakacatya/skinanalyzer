import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> with TickerProviderStateMixin {
  String? skinType;
  bool isLoading = true;
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final Map<String, List<Map<String, String>>> tipsBySkinType = {
    'Kering': [
      {
        'title': 'Gunakan Pelembap Intensif',
        'description': 'Gunakan pelembap yang kaya dan intensif setiap hari, terutama setelah mandi.',
        'icon': '💧'
      },
      {
        'title': 'Hindari Air Panas',
        'description': 'Hindari mandi air panas terlalu lama karena dapat menghilangkan minyak alami kulit.',
        'icon': '🚿'
      },
      {
        'title': 'Pembersih Lembut',
        'description': 'Gunakan sabun pembersih yang lembut dan bebas alkohol untuk menjaga kelembapan.',
        'icon': '🧴'
      },
    ],
    'Berminyak': [
      {
        'title': 'Bersihkan Wajah Rutin',
        'description': 'Gunakan pembersih wajah dua kali sehari untuk mengontrol produksi minyak.',
        'icon': '🧽'
      },
      {
        'title': 'Masker Tanah Liat',
        'description': 'Gunakan masker tanah liat 1–2 kali seminggu untuk menyerap minyak berlebih.',
        'icon': '🎭'
      },
      {
        'title': 'Produk Oil-Free',
        'description': 'Pilih produk bebas minyak (oil-free) dan non-comedogenic.',
        'icon': '✨'
      },
    ],
    'Sensitif': [
      {
        'title': 'Produk Hypoallergenic',
        'description': 'Gunakan produk tanpa pewangi atau alkohol yang dapat mengiritasi kulit.',
        'icon': '🌸'
      },
      {
        'title': 'Patch Test',
        'description': 'Selalu lakukan patch test sebelum menggunakan produk baru.',
        'icon': '🔬'
      },
      {
        'title': 'Eksfoliasi Lembut',
        'description': 'Hindari eksfoliasi terlalu sering, cukup 1-2 kali seminggu dengan produk lembut.',
        'icon': '🌿'
      },
    ],
    'Kombinasi': [
      {
        'title': 'Pelembap Ringan',
        'description': 'Gunakan pelembap ringan untuk seluruh wajah yang tidak menyumbat pori.',
        'icon': '💫'
      },
      {
        'title': 'Perawatan T-Zone',
        'description': 'Gunakan produk khusus untuk area T-zone jika berminyak.',
        'icon': '🎯'
      },
      {
        'title': 'Pembersih Seimbang',
        'description': 'Cuci muka dua kali sehari dengan pembersih yang tidak terlalu keras.',
        'icon': '⚖️'
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    
    // Initialize Animation Controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // Initialize Animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _loadSkinType();
    _startAnimations();
  }
  
  void _startAnimations() {
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
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
            SnackBar(
              content: Text('Error resetting skin type: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFCE4EC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF48FB1),
                      const Color(0xFFEC407A),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lightbulb,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Memuat tips...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final tips = tipsBySkinType[skinType!] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      appBar: AppBar(
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            'Tips Perawatan Kulit',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
        ),
        backgroundColor: const Color(0xFFF8BBD0),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            tooltip: 'Kembali ke Profil',
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/profile');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSkinType,
        color: const Color(0xFFEC407A),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Skin Type Header
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        const Color(0xFFFCE4EC),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFF48FB1),
                              const Color(0xFFEC407A),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.face,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Jenis Kulitmu',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        skinType!,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFEC407A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Tips Section
              SlideTransition(
                position: _slideAnimation,
                child: Text(
                  'Tips Perawatan Khusus',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Tips List
              ...tips.asMap().entries.map((entry) {
                final index = entry.key;
                final tip = entry.value;
                
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _slideController,
                    curve: Interval(
                      index * 0.1,
                      1.0,
                      curve: Curves.easeOutCubic,
                    ),
                  )),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFF48FB1).withOpacity(0.2),
                                const Color(0xFFEC407A).withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              tip['icon']!,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tip['title']!,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tip['description']!,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              
              const SizedBox(height: 24),
              
              // Reset Button
              FadeTransition(
                opacity: _fadeAnimation,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _resetSkinType,
                    icon: const Icon(Icons.restart_alt, color: Colors.white),
                    label: Text(
                      'Ulangi Kuis',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC407A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
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
