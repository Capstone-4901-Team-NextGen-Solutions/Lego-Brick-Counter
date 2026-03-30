import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'auth_service.dart';

class ApiService {
  // ── Base URL ────────────────────────────────────────────────────
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:5000/api';
    return 'http://localhost:5000/api';
  }

  static const Duration timeout = Duration(seconds: 30);

  // ── Auth headers (reads from the singleton) ─────────────────────
  static Map<String, String> get _authHeaders => AuthService.instance.authHeaders;

  // ── Auth-aware request helper ───────────────────────────────────
  static Future<Map<String, dynamic>> _authRequest(
    String method,
    String endpoint, {
    Map<String, String>? extraHeaders,
    Object? body,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ..._authHeaders,
      ...?extraHeaders,
    };

    try {
      late http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(url, headers: headers).timeout(timeout);
          break;
        case 'POST':
          response = await http.post(url, headers: headers, body: body).timeout(timeout);
          break;
        case 'PUT':
          response = await http.put(url, headers: headers, body: body).timeout(timeout);
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers).timeout(timeout);
          break;
        default:
          throw Exception('Unsupported method: $method');
      }

      if (response.statusCode == 401) {
        await AuthService.instance.logout();
        return {
          'success': false,
          'error': 'Session expired. Please login again.',
          'unauthorized': true,
        };
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      // Try to parse error message from body
      try {
        final parsed = json.decode(response.body) as Map<String, dynamic>;
        return {
          'success': false,
          'error': parsed['error'] ?? 'Server error (${response.statusCode})',
          'statusCode': response.statusCode,
        };
      } catch (_) {
        return {
          'success': false,
          'error': 'Server error (${response.statusCode})',
          'statusCode': response.statusCode,
        };
      }
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out'};
    } catch (e) {
      return {'success': false, 'error': 'Request failed: $e'};
    }
  }

  // ── Authentication ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password, 'username': username}),
      ).timeout(timeout);
      return json.decode(response.body);
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out'};
    } catch (e) {
      return {'success': false, 'error': 'Registration failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      ).timeout(timeout);
      return json.decode(response.body);
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out'};
    } catch (e) {
      return {'success': false, 'error': 'Login failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> getProfile() async =>
      _authRequest('GET', '/auth/profile');

  static Future<Map<String, dynamic>> logout() async =>
      _authRequest('POST', '/auth/logout');

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async =>
      _authRequest('POST', '/auth/change-password',
          body: json.encode({
            'current_password': currentPassword,
            'new_password': newPassword,
          }));

  // ── Image upload ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> uploadImage(XFile imageFile) async {
    try {
      if (kIsWeb) return await _uploadImageWeb(imageFile);
      return await _uploadImageNative(imageFile);
    } on TimeoutException {
      return {'success': false, 'error': 'Request timed out. Please try again.'};
    } catch (e) {
      return {'success': false, 'error': 'Failed to upload image: $e'};
    }
  }

  static Future<Map<String, dynamic>> _uploadImageWeb(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    String mimeType = 'image/jpeg';
    final name = imageFile.name.toLowerCase();
    if (name.endsWith('.png')) mimeType = 'image/png';
    if (name.endsWith('.gif')) mimeType = 'image/gif';
    if (name.endsWith('.webp')) mimeType = 'image/webp';

    final response = await http.post(
      Uri.parse('$baseUrl/upload'),
      headers: {
        'Content-Type': 'application/json',
        ..._authHeaders,
      },
      body: json.encode({'image': 'data:$mimeType;base64,$base64Image'}),
    ).timeout(timeout);

    if (response.statusCode == 200) return json.decode(response.body);
    if (response.statusCode == 401) {
      await AuthService.instance.logout();
      return {'success': false, 'error': 'Session expired', 'unauthorized': true};
    }
    return {'success': false, 'error': 'Server error (${response.statusCode})'};
  }

  static Future<Map<String, dynamic>> _uploadImageNative(XFile imageFile) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));

    request.headers.addAll(_authHeaders);

    final bytes = await imageFile.readAsBytes();
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: imageFile.name,
    ));

    final streamed = await request.send().timeout(timeout);
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) return json.decode(body);
    if (streamed.statusCode == 401) {
      await AuthService.instance.logout();
      return {'success': false, 'error': 'Session expired', 'unauthorized': true};
    }
    return {'success': false, 'error': 'Server error (${streamed.statusCode}): $body'};
  }

  // ── Inventory ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getInventory() async =>
      _authRequest('GET', '/inventory');

  static Future<Map<String, dynamic>> addToInventory(
          List<Map<String, dynamic>> bricks) async =>
      _authRequest('POST', '/inventory', body: json.encode({'bricks': bricks}));

  static Future<Map<String, dynamic>> updateInventory(
          List<Map<String, dynamic>> bricks) async =>
      _authRequest('POST', '/inventory', body: json.encode({'bricks': bricks}));

  static Future<Map<String, dynamic>> updateInventoryItem(
    String brickId, {
    String? color,
    int? quantity,
    String? name,
  }) async =>
      _authRequest('PUT', '/inventory/$brickId',
          body: json.encode({
            if (color != null) 'color': color,
            if (quantity != null) 'quantity': quantity,
            if (name != null) 'name': name,
          }));

  static Future<Map<String, dynamic>> deleteInventoryItem(
    String brickId, {
    String color = 'Unknown',
  }) async =>
      _authRequest('DELETE', '/inventory/$brickId?color=$color');

  static Future<Map<String, dynamic>> clearInventory() async =>
      _authRequest('DELETE', '/inventory?confirm=true');

  // ── Recommendations ─────────────────────────────────────────────

  // Fixed: was using _safeGet (no auth), now uses _authRequest
  static Future<Map<String, dynamic>> getRecommendations() async =>
      _authRequest('GET', '/recommendations');

  // ── Scan history ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getScanHistory({int limit = 20}) async =>
      _authRequest('GET', '/scan-history?limit=$limit');

  // ── Health ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'), headers: {'Accept': 'application/json'})
          .timeout(timeout);
      if (response.statusCode == 200) return json.decode(response.body);
      return {'error': 'Server returned status ${response.statusCode}'};
    } on TimeoutException {
      return {'error': 'Connection timed out'};
    } catch (e) {
      return {'error': 'Request failed: $e'};
    }
  }

  static Future<bool> testConnection() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/health'), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Metadata ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getBrickInfo(String brickId) async =>
      _authRequest('GET', '/brick/$brickId');

  static Future<Map<String, dynamic>> getSetInfo(String setId) async =>
      _authRequest('GET', '/set/$setId');

  // ── Pinecone ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> findSimilarBricks(
    Map<String, dynamic> brick, {
    int topK = 5,
  }) async =>
      _authRequest('POST', '/similar', body: json.encode({'brick': brick, 'top_k': topK}));

  static Future<Map<String, dynamic>> getPineconeStats() async =>
      _authRequest('GET', '/pinecone/stats');
}