import 'package:flutter/material.dart';
import '../constants/colors.dart';
import 'login_screen.dart';
import 'main_nav_screen.dart';
import 'package:pocketbase/pocketbase.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final pb = PocketBase('http://127.0.0.1:8090');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      try {
        final body = {
          'name': _nameController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
          'passwordConfirm': _passwordController.text,
        };
        await pb.collection('users').create(body: body);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainNavScreen()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registrasi gagal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Image.asset('assets/images/login_illustration.png', height: 150),
                  const SizedBox(height: 32),
                  const Text(
                    'Buat Akun Baru',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: _nameController,
                    hint: 'Nama Lengkap',
                    validator: (value) => value!.isEmpty ? 'Masukkan nama' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailController,
                    hint: 'Email',
                    validator: (value) => !value!.contains('@') ? 'Email tidak valid' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _passwordController,
                    hint: 'Password',
                    obscure: true,
                    validator: (value) => value!.length < 6 ? 'Password minimal 6 karakter' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Daftar', style: TextStyle(color: Colors.white)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: const Text('Sudah punya akun? Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      validator: validator,
    );
  }
}