import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _token != null;
  bool get isLoading => _isLoading;

  static const String _baseUrl = 'http://localhost:5000/api/auth';

  // Initialize - check for saved token
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    if (_token != null) {
      await getProfile();
    }
    notifyListeners();
  }

  // Register
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? username,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'username': username ?? email.split('@')[0],
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201 && data['success']) {
        _token = data['token'];
        _user = data['user'];
        
        // Save token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        
        return {'success': true, 'message': 'Registration successful'};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        _token = data['token'];
        _user = data['user'];
        
        // Save token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        
        return {'success': true, 'message': 'Login successful'};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get profile
  Future<void> getProfile() async {
    if (_token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success']) {
        _user = data['user'];
      } else {
        // Token invalid
        await logout();
      }
    } catch (e) {
      print('Profile fetch error: $e');
    } finally {
      notifyListeners();
    }
  }

  // Logout
  Future<void> logout() async {
    _token = null;
    _user = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    
    notifyListeners();
  }

  // Change password
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_token == null) {
      return {'success': false, 'error': 'Not authenticated'};
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      final data = json.decode(response.body);
      return {
        'success': data['success'] ?? false,
        'message': data['message'],
        'error': data['error'],
      };
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Get auth headers for API calls
  Map<String, String> get authHeaders {
    if (_token == null) return {};
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };
  }
}