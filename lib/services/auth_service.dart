import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/notification_service/notification_service.dart';
import '../models/auth_response.dart';
import 'token_storage_service.dart';

/// Authentication Service
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Web client id from Firebase (google-services.json client_type: 3).
    // Needed on some Android devices to avoid Google sign-in failures.
    serverClientId:
        '322915697-tav8lgdjc4b8g6lm5r72gfa3gi38ovte.apps.googleusercontent.com',
  );

  /// Check if input is email or phone
  bool _isEmail(String input) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(input);
  }

  String _buildDeviceLimitMessage(Map<String, dynamic>? errorData) {
    if (errorData == null) {
      return 'تم تجاوز الحد الأقصى لعدد الأجهزة المسموح بها لهذا الحساب';
    }

    final message = errorData['message']?.toString();
    final data = errorData['data'] as Map<String, dynamic>?;
    final maxDevices = data?['max_devices']?.toString();
    final currentDevices = data?['current_devices']?.toString();

    if (maxDevices != null &&
        maxDevices.isNotEmpty &&
        currentDevices != null &&
        currentDevices.isNotEmpty) {
      final prefix = (message != null && message.isNotEmpty)
          ? message
          : 'تم تجاوز الحد الأقصى لعدد الأجهزة المسموح بها';
      return '$prefix (الأقصى: $maxDevices - الحالي: $currentDevices)';
    }

    return (message != null && message.isNotEmpty)
        ? message
        : 'تم تجاوز الحد الأقصى لعدد الأجهزة المسموح بها لهذا الحساب';
  }

  String _extractApiErrorMessage(
    ApiException e, {
    required String fallbackMessage,
  }) {
    final errorData = e.errorData;
    if (errorData != null) {
      final message = errorData['message']?.toString();
      if (message != null && message.isNotEmpty) {
        final errors = errorData['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final fieldErrors = <String>[];
          for (final value in errors.values) {
            if (value is List) {
              for (final item in value) {
                final text = item?.toString().trim() ?? '';
                if (text.isNotEmpty) fieldErrors.add(text);
              }
            } else {
              final text = value?.toString().trim() ?? '';
              if (text.isNotEmpty) fieldErrors.add(text);
            }
          }

          if (fieldErrors.isNotEmpty) {
            return '$message\n${fieldErrors.join('\n')}';
          }
        }
        return message;
      }
    }

    final directMessage = e.message.trim();
    if (directMessage.isNotEmpty) return directMessage;
    return fallbackMessage;
  }

  /// Login user with email or phone
  Future<AuthResponse> login({
    required String emailOrPhone,
    required String password,
  }) async {
    try {
      // Determine if input is email or phone
      final isEmail = _isEmail(emailOrPhone.trim());

      // Build request body with appropriate key
      final Map<String, dynamic> requestBody = {
        'password': password,
      };

      if (isEmail) {
        requestBody['email'] = emailOrPhone.trim();
      } else {
        requestBody['phone'] = emailOrPhone.trim();
      }

      final response = await ApiClient.instance.post(
        ApiEndpoints.login,
        body: requestBody,
        requireAuth: false, // Login doesn't need auth
      );

      // Print full response for debugging
      if (kDebugMode) {
        print('📦 Full Login Response:');
        print('  Response: $response');
        print('  Response Type: ${response.runtimeType}');
        print('  Response Keys: ${response.keys.toList()}');
        response.forEach((key, value) {
          print('    $key: $value (${value.runtimeType})');
        });
      }

      if (response['success'] == true) {
        // Debug: Print raw response to see structure
        if (kDebugMode) {
          print('🔍 Raw Login Response:');
          print('  response keys: ${response.keys.toList()}');
          if (response['data'] != null) {
            final data = response['data'] as Map<String, dynamic>;
            print('  data keys: ${data.keys.toList()}');
            print('  token in data: ${data.containsKey('token')}');
            final tokenStr = data['token']?.toString() ?? 'NULL';
            final tokenPreview = tokenStr != 'NULL' && tokenStr.length > 20
                ? '${tokenStr.substring(0, 20)}...'
                : tokenStr;
            print('  token value: $tokenPreview');
            print(
                '  refresh_token in data: ${data.containsKey('refresh_token')}');
          }
        }

        final authResponse = AuthResponse.fromJson(response);

        print('🔐 Login successful - Parsing tokens...');
        print(
            '  Token from model: ${authResponse.token.isNotEmpty ? "${authResponse.token.substring(0, authResponse.token.length > 20 ? 20 : authResponse.token.length)}..." : "EMPTY"}');
        print('  Token length: ${authResponse.token.length}');
        print('  Refresh token length: ${authResponse.refreshToken.length}');

        if (authResponse.token.isEmpty) {
          print('❌ ERROR: Token is EMPTY after parsing!');
          print('💡 Check if API response contains token in data.token');
          throw Exception('Token is empty in response');
        }

        // Save tokens to cache (like Dio setTokenIntoHeaderAfterLogin)
        print('💾 Saving tokens to cache...');
        await TokenStorageService.instance.saveTokens(
          accessToken: authResponse.token,
          refreshToken: authResponse.refreshToken,
        );
        await TokenStorageService.instance.saveUserRole(authResponse.user.role);

        // Verify token was saved to cache
        print('🔍 Verifying token was saved to cache...');
        final savedToken = await TokenStorageService.instance.getAccessToken();
        if (savedToken != null && savedToken.isNotEmpty) {
          if (savedToken == authResponse.token) {
            print('✅ Token cached successfully');
            print('  Cached token length: ${savedToken.length}');
            print('  💡 Token is now available for all API requests');
          } else {
            print('❌ Token mismatch in cache!');
            print(
                '  Original: ${authResponse.token.substring(0, authResponse.token.length > 20 ? 20 : authResponse.token.length)}...');
            print(
                '  Cached: ${savedToken.substring(0, savedToken.length > 20 ? 20 : savedToken.length)}...');
          }
        } else {
          print('❌ Token cache verification failed');
          print('  savedToken is null: ${savedToken == null}');
          print('  savedToken is empty: ${savedToken?.isEmpty ?? true}');
          throw Exception('Failed to cache token after login');
        }

        return authResponse;
      } else {
        throw Exception(response['message'] ?? 'Login failed');
      }
    } catch (e) {
      if (e is ApiException) {
        final errorData = e.errorData;
        final errorCode = errorData?['error_code']?.toString();
        final isDeviceLimit = e.statusCode == 403 &&
            errorCode != null &&
            errorCode.toUpperCase() == 'DEVICE_LIMIT_EXCEEDED';
        if (isDeviceLimit) {
          throw Exception(_buildDeviceLimitMessage(errorData));
        }

        // Try to parse error message from response body
        try {
          if (errorData != null) {
            final message =
                errorData['message'] ?? errorData['error'] ?? 'Login failed';
            throw Exception(message);
          }
        } catch (_) {}
        throw Exception('فشل تسجيل الدخول. تحقق من بيانات الاعتماد');
      }
      rethrow;
    }
  }

  /// Register user
  Future<AuthResponse> register({
    required String name,
    required String email,
    String? phone,
    required String password,
    required String passwordConfirmation,
    required bool acceptTerms,
    String role = 'student', // Default to student, can be 'instructor'
    String? studentType, // Only required for students
  }) async {
    try {
      // Build request body
      final body = <String, dynamic>{
        'name': name,
        'email': email,
        'password': password,
        'role': role,
      };

      // Add phone if provided
      if (phone != null && phone.isNotEmpty) {
        body['phone'] = phone;
      }

      // Add student_type for students and default it to online
      if (role == 'student') {
        // Map student_type values to API format
        // API expects: "online" or "offline"
        String mappedStudentType = (studentType == null || studentType.isEmpty)
            ? 'online'
            : studentType;
        if (studentType == 'in_person') {
          mappedStudentType = 'offline';
        } else if (studentType == 'both') {
          mappedStudentType = 'online'; // Default to online for "both"
        }
        body['student_type'] = mappedStudentType;
      }

      final response = await ApiClient.instance.post(
        ApiEndpoints.register,
        body: body,
        requireAuth: false, // Register doesn't need auth
      );

      // Print full response for debugging
      if (kDebugMode) {
        print('📦 Full Register Response:');
        print('  Response: $response');
        print('  Response Type: ${response.runtimeType}');
        print('  Response Keys: ${response.keys.toList()}');
        response.forEach((key, value) {
          print('    $key: $value (${value.runtimeType})');
        });
      }

      if (response['success'] == true) {
        // Debug: Print raw response to see structure
        if (kDebugMode) {
          print('🔍 Raw Register Response:');
          print('  response keys: ${response.keys.toList()}');
          if (response['data'] != null) {
            final data = response['data'] as Map<String, dynamic>;
            print('  data keys: ${data.keys.toList()}');
            print('  token in data: ${data.containsKey('token')}');
            final tokenStr = data['token']?.toString() ?? 'NULL';
            final tokenPreview = tokenStr != 'NULL' && tokenStr.length > 20
                ? '${tokenStr.substring(0, 20)}...'
                : tokenStr;
            print('  token value: $tokenPreview');
            print(
                '  refresh_token in data: ${data.containsKey('refresh_token')}');
          }
        }

        // Check if user status is PENDING (waiting for admin approval)
        final data = response['data'] as Map<String, dynamic>? ?? {};
        final status = data['status'] as String?;

        if (status == 'PENDING') {
          print('⏳ Registration successful but account is PENDING approval');
          print('  Status: $status');
          print(
              '  Message: ${response['message'] ?? 'في انتظار موافقة المدير'}');
          print('  💡 Token will be provided after admin approval');

          // Throw a specific exception for pending status
          throw Exception(response['message']?.toString() ??
              'تم إنشاء الحساب بنجاح، في انتظار موافقة المدير');
        }

        final authResponse = AuthResponse.fromJson(response);

        print('🔐 Registration successful - Parsing tokens...');
        print(
            '  Token from model: ${authResponse.token.isNotEmpty ? "${authResponse.token.substring(0, authResponse.token.length > 20 ? 20 : authResponse.token.length)}..." : "EMPTY"}');
        print('  Token length: ${authResponse.token.length}');
        print('  Refresh token length: ${authResponse.refreshToken.length}');

        if (authResponse.token.isEmpty) {
          print('❌ ERROR: Token is EMPTY after parsing!');
          print('💡 Check if API response contains token in data.token');
          print('💡 This might be a PENDING account - check status field');
          throw Exception(response['message']?.toString() ??
              'تم إنشاء الحساب بنجاح، لكن لا يمكن تسجيل الدخول الآن. يرجى انتظار موافقة المدير');
        }

        // Save tokens to cache (like Dio setTokenIntoHeaderAfterLogin)
        print('💾 Saving tokens to cache...');
        await TokenStorageService.instance.saveTokens(
          accessToken: authResponse.token,
          refreshToken: authResponse.refreshToken,
        );
        await TokenStorageService.instance.saveUserRole(authResponse.user.role);

        // Verify token was saved to cache
        print('🔍 Verifying token was saved to cache...');
        final savedToken = await TokenStorageService.instance.getAccessToken();
        if (savedToken != null && savedToken.isNotEmpty) {
          if (savedToken == authResponse.token) {
            print('✅ Token cached successfully');
            print('  Cached token length: ${savedToken.length}');
            print('  💡 Token is now available for all API requests');
          } else {
            print('❌ Token mismatch in cache!');
            print(
                '  Original: ${authResponse.token.substring(0, authResponse.token.length > 20 ? 20 : authResponse.token.length)}...');
            print(
                '  Cached: ${savedToken.substring(0, savedToken.length > 20 ? 20 : savedToken.length)}...');
          }
        } else {
          print('❌ Token cache verification failed');
          print('  savedToken is null: ${savedToken == null}');
          print('  savedToken is empty: ${savedToken?.isEmpty ?? true}');
          throw Exception('Failed to cache token after registration');
        }

        return authResponse;
      } else {
        throw Exception(response['message'] ?? 'Registration failed');
      }
    } catch (e) {
      if (e is ApiException) {
        throw Exception(
          _extractApiErrorMessage(
            e,
            fallbackMessage: 'فشل إنشاء الحساب. يرجى المحاولة مرة أخرى',
          ),
        );
      }
      rethrow;
    }
  }

  /// Refresh access token
  Future<AuthResponse> refreshAccessToken() async {
    try {
      final refreshToken = await TokenStorageService.instance.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        throw Exception('لا يوجد refresh token');
      }

      final response = await ApiClient.instance.post(
        ApiEndpoints.refreshToken,
        body: {
          'refreshToken': refreshToken,
        },
        requireAuth: false, // Refresh doesn't need access token
      );

      if (response['success'] == true) {
        final authResponse = AuthResponse.fromJson(response);

        if (authResponse.token.isEmpty) {
          throw Exception('Token is empty in refresh response');
        }

        // Save new tokens to cache
        await TokenStorageService.instance.saveTokens(
          accessToken: authResponse.token,
          refreshToken: authResponse.refreshToken,
        );

        if (kDebugMode) {
          print('✅ Access token refreshed successfully');
          print('  New token length: ${authResponse.token.length}');
        }

        return authResponse;
      } else {
        throw Exception(response['message'] ?? 'فشل تجديد الـ access token');
      }
    } catch (e) {
      if (e is ApiException) {
        // Try to parse error message from response body
        try {
          final errorBody = e.message;
          final match = RegExp(r'\{.*\}').firstMatch(errorBody);
          if (match != null) {
            final errorJson = jsonDecode(match.group(0)!);
            final message = errorJson['message'] ??
                errorJson['error'] ??
                'فشل تجديد الـ access token';
            throw Exception(message);
          }
        } catch (_) {}
        throw Exception(
            'فشل تجديد الـ access token. يرجى تسجيل الدخول مرة أخرى');
      }
      rethrow;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      // Clear Firebase social sessions too.
      await FirebaseAuth.instance.signOut();
      await _googleSignIn.signOut();

      // Use requireAuth: true to automatically add token from cache
      await ApiClient.instance.post(
        ApiEndpoints.logout,
        requireAuth: true,
      );
    } catch (e) {
      // Even if API call fails, clear cached tokens
      print('Logout API error: $e');
    } finally {
      // Always clear cached tokens (like _handleTokenExpiry)
      print('🗑️ Clearing cached tokens...');
      await TokenStorageService.instance.clearTokens();
      print('✅ Cached tokens cleared');
    }
  }

  /// Forgot password - Send reset link to email
  Future<void> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.forgotPassword,
        body: {
          'email': email,
        },
        requireAuth: false, // Forgot password doesn't need auth
      );

      if (response['success'] != true) {
        throw Exception(
            response['message'] ?? 'فشل إرسال رابط إعادة تعيين كلمة المرور');
      }
    } catch (e) {
      if (e is ApiException) {
        // Try to parse error message from response body
        try {
          final errorBody = e.message;
          final match = RegExp(r'\{.*\}').firstMatch(errorBody);
          if (match != null) {
            final errorJson = jsonDecode(match.group(0)!);
            final message = errorJson['message'] ??
                errorJson['error'] ??
                'فشل إرسال رابط إعادة تعيين كلمة المرور';
            throw Exception(message);
          }
        } catch (_) {}
        throw Exception(
            'فشل إرسال رابط إعادة تعيين كلمة المرور. يرجى المحاولة مرة أخرى');
      }
      rethrow;
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    return await TokenStorageService.instance.isLoggedIn();
  }

  /// Google sign-in with Firebase Auth + backend social-login API
  Future<AuthResponse> signInWithGoogle() async {
    try {
      // Clear stale session before new attempt (helps with transient failures).
      await _googleSignIn.signOut();

      // Step 1: Get Google credentials
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('تم إلغاء تسجيل الدخول بواسطة المستخدم');
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw Exception('فشل الحصول على بيانات المصادقة من جوجل');
      }

      // Step 2: Sign in to Firebase Auth.
      final firebaseCredential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(firebaseCredential);

      if (kDebugMode) {
        print('✅ Google Firebase Sign-In successful');
        print('  uid: ${userCredential.user?.uid}');
        print('  email: ${userCredential.user?.email}');
      }

      // Step 3: Get Firebase ID token to send to backend
      final firebaseIdToken =
          await userCredential.user?.getIdToken() ?? googleAuth.idToken!;

      // Step 4: Get FCM token
      String? fcmToken = FirebaseNotification.fcmToken;
      if (fcmToken == null || fcmToken.isEmpty) {
        await FirebaseNotification.getFcmToken();
        fcmToken = FirebaseNotification.fcmToken ?? '';
      }

      // Step 5: Get device info
      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'unknown';

      // Step 6: Build request body
      final requestBody = {
        'provider': 'google',
        'id_token': firebaseIdToken,
        'fcm_token': fcmToken,
        'device': {
          'platform': platform,
          'model': 'Unknown',
          'app_version': '1.0.0',
        },
      };

      if (kDebugMode) {
        print('🔐 Google Social Login Request:');
        print('  provider: google');
        print(
            '  id_token: ${firebaseIdToken.substring(0, firebaseIdToken.length > 20 ? 20 : firebaseIdToken.length)}...');
        print(
            '  fcm_token: ${fcmToken.isNotEmpty ? "${fcmToken.substring(0, fcmToken.length > 20 ? 20 : fcmToken.length)}..." : "EMPTY"}');
        print('  platform: $platform');
      }

      // Step 7: Send request to backend API
      final response = await ApiClient.instance.post(
        ApiEndpoints.socialLogin,
        body: requestBody,
        requireAuth: false,
      );

      if (response['success'] == true) {
        final authResponse = AuthResponse.fromJson(response);

        if (kDebugMode) {
          print('🔐 Google Social Login successful - Saving tokens...');
          print('  Token length: ${authResponse.token.length}');
          print('  Refresh token length: ${authResponse.refreshToken.length}');
        }

        // Save tokens to cache
        await TokenStorageService.instance.saveTokens(
          accessToken: authResponse.token,
          refreshToken: authResponse.refreshToken,
        );
        await TokenStorageService.instance.saveUserRole(authResponse.user.role);

        // Verify token was cached
        final savedToken = await TokenStorageService.instance.getAccessToken();
        if (savedToken != null &&
            savedToken.isNotEmpty &&
            savedToken == authResponse.token) {
          if (kDebugMode) {
            print('✅ Token cached successfully (length: ${savedToken.length})');
          }
        } else {
          if (kDebugMode) {
            print('❌ Token cache verification failed');
          }
          throw Exception('Failed to cache token after Google login');
        }

        return authResponse;
      } else {
        throw Exception(response['message'] ?? 'فشل تسجيل الدخول عبر Google');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Google Sign-In Exception: $e');
      }

      if (e is ApiException) {
        try {
          final errorBody = e.message;
          final match = RegExp(r'\{.*\}').firstMatch(errorBody);
          if (match != null) {
            final errorJson = jsonDecode(match.group(0)!);
            final message = errorJson['message'] ??
                errorJson['error'] ??
                'فشل تسجيل الدخول عبر Google';
            throw Exception(message);
          }
        } catch (_) {}
        throw Exception('فشل تسجيل الدخول عبر Google. يرجى المحاولة مرة أخرى');
      }

      // Handle Google Play Services / plugin sign-in exceptions.
      if (e.toString().contains('PlatformException') ||
          e.toString().contains('sign_in_failed') ||
          e.toString().contains('ApiException')) {
        if (kDebugMode) {
          print('❌ Google Sign-In PlatformException: $e');
        }

        if (e.toString().contains('network_error') ||
            e.toString().contains('ApiException: 7') ||
            e.toString().contains('7:')) {
          throw Exception('تعذر الاتصال بخدمات Google (ApiException: 7).\n'
              'يرجى التحقق من:\n'
              '1. اتصال الإنترنت على الهاتف\n'
              '2. تحديث Google Play Services\n'
              '3. إيقاف VPN/Proxy (إن وجد)\n'
              '4. التاريخ والوقت التلقائي في الجهاز');
        }

        if (e.toString().contains('ApiException: 12500') ||
            e.toString().contains('12500:')) {
          throw Exception('فشل مصادقة Google (ApiException: 12500).\n'
              'السبب غالبا إعدادات Firebase/OAuth غير متطابقة.\n'
              'يرجى التأكد من:\n'
              '1. package name = com.anmka.drchampion\n'
              '2. إضافة SHA-1 الصحيحة لهذا الجهاز في Firebase\n'
              '3. عدم وجود تعارض لنفس package+SHA في مشروع Google آخر\n'
              '4. تنزيل google-services.json الجديد بعد الحفظ');
        }

        if (e.toString().contains('oauth_client') ||
            e.toString().contains('Api10') ||
            e.toString().contains('ApiException: 10') ||
            e.toString().contains('10:') ||
            e.toString().contains('DEVELOPER_ERROR')) {
          throw Exception('خطأ في إعدادات Google Sign-In:\n'
              'يرجى التأكد من:\n'
              '1. تفعيل Google Sign-In في Firebase Console\n'
              '2. إضافة OAuth Client ID للـ Android app\n'
              '3. تحميل ملف google-services.json المحدث\n'
              '4. التأكد من تطابق package_name مع applicationId');
        }

        throw Exception('فشل تسجيل الدخول عبر Google. يرجى التحقق من:\n'
            '- اتصال الإنترنت\n'
            '- إعدادات Google Sign-In في Firebase Console\n'
            '- ملف google-services.json يحتوي على OAuth Client IDs');
      }

      final errorString = e.toString();
      if (e is Exception &&
          (errorString.contains('خطأ') ||
              errorString.contains('تم إلغاء') ||
              errorString.contains('فشل'))) {
        rethrow;
      }

      throw Exception('فشل تسجيل الدخول عبر Google: ${e.toString()}');
    }
  }

  /// Apple sign-in with API integration
  Future<AuthResponse> signInWithApple() async {
    try {
      // Step 1: Generate nonce for Apple sign-in
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Step 2: Get Apple credentials
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      if (appleCredential.identityToken == null) {
        throw Exception('فشل الحصول على بيانات المصادقة من Apple');
      }

      // Step 3: Get FCM token
      String? fcmToken = FirebaseNotification.fcmToken;
      if (fcmToken == null || fcmToken.isEmpty) {
        // Try to get token if not available
        await FirebaseNotification.getFcmToken();
        fcmToken = FirebaseNotification.fcmToken ?? '';
      }

      // Step 4: Get device info
      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'unknown';

      // Step 5: Build request body
      final requestBody = {
        'provider': 'apple',
        'id_token': appleCredential.identityToken,
        'nonce': rawNonce,
        'fcm_token': fcmToken,
        'device': {
          'platform': platform,
          'model': 'Unknown', // Can be enhanced with device_info_plus package
          'app_version': '1.0.0',
        },
      };

      if (kDebugMode) {
        print('🔐 Apple Social Login Request:');
        print('  provider: apple');
        print(
            '  id_token: ${appleCredential.identityToken?.substring(0, 20)}...');
        print('  nonce: ${rawNonce.substring(0, 20)}...');
        print(
            '  fcm_token: ${fcmToken.isNotEmpty ? "${fcmToken.substring(0, 20)}..." : "EMPTY"}');
        print('  platform: $platform');
      }

      // Step 6: Send request to API
      final response = await ApiClient.instance.post(
        ApiEndpoints.socialLogin,
        body: requestBody,
        requireAuth: false, // Social login doesn't need auth
      );

      if (response['success'] == true) {
        final authResponse = AuthResponse.fromJson(response);

        if (kDebugMode) {
          print('🔐 Apple Social Login successful - Saving tokens...');
          print('  Token length: ${authResponse.token.length}');
          print('  Refresh token length: ${authResponse.refreshToken.length}');
        }

        // Save tokens to cache
        await TokenStorageService.instance.saveTokens(
          accessToken: authResponse.token,
          refreshToken: authResponse.refreshToken,
        );
        await TokenStorageService.instance.saveUserRole(authResponse.user.role);

        // Verify token was cached
        final savedToken = await TokenStorageService.instance.getAccessToken();
        if (savedToken != null &&
            savedToken.isNotEmpty &&
            savedToken == authResponse.token) {
          if (kDebugMode) {
            print('✅ Token cached successfully (length: ${savedToken.length})');
          }
        } else {
          if (kDebugMode) {
            print('❌ Token cache verification failed');
          }
          throw Exception('Failed to cache token after Apple login');
        }

        return authResponse;
      } else {
        throw Exception(response['message'] ?? 'فشل تسجيل الدخول عبر Apple');
      }
    } catch (e) {
      if (e is ApiException) {
        // Try to parse error message from response body
        try {
          final errorBody = e.message;
          final match = RegExp(r'\{.*\}').firstMatch(errorBody);
          if (match != null) {
            final errorJson = jsonDecode(match.group(0)!);
            final message = errorJson['message'] ??
                errorJson['error'] ??
                'فشل تسجيل الدخول عبر Apple';
            throw Exception(message);
          }
        } catch (_) {}
        throw Exception('فشل تسجيل الدخول عبر Apple. يرجى المحاولة مرة أخرى');
      }
      rethrow;
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
