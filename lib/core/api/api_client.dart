import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String defaultServerUrl = "https://vps-mobile.vpsbusinesssolution.com";
  
  Future<Map<String, dynamic>> post(String method, Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('serverUrl') ?? defaultServerUrl;
    final sid = prefs.getString('sid');
    
    final url = Uri.parse('$serverUrl/api/method/$method');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (sid != null) 'Cookie': 'sid=$sid',
      },
      body: jsonEncode(body),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> get(String method, {Map<String, String>? params}) async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('serverUrl') ?? defaultServerUrl;
    final sid = prefs.getString('sid');
    
    var url = Uri.parse('$serverUrl/api/method/$method');
    if (params != null) {
      url = url.replace(queryParameters: params);
    }
    
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        if (sid != null) 'Cookie': 'sid=$sid',
      },
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }
}
