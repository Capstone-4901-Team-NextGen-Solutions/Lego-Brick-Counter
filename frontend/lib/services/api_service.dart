//lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  //For Android emulator use 10.0.2.2, for iOS simulator use localhost
  static const String baseUrl = 'http://10.0.2.2:5000/api'; // Android emulator
  //static const String baseUrl = 'http://localhost:5000/api'; // iOS simulator
  //static const String baseUrl = 'http://192.168.1.100:5000/api'; // Real device (computer IP)

  static Future<Map<String, dynamic>> uploadImage(File imageFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      
      var response = await request.send();
      final respStr = await response.stream.bytesToString();
      return json.decode(respStr);
    } catch (e) {
      print('Upload error: $e');
      return {'error': 'Failed to upload image: $e'};
    }
  }

  static Future<Map<String, dynamic>> getHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return json.decode(response.body);
    } catch (e) {
      return {'error': 'Failed to connect to server: $e'};
    }
  }

  static Future<Map<String, dynamic>> getInventory() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/inventory'));
      return json.decode(response.body);
    } catch (e) {
      return {'error': 'Failed to fetch inventory: $e'};
    }
  }

  static Future<Map<String, dynamic>> getRecommendations() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/recommendations'));
      return json.decode(response.body);
    } catch (e) {
      return {'error': 'Failed to fetch recommendations: $e'};
    }
  }
}