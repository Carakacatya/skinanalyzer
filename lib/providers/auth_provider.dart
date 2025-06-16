import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final PocketBase pb = PocketBase('http://127.0.0.1:8090');
  
  User? _currentUser;
  Address? _currentAddress;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get currentUser => _currentUser;
  Address? get currentAddress => _currentAddress;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null && pb.authStore.isValid;

  // Initialize auth provider
  Future<void> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Load saved auth data
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final modelJson = prefs.getString('auth_model');
      
      if (token != null && modelJson != null) {
        // Restore auth state
        final modelData = jsonDecode(modelJson);
        final recordModel = RecordModel.fromJson(modelData);
        
        // Manually set the auth store
        pb.authStore.save(token, recordModel);
        
        // Verify if the token is still valid
        if (pb.authStore.isValid) {
          await _loadUserData();
        } else {
          // Token expired, clear auth
          await logout();
        }
      }
    } catch (e) {
      _errorMessage = 'Gagal menginisialisasi autentikasi: ${e.toString()}';
      print('Initialize error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load user data from PocketBase
  Future<void> _loadUserData() async {
    try {
      if (!pb.authStore.isValid) return;
      
      final recordModel = pb.authStore.model;
      if (recordModel == null) return;
      
      final userId = recordModel.id;
      final userData = await pb.collection('users').getOne(userId);
      
      // Build avatar URL if exists
      String? avatarUrl;
      if (userData.data['avatar'] != null && userData.data['avatar'].toString().isNotEmpty) {
        avatarUrl = pb.files.getUrl(userData, userData.data['avatar']).toString();
        print('Avatar URL: $avatarUrl'); // Debug log
      }
      
      _currentUser = User(
        id: userData.id,
        username: userData.data['name'] ?? 'Nama Pengguna',
        email: userData.data['email'] ?? 'user@email.com',
        phone: userData.data['phone'] ?? '',
        skinType: userData.data['skin_type'] ?? 'Belum dianalisis',
        avatarUrl: avatarUrl,
      );
      
      // Load user address
      await loadUserAddress();
      
    } catch (e) {
      _errorMessage = 'Gagal memuat data user: ${e.toString()}';
      print('Load user data error: $e');
    }
  }

  // Load user address
  Future<void> loadUserAddress() async {
    try {
      if (_currentUser == null) return;
      
      final resultList = await pb.collection('user_addresses').getList(
        filter: 'user_id = "${_currentUser!.id}"',
        sort: '-created',
        page: 1,
        perPage: 1,
      );
      
      if (resultList.items.isNotEmpty) {
        final address = resultList.items.first;
        _currentAddress = Address(
          id: address.id,
          userId: address.data['user_id'] ?? '',
          street: address.data['Jalan'] ?? '',
          subdistrict: address.data['Kecamatan'] ?? '',
          city: address.data['Kota'] ?? '',
          province: address.data['Provinsi'] ?? '',
          postalCode: address.data['Kode_pos'] ?? '',
        );
      }
    } catch (e) {
      print('Error loading address: ${e.toString()}');
    }
  }

  // Login method
  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final authData = await pb.collection('users').authWithPassword(email, password);
      
      // Save auth data to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', pb.authStore.token);
      
      // Save model as JSON string
      if (pb.authStore.model != null) {
        final modelJson = jsonEncode(pb.authStore.model!.toJson());
        await prefs.setString('auth_model', modelJson);
      }

      // Load user data
      await _loadUserData();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Login gagal: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Register method
  Future<bool> register(String email, String password, String name) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Create new user
      final userData = {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'name': name,
      };

      await pb.collection('users').create(body: userData);
      
      // Auto login after registration
      final success = await login(email, password);
      
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Registrasi gagal: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout method
  Future<void> logout() async {
    try {
      pb.authStore.clear();
      _currentUser = null;
      _currentAddress = null;
      
      // Clear saved auth data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('auth_model');
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Logout gagal: ${e.toString()}';
      notifyListeners();
    }
  }

  // Update profile method (without image)
  Future<bool> updateProfile(User user) async {
    if (_currentUser == null) return false;

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final updatedRecord = await pb.collection('users').update(_currentUser!.id, body: {
        'name': user.username,
        'phone': user.phone,
        'skin_type': user.skinType,
      });
      
      // Build avatar URL if exists
      String? avatarUrl;
      if (updatedRecord.data['avatar'] != null && updatedRecord.data['avatar'].toString().isNotEmpty) {
        avatarUrl = pb.files.getUrl(updatedRecord, updatedRecord.data['avatar']).toString();
      }
      
      _currentUser = User(
        id: updatedRecord.id,
        username: updatedRecord.data['name'] ?? 'Nama Pengguna',
        email: updatedRecord.data['email'] ?? 'user@email.com',
        phone: updatedRecord.data['phone'] ?? '',
        skinType: updatedRecord.data['skin_type'] ?? 'Belum dianalisis',
        avatarUrl: avatarUrl,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Update profil gagal: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update profile with image using HTTP multipart request
  Future<bool> updateProfileWithImage(User user, Uint8List? imageBytes, String? imageName) async {
    if (_currentUser == null) return false;

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      print('Starting profile update with image...');
      print('Image bytes length: ${imageBytes?.length}');
      print('Image name: $imageName');

      if (imageBytes != null && imageName != null) {
        // Use HTTP multipart request for file upload
        final uri = Uri.parse('${pb.baseUrl}/api/collections/users/records/${_currentUser!.id}');
        final request = http.MultipartRequest('PATCH', uri);
        
        // Add authorization header
        request.headers['Authorization'] = pb.authStore.token;
        
        // Add form fields
        request.fields['name'] = user.username;
        request.fields['phone'] = user.phone;
        request.fields['skin_type'] = user.skinType;
        
        // Add file
        request.files.add(
          http.MultipartFile.fromBytes(
            'avatar',
            imageBytes,
            filename: imageName,
          ),
        );
        
        print('Sending multipart request...');
        final response = await request.send();
        final responseBody = await response.stream.bytesToString();
        
        print('Response status: ${response.statusCode}');
        print('Response body: $responseBody');
        
        if (response.statusCode == 200) {
          final responseData = jsonDecode(responseBody);
          
          // Build avatar URL
          String? avatarUrl;
          if (responseData['avatar'] != null && responseData['avatar'].toString().isNotEmpty) {
            // Create a temporary RecordModel to get the URL
            final tempRecord = RecordModel.fromJson(responseData);
            avatarUrl = pb.files.getUrl(tempRecord, responseData['avatar']).toString();
            print('New avatar URL: $avatarUrl');
          }
          
          _currentUser = User(
            id: responseData['id'],
            username: responseData['name'] ?? 'Nama Pengguna',
            email: responseData['email'] ?? 'user@email.com',
            phone: responseData['phone'] ?? '',
            skinType: responseData['skin_type'] ?? 'Belum dianalisis',
            avatarUrl: avatarUrl,
          );
          
          print('Profile update completed successfully');
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          throw Exception('HTTP ${response.statusCode}: $responseBody');
        }
      } else {
        // Update without image using regular PocketBase method
        print('No image provided, updating profile only...');
        final updatedRecord = await pb.collection('users').update(
          _currentUser!.id,
          body: {
            'name': user.username,
            'phone': user.phone,
            'skin_type': user.skinType,
          },
        );
        
        // Keep existing avatar URL
        String? avatarUrl;
        if (updatedRecord.data['avatar'] != null && updatedRecord.data['avatar'].toString().isNotEmpty) {
          avatarUrl = pb.files.getUrl(updatedRecord, updatedRecord.data['avatar']).toString();
        }
        
        _currentUser = User(
          id: updatedRecord.id,
          username: updatedRecord.data['name'] ?? 'Nama Pengguna',
          email: updatedRecord.data['email'] ?? 'user@email.com',
          phone: updatedRecord.data['phone'] ?? '',
          skinType: updatedRecord.data['skin_type'] ?? 'Belum dianalisis',
          avatarUrl: avatarUrl,
        );
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'Update profil gagal: ${e.toString()}';
      print('Update profile error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update or create address
  Future<bool> updateAddress(Address address) async {
    if (_currentUser == null) return false;

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (address.id.isNotEmpty) {
        // Update existing address
        final updatedRecord = await pb.collection('user_addresses').update(
          address.id, 
          body: {
            'user_id': _currentUser!.id,
            'Jalan': address.street,
            'Kecamatan': address.subdistrict,
            'Kota': address.city,
            'Provinsi': address.province,
            'Kode_pos': address.postalCode,
          },
        );
        
        _currentAddress = Address(
          id: updatedRecord.id,
          userId: updatedRecord.data['user_id'] ?? '',
          street: updatedRecord.data['Jalan'] ?? '',
          subdistrict: updatedRecord.data['Kecamatan'] ?? '',
          city: updatedRecord.data['Kota'] ?? '',
          province: updatedRecord.data['Provinsi'] ?? '',
          postalCode: updatedRecord.data['Kode_pos'] ?? '',
        );
      } else {
        // Create new address
        final newRecord = await pb.collection('user_addresses').create(
          body: {
            'user_id': _currentUser!.id,
            'Jalan': address.street,
            'Kecamatan': address.subdistrict,
            'Kota': address.city,
            'Provinsi': address.province,
            'Kode_pos': address.postalCode,
          },
        );
        
        _currentAddress = Address(
          id: newRecord.id,
          userId: newRecord.data['user_id'] ?? '',
          street: newRecord.data['Jalan'] ?? '',
          subdistrict: newRecord.data['Kecamatan'] ?? '',
          city: newRecord.data['Kota'] ?? '',
          province: newRecord.data['Provinsi'] ?? '',
          postalCode: newRecord.data['Kode_pos'] ?? '',
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Update alamat gagal: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Refresh user data
  Future<void> refreshUserData() async {
    if (!pb.authStore.isValid) return;
    
    try {
      _isLoading = true;
      notifyListeners();
      
      await _loadUserData();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Gagal memperbarui data user: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    if (pb.authStore.isValid) {
      print('User is authenticated with valid token');
      return true;
    }
    
    // Try to restore from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final modelJson = prefs.getString('auth_model');
    
    if (token != null && modelJson != null) {
      try {
        final modelData = jsonDecode(modelJson);
        final recordModel = RecordModel.fromJson(modelData);
        
        // Manually set the auth store
        pb.authStore.save(token, recordModel);
        
        if (pb.authStore.isValid) {
          print('User authenticated from saved token');
          return true;
        }
      } catch (e) {
        print('Error restoring authentication: ${e.toString()}');
      }
    }
    
    print('User is not authenticated');
    return false;
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
