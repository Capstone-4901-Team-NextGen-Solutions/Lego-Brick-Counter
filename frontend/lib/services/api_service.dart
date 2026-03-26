import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

//IMPORT for AuthService
import 'auth_service.dart';

class ApiService {
  // Platform-specific base URL
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    // Android emulator uses 10.0.2.2 to reach host machine's localhost
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000/api';
    }
    // Windows, macOS, Linux, iOS simulator all use localhost
    return 'http://localhost:5000/api';
  }

  static const Duration timeout = Duration(seconds: 30);

  // -------------------------------------------------------------------
  // Auth-aware request helper
  // -------------------------------------------------------------------
  static Future<Map<String, dynamic>> _authRequest(
    String method,
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final auth = AuthService();
    final url = Uri.parse('$baseUrl$endpoint');
    
    final requestHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
      ...auth.authHeaders,
    };
    
    try {
      late http.Response response;
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(url, headers: requestHeaders).timeout(timeout);
          break;
        case 'POST':
          response = await http.post(url, headers: requestHeaders, body: body).timeout(timeout);
          break;
        case 'PUT':
          response = await http.put(url, headers: requestHeaders, body: body).timeout(timeout);
          break;
        case 'DELETE':
          response = await http.delete(url, headers: requestHeaders).timeout(timeout);
          break;
        default:
          throw Exception('Unsupported method: $method');
      }
      
      if (response.statusCode == 401) {
        // Token expired - logout
        final auth = AuthService();
        await auth.logout();
        return {'success': false, 'error': 'Session expired. Please login again.', 'unauthorized': true};
      }
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      
      return {
        'success': false,
        'error': 'Server error (${response.statusCode})',
        'statusCode': response.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'error': 'Connection timed out'};
    } catch (e) {
      return {'success': false, 'error': 'Request failed: $e'};
    }
  }

  // -------------------------------------------------------------------
  // Authentication endpoints
  // -------------------------------------------------------------------
  
  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'username': username,
        }),
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
        body: json.encode({
          'email': email,
          'password': password,
        }),
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
  }) async => _authRequest('POST', '/auth/change-password', body: json.encode({
    'current_password': currentPassword,
    'new_password': newPassword,
  }));

  // -------------------------------------------------------------------
  // Authenticated inventory methods
  // -------------------------------------------------------------------
  
  static Future<Map<String, dynamic>> addToInventory(List<Map<String, dynamic>> bricks) async =>
      _authRequest('POST', '/inventory', body: json.encode({'bricks': bricks}));

  static Future<Map<String, dynamic>> updateInventoryItem(
    String brickId, {
    String? color,
    int? quantity,
    String? name,
  }) async => _authRequest('PUT', '/inventory/$brickId', body: json.encode({
    if (color != null) 'color': color,
    if (quantity != null) 'quantity': quantity,
    if (name != null) 'name': name,
  }));

  static Future<Map<String, dynamic>> deleteInventoryItem(
    String brickId, {
    String color = 'Unknown',
  }) async => _authRequest('DELETE', '/inventory/$brickId?color=$color');

  // -------------------------------------------------------------------
  // Private helpers 
  // -------------------------------------------------------------------

  /// Wraps any HTTP GET call with consistent error handling.
  static Future<Map<String, dynamic>> _safeGet(String path) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$path'),
              headers: {'Accept': 'application/json'})
          .timeout(timeout);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'error': 'Server returned status ${response.statusCode}'};
    } on TimeoutException {
      return {'error': 'Connection timed out'};
    } catch (e) {
      return {'error': 'Request failed: $e'};
    }
  }

  /// Wraps any HTTP POST (JSON body) call.
  static Future<Map<String, dynamic>> _safePost(
      String path, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(timeout);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {
        'success': false,
        'error': 'Server error (${response.statusCode}): ${response.body}'
      };
    } on TimeoutException {
      return {'success': false, 'error': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'error': 'Request failed: $e'};
    }
  }

  // -------------------------------------------------------------------
  // Image upload (platform-aware) 
  // -------------------------------------------------------------------

  static Future<Map<String, dynamic>> uploadImage(XFile imageFile) async {
    try {
      if (kIsWeb) {
        return await _uploadImageWeb(imageFile);
      } else {
        return await _uploadImageNative(imageFile);
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Request timed out. Please try again.'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to upload image: ${e.toString()}'
      };
    }
  }

  static Future<Map<String, dynamic>> _uploadImageWeb(XFile imageFile) async {
    final auth = AuthService();
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    String mimeType = 'image/jpeg';
    final name = imageFile.name.toLowerCase();
    if (name.endsWith('.png')) mimeType = 'image/png';
    if (name.endsWith('.gif')) mimeType = 'image/gif';
    if (name.endsWith('.webp')) mimeType = 'image/webp';

    final response = await http
        .post(
          Uri.parse('$baseUrl/upload'),
          headers: {
            'Content-Type': 'application/json',
            ...auth.authHeaders,
          },
          body: json.encode({'image': 'data:$mimeType;base64,$base64Image'}),
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    if (response.statusCode == 401) {
      await auth.logout();
      return {'success': false, 'error': 'Session expired', 'unauthorized': true};
    }
    return {
      'success': false,
      'error': 'Server error (${response.statusCode})'
    };
  }

  static Future<Map<String, dynamic>> _uploadImageNative(
      XFile imageFile) async {
    final auth = AuthService();
    var request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
    
    // Add auth headers
    request.headers.addAll(auth.authHeaders);
    
    final bytes = await imageFile.readAsBytes();
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: imageFile.name,
    ));

    var streamed = await request.send().timeout(timeout);
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) {
      return json.decode(body);
    }
    if (streamed.statusCode == 401) {
      await auth.logout();
      return {'success': false, 'error': 'Session expired', 'unauthorized': true};
    }
    return {
      'success': false,
      'error': 'Server error (${streamed.statusCode}): $body'
    };
  }

  // -------------------------------------------------------------------
  // Health 
  // -------------------------------------------------------------------

  static Future<Map<String, dynamic>> getHealth() async =>
      _safeGet('/health');

  static Future<bool> testConnection() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/health'),
              headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------------------
  // Inventory 
  // -------------------------------------------------------------------

  static Future<Map<String, dynamic>> getInventory() async =>
      _authRequest('GET', '/inventory');  // Changed to use auth

  static Future<Map<String, dynamic>> updateInventory(
          List<Map<String, dynamic>> bricks) async =>
      _authRequest('POST', '/inventory', body: json.encode({'bricks': bricks}));  // Changed to use auth

  static Future<Map<String, dynamic>> clearInventory() async {
    try {
      final auth = AuthService();
      final response = await http
          .delete(
            Uri.parse('$baseUrl/inventory?confirm=true'),
            headers: {
              'Accept': 'application/json',
              ...auth.authHeaders,
            },
          )
          .timeout(timeout);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {
        'success': false,
        'error': 'Failed (${response.statusCode})'
      };
    } catch (e) {
      return {'success': false, 'error': '$e'};
    }
  }

  // -------------------------------------------------------------------
  // Recommendations
  // -------------------------------------------------------------------

  static Future<Map<String, dynamic>> getRecommendations() async =>
      _safeGet('/recommendations');

  // -------------------------------------------------------------------
  // Metadata 
  // -------------------------------------------------------------------

  static Future<Map<String, dynamic>> getBrickInfo(String brickId) async =>
      _safeGet('/brick/$brickId');

  static Future<Map<String, dynamic>> getSetInfo(String setId) async =>
      _safeGet('/set/$setId');

  // -------------------------------------------------------------------
  // Pinecone endpoints 
  // -------------------------------------------------------------------

  /// Find bricks similar to [brick] using Pinecone vector search.
  static Future<Map<String, dynamic>> findSimilarBricks(
          Map<String, dynamic> brick,
          {int topK = 5}) async =>
      _safePost('/similar', {'brick': brick, 'top_k': topK});

  /// Get Pinecone index statistics.
  static Future<Map<String, dynamic>> getPineconeStats() async =>
      _safeGet('/pinecone/stats');

  /// Get user's scan history with detection results.
  static Future<List<dynamic>> getScanHistory() async {
    try {
      final result = await _authRequest('GET', '/scan-history');
      if (result['success'] == true && result['scans'] != null) {
        final scans = result['scans'];
        if (scans is List) {
          return List<dynamic>.from(scans);
        }
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load scan history: $e');
    }
  }

  /// Clear all scan history for current user
  static Future<void> clearScanHistory() async {
    final result = await _authRequest('DELETE', '/scan-history');
    if (result['success'] != true) {
      throw Exception(result['error'] ?? 'Failed to clear scan history');
    }
  }

  /// Export inventory as JSON string
  static Future<String> exportInventory() async {
    final result = await _authRequest('GET', '/inventory');
    if (result['success'] == true && result['inventory'] != null) {
      return json.encode(result['inventory']);
    }
    throw Exception('Failed to export inventory');
  }
}

