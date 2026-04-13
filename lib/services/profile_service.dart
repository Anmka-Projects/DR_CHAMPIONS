import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Service for user profile management
class ProfileService {
  ProfileService._();
  
  static final ProfileService instance = ProfileService._();

  String _resolveFirebaseEmail(User firebaseUser) {
    final directEmail = firebaseUser.email?.trim() ?? '';
    if (directEmail.isNotEmpty) {
      return directEmail;
    }

    for (final provider in firebaseUser.providerData) {
      final providerEmail = provider.email?.trim() ?? '';
      if (providerEmail.isNotEmpty) {
        return providerEmail;
      }
    }

    return '';
  }

  String _resolveFirebaseName(User firebaseUser) {
    final displayName = firebaseUser.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) {
      return displayName;
    }

    final email = _resolveFirebaseEmail(firebaseUser);
    if (email.isNotEmpty && email.contains('@')) {
      final localPart = email.split('@').first;
      if (localPart.isNotEmpty) {
        return localPart;
      }
    }

    return 'User';
  }

  String _resolveFirebaseProvider(User firebaseUser) {
    if (firebaseUser.providerData.isNotEmpty) {
      return firebaseUser.providerData.first.providerId;
    }
    return 'firebase';
  }

  Map<String, dynamic>? _firebaseProfileFallback() {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return null;
    final resolvedEmail = _resolveFirebaseEmail(firebaseUser);

    return {
      'id': firebaseUser.uid,
      'name': _resolveFirebaseName(firebaseUser),
      'email': resolvedEmail,
      'phone': firebaseUser.phoneNumber ?? '',
      'avatar': firebaseUser.photoURL ?? '',
      'provider': _resolveFirebaseProvider(firebaseUser),
    };
  }

  Map<String, dynamic> _mergeProfileWithFirebase(
    Map<String, dynamic> profile,
  ) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      return profile;
    }

    final merged = Map<String, dynamic>.from(profile);
    merged['name'] = _resolveFirebaseName(firebaseUser);
    merged['email'] = _resolveFirebaseEmail(firebaseUser);

    final firebaseAvatar = firebaseUser.photoURL?.trim() ?? '';
    if (firebaseAvatar.isNotEmpty) {
      merged['avatar'] = firebaseAvatar;
    }

    return merged;
  }

  /// Get user profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📤 PROFILE SERVICE - GET PROFILE');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('URL: ${ApiEndpoints.me}');
        print('Require Auth: true');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }
      
      final response = await ApiClient.instance.get(
        ApiEndpoints.me,
        requireAuth: true,
      );
      
      if (kDebugMode) {
        print('📥 PROFILE SERVICE - RESPONSE RECEIVED');
        print('Response keys: ${response.keys.toList()}');
        print('Response success: ${response['success']}');
        print('Response data: ${response['data']}');
        if (response['data'] != null) {
          final data = response['data'] as Map<String, dynamic>;
          print('Data keys: ${data.keys.toList()}');
          print('Data name: ${data['name']}');
          print('Data email: ${data['email']}');
          print('Data type: ${data.runtimeType}');
        }
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }
      
      if (response['success'] == true && response['data'] != null) {
        final profileData = response['data'] as Map<String, dynamic>;
        final mergedProfile = _mergeProfileWithFirebase(profileData);
        if (kDebugMode) {
          print('✅ Profile data extracted successfully');
          print('  Profile keys: ${mergedProfile.keys.toList()}');
          print('  Profile name: ${mergedProfile['name']}');
          print('  Profile email: ${mergedProfile['email']}');
        }
        return mergedProfile;
      } else {
        if (kDebugMode) {
          print('❌ Profile response failed');
          print('  Success: ${response['success']}');
          print('  Message: ${response['message']}');
          print('  Data: ${response['data']}');
        }
        final firebaseFallback = _firebaseProfileFallback();
        if (firebaseFallback != null) {
          if (kDebugMode) {
            print('ℹ️ Using Firebase profile fallback');
          }
          return firebaseFallback;
        }

        throw Exception(response['message'] ?? 'Failed to fetch profile');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ PROFILE SERVICE ERROR');
        print('  Error: $e');
        print('  Error type: ${e.runtimeType}');
      }
      final firebaseFallback = _firebaseProfileFallback();
      if (firebaseFallback != null) {
        if (kDebugMode) {
          print('ℹ️ Using Firebase profile fallback after error');
        }
        return firebaseFallback;
      }

      rethrow;
    }
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? phone,
    String? bio,
    String? country,
    String? timezone,
    String? language,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (phone != null) body['phone'] = phone;
      if (bio != null) body['bio'] = bio;
      if (country != null) body['country'] = country;
      if (timezone != null) body['timezone'] = timezone;
      if (language != null) body['language'] = language;

      final response = await ApiClient.instance.put(
        ApiEndpoints.profile,
        body: body,
        requireAuth: true,
      );
      
      if (response['success'] == true) {
        return response['data'] ?? {};
      } else {
        throw Exception(response['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.changePassword,
        body: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
          'confirmPassword': newPasswordConfirmation,
        },
        requireAuth: true,
      );
      
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to change password');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Update preferences
  Future<void> updatePreferences({
    bool? emailNotifications,
    bool? pushNotifications,
    bool? marketingEmails,
    bool? courseReminders,
    bool? examReminders,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (emailNotifications != null) body['email_notifications'] = emailNotifications;
      if (pushNotifications != null) body['push_notifications'] = pushNotifications;
      if (marketingEmails != null) body['marketing_emails'] = marketingEmails;
      if (courseReminders != null) body['course_reminders'] = courseReminders;
      if (examReminders != null) body['exam_reminders'] = examReminders;

      final response = await ApiClient.instance.put(
        ApiEndpoints.profile,
        body: body,
        requireAuth: true,
      );
      
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to update preferences');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Upload avatar image
  Future<Map<String, dynamic>> uploadAvatar(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('Image file not found');
      }

      if (kDebugMode) {
        print('📤 ProfileService: Uploading avatar from $imagePath');
        print('📤 ProfileService: File exists: ${await file.exists()}');
        print('📤 ProfileService: File size: ${await file.length()} bytes');
      }

      final response = await ApiClient.instance.postMultipart(
        ApiEndpoints.profile,
        fields: {},
        files: {'avatar': file},
        requireAuth: true,
      );
      
      if (kDebugMode) {
        print('📥 ProfileService: Upload response: $response');
      }
      
      if (response['success'] == true) {
        // Handle different response structures
        final data = response['data'];
        if (data != null) {
          // If data contains avatar directly
          if (data is Map<String, dynamic>) {
            return data;
          }
          // If data is a string or other type, return it wrapped
          return {'avatar': data};
        }
        // If no data, check if avatar is at root level
        if (response.containsKey('avatar')) {
          return {
            'avatar': response['avatar'],
            'avatar_thumbnail': response['avatar_thumbnail'],
          };
        }
        return {};
      } else {
        final errorMessage = response['message'] ?? 'Failed to upload avatar';
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ProfileService: Avatar upload error: $e');
      }
      rethrow;
    }
  }
}

