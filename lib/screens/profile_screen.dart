import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

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
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
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
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
      _startEntranceAnimations();
    });
  }
  
  void _startEntranceAnimations() {
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _scaleController.forward();
    });
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.refreshUserData();
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: $e')),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.settings.arguments == true) {
      _loadUserData();
    }
  }

  String getFormattedAddress(User? user, Address? address) {
    if (user == null || address == null) return 'Belum ada alamat';
    
    final parts = [
      if (address.street.isNotEmpty) address.street.trim(),
      if (address.subdistrict.isNotEmpty) address.subdistrict.trim(),
      if (address.city.isNotEmpty) address.city.trim(),
      if (address.province.isNotEmpty) address.province.trim(),
      if (address.postalCode.isNotEmpty) address.postalCode.trim(),
    ].where((part) => part.isNotEmpty);

    return parts.isEmpty ? 'Belum ada alamat' : parts.join(', ');
  }

  Widget _buildProfileAvatar(String? avatarUrl) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF48FB1),
            const Color(0xFFEC407A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC407A).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? ClipOval(
              child: Image.network(
                avatarUrl,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.white,
                  );
                },
              ),
            )
          : const Icon(
              Icons.person,
              size: 50,
              color: Colors.white,
            ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                (iconColor ?? const Color(0xFFEC407A)).withOpacity(0.1),
                (iconColor ?? const Color(0xFFEC407A)).withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor ?? const Color(0xFFEC407A),
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF333333),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey[400],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final user = authProvider.currentUser;
    final address = authProvider.currentAddress;

    if (_isLoading || user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFCE4EC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
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
                  Icons.person,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Loading profile...',
                style: GoogleFonts.poppins(
                  color: Colors.grey[700],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      appBar: AppBar(
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            'Profil Saya',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
        ),
        backgroundColor: const Color(0xFFF8BBD0),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.pushNamed(context, '/edit_profile');
                if (result == true) {
                  _loadUserData();
                }
              },
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Profile Header
              SlideTransition(
                position: _slideAnimation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
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
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: _buildProfileAvatar(user.avatarUrl),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.username,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFEC407A).withOpacity(0.1),
                              const Color(0xFFF48FB1).withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFEC407A).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          user.skinType,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFEC407A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Menu Items
              SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    _buildMenuCard(
                      icon: Icons.history,
                      title: 'Riwayat Pesanan',
                      subtitle: 'Lihat pesanan yang telah dibuat',
                      onTap: () => Navigator.pushNamed(context, '/order_history'),
                      iconColor: const Color(0xFF4CAF50),
                    ),
                    
                    _buildMenuCard(
                      icon: Icons.phone,
                      title: 'Nomor Telepon',
                      subtitle: user.phone.isNotEmpty ? user.phone : 'Belum diatur',
                      onTap: () async {
                        final result = await Navigator.pushNamed(context, '/edit_profile');
                        if (result == true) {
                          _loadUserData();
                        }
                      },
                      iconColor: const Color(0xFF2196F3),
                    ),
                    
                    _buildMenuCard(
                      icon: Icons.location_on,
                      title: 'Alamat',
                      subtitle: getFormattedAddress(user, address),
                      onTap: () async {
                        final result = await Navigator.pushNamed(context, '/edit_profile');
                        if (result == true) {
                          _loadUserData();
                        }
                      },
                      iconColor: const Color(0xFFFF9800),
                    ),
                    
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SwitchListTile(
                        secondary: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF9C27B0).withOpacity(0.1),
                                const Color(0xFF9C27B0).withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.dark_mode,
                            color: Color(0xFF9C27B0),
                            size: 24,
                          ),
                        ),
                        title: Text(
                          'Mode Gelap',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        subtitle: Text(
                          isDarkMode ? 'Aktif' : 'Nonaktif',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        value: isDarkMode,
                        activeColor: const Color(0xFFEC407A),
                        onChanged: (value) {
                          Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                        },
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Logout Button
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.red[400]!,
                        Colors.red[600]!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: Text(
                      'Logout',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
