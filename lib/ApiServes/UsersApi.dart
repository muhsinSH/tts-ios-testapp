import 'dart:convert';
import 'package:http/http.dart' as http;

import '../user_model.dart';

class ApiService {
  // استبدل 192.168.1.10 بـ IP جهاز الكمبيوتر الخاص بك
  static const String baseUrl = "http://72.62.150.219:8383/api/flutter";

  Future<List<User>> getUsers() async {
    final response = await http.get(Uri.parse("$baseUrl/users"));
    if (response.statusCode == 200) {
      List data = json.decode(response.body)['users'];
      print(data);
      return data.map((u) => User.fromJson(u)).toList();
    }
    throw Exception("Failed to load users");
  }

  // إضافة مستخدم
  Future<bool> addUser(Map<String, dynamic> userData) async {
    final response = await http.post(
      Uri.parse("$baseUrl/add_user"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(userData),
    );
    return response.statusCode == 200;
  }

  // حذف مستخدم
  Future<bool> deleteUser(int id) async {
    final response = await http.delete(Uri.parse("$baseUrl/delete_user/$id"));
    return response.statusCode == 200;
  }
  // تعديل مستخدم موجود
  Future<bool> updateUser(int id, Map<String, dynamic> userData) async {
    final response = await http.put(
      Uri.parse("$baseUrl/update_user/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(userData),
    );
    return response.statusCode == 200;
  }
}