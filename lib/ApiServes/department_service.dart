import 'dart:convert';
import 'package:http/http.dart' as http;

class DepartmentService {
  static const String baseUrl = "http://72.62.150.219:8383/api"; // عدل IP

  static Future<List<String>> getDepartments() async {
    final url = Uri.parse("$baseUrl/departments");

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      if (json['success'] == true) {
        return List<String>.from(json['departments']);
      }
    }

    return [];
  }
}
