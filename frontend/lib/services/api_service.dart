//lib/services/api_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io'; 

class ApiService {
  //Platform-specific base URLs with web support
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api'; //Web
    } else {
      return 'http://10.0.2.2:5000/api'; //Android emulator
      //For iOS simulator: 'http://localhost:5000/api'
      //For real device: 'http://<your-computer-ip>:5000/api'
    }
  }

  static const Duration timeout = Duration(seconds: 30);

  // Upload image to Flask backend with platform detection
  static Future<Map<String, dynamic>> uploadImage(XFile imageFile) async {
    try {
      if (kIsWeb) {
        return await _uploadImageWeb(imageFile);
      } else {
        return await _uploadImageNative(imageFile);
      }
    } on SocketException {
      return {
        'success': false,
        'error': 'Cannot connect to server. Please check if the backend is running.'
      };
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

  //Web implementation - uses base64 encoding
  static Future<Map<String, dynamic>> _uploadImageWeb(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      String mimeType = 'image/jpeg';
      if (imageFile.name.toLowerCase().endsWith('.png')) mimeType = 'image/png';
      if (imageFile.name.toLowerCase().endsWith('.gif')) mimeType = 'image/gif';
      
      final response = await http.post(
        Uri.parse('$baseUrl/upload'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'image': 'data:$mimeType;base64,$base64Image'
        }),
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Server error (${response.statusCode}): ${response.body}'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Web upload failed: $e'
      };
    }
  }

  //Mobile/Desktop implementation - uses multipart form with timeout
  static Future<Map<String, dynamic>> _uploadImageNative(XFile imageFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
      
      final bytes = await imageFile.readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: imageFile.name,
      ));
      
      var streamedResponse = await request.send().timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException('Request timed out after ${timeout.inSeconds} seconds');
        },
      );
      
      final respStr = await streamedResponse.stream.bytesToString();
      
      if (streamedResponse.statusCode == 200) {
        return json.decode(respStr);
      } else {
        return {
          'success': false,
          'error': 'Server error (${streamedResponse.statusCode}): $respStr'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Native upload failed: $e'
      };
    }
  }

  //Check if Flask server is running with timeout
  static Future<Map<String, dynamic>> getHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'status': 'error',
          'error': 'Server returned status ${response.statusCode}'
        };
      }
    } on SocketException {
      return {
        'status': 'error',
        'error': 'Cannot connect to server'
      };
    } on TimeoutException {
      return {
        'status': 'error',
        'error': 'Connection timed out'
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': 'Failed to connect to server: $e'
      };
    }
  }

  //Get user inventory from backend with timeout
  static Future<Map<String, dynamic>> getInventory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/inventory'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'error': 'Server returned status ${response.statusCode}'
        };
      }
    } on SocketException {
      return {'error': 'Cannot connect to server'};
    } on TimeoutException {
      return {'error': 'Connection timed out'};
    } catch (e) {
      return {
        'error': 'Failed to fetch inventory: $e'
      };
    }
  }

  //Get set recommendations from backend with timeout
  static Future<Map<String, dynamic>> getRecommendations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recommendations'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'error': 'Server returned status ${response.statusCode}'
        };
      }
    } on SocketException {
      return {'error': 'Cannot connect to server'};
    } on TimeoutException {
      return {'error': 'Connection timed out'};
    } catch (e) {
      return {
        'error': 'Failed to fetch recommendations: $e'
      };
    }
  }

  //Update inventory with new bricks (after scan)
  static Future<Map<String, dynamic>> updateInventory(List<Map<String, dynamic>> bricks) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/inventory'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'bricks': bricks}),
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Failed to update inventory: ${response.statusCode}'
        };
      }
    } on SocketException {
      return {
        'success': false,
        'error': 'Cannot connect to server'
      };
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Request timed out'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to update inventory: $e'
      };
    }
  }

  //Clear user inventory with timeout
  static Future<Map<String, dynamic>> clearInventory() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/inventory'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Failed to clear inventory: ${response.statusCode}'
        };
      }
    } on SocketException {
      return {
        'success': false,
        'error': 'Cannot connect to server'
      };
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Request timed out'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to clear inventory: $e'
      };
    }
  }

  //Test connection to backend with timeout (quick test)
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  //Get detailed brick information by ID
  static Future<Map<String, dynamic>> getBrickInfo(String brickId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/brick/$brickId'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'error': 'Brick not found: $brickId'
        };
      }
    } on SocketException {
      return {'error': 'Cannot connect to server'};
    } on TimeoutException {
      return {'error': 'Connection timed out'};
    } catch (e) {
      return {
        'error': 'Failed to get brick info: $e'
      };
    }
  }

  //Get Lego set information by set ID
  static Future<Map<String, dynamic>> getSetInfo(String setId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/set/$setId'),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'error': 'Set not found: $setId'
        };
      }
    } on SocketException {
      return {'error': 'Cannot connect to server'};
    } on TimeoutException {
      return {'error': 'Connection timed out'};
    } catch (e) {
      return {
        'error': 'Failed to get set info: $e'
      };
    }
  }
}