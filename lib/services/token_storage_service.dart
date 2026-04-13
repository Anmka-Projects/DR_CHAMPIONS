import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for storing and retrieving authentication tokens
class TokenStorageService {
  TokenStorageService._();

  static final TokenStorageService instance = TokenStorageService._();

  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUser = 'user_data';
  static const String _keyUserRole = 'user_role';

  /// Save access token
  Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, token);
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyAccessToken);
    if (kDebugMode && token != null) {
      print('🔑 Retrieved token from storage (length: ${token.length})');
    } else if (kDebugMode) {
      print('🔑 No token found in storage');
    }
    return token;
  }

  /// Save refresh token
  Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRefreshToken, token);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefreshToken);
  }

  /// Save tokens
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    if (kDebugMode) {
      print('💾 TokenStorageService.saveTokens called');
      print('  accessToken length: ${accessToken.length}');
      print('  accessToken isEmpty: ${accessToken.isEmpty}');
      print('  refreshToken length: ${refreshToken.length}');
    }

    if (accessToken.isEmpty) {
      print('❌ ERROR: Cannot save empty access token!');
      throw Exception('Access token cannot be empty');
    }

    final prefs = await SharedPreferences.getInstance();

    if (kDebugMode) {
      print('  Saving to SharedPreferences...');
      print('  Key: $_keyAccessToken');
    }

    final saveResult = await Future.wait([
      prefs.setString(_keyAccessToken, accessToken),
      prefs.setString(_keyRefreshToken, refreshToken),
    ]);

    if (kDebugMode) {
      print('  Save results: $saveResult');
    }

    // Verify tokens were saved immediately
    final savedToken = await prefs.getString(_keyAccessToken);
    if (kDebugMode) {
      print(
          '  Verification read: ${savedToken != null ? "token exists (length: ${savedToken.length})" : "token is NULL"}');
    }

    if (savedToken != null && savedToken == accessToken) {
      print('✅ Token saved successfully (length: ${accessToken.length})');
    } else {
      print('❌ Token save verification failed');
      print('  Expected length: ${accessToken.length}');
      print(
          '  Saved token: ${savedToken != null ? "exists (length: ${savedToken.length})" : "NULL"}');
      print('  Tokens match: ${savedToken == accessToken}');
    }
  }

  /// Save user role (for role-based routing: student vs instructor)
  Future<void> saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserRole, role);
  }

  /// Get stored user role
  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole);
  }

  /// Clear all tokens and role
  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyAccessToken),
      prefs.remove(_keyRefreshToken),
      prefs.remove(_keyUser),
      prefs.remove(_keyUserRole),
    ]);
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
