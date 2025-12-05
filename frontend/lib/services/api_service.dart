//lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;

class ApiService {
  //For Android emulator use 10.0.2.2, for iOS simulator use localhost
  static const String baseUrl = 'http://10.0.2.2:5000/api'; // Android emulator
  //static const String baseUrl = 'http://localhost:5000/api'; // iOS simulator
  //static const String baseUrl = 'http://192.168.1.100:5000/api'; // Real device (computer IP)
  
  static const Duration timeout = Duration(seconds: 30);

  static Future<Map<String, dynamic>> uploadImage(File imageFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      
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
    } on SocketException {
      return {
        'success': false,
        'error': 'Cannot connect to server. Please check if the backend is running.'
      };
    } on TimeoutException catch (e) {
      return {
        'success': false,
        'error': 'Request timed out. Please try again.'
      };
    } catch (e) {
      print('Upload error: $e');
      return {
        'success': false,
        'error': 'Failed to upload image: ${e.toString()}'
      };
    }
  }

  static Future<Map<String, dynamic>> getHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health')
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'error': 'Server returned status ${response.statusCode}'};
      }
    } on SocketException {
      return {'error': 'Cannot connect to server'};
    } on TimeoutException {
      return {'error': 'Connection timed out'};
    } catch (e) {
      return {'error': 'Failed to connect to server: $e'};
    }
  }

  static Future<Map<String, dynamic>> getInventory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/inventory')
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'error': 'Server returned status ${response.statusCode}'};
      }
    } on SocketException {
      return {'error': 'Cannot connect to server'};
    } on TimeoutException {
      return {'error': 'Connection timed out'};
    } catch (e) {
      return {'error': 'Failed to fetch inventory: $e'};
    }
  }

  static Future<Map<String, dynamic>> getRecommendations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recommendations')
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'error': 'Server returned status ${response.statusCode}'};
      }
    } on SocketException {
      return {'error': 'Cannot connect to server'};
    } on TimeoutException {
      return {'error': 'Connection timed out'};
    } catch (e) {
      return {'error': 'Failed to fetch recommendations: $e'};
    }
  }
}