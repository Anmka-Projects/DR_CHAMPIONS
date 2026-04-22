import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Lists and uploads question banks for instructor flows.
/// Supports multiple common API response shapes; falls back to generic [UploadService].
class QuestionBankService {
  QuestionBankService._();
  static final QuestionBankService instance = QuestionBankService._();

  List<Map<String, dynamic>> _banksFromResponse(Map<String, dynamic> response) {
    dynamic raw = response['data'];
    if (raw == null) raw = response['question_banks'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (raw is Map) {
      final inner = raw['items'] ??
          raw['data'] ??
          raw['banks'] ??
          raw['question_banks'];
      if (inner is List) {
        return inner
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return [];
  }

  /// GET course-scoped banks, then global list with `course_id` query.
  Future<List<Map<String, dynamic>>> listQuestionBanks(String courseId) async {
    if (courseId.isEmpty) return [];
    try {
      final url = ApiEndpoints.adminCourseQuestionBanks(courseId);
      final response =
          await ApiClient.instance.get(url, requireAuth: true, logTag: 'QB');
      if (response['success'] == true) {
        return _banksFromResponse(response);
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ QuestionBankService list (course): $e');
      }
    }
    try {
      final uri = Uri.parse(ApiEndpoints.adminQuestionBanks).replace(
        queryParameters: {'course_id': courseId},
      );
      final response = await ApiClient.instance.get(
        uri.toString(),
        requireAuth: true,
        logTag: 'QB',
      );
      if (response['success'] == true) {
        return _banksFromResponse(response);
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ QuestionBankService list (query): $e');
      }
    }
    return [];
  }

  /// POST multipart to course-scoped endpoint, then [ApiEndpoints.adminQuestionBanks],
  /// then caller may use [UploadService.uploadQuestionBankFile] as last resort.
  Future<Map<String, dynamic>> uploadQuestionBankMultipart(
    File file, {
    required String courseId,
    String? title,
  }) async {
    final fields = <String, String>{
      if (title != null && title.isNotEmpty) 'title': title,
    };
    try {
      final url = ApiEndpoints.adminCourseQuestionBanks(courseId);
      final response = await ApiClient.instance.postMultipart(
        url,
        fields: fields,
        files: {'file': file},
        requireAuth: true,
        logTag: 'QB',
      );
      if (response['success'] == true) return response;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ QuestionBankService upload (course): $e');
      }
    }
    try {
      final response = await ApiClient.instance.postMultipart(
        ApiEndpoints.adminQuestionBanks,
        fields: {
          ...fields,
          'course_id': courseId,
        },
        files: {'file': file},
        requireAuth: true,
        logTag: 'QB',
      );
      if (response['success'] == true) return response;
      return response;
    } catch (e) {
      if (kDebugMode) {
        print('❌ QuestionBankService upload (admin): $e');
      }
      rethrow;
    }
  }

  static String? extractBankId(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map) {
      final id = data['id'] ?? data['question_bank_id'];
      if (id != null) return id.toString();
    }
    final id = response['id'] ?? response['question_bank_id'];
    if (id != null) return id.toString();
    return null;
  }

  static String? extractFileUrl(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map) {
      final u = data['url'] ?? data['file_url'] ?? data['fileUrl'];
      if (u != null) return u.toString();
    }
    final u = response['url'] ?? response['file_url'];
    if (u != null) return u.toString();
    return null;
  }
}
