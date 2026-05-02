import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Service for live courses
class LiveCoursesService {
  LiveCoursesService._();

  static final LiveCoursesService instance = LiveCoursesService._();

  /// Get live courses
  Future<Map<String, dynamic>> getLiveCourses({
    String? courseId,
    bool requireAuth = false,
  }) async {
    try {
      var url = ApiEndpoints.liveCourses;
      final normalizedCourseId = courseId?.trim();
      if (normalizedCourseId != null && normalizedCourseId.isNotEmpty) {
        final uri = Uri.parse(url).replace(
          queryParameters: {
            'courseId': normalizedCourseId,
          },
        );
        url = uri.toString();
      }

      final response = await ApiClient.instance.get(
        url,
        requireAuth: requireAuth,
      );

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch live courses');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Register for live course
  Future<Map<String, dynamic>> registerForLiveCourse(String liveSessionId) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.liveSession(liveSessionId),
        requireAuth: true,
      );
      
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to register for live course');
      }
    } catch (e) {
      rethrow;
    }
  }
}

