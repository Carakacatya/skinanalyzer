import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _streetController; 
  late TextEditingController _subdistrictController;
  late TextEditingController _cityController;
  late TextEditingController _provinceController;
  late TextEditingController _postalCodeController;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController = TextEditingController(text: prefs.getString('username') ?? '');
    _emailController = TextEditingController(text: prefs.getString('email') ?? '');
    _phoneController = TextEditingController(text: prefs.getString('phone') ?? '');
    _streetController = TextEditingController(text: prefs.getString('street') ?? '');
    _subdistrictController = TextEditingController(text: prefs.getString('subdistrict') ?? '');
    _cityController = TextEditingController(text: prefs.getString('city') ?? '');
    _provinceController = TextEditingController(text: prefs.getString('province') ?? '');
    _postalCodeController = TextEditingController(text: prefs.getString('postalCode') ?? '');
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveUserData() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', _nameController.text);
      await prefs.setString('email', _emailController.text);
      await prefs.setString('phone', _phoneController.text);
      await prefs.setString('street', _streetController.text);
      await prefs.setString('subdistrict', _subdistrictController.text);
      await prefs.setString('city', _cityController.text);
      await prefs.setString('province', _provinceController.text);
      await prefs.setString('postalCode', _postalCodeController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui!')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _subdistrictController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profil'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nama'),
                      validator: (value) => value!.isEmpty ? 'Nama tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) => value!.isEmpty ? 'Email tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Nomor Telepon'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _streetController,
                      decoration: const InputDecoration(labelText: 'Jalan / Detail Alamat'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _subdistrictController,
                      decoration: const InputDecoration(labelText: 'Kelurahan / Kecamatan'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(labelText: 'Kota / Kabupaten'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _provinceController,
                      decoration: const InputDecoration(labelText: 'Provinsi'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _postalCodeController,
                      decoration: const InputDecoration(labelText: 'Kode Pos'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveUserData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Simpan', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
