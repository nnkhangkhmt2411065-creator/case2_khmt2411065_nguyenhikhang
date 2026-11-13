import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class StatisticsService {
  // Android Emulator: localhost tro ve may tinh chay Backend.
  static const String baseUrl = 'http://localhost:3000';

  static Future<Map<String, dynamic>> _get(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Exception('Ban chua dang nhap');
    }

    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('API loi ${response.statusCode}: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getTaskStatistics() {
    return _get('/statistics/tasks');
  }

  static Future<Map<String, dynamic>> getAssignmentStatistics() {
    return _get('/statistics/assignments');
  }

  static Future<Map<String, dynamic>> getDeadlineStatistics() {
    return _get('/statistics/deadlines');
  }
}
