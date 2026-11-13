
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'http://localhost:3000/api';

  // POST - Gửi dữ liệu lên server
  static Future<http.Response> post(
      String endpoint,
      Map<String, dynamic> body, {
        String? token,
      }) async {
    final url = Uri.parse('$baseUrl$endpoint');

    return http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
  }

  // GET - Lấy dữ liệu từ server
  static Future<http.Response> get(
      String endpoint, {
        String? token,
      }) async {
    final url = Uri.parse('$baseUrl$endpoint');

    return http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  // PUT - Cập nhật dữ liệu trên server
  static Future<http.Response> put(
      String endpoint,
      Map<String, dynamic> body, {
        String? token,
      }) async {
    final url = Uri.parse('$baseUrl$endpoint');

    return http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
  }

  // DELETE - Xóa dữ liệu trên server
  static Future<http.Response> delete(
      String endpoint, {
        String? token,
      }) async {
    final url = Uri.parse('$baseUrl$endpoint');

    return http.delete(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }
}
