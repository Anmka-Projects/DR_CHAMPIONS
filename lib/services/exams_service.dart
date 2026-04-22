import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Service for exams
class ExamsService {
  ExamsService._();
  
  static final ExamsService instance = ExamsService._();

  List<Map<String, dynamic>> _extractExamList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (data is Map<String, dynamic>) {
      final candidates = [
        data['exams'],
        data['items'],
        data['results'],
        data['completed'],
        data['data'],
      ];
      for (final candidate in candidates) {
        final extracted = _extractExamList(candidate);
        if (extracted.isNotEmpty) return extracted;
      }
    }

    return [];
  }

  /// Get exam details from course exams API (auth optional).
  Future<Map<String, dynamic>> getExamDetails(
    String courseId,
    String examId,
  ) async {
    try {
      Future<Map<String, dynamic>> fetch({required bool requireAuth}) {
        return ApiClient.instance.get(
          ApiEndpoints.courseExamDetails(courseId, examId),
          requireAuth: requireAuth,
        );
      }

      Map<String, dynamic> response;
      try {
        response = await fetch(requireAuth: true);
      } on ApiException catch (e) {
        if (e.statusCode == 401 || e.statusCode == 403) {
          response = await fetch(requireAuth: false);
        } else {
          rethrow;
        }
      }

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
      throw Exception(response['message'] ?? 'Failed to fetch exam details');
    } catch (e) {
      rethrow;
    }
  }

  /// Start exam for a specific course
  Future<Map<String, dynamic>> startExam(String courseId, String examId) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.courseExamStart(courseId, examId),
        requireAuth: true,
      );
      
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to start exam');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Submit exam
  Future<Map<String, dynamic>> submitExam(
    String courseId,
    String examId, {
    required String attemptId,
    required List<Map<String, dynamic>> answers,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.courseExamSubmit(courseId, examId),
        body: {
          'attempt_id': attemptId,
          'answers': answers,
        },
        requireAuth: true,
      );
      
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to submit exam');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get user exams
  Future<Map<String, dynamic>> getMyExams() async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.myExamResults(),
        requireAuth: true,
      );
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
        if (data is List) {
          return {'completed': _extractExamList(data)};
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch exams');
      }
      return {'completed': <Map<String, dynamic>>[]};
    } catch (e) {
      rethrow;
    }
  }

  /// Get course exams (optionally scoped to a lesson via lesson_id query).
  Future<List<Map<String, dynamic>>> getCourseExams(
    String courseId, {
    String? lessonId,
  }) async {
    try {
      Future<Map<String, dynamic>> fetch({required bool requireAuth}) {
        return ApiClient.instance.get(
          ApiEndpoints.courseExams(courseId, lessonId: lessonId),
          requireAuth: requireAuth,
        );
      }

      Map<String, dynamic> response;
      try {
        response = await fetch(requireAuth: true);
      } on ApiException catch (e) {
        if (e.statusCode == 401 || e.statusCode == 403) {
          response = await fetch(requireAuth: false);
        } else if ((e.message).toLowerCase().contains('invalid data provided')) {
          // Per API guide: retry once and log full response upstream.
          response = await fetch(requireAuth: true);
        } else {
          rethrow;
        }
      }

      if (response['success'] == true && response['data'] != null) {
        return _extractExamList(response['data']);
      }
      throw Exception(response['message'] ?? 'Failed to fetch course exams');
    } catch (e) {
      rethrow;
    }
  }

  /// Get course exam details
  Future<Map<String, dynamic>> getCourseExamDetails(
    String courseId,
    String examId,
  ) async {
    try {
      Future<Map<String, dynamic>> fetch({required bool requireAuth}) {
        return ApiClient.instance.get(
          ApiEndpoints.courseExamDetails(courseId, examId),
          requireAuth: requireAuth,
        );
      }

      Map<String, dynamic> response;
      try {
        response = await fetch(requireAuth: true);
      } on ApiException catch (e) {
        if (e.statusCode == 401 || e.statusCode == 403) {
          response = await fetch(requireAuth: false);
        } else {
          rethrow;
        }
      }

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
      throw Exception(response['message'] ?? 'Failed to fetch exam details');
    } catch (e) {
      rethrow;
    }
  }
}

