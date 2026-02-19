// lib/services/api_service.dart
//
// v2.0 – Pinecone-aware, web-safe, deduplicated error handling

import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'image': 'data:$mimeType;base64,$base64Image'}),
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return {
      'success': false,
      'error': 'Server error (${response.statusCode})'
    };
  }

  static Future<Map<String, dynamic>> _uploadImageNative(
      XFile imageFile) async {
    var request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
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
      _safeGet('/inventory');

  static Future<Map<String, dynamic>> updateInventory(
          List<Map<String, dynamic>> bricks) async =>
      _safePost('/inventory', {'bricks': bricks});

  static Future<Map<String, dynamic>> clearInventory() async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/inventory?confirm=true'),
              headers: {'Accept': 'application/json'})
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
  // Pinecone endpoints (NEW)
  // -------------------------------------------------------------------

  /// Find bricks similar to [brick] using Pinecone vector search.
  static Future<Map<String, dynamic>> findSimilarBricks(
          Map<String, dynamic> brick,
          {int topK = 5}) async =>
      _safePost('/similar', {'brick': brick, 'top_k': topK});

  /// Get Pinecone index statistics.
  static Future<Map<String, dynamic>> getPineconeStats() async =>
      _safeGet('/pinecone/stats');
}
