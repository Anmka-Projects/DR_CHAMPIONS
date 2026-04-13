import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Service for fetching progress data
class ProgressService {
  ProgressService._();

  static final ProgressService instance = ProgressService._();

  /// Fetch progress data for a specific period (weekly or monthly)
  Future<Map<String, dynamic>> getProgressData(String period) async {
    try {
      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📤 PROGRESS API REQUEST');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('Method: GET');
        print('URL: ${ApiEndpoints.progress(period)}');
        print('Period: $period');
        print('Require Auth: true');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      final response = await ApiClient.instance.get(
        ApiEndpoints.progress(period),
        requireAuth: true,
      );

      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📥 PROGRESS API RESPONSE');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('URL: ${ApiEndpoints.progress(period)}');
        try {
          final prettyJson =
              const JsonEncoder.withIndent('  ').convert(response);
          print('Response Body:');
          print(prettyJson);
        } catch (e) {
          print('Response: $response');
        }
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final processedData = Map<String, dynamic>.from(data);

        // Process user avatar if exists
        if (processedData['user'] != null) {
          final user = processedData['user'] as Map<String, dynamic>?;
          if (user != null && user['avatar'] != null) {
            user['avatar'] = ApiEndpoints.getImageUrl(
              user['avatar']?.toString(),
            );
          }
        }

        // Process top students avatars if exists
        if (processedData['top_students'] != null) {
          final topStudents = processedData['top_students'] as List?;
          if (topStudents != null) {
            for (var student in topStudents) {
              if (student is Map<String, dynamic> &&
                  student['avatar'] != null) {
                student['avatar'] = ApiEndpoints.getImageUrl(
                  student['avatar']?.toString(),
                );
              }
            }
          }
        }

        if (kDebugMode) {
          print('✅ Progress data processed - Image URLs updated');
        }

        return processedData;
      } else {
        throw Exception(
            response['message'] ?? 'Failed to fetch progress data');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Progress API Error: $e');
      }
      rethrow;
    }
  }
}

