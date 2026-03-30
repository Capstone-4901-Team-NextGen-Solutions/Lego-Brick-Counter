import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class AuthService extends ChangeNotifier {
  // ── Singleton ────────────────────────────────────────────────────
  // This is the critical fix. Previously `AuthService()` created a fresh
  // instance every time, so ApiService always got an empty token.
  static final AuthService _instance = AuthService._internal();
  static AuthService get instance => _instance;

  factory AuthService() => _instance;  // every `AuthService()` call returns the same object
  AuthService._internal();

  // ── State ─────────────────────────────────────────────────────────
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  bool get isLoggedIn => _token != null;
  bool get isLoading => _isLoading;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;

  /// Authorization header map — empty if not logged in.
  Map<String, String> get authHeaders =>
      _token != null ? {'Authorization': 'Bearer $_token'} : {};

  // ── Base URL (mirrors ApiService) ─────────────────────────────────
  static String get _baseUrl {
    if (kIsWeb) return 'http://localhost:5000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:5000/api';
    } catch (_) {}
    return 'http://localhost:5000/api';
  }

  // ── Init — call once in main() ────────────────────────────────────
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');

      if (_token != null) {
        _user = {
          'id': prefs.getInt('user_id'),
          'email': prefs.getString('user_email') ?? '',
          'username': prefs.getString('user_username') ?? '',
        };
      }
    } catch (_) {
      _token = null;
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Login ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 30));

      final result = json.decode(response.body) as Map<String, dynamic>;

      if (result['success'] == true && result['token'] != null) {
        await _saveSession(result['token'] as String, result['user'] as Map<String, dynamic>?);
      }

      return result;
    } catch (e) {
      return {'success': false, 'error': 'Login failed: $e'};
    }
  }

  // ── Register ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': email, 'password': password, 'username': username}),
          )
          .timeout(const Duration(seconds: 30));

      final result = json.decode(response.body) as Map<String, dynamic>;

      if (result['success'] == true && result['token'] != null) {
        await _saveSession(result['token'] as String, result['user'] as Map<String, dynamic>?);
      }

      return result;
    } catch (e) {
      return {'success': false, 'error': 'Registration failed: $e'};
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────
  Future<void> logout() async {
    _token = null;
    _user = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_email');
      await prefs.remove('user_username');
      await prefs.remove('user_id');
    } catch (_) {}

    notifyListeners();
  }

  // ── Persist session ────────────────────────────────────────────────
  Future<void> _saveSession(String token, Map<String, dynamic>? userData) async {
    _token = token;
    _user = userData;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      if (userData != null) {
        if (userData['email'] != null) await prefs.setString('user_email', userData['email']);
        if (userData['username'] != null) await prefs.setString('user_username', userData['username']);
        if (userData['id'] != null) await prefs.setInt('user_id', userData['id'] as int);
      }
    } catch (_) {}

    notifyListeners();
  }
}