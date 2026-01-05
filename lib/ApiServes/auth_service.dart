import 'package:http/http.dart' as http;
import 'dart:convert';

import '../user_model.dart';


class AuthService {
  static const String _baseUrl = 'http://72.62.150.219:8383'; // استبدل بعنوان خادمك

  static Future<Map<String, dynamic>> login({
    required String badgeNumber,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/flutter/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'badge_number': badgeNumber,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return {
          'success': true,
          'user': User.fromJson(data['user']),
          'message': data['message']
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'فشل تسجيل الدخول'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'خطأ في الاتصال: $e'
      };
    }
  }
}