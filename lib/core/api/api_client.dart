import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String defaultServerUrl = "https://oasis.vpsbusinesssolution.com";
  
  Future<Map<String, dynamic>> post(String method, Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('serverUrl') ?? defaultServerUrl;
    final sid = prefs.getString('sid');
    
    final url = Uri.parse('$serverUrl/api/method/$method');
    
    debugPrint('🚀 [API POST] $url');
    debugPrint('📦 Body: ${jsonEncode(body)}');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (sid != null) 'Cookie': 'sid=$sid',
      },
      body: jsonEncode(body),
    );

    debugPrint('📥 [Response ${response.statusCode}] $url');
    debugPrint('📄 Data: ${response.body}');
    
    // Extract session ID (sid) from response headers if present
    final String? setCookie = response.headers['set-cookie'];
    if (setCookie != null && setCookie.contains('sid=')) {
      final sidValue = setCookie.split('sid=')[1].split(';')[0];
      if (sidValue != 'Guest') {
        await prefs.setString('sid', sidValue);
      }
    }
    
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
    
    debugPrint('🚀 [API GET] $url');
    
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        if (sid != null) 'Cookie': 'sid=$sid',
      },
    );

    debugPrint('📥 [Response ${response.statusCode}] $url');
    debugPrint('📄 Data: ${response.body}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }

  /// Upload a file to Frappe's /api/method/upload_file
  /// Attaches to the given [doctype]/[docname] if provided.
  Future<Map<String, dynamic>> uploadFile({
    required String filePath,
    required String fileName,
    String? doctype,
    String? docname,
    bool isPrivate = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('serverUrl') ?? defaultServerUrl;
    final sid = prefs.getString('sid');

    final url = Uri.parse('$serverUrl/api/method/upload_file');

    debugPrint('🚀 [UPLOAD] $url — $fileName for $doctype/$docname');

    final request = http.MultipartRequest('POST', url);
    request.headers['Accept'] = 'application/json';
    if (sid != null) {
      request.headers['Cookie'] = 'sid=$sid';
    }
    if (doctype != null) request.fields['doctype'] = doctype;
    if (docname != null) request.fields['docname'] = docname;
    request.fields['is_private'] = isPrivate ? '1' : '0';
    request.fields['folder'] = 'Home/Attachments';

    request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));

    final streamed = await request.send();
    final responseBody = await streamed.stream.bytesToString();

    debugPrint('📥 [Upload Response ${streamed.statusCode}] $url');
    debugPrint('📄 Data: $responseBody');

    if (streamed.statusCode == 200) {
      return jsonDecode(responseBody);
    } else {
      throw Exception('Upload failed: ${streamed.statusCode} - $responseBody');
    }
  }
}
