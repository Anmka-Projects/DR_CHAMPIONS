import 'user.dart';

/// Authentication Response Model
class AuthResponse {
  final bool success;
  final String? message;
  final User user;
  final String token;
  final String refreshToken;
  final String? expiresAt;

  AuthResponse({
    required this.success,
    this.message,
    required this.user,
    required this.token,
    required this.refreshToken,
    this.expiresAt,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    
    // Check if data itself is the user (register response) or if data.user exists (login response)
    Map<String, dynamic> userData;
    if (data.containsKey('user')) {
      // Login response: data.user exists
      userData = data['user'] as Map<String, dynamic>? ?? {};
    } else if (data.containsKey('id') || data.containsKey('email')) {
      // Register response: data itself is the user
      userData = data;
      print('  ℹ️ User data is at root level of data (register response)');
    } else {
      userData = {};
    }

    // Debug logging
    print('🔍 Parsing AuthResponse...');
    print('  json keys: ${json.keys.toList()}');
    if (data.isNotEmpty) {
      print('  data keys: ${data.keys.toList()}');
    }
    if (data.containsKey('status')) {
      print('  ⚠️ User status: ${data['status']}');
    }

    // Try multiple possible locations for token (API uses accessToken, not token)
    String? token;
    String? refreshToken;

    // First try: data.accessToken (actual API format)
    token = data['accessToken'] as String?;
    refreshToken = data['refreshToken'] as String?;

    // Fallback: data.token (standard location)
    if ((token == null || token.isEmpty)) {
      token = data['token'] as String?;
    }

    // Fallback: data.access_token (snake_case)
    if ((token == null || token.isEmpty)) {
      token = data['access_token'] as String?;
    }

    // Fallback: Check if token is at root level
    if ((token == null || token.isEmpty) && json.containsKey('token')) {
      print('  ⚠️ Token not in data, trying root level...');
      token = json['token'] as String?;
    }

    // Fallback for refresh_token (snake_case)
    if ((refreshToken == null || refreshToken.isEmpty)) {
      refreshToken = data['refresh_token'] as String?;
    }

    // Fallback for refreshToken at root
    if ((refreshToken == null || refreshToken.isEmpty) &&
        json.containsKey('refreshToken')) {
      refreshToken = json['refreshToken'] as String?;
    }

    final finalToken = token ?? '';
    final finalRefreshToken = refreshToken ?? '';

    if (finalToken.isEmpty) {
      print('❌ ERROR: Token is empty in AuthResponse.fromJson');
      print(
          '  Checked locations: data.accessToken, data.token, data.access_token, json.token');
      print('  Full response structure:');
      final responseStr = json.toString();
      print(
          '    ${responseStr.length > 500 ? responseStr.substring(0, 500) : responseStr}...');
    } else {
      print('✅ Token found (length: ${finalToken.length})');
      print(
          '  Token source: ${data.containsKey('accessToken') ? 'data.accessToken' : data.containsKey('token') ? 'data.token' : 'other'}');
    }

    if (finalRefreshToken.isEmpty) {
      print('⚠️ WARNING: Refresh token is empty in AuthResponse.fromJson');
    } else {
      print('✅ Refresh token found (length: ${finalRefreshToken.length})');
    }

    return AuthResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      user: User.fromJson(userData),
      token: finalToken,
      refreshToken: finalRefreshToken,
      expiresAt: data['expires_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': {
        'user': user.toJson(),
        'token': token,
        'refresh_token': refreshToken,
        'expires_at': expiresAt,
      },
    };
  }
}
