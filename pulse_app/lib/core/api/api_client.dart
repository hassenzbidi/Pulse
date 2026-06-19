import 'package:dio/dio.dart';

class ApiClient {
  static const String baseUrl = 'http://192.168.1.100:3000/api';

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  static Dio get dio => _dio;

  // Token utilisateur normal
  static void setUserId(String userId) {
    _dio.options.headers['Authorization'] =
      'Bearer $userId';
  }

  // Token admin
  static String? _adminToken;

  static void setAdminToken(String token) {
    _adminToken = token;
  }

  static Map<String, String> get adminHeaders {
    if (_adminToken == null) return {};
    final decoded = String.fromCharCodes(
      Uri.parse('data:text/plain;base64,$_adminToken')
        .data!.contentAsBytes());
    final parts   = decoded.split(':');
    return {
      'username': parts[0],
      'password': parts.sublist(1).join(':'),
    };
  }
}