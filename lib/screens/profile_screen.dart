// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
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
    // Refresh data jika kembali dari EditProfileScreen
    if (ModalRoute.of(context)?.settings.arguments == true) {
      _loadUserData();
    }
  }

  // Helper method untuk mendapatkan formatted address
  String getFormattedAddress(User? user, Address? address) {
    if (user == null || address == null) return '-';
    
    final parts = [
      if (address.street.isNotEmpty) address.street.trim(),
      if (address.subdistrict.isNotEmpty) address.subdistrict.trim(),
      if (address.city.isNotEmpty) address.city.trim(),
      if (address.province.isNotEmpty) address.province.trim(),
      if (address.postalCode.isNotEmpty) address.postalCode.trim(),
    ].where((part) => part.isNotEmpty);

    return parts.isEmpty ? '-' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final user = authProvider.currentUser;
    final address = authProvider.currentAddress;

    if (_isLoading || user == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFEFBDC6)),
          ),
        ),
      );
    }

    final Color primaryPink = const Color(0xFFEFBDC6);
    final Color backgroundPink = const Color(0xFFFAE3E7);
    final Color textColor = Colors.black87;
    final Color subtitleColor = Colors.black54;

    // Tampilkan pesan sukses jika ada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ModalRoute.of(context)?.settings.arguments == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profil Saya',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryPink,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black87),
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/edit_profile');
              if (result == true) {
                _loadUserData(); // Pastikan data diperbarui
              }
            },
          ),
        ],
      ),
      body: Container(
        color: backgroundPink,
        child: ListView(
          children: [
            const SizedBox(height: 30),
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: primaryPink,
                child: const Icon(
                  Icons.person,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                user.username,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            Center(
              child: Text(
                user.email,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, thickness: 1),
            ListTile(
              leading: Icon(Icons.face, color: primaryPink),
              title: Text('Jenis Kulit', style: TextStyle(color: textColor)),
              subtitle: Text(user.skinType, style: TextStyle(color: subtitleColor)),
            ),
            ListTile(
              leading: Icon(Icons.phone, color: primaryPink),
              title: Text('Nomor Telepon', style: TextStyle(color: textColor)),
              subtitle: Text(
                user.phone.isNotEmpty ? user.phone : '-',
                style: TextStyle(color: subtitleColor),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home, color: primaryPink),
              title: Text('Alamat Lengkap', style: TextStyle(color: textColor)),
              subtitle: Text(
                getFormattedAddress(user, address),
                style: TextStyle(color: subtitleColor),
              ),
            ),
            const Divider(height: 1, thickness: 1),
            SwitchListTile(
              title: Text('Mode Gelap', style: TextStyle(color: textColor)),
              secondary: Icon(Icons.dark_mode, color: textColor),
              value: isDarkMode,
              activeColor: primaryPink,
              onChanged: (value) {
                Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
              },
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}