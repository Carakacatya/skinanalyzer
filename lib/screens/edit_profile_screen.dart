import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../constants/colors.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  late TextEditingController _streetController;
  late TextEditingController _subdistrictController;
  late TextEditingController _cityController;
  late TextEditingController _provinceController;
  late TextEditingController _postalCodeController;
  String? _selectedSkinType;
  bool _isLoading = false;
  bool _isInitialized = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _currentAvatarUrl;
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> _skinTypes = [
    'Belum dianalisis',
    'Normal',
    'Kering',
    'Berminyak',
    'Kombinasi',
    'Sensitif'
  ];

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
    
    _usernameController = TextEditingController();
    _phoneController = TextEditingController();
    _streetController = TextEditingController();
    _subdistrictController = TextEditingController();
    _cityController = TextEditingController();
    _provinceController = TextEditingController();
    _postalCodeController = TextEditingController();

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
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _subdistrictController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      final address = authProvider.currentAddress;

      if (user != null) {
        _usernameController.text = user.username;
        _phoneController.text = user.phone;
        _currentAvatarUrl = user.avatarUrl;
        _selectedSkinType = _skinTypes.contains(user.skinType) 
            ? user.skinType 
            : 'Belum dianalisis';
        
        if (address != null) {
          _streetController.text = address.street;
          _subdistrictController.text = address.subdistrict;
          _cityController.text = address.city;
          _provinceController.text = address.province;
          _postalCodeController.text = address.postalCode;
        }
      } else {
        _selectedSkinType = 'Belum dianalisis';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user data: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
        _isInitialized = true;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      
      // Show options dialog
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Pilih Sumber Gambar',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text('Kamera', style: GoogleFonts.poppins()),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text('Galeri', style: GoogleFonts.poppins()),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      
      if (source != null) {
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 80,
        );
        
        if (image != null) {
          final bytes = await image.readAsBytes();
          print('Image picked: ${image.name}, size: ${bytes.length} bytes'); // Debug log
          
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImageName = image.name;
          });
          
          print('Image state updated successfully'); // Debug log
        }
      }
    } catch (e) {
      print('Error picking image: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) {
        throw Exception('User ID not found. Please log in again.');
      }

      print('Saving profile...'); // Debug log
      print('Has image: ${_selectedImageBytes != null}'); // Debug log

      // Create updated user object
      final updatedUser = User(
        id: user.id,
        username: _usernameController.text.trim(),
        email: user.email,
        phone: _phoneController.text.trim(),
        skinType: _selectedSkinType ?? 'Belum dianalisis',
        avatarUrl: user.avatarUrl,
      );
      
      // Update profile with image if selected
      final success = await authProvider.updateProfileWithImage(
        updatedUser, 
        _selectedImageBytes, 
        _selectedImageName,
      );

      if (!success) {
        throw Exception('Failed to update profile');
      }
      
      // Update address
      final address = Address(
        id: authProvider.currentAddress?.id ?? '',
        userId: user.id,
        street: _streetController.text.trim(),
        subdistrict: _subdistrictController.text.trim(),
        city: _cityController.text.trim(),
        province: _provinceController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        isDefault: true,
      );
      
      await authProvider.updateAddress(address);

      // Clear selected image after successful save
      setState(() {
        _selectedImageBytes = null;
        _selectedImageName = null;
        _currentAvatarUrl = authProvider.currentUser?.avatarUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profil berhasil diperbarui',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Save profile error: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving profile: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
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
            child: _selectedImageBytes != null
                ? ClipOval(
                    child: Image.memory(
                      _selectedImageBytes!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  )
                : _currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          _currentAvatarUrl!,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('Error loading avatar: $error'); // Debug log
                            return const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.white,
                      ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 20,
                  color: Color(0xFFEC407A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool enabled = true,
    String? initialValue,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: enabled ? controller : null,
        initialValue: !enabled ? initialValue : null,
        enabled: enabled,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.poppins(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: const Color(0xFFEC407A)),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEC407A), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFFFCE4EC),
        appBar: AppBar(
          title: Text(
            'Edit Profil',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFF8BBD0),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      appBar: AppBar(
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            'Edit Profil',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        backgroundColor: const Color(0xFFF8BBD0),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Section
                SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                        _buildAvatarSection(),
                        const SizedBox(height: 16),
                        Text(
                          'Tap untuk mengubah foto profil',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_selectedImageBytes != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Gambar baru dipilih ✓',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Form Fields
                SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi Dasar',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 20),

                        _buildFormField(
                          controller: _usernameController,
                          label: 'Nama Pengguna',
                          icon: Icons.person,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama pengguna tidak boleh kosong';
                            }
                            return null;
                          },
                        ),

                        Consumer<AuthProvider>(
                          builder: (context, authProvider, _) {
                            return _buildFormField(
                              controller: TextEditingController(),
                              label: 'Email',
                              icon: Icons.email,
                              enabled: false,
                              initialValue: authProvider.currentUser?.email ?? 'user@email.com',
                            );
                          },
                        ),

                        _buildFormField(
                          controller: _phoneController,
                          label: 'Nomor Telepon',
                          icon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty && 
                                !RegExp(r'^\+?0[0-9]{9,}$').hasMatch(value.trim())) {
                              return 'Nomor telepon tidak valid';
                            }
                            return null;
                          },
                        ),

                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: DropdownButtonFormField<String>(
                            value: _selectedSkinType,
                            style: GoogleFonts.poppins(),
                            decoration: InputDecoration(
                              labelText: 'Jenis Kulit',
                              labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                              prefixIcon: const Icon(Icons.face, color: Color(0xFFEC407A)),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFEC407A), width: 2),
                              ),
                            ),
                            items: _skinTypes.map((String type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedSkinType = newValue;
                                });
                              }
                            },
                            validator: (value) => value == null ? 'Pilih jenis kulit' : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Address Section
                SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alamat',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 20),

                        _buildFormField(
                          controller: _streetController,
                          label: 'Jalan',
                          icon: Icons.home,
                        ),

                        _buildFormField(
                          controller: _subdistrictController,
                          label: 'Kecamatan',
                          icon: Icons.location_on,
                        ),

                        _buildFormField(
                          controller: _cityController,
                          label: 'Kota',
                          icon: Icons.location_city,
                        ),

                        _buildFormField(
                          controller: _provinceController,
                          label: 'Provinsi',
                          icon: Icons.map,
                        ),

                        _buildFormField(
                          controller: _postalCodeController,
                          label: 'Kode Pos',
                          icon: Icons.markunread_mailbox,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty && 
                                !RegExp(r'^\d{5}$').hasMatch(value.trim())) {
                              return 'Kode pos harus 5 digit';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Save Button
                SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFF48FB1),
                          const Color(0xFFEC407A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEC407A).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Simpan Perubahan',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
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
      ),
    );
  }
}
