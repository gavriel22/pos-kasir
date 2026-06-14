// lib/services/api_client.dart
//
// Thin HTTP wrapper di atas dart:io HttpClient.
// Hanya bertanggung jawab pada I/O — tidak ada business logic di sini.
// Semua logic ada di repository layer.

import 'dart:convert';
import 'dart:io';

/// Exception khusus untuk error dari API backend.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  // TODO: pindahkan ke environment config atau flutter_dotenv
  static const String _baseUrl = 'https://your-pos-api.vercel.app/api/v1';

  String? _token; // JWT dari login — di-set oleh AuthRepository setelah login

  void setToken(String token) => _token = token;
  void clearToken() => _token = null;

  Map<String, String> get _headers => {
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.acceptHeader: 'application/json',
        if (_token != null) HttpHeaders.authorizationHeader: 'Bearer $_token',
      };

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      _headers.forEach(request.headers.set);
      request.write(jsonEncode(body));

      final response = await request.close().timeout(timeout);
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(responseBody) as Map<String, dynamic>;
      }

      final error = jsonDecode(responseBody) as Map<String, dynamic>;
      throw ApiException(
        response.statusCode,
        error['error'] as String? ?? 'Server error',
      );
    } on SocketException {
      throw const ApiException(0, 'Tidak ada koneksi internet');
    } on HttpException catch (e) {
      throw ApiException(0, e.message);
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = Uri.parse('$_baseUrl$path')
        .replace(queryParameters: queryParams);
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      _headers.forEach(request.headers.set);

      final response = await request.close().timeout(timeout);
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(responseBody) as Map<String, dynamic>;
      }

      throw ApiException(response.statusCode, 'GET $path gagal');
    } on SocketException {
      throw const ApiException(0, 'Tidak ada koneksi internet');
    } finally {
      client.close();
    }
  }
}