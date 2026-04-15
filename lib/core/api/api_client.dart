import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../services/token_storage_service.dart';
import 'api_endpoints.dart';

/// API Client for making HTTP requests
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  bool _isRefreshing = false;

  String _normalizeBearerToken(String token) {
    final trimmed = token.trim();
    if (trimmed.toLowerCase().startsWith('bearer ')) {
      return trimmed.substring(7).trim();
    }
    return trimmed;
  }

  /// Attempt to refresh the access token using the stored refresh token.
  Future<bool> _tryRefreshToken() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;
    try {
      final refreshToken =
          await TokenStorageService.instance.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;

      if (kDebugMode) {
        print('🔄 Attempting automatic token refresh...');
      }

      final response = await http
          .post(
            Uri.parse(ApiEndpoints.refreshToken),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final responseData =
              data['data'] as Map<String, dynamic>? ?? {};
          final newToken = (responseData['accessToken'] ??
                  responseData['token'] ??
                  responseData['access_token'])
              ?.toString();
          final newRefresh = (responseData['refreshToken'] ??
                  responseData['refresh_token'])
              ?.toString();

          if (newToken != null && newToken.isNotEmpty) {
            await TokenStorageService.instance.saveTokens(
              accessToken: newToken,
              refreshToken:
                  (newRefresh != null && newRefresh.isNotEmpty)
                      ? newRefresh
                      : refreshToken,
            );
            if (kDebugMode) {
              print('✅ Token refreshed automatically');
            }
            return true;
          }
        }
      }

      if (kDebugMode) {
        print('❌ Token refresh failed (status: ${response.statusCode})');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Token refresh error: $e');
      }
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  Map<String, dynamic> _sanitizeBodyForLogs(Map<String, dynamic> body) {
    dynamic sanitize(dynamic v, {String? key}) {
      final lowerKey = key?.toLowerCase();
      final isSensitiveKey = lowerKey != null &&
          (lowerKey.contains('password') ||
              lowerKey.contains('token') ||
              lowerKey == 'authorization' ||
              lowerKey == 'id_token' ||
              lowerKey == 'access_token' ||
              lowerKey == 'refresh_token' ||
              lowerKey == 'refreshtoken');

      if (v is Map) {
        return v.map((k, val) =>
            MapEntry(k.toString(), sanitize(val, key: k.toString())));
      }
      if (v is List) {
        return v.map((e) => sanitize(e, key: key)).toList();
      }
      if (v is String) {
        if (!isSensitiveKey) return v;
        if (v.isEmpty) return v;
        final previewLen = v.length >= 12 ? 12 : v.length;
        return '${v.substring(0, previewLen)}...<redacted>';
      }
      if (isSensitiveKey && v != null) {
        return '<redacted>';
      }
      return v;
    }

    return sanitize(body) as Map<String, dynamic>;
  }

  /// Log API request (optionally via dart:developer for filterable logs)
  void _logRequest(String method, String url, Map<String, String>? headers,
      Map<String, dynamic>? body,
      {String? logTag}) {
    if (!kDebugMode && logTag == null) return;
    final sb = StringBuffer();
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('📤 API REQUEST');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('Method: $method');
    sb.writeln('URL: $url');
    if (headers != null && headers.isNotEmpty) {
      sb.writeln('Headers:');
      headers.forEach((key, value) {
        if (key.toLowerCase() == 'authorization') {
          sb.writeln(
              '  $key: Bearer ${value.length > 20 ? "${value.substring(0, 20)}..." : value}');
        } else {
          sb.writeln('  $key: $value');
        }
      });
      if (!headers.containsKey('Authorization')) {
        sb.writeln('  ⚠️ WARNING: Authorization header is MISSING!');
      }
    } else {
      sb.writeln('⚠️ WARNING: No headers provided!');
    }
    if (body != null && body.isNotEmpty) {
      sb.writeln('Body:');
      try {
        sb.writeln(const JsonEncoder.withIndent('  ')
            .convert(_sanitizeBodyForLogs(body)));
      } catch (e) {
        sb.writeln('  $body');
      }
    }
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    final msg = sb.toString();
    if (logTag != null) {
      developer.log(msg, name: logTag);
    } else if (kDebugMode) {
      print(msg);
    }
  }

  /// Log API response (optionally via dart:developer for filterable logs)
  void _logResponse(String method, String url, int statusCode,
      Map<String, dynamic>? response, String? error,
      {String? logTag}) {
    if (!kDebugMode && logTag == null) return;
    final sb = StringBuffer();
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('📥 API RESPONSE');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('Method: $method');
    sb.writeln('URL: $url');
    sb.writeln('Status Code: $statusCode');
    if (error != null) {
      sb.writeln('❌ Error: $error');
    } else if (response != null) {
      sb.writeln('Response:');
      try {
        sb.writeln(const JsonEncoder.withIndent('  ').convert(response));
      } catch (e) {
        sb.writeln('  $response');
      }
    }
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    final msg = sb.toString();
    if (logTag != null) {
      developer.log(msg, name: logTag);
    } else if (kDebugMode) {
      print(msg);
    }
  }

  /// Base headers for all requests
  Future<Map<String, String>> _getHeaders({
    Map<String, String>? additionalHeaders,
    bool requireAuth = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Add authentication token from cache if required (like Dio interceptor)
    if (requireAuth) {
      // Always read token from cache (like Dio onRequest interceptor)
      final token = await TokenStorageService.instance.getAccessToken();

      if (kDebugMode) {
        print('🔑 Token Check (from cache):');
        print('  requireAuth: $requireAuth');
        print('  token exists: ${token != null}');
        print('  token length: ${token?.length ?? 0}');
      }

      if (token != null && token.isNotEmpty) {
        final normalizedToken = _normalizeBearerToken(token);
        headers['Authorization'] = 'Bearer $normalizedToken';
        if (kDebugMode) {
          print('  ✅ Authorization header added from cache');
          print(
              '  token preview: ${normalizedToken.length > 20 ? "${normalizedToken.substring(0, 20)}..." : normalizedToken}');
        }
      } else {
        if (kDebugMode) {
          print('  ⚠️ WARNING: No token found in cache');
          print(
              '  💡 Make sure you are logged in and token is cached correctly');
        }
      }
    } else {
      if (kDebugMode) {
        print('🔓 Auth not required for this request');
      }
    }

    // Add any additional headers
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
      // If additional headers contain Authorization, it will override the one we set
      if (additionalHeaders.containsKey('Authorization')) {
        if (kDebugMode) {
          print('  ℹ️ Authorization header provided in additionalHeaders');
        }
      }
    }

    if (kDebugMode) {
      print('📋 Final headers: ${headers.keys.toList()}');
    }

    return headers;
  }

  /// GET request
  Future<Map<String, dynamic>> get(
    String url, {
    Map<String, String>? headers,
    bool requireAuth = true,
    String? logTag,
  }) async {
    try {
      final finalHeaders = await _getHeaders(
        additionalHeaders: headers,
        requireAuth: requireAuth,
      );

      if (logTag != null) {
        _logRequest('GET', url, finalHeaders, null, logTag: logTag);
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: finalHeaders,
          )
          .timeout(const Duration(seconds: 45));

      final responseData = _handleResponse(response);
      if (logTag != null) {
        _logResponse('GET', url, response.statusCode, responseData, null,
            logTag: logTag);
      }
      return responseData;
    } on ApiException catch (e) {
      if (e.statusCode == 401 && requireAuth && !_isRefreshing) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          final retryHeaders = await _getHeaders(
            additionalHeaders: headers,
            requireAuth: requireAuth,
          );
          final retryResponse = await http
              .get(Uri.parse(url), headers: retryHeaders)
              .timeout(const Duration(seconds: 45));
          return _handleResponse(retryResponse);
        }
        await TokenStorageService.instance.clearTokens();
      }
      if (logTag != null) {
        _logResponse('GET', url, e.statusCode ?? 0, null, e.toString(),
            logTag: logTag);
      }
      rethrow;
    } catch (e) {
      if (logTag != null) {
        _logResponse('GET', url, 0, null, e.toString(), logTag: logTag);
      }
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  /// POST request
  Future<Map<String, dynamic>> post(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    bool requireAuth = true,
    String? logTag,
  }) async {
    try {
      final finalHeaders = await _getHeaders(
        additionalHeaders: headers,
        requireAuth: requireAuth,
      );

      _logRequest('POST', url, finalHeaders, body, logTag: logTag);

      final response = await http
          .post(
            Uri.parse(url),
            headers: finalHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 45));

      final responseData = _handleResponse(response);
      _logResponse('POST', url, response.statusCode, responseData, null,
          logTag: logTag);
      return responseData;
    } on ApiException catch (e) {
      if (e.statusCode == 401 && requireAuth && !_isRefreshing) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          final retryHeaders = await _getHeaders(
            additionalHeaders: headers,
            requireAuth: requireAuth,
          );
          final retryResponse = await http
              .post(
                Uri.parse(url),
                headers: retryHeaders,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(const Duration(seconds: 45));
          return _handleResponse(retryResponse);
        }
        await TokenStorageService.instance.clearTokens();
      }
      _logResponse('POST', url, e.statusCode ?? 0, null, e.toString(),
          logTag: logTag);
      rethrow;
    } catch (e) {
      _logResponse('POST', url, 0, null, e.toString(), logTag: logTag);
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  /// PUT request
  Future<Map<String, dynamic>> put(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    bool requireAuth = true,
    String? logTag,
  }) async {
    try {
      final finalHeaders = await _getHeaders(
        additionalHeaders: headers,
        requireAuth: requireAuth,
      );

      _logRequest('PUT', url, finalHeaders, body, logTag: logTag);

      final response = await http
          .put(
            Uri.parse(url),
            headers: finalHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 45));

      final responseData = _handleResponse(response);
      _logResponse('PUT', url, response.statusCode, responseData, null,
          logTag: logTag);
      return responseData;
    } on ApiException catch (e) {
      if (e.statusCode == 401 && requireAuth && !_isRefreshing) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          final retryHeaders = await _getHeaders(
            additionalHeaders: headers,
            requireAuth: requireAuth,
          );
          final retryResponse = await http
              .put(
                Uri.parse(url),
                headers: retryHeaders,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(const Duration(seconds: 45));
          return _handleResponse(retryResponse);
        }
        await TokenStorageService.instance.clearTokens();
      }
      _logResponse('PUT', url, e.statusCode ?? 0, null, e.toString(),
          logTag: logTag);
      rethrow;
    } catch (e) {
      _logResponse('PUT', url, 0, null, e.toString(), logTag: logTag);
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  /// PATCH request
  Future<Map<String, dynamic>> patch(
    String url, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    bool requireAuth = true,
    String? logTag,
  }) async {
    try {
      final finalHeaders = await _getHeaders(
        additionalHeaders: headers,
        requireAuth: requireAuth,
      );

      _logRequest('PATCH', url, finalHeaders, body, logTag: logTag);

      final response = await http
          .patch(
            Uri.parse(url),
            headers: finalHeaders,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 45));

      final responseData = _handleResponse(response);
      _logResponse('PATCH', url, response.statusCode, responseData, null,
          logTag: logTag);
      return responseData;
    } on ApiException catch (e) {
      if (e.statusCode == 401 && requireAuth && !_isRefreshing) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          final retryHeaders = await _getHeaders(
            additionalHeaders: headers,
            requireAuth: requireAuth,
          );
          final retryResponse = await http
              .patch(
                Uri.parse(url),
                headers: retryHeaders,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(const Duration(seconds: 45));
          return _handleResponse(retryResponse);
        }
        await TokenStorageService.instance.clearTokens();
      }
      _logResponse('PATCH', url, e.statusCode ?? 0, null, e.toString(),
          logTag: logTag);
      rethrow;
    } catch (e) {
      _logResponse('PATCH', url, 0, null, e.toString(), logTag: logTag);
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  /// DELETE request
  Future<Map<String, dynamic>> delete(
    String url, {
    Map<String, String>? headers,
    bool requireAuth = true,
    String? logTag,
  }) async {
    try {
      final finalHeaders = await _getHeaders(
        additionalHeaders: headers,
        requireAuth: requireAuth,
      );

      _logRequest('DELETE', url, finalHeaders, null, logTag: logTag);

      final response = await http
          .delete(
            Uri.parse(url),
            headers: finalHeaders,
          )
          .timeout(const Duration(seconds: 45));

      final responseData = _handleResponse(response);
      _logResponse('DELETE', url, response.statusCode, responseData, null,
          logTag: logTag);
      return responseData;
    } on ApiException catch (e) {
      if (e.statusCode == 401 && requireAuth && !_isRefreshing) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          final retryHeaders = await _getHeaders(
            additionalHeaders: headers,
            requireAuth: requireAuth,
          );
          final retryResponse = await http
              .delete(Uri.parse(url), headers: retryHeaders)
              .timeout(const Duration(seconds: 45));
          return _handleResponse(retryResponse);
        }
        await TokenStorageService.instance.clearTokens();
      }
      _logResponse('DELETE', url, e.statusCode ?? 0, null, e.toString(),
          logTag: logTag);
      rethrow;
    } catch (e) {
      _logResponse('DELETE', url, 0, null, e.toString(), logTag: logTag);
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  /// Multipart POST request for file uploads
  Future<Map<String, dynamic>> postMultipart(
    String url, {
    required Map<String, String> fields,
    required Map<String, File> files,
    bool requireAuth = true,
    String? logTag,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));

      // Add headers (but NOT Content-Type - it will be set automatically by multipart)
      request.headers['Accept'] = 'application/json';

      // Add authentication token
      if (requireAuth) {
        final token = await TokenStorageService.instance.getAccessToken();
        if (token != null && token.isNotEmpty) {
          final normalizedToken = _normalizeBearerToken(token);
          request.headers['Authorization'] = 'Bearer $normalizedToken';
          if (kDebugMode) {
            print(
                '🔑 Avatar Upload - Token added: ${normalizedToken.length > 20 ? "${normalizedToken.substring(0, 20)}..." : normalizedToken}');
          }
        } else {
          if (kDebugMode) {
            print('⚠️ Avatar Upload - No token found!');
          }
        }
      }

      // Add fields
      request.fields.addAll(fields);

      // Add files
      for (var entry in files.entries) {
        final file = entry.value;
        final fieldName = entry.key;
        final fileName = file.path.split(Platform.pathSeparator).last;

        if (kDebugMode) {
          print('📎 Adding file: $fieldName = $fileName (${file.path})');
        }

        request.files.add(
          await http.MultipartFile.fromPath(
            fieldName,
            file.path,
            filename: fileName,
          ),
        );
      }

      _logRequest(
          'POST (Multipart)',
          url,
          request.headers,
          {
            'fields': fields,
            'files': files.keys.toList(),
          },
          logTag: logTag);

      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 60),
          );

      final response = await http.Response.fromStream(streamedResponse);

      if (kDebugMode) {
        print('📥 Avatar Upload Response Status: ${response.statusCode}');
        print('📥 Avatar Upload Response Body: ${response.body}');
      }

      final responseData = _handleResponse(response);
      _logResponse(
          'POST (Multipart)', url, response.statusCode, responseData, null,
          logTag: logTag);
      return responseData;
    } on ApiException {
      rethrow;
    } catch (e) {
      _logResponse('POST (Multipart)', url, 0, null, e.toString(),
          logTag: logTag);
      if (kDebugMode) {
        print('❌ Avatar Upload Error: $e');
      }
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  /// Handle HTTP response
  /// Automatically handles 401 errors by clearing cached tokens (like Dio interceptor)
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to parse JSON response: ${response.body}');
        }
        throw ApiException('Invalid JSON response: ${e.toString()}');
      }
    } else {
      String errorMessage = 'Request failed with status ${response.statusCode}';
      Map<String, dynamic>? errorData;

      try {
        errorData = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = errorData['message'] as String? ?? errorMessage;
      } catch (e) {
        // Not JSON, use raw body
      }

      if (kDebugMode) {
        final body = response.body;
        final trimmed = body.trimLeft();
        final looksLikeHtml = trimmed.startsWith('<!') ||
            trimmed.startsWith('<html') ||
            body.contains('DOCTYPE html');
        if (looksLikeHtml) {
          print(
            '❌ Error Response: HTTP ${response.statusCode} — body is HTML '
            '(likely frontend 404; API route missing or wrong URL). '
            'First 120 chars: ${body.length > 120 ? body.substring(0, 120) : body}…',
          );
        } else {
          print('❌ Error Response Body: $body');
        }
      }

      if (response.statusCode == 401) {
        if (kDebugMode) {
          print('🔒 401 Unauthorized - Token may be expired or invalid');
        }
      }

      throw ApiException(
        errorMessage,
        statusCode: response.statusCode,
        errorData: errorData,
      );
    }
  }
}

/// API Exception class
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errorData;

  ApiException(
    this.message, {
    this.statusCode,
    this.errorData,
  });

  @override
  String toString() => message;
}
