import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  static String get baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android Emulator gọi server đang chạy trên máy tính qua địa chỉ này.
      return 'http://10.0.2.2:3000';
    }

    // Chrome hoặc Windows desktop.
    return 'http://localhost:3000';
  }

  static Map<String, String> _headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Uri _url(String endpoint) {
    return Uri.parse('$baseUrl$endpoint');
  }

  // POST
  static Future<http.Response> post(
      String endpoint,
      Map<String, dynamic> body, {
        String? token,
      }) {
    return http.post(
      _url(endpoint),
      headers: _headers(token: token),
      body: jsonEncode(body),
    );
  }

  // GET
  static Future<http.Response> get(
      String endpoint, {
        String? token,
      }) {
    return http.get(
      _url(endpoint),
      headers: _headers(token: token),
    );
  }

  // PUT
  static Future<http.Response> put(
      String endpoint,
      Map<String, dynamic> body, {
        String? token,
      }) {
    return http.put(
      _url(endpoint),
      headers: _headers(token: token),
      body: jsonEncode(body),
    );
  }

  // PATCH
  static Future<http.Response> patch(
      String endpoint,
      Map<String, dynamic> body, {
        String? token,
      }) {
    return http.patch(
      _url(endpoint),
      headers: _headers(token: token),
      body: jsonEncode(body),
    );
  }

  // DELETE
  static Future<http.Response> delete(
      String endpoint, {
        String? token,
      }) {
    return http.delete(
      _url(endpoint),
      headers: _headers(token: token),
    );
  }
}