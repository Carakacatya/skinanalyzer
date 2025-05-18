import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/edit_profile_screen.dart';
import '../constants/colors.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _skinType = 'Belum dianalisis';
  String _username = 'Nama Pengguna';
  String _email = 'user@email.com';
  String _phone = '';
  String _street = '';
  String _subdistrict = '';
  String _city = '';
  String _province = '';
  String _postalCode = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _skinType = prefs.getString('skinType') ?? 'Belum dianalisis';
      _username = prefs.getString('username') ?? 'Nama Pengguna';
      _email = prefs.getString('email') ?? 'user@email.com';
      _phone = prefs.getString('phone') ?? '';
      _street = prefs.getString('street') ?? '';
      _subdistrict = prefs.getString('subdistrict') ?? '';
      _city = prefs.getString('city') ?? '';
      _province = prefs.getString('province') ?? '';
      _postalCode = prefs.getString('postalCode') ?? '';
    });
  }

  Future<void> _logout() async {
    Provider.of<AuthProvider>(context, listen: false).logout();
    Navigator.pushReplacementNamed(context, '/login'); // atau route yang sesuai
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
              _loadUserData(); // refresh setelah edit
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.person, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              _username,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Center(child: Text(_email)),
          const SizedBox(height: 20),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.face, color: AppColors.primary),
            title: const Text('Jenis Kulit'),
            subtitle: Text(_skinType),
          ),
          ListTile(
            leading: const Icon(Icons.phone, color: AppColors.primary),
            title: const Text('Nomor Telepon'),
            subtitle: Text(_phone.isNotEmpty ? _phone : '-'),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: AppColors.primary),
            title: const Text('Alamat Lengkap'),
            subtitle: Text(
              [
                if (_street.isNotEmpty) _street,
                if (_subdistrict.isNotEmpty) _subdistrict,
                if (_city.isNotEmpty) _city,
                if (_province.isNotEmpty) _province,
                if (_postalCode.isNotEmpty) _postalCode,
              ].join(', '),
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Mode Gelap'),
            secondary: const Icon(Icons.dark_mode),
            value: isDarkMode,
            onChanged: (value) {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
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
        ],
      ),
    );
  }
}
