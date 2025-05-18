import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  String _username = '';
  String _email = '';

  bool get isLoggedIn => _isLoggedIn;
  String get username => _username;
  String get email => _email;

  Future<void> login(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();

    // Ambil data email dan password yang tersimpan saat register
    final savedEmail = prefs.getString('email');
    final savedPassword = prefs.getString('password');

    if (email == savedEmail && password == savedPassword) {
      _email = email;
      _username = prefs.getString('username') ?? '';
      _isLoggedIn = true;
      notifyListeners();
    } else {
      throw Exception('Email atau password salah');
    }
  }

  Future<void> register(String username, String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    await prefs.setString('email', email);
    await prefs.setString('password', password);

    _username = username;
    _email = email;
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    notifyListeners();
  }
}
