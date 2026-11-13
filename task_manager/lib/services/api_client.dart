
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'http://localhost:3000';

  // POST - Gá»­i dá»¯ liá»‡u lĂªn server
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

  // GET - Láº¥y dá»¯ liá»‡u tá»« server
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

  // PUT - Cáº­p nháº­t dá»¯ liá»‡u trĂªn server
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

  // DELETE - XĂ³a dá»¯ liá»‡u trĂªn server
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
