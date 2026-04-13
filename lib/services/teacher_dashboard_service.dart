import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import 'profile_service.dart';

/// Service for teacher/instructor dashboard APIs (TEACHER_DASHBOARD_API.md).
/// Uses admin endpoints with instructor token; filter by current user for instructor view.
class TeacherDashboardService {
  TeacherDashboardService._();

  static final TeacherDashboardService instance = TeacherDashboardService._();

  /// Dashboard overview (stats: totalUsers, totalCourses, totalSubscriptions, totalRevenue, *Growth).
  /// For instructor view, backend may return filtered data by current user.
  Future<Map<String, dynamic>> getDashboardOverview() async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.adminDashboardOverview,
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
      throw Exception(
          response['message'] ?? 'Failed to load dashboard overview');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.getDashboardOverview: $e');
      }
      rethrow;
    }
  }

  /// Dashboard charts (usersGrowth, revenue, courseCompletion).
  /// For instructor: filtered to his courses.
  Future<Map<String, dynamic>> getDashboardCharts() async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.adminDashboardCharts,
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
      throw Exception(response['message'] ?? 'Failed to load dashboard charts');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.getDashboardCharts: $e');
      }
      rethrow;
    }
  }

  /// Dashboard activity (recentPayments, recentEnrollments).
  /// For instructor: activity of his courses only.
  Future<Map<String, dynamic>> getDashboardActivity() async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.adminDashboardActivity,
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
      throw Exception(
          response['message'] ?? 'Failed to load dashboard activity');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.getDashboardActivity: $e');
      }
      rethrow;
    }
  }

  /// Create a new course (POST /api/admin/courses). TEACHER_CREATE_COURSE_API.md
  Future<Map<String, dynamic>> createCourse({
    required String title,
    required String categoryId,
    required String instructorId,
    String? description,
    String? thumbnail,
    double? price,
    double? discountPrice,
    String level = 'beginner',
    int duration = 0,
    String status = 'draft',
    bool isFeatured = false,
  }) async {
    try {
      final body = <String, dynamic>{
        'title': title,
        'categoryId': categoryId,
        'instructorId': instructorId,
        'level': level,
        'duration': duration,
        'status': status,
        'isFeatured': isFeatured,
      };
      if (description != null && description.isNotEmpty) {
        body['description'] = description;
      }
      if (thumbnail != null && thumbnail.isNotEmpty) {
        body['thumbnail'] = thumbnail;
      }
      if (price != null) body['price'] = price;
      if (discountPrice != null) body['discountPrice'] = discountPrice;

      final response = await ApiClient.instance.post(
        ApiEndpoints.adminCourses,
        body: body,
        requireAuth: true,
      );
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
      throw Exception(response['message'] ?? 'Failed to create course');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.createCourse: $e');
      }
      rethrow;
    }
  }

  /// My courses (instructor filter). Pass current user id as instructorId.
  Future<Map<String, dynamic>> getMyCourses({
    required String instructorId,
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    try {
      final query = <String, String>{
        'instructorId': instructorId,
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (status != null && status.isNotEmpty) {
        query['status'] = status;
      }
      final uri = Uri.parse(ApiEndpoints.adminCourses).replace(
        queryParameters: query,
      );
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('📤 GET MY COURSES REQUEST');
        print('═══════════════════════════════════════════════════════════');
        print('  Method: GET');
        print('  URL: $uri');
        print('  instructorId: $instructorId');
        print('  page: $page');
        print('  limit: $limit');
        if (status != null && status.isNotEmpty) {
          print('  status: $status');
        }
        print('───────────────────────────────────────────────────────────');
      }
      final response = await ApiClient.instance.get(
        uri.toString(),
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true) {
        return response['data'] as Map<String, dynamic>? ?? {};
      }
      throw Exception(response['message'] ?? 'Failed to load courses');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.getMyCourses: $e');
      }
      rethrow;
    }
  }

  /// Single course details for instructor/admin (GET /api/admin/courses/:id).
  Future<Map<String, dynamic>> getCourseDetails(String courseId) async {
    final url = ApiEndpoints.adminCourse(courseId);
    if (kDebugMode) {
      print('═══════════════════════════════════════════════════════════');
      print('📤 COURSE DETAILS REQUEST (instructor/admin)');
      print('═══════════════════════════════════════════════════════════');
      print('  Method: GET');
      print('  URL: $url');
      print('  Course ID: $courseId');
      print('───────────────────────────────────────────────────────────');
    }
    try {
      final response = await ApiClient.instance.get(
        url,
        requireAuth: true,
      );
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('📥 COURSE DETAILS RESPONSE (instructor/admin)');
        print('═══════════════════════════════════════════════════════════');
        print('  success: ${response['success']}');
        print('  message: ${response['message']}');
        final data = response['data'];
        print('  data type: ${data.runtimeType}');
        if (data is Map) {
          print('  data keys: ${data.keys.toList()}');
          print('  id: ${data['id']}');
          print('  title: ${data['title']}');
          print('  status: ${data['status']}');
          print('  price: ${data['price']}');
          print('  studentsCount: ${data['studentsCount']}');
          print('  lessonsCount: ${data['lessonsCount']}');
          final students = data['students'];
          if (students is List) {
            print('  students length: ${students.length}');
          }
          final sections = data['sections'];
          if (sections is List) {
            print('  sections length: ${sections.length}');
          }
        }
        try {
          print('  Full response JSON:');
          print(const JsonEncoder.withIndent('    ').convert(response));
        } catch (_) {
          print('  Raw response: $response');
        }
        print('───────────────────────────────────────────────────────────');
      }
      if (response['success'] == true && response['data'] != null) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
      throw Exception(response['message'] ?? 'Failed to load course details');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.getCourseDetails: $e');
      }
      rethrow;
    }
  }

  /// User's earnings (totalEarnings, periodEarnings, byCourse).
  /// Uses /admin/users/:userId/earnings with actual userId (fallback to /me/earnings).
  Future<Map<String, dynamic>> getUsersMeEarnings() async {
    String userId = '';
    try {
      final profile = await ProfileService.instance.getProfile();
      userId = profile['id']?.toString() ?? '';
    } catch (_) {}
    final url = userId.isNotEmpty
        ? ApiEndpoints.adminUsersEarnings(userId)
        : ApiEndpoints.adminUsersMeEarnings;
    if (kDebugMode) {
      print('═══════════════════════════════════════════════════════════');
      print('📤 USERS ME EARNINGS REQUEST');
      print('═══════════════════════════════════════════════════════════');
      print('  Method: GET');
      print('  URL: $url');
      print('  userId: ${userId.isEmpty ? 'me (fallback)' : userId}');
      print('───────────────────────────────────────────────────────────');
    }
    try {
      final response = await ApiClient.instance.get(
        url,
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('📥 USERS ME EARNINGS RESPONSE');
        print('═══════════════════════════════════════════════════════════');
        print('  success: ${response['success']}');
        print('  message: ${response['message']}');
        final data = response['data'];
        print('  data type: ${data.runtimeType}');
        if (data is Map) print('  data keys: ${data.keys.toList()}');
        try {
          print('  Full response JSON:');
          print(const JsonEncoder.withIndent('    ').convert(response));
        } catch (_) {
          print('  Raw: $response');
        }
        print('───────────────────────────────────────────────────────────');
      }
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
      throw Exception(response['message'] ?? 'Failed to load earnings');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.getUsersMeEarnings: $e');
      }
      rethrow;
    }
  }

  /// All payments. Filter on client by instructor's course IDs for "إجمالي المبيعات".
  Future<Map<String, dynamic>> getPayments({
    int page = 1,
    int limit = 50,
    String? status,
  }) async {
    try {
      final query = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (status != null && status.isNotEmpty) {
        query['status'] = status;
      }
      final uri = Uri.parse(ApiEndpoints.adminPayments).replace(
        queryParameters: query,
      );
      final response = await ApiClient.instance.get(
        uri.toString(),
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true) {
        return response['data'] as Map<String, dynamic>? ?? {};
      }
      throw Exception(response['message'] ?? 'Failed to load payments');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.getPayments: $e');
      }
      rethrow;
    }
  }

  /// Current user's (teacher) salary settings.
  Future<Map<String, dynamic>> getMySalarySettings() async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.adminTeachersMeSalarySettings,
        requireAuth: true,
      );
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
      throw Exception(response['message'] ?? 'Failed to load salary settings');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.getMySalarySettings: $e');
      }
      rethrow;
    }
  }

  /// Calculate current user's (teacher) salary for a period.
  Future<Map<String, dynamic>> calculateMySalary({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.adminTeachersMeCalculateSalary,
        body: {
          'startDate': startDate,
          'endDate': endDate,
        },
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
      throw Exception(response['message'] ?? 'Failed to calculate salary');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.calculateMySalary: $e');
      }
      rethrow;
    }
  }

  /// Teacher reports (optional: pass teacherId for current user).
  /// [summary] true = ملخص، false = تفصيلي (per reference).
  Future<Map<String, dynamic>> getReports({
    String? teacherId,
    String? startDate,
    String? endDate,
    bool? summary,
    int page = 1,
    int limit = 20,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (teacherId != null && teacherId.isNotEmpty) {
      query['teacherId'] = teacherId;
    }
    if (startDate != null) query['startDate'] = startDate;
    if (endDate != null) query['endDate'] = endDate;
    if (summary != null) query['summary'] = summary.toString();
    final uri = Uri.parse(ApiEndpoints.adminTeachersReports).replace(
      queryParameters: query,
    );
    if (kDebugMode) {
      print('═══════════════════════════════════════════════════════════');
      print('📤 REPORTS REQUEST');
      print('═══════════════════════════════════════════════════════════');
      print('  Method: GET');
      print('  URL: $uri');
      print('  Query: $query');
      print('───────────────────────────────────────────────────────────');
    }
    try {
      final response = await ApiClient.instance.get(
        uri.toString(),
        requireAuth: true,
      );
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('📥 REPORTS RESPONSE');
        print('═══════════════════════════════════════════════════════════');
        print('  success: ${response['success']}');
        print('  message: ${response['message']}');
        final data = response['data'];
        print('  data type: ${data.runtimeType}');
        if (data is Map) print('  data keys: ${data.keys.toList()}');
        try {
          print('  Full response JSON:');
          print(const JsonEncoder.withIndent('    ').convert(response));
        } catch (_) {
          print('  Raw: $response');
        }
        print('───────────────────────────────────────────────────────────');
      }
      if (response['success'] == true) {
        return response['data'] as Map<String, dynamic>? ?? {};
      }
      throw Exception(response['message'] ?? 'Failed to load reports');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.getReports: $e');
      }
      rethrow;
    }
  }

  /// Attendance records for teacher's courses.
  /// Pass [courseId] and [action: 'course-enrollments'] for enrollments of a course.
  Future<Map<String, dynamic>> getAttendance({
    String? courseId,
    String? action,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final query = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (courseId != null && courseId.isNotEmpty) {
        query['courseId'] = courseId;
      }
      if (action != null && action.isNotEmpty) {
        query['action'] = action;
      }
      final uri = Uri.parse(ApiEndpoints.adminAttendance).replace(
        queryParameters: query,
      );
      final response = await ApiClient.instance.get(
        uri.toString(),
        requireAuth: true,
      );
      if (response['success'] == true) {
        return response['data'] as Map<String, dynamic>? ?? {};
      }
      throw Exception(response['message'] ?? 'Failed to load attendance');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.getAttendance: $e');
      }
      rethrow;
    }
  }

  /// Update student parent phone. Teacher can only update students enrolled in their courses.
  /// Request body: { "parentPhone": "+201234567890" } or { "parentPhone": "" } to clear.
  Future<Map<String, dynamic>> updateStudentParentPhone({
    required String studentId,
    required String parentPhone,
  }) async {
    try {
      final url = ApiEndpoints.adminStudentParentPhone(studentId);
      final response = await ApiClient.instance.patch(
        url,
        body: {'parentPhone': parentPhone},
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
      throw Exception(response['message'] ?? 'Failed to update parent phone');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.updateStudentParentPhone: $e');
      }
      rethrow;
    }
  }

  /// Update course curriculum.
  /// PUT /api/admin/curriculum/:courseId – body: { sections: [{ id, title, order, lessons: [...] }] }.
  Future<Map<String, dynamic>> updateCourseCurriculum(
    String courseId, {
    required Map<String, dynamic> body,
  }) async {
    try {
      final url = ApiEndpoints.adminCurriculum(courseId);
      // Send only sections per reference (id, title, order, lessons per section)
      final sections = body['sections'] ?? body['curriculum'] ?? [];
      final payload = <String, dynamic>{'sections': sections};
      final response = await ApiClient.instance.put(
        url,
        body: payload,
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true) {
        final data = response['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
        return {'data': data};
      }
      throw Exception(response['message'] ?? 'Failed to update curriculum');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.updateCourseCurriculum: $e');
      }
      rethrow;
    }
  }

  /// Get course curriculum (sections and lessons).
  /// Uses GET /api/admin/curriculum/:courseId per teacher reference.
  Future<Map<String, dynamic>> getCourseCurriculum(String courseId) async {
    try {
      final url = ApiEndpoints.adminCurriculum(courseId);
      final response = await ApiClient.instance.get(
        url,
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true) {
        final data = response['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
        // Backend may return sections array directly
        if (data is List) return {'sections': data};
        return {'sections': data ?? []};
      }
      throw Exception(response['message'] ?? 'Failed to load curriculum');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.getCourseCurriculum: $e');
      }
      rethrow;
    }
  }

  /// POST /api/admin/curriculum/:courseId/sections – create section.
  Future<Map<String, dynamic>> addCurriculumSection(
    String courseId, {
    required String title,
    int order = 0,
  }) async {
    try {
      final url = ApiEndpoints.adminCurriculumSections(courseId);
      final response = await ApiClient.instance.post(
        url,
        body: {'title': title, 'order': order},
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
        return {'data': data};
      }
      throw Exception(response['message'] ?? 'Failed to add section');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.addCurriculumSection: $e');
      }
      rethrow;
    }
  }

  /// PUT /api/admin/curriculum/:courseId/sections/:sectionId – update section.
  Future<Map<String, dynamic>> updateCurriculumSection(
    String courseId,
    String sectionId, {
    String? title,
    int? order,
  }) async {
    try {
      final url = ApiEndpoints.adminCurriculumSection(courseId, sectionId);
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (order != null) body['order'] = order;
      final response = await ApiClient.instance.put(
        url,
        body: body,
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true) {
        final data = response['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
        return {};
      }
      throw Exception(response['message'] ?? 'Failed to update section');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.updateCurriculumSection: $e');
      }
      rethrow;
    }
  }

  /// DELETE /api/admin/curriculum/:courseId/sections/:sectionId.
  Future<void> deleteCurriculumSection(
    String courseId,
    String sectionId,
  ) async {
    try {
      final url = ApiEndpoints.adminCurriculumSection(courseId, sectionId);
      final response = await ApiClient.instance.delete(
        url,
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to delete section');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.deleteCurriculumSection: $e');
      }
      rethrow;
    }
  }

  /// POST /api/admin/curriculum/:courseId/sections/:sectionId/lessons – create lesson.
  Future<Map<String, dynamic>> addCurriculumLesson(
    String courseId,
    String sectionId, {
    required String title,
    required String type,
    int duration = 0,
    String? content,
    String? videoUrl,
    String? fileUrl,
    bool isFree = false,
    int order = 0,
  }) async {
    try {
      final url = ApiEndpoints.adminCurriculumLessons(courseId, sectionId);
      final body = <String, dynamic>{
        'title': title,
        'type': type,
        'duration': duration,
        'isFree': isFree,
        'order': order,
      };
      if (content != null) body['content'] = content;
      if (videoUrl != null) body['videoUrl'] = videoUrl;
      if (fileUrl != null) body['fileUrl'] = fileUrl;
      final response = await ApiClient.instance.post(
        url,
        body: body,
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
        return {'data': data};
      }
      throw Exception(response['message'] ?? 'Failed to add lesson');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.addCurriculumLesson: $e');
      }
      rethrow;
    }
  }

  /// PUT /api/admin/curriculum/.../sections/.../lessons/:lessonId – update lesson.
  Future<Map<String, dynamic>> updateCurriculumLesson(
    String courseId,
    String sectionId,
    String lessonId, {
    String? title,
    String? type,
    int? duration,
    String? content,
    String? videoUrl,
    String? fileUrl,
    bool? isFree,
    int? order,
  }) async {
    try {
      final url =
          ApiEndpoints.adminCurriculumLesson(courseId, sectionId, lessonId);
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (type != null) body['type'] = type;
      if (duration != null) body['duration'] = duration;
      if (content != null) body['content'] = content;
      if (videoUrl != null) body['videoUrl'] = videoUrl;
      if (fileUrl != null) body['fileUrl'] = fileUrl;
      if (isFree != null) body['isFree'] = isFree;
      if (order != null) body['order'] = order;
      final response = await ApiClient.instance.put(
        url,
        body: body,
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true) {
        final data = response['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
        return {};
      }
      throw Exception(response['message'] ?? 'Failed to update lesson');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.updateCurriculumLesson: $e');
      }
      rethrow;
    }
  }

  /// DELETE /api/admin/curriculum/.../sections/.../lessons/:lessonId.
  Future<void> deleteCurriculumLesson(
    String courseId,
    String sectionId,
    String lessonId,
  ) async {
    try {
      final url =
          ApiEndpoints.adminCurriculumLesson(courseId, sectionId, lessonId);
      final response = await ApiClient.instance.delete(
        url,
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to delete lesson');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.deleteCurriculumLesson: $e');
      }
      rethrow;
    }
  }

  /// List course lectures. GET /api/admin/courses/:courseId/lectures
  Future<Map<String, dynamic>> getCourseLectures(
    String courseId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final uri = Uri.parse(ApiEndpoints.adminCourseLectures(courseId))
          .replace(queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      });
      final response = await ApiClient.instance.get(
        uri.toString(),
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true) {
        final data = response['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
        return {'lectures': data ?? [], 'meta': {}};
      }
      throw Exception(response['message'] ?? 'Failed to load lectures');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.getCourseLectures: $e');
      }
      rethrow;
    }
  }

  /// Get single lecture. GET /api/admin/courses/:courseId/lectures/:lectureId
  Future<Map<String, dynamic>> getCourseLecture(
    String courseId,
    String lectureId,
  ) async {
    try {
      final url = ApiEndpoints.adminCourseLecture(courseId, lectureId);
      final response = await ApiClient.instance.get(
        url,
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
        return {'data': data};
      }
      throw Exception(response['message'] ?? 'Failed to load lecture');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.getCourseLecture: $e');
      }
      rethrow;
    }
  }

  /// Add lecture. POST /api/admin/courses/:courseId/lectures
  Future<Map<String, dynamic>> addCourseLecture(
    String courseId, {
    required Map<String, dynamic> body,
  }) async {
    try {
      final url = ApiEndpoints.adminCourseLectures(courseId);
      final response = await ApiClient.instance.post(
        url,
        body: body,
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
        return {'data': data};
      }
      throw Exception(response['message'] ?? 'Failed to add lecture');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.addCourseLecture: $e');
      }
      rethrow;
    }
  }

  /// Update lecture. PUT /api/admin/courses/:courseId/lectures/:lectureId
  Future<Map<String, dynamic>> updateCourseLecture(
    String courseId,
    String lectureId, {
    required Map<String, dynamic> body,
  }) async {
    try {
      final url = ApiEndpoints.adminCourseLecture(courseId, lectureId);
      final response = await ApiClient.instance.put(
        url,
        body: body,
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true) {
        final data = response['data'];
        if (data is Map<String, dynamic>) return data;
        if (data is Map) return Map<String, dynamic>.from(data);
        return {};
      }
      throw Exception(response['message'] ?? 'Failed to update lecture');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.updateCourseLecture: $e');
      }
      rethrow;
    }
  }

  /// Delete lecture. DELETE /api/admin/courses/:courseId/lectures/:lectureId
  Future<void> deleteCourseLecture(
    String courseId,
    String lectureId,
  ) async {
    try {
      final url = ApiEndpoints.adminCourseLecture(courseId, lectureId);
      final response = await ApiClient.instance.delete(
        url,
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to delete lecture');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.deleteCourseLecture: $e');
      }
      rethrow;
    }
  }

  /// Get attendance session data for a course and session title.
  /// GET /api/attendance/session?course_id=xxx&session_title=yyy
  Future<Map<String, dynamic>> getAttendanceSession({
    required String courseId,
    required String sessionTitle,
  }) async {
    try {
      final uri = Uri.parse(ApiEndpoints.attendanceSession).replace(
        queryParameters: {
          'course_id': courseId,
          'session_title': sessionTitle,
        },
      );
      final response = await ApiClient.instance.get(
        uri.toString(),
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true) {
        return response;
      }
      throw Exception(
          response['message'] ?? 'Failed to load session attendance');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.getAttendanceSession: $e');
      }
      rethrow;
    }
  }

  /// Scan QR code to mark attendance. Teacher scans student's QR.
  /// POST /api/attendance/scan – body: qr_code, course_id, session_title (per reference).
  Future<Map<String, dynamic>> scanAttendance(
    String qrCode, {
    required String courseId,
    required String sessionTitle,
  }) async {
    try {
      final body = <String, dynamic>{
        'qr_code': qrCode,
        'course_id': courseId,
        'session_title': sessionTitle,
      };
      final response = await ApiClient.instance.post(
        ApiEndpoints.attendanceScan,
        body: body,
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true) {
        return response;
      }
      throw Exception(response['message'] ?? 'Failed to mark attendance');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.scanAttendance: $e');
      }
      rethrow;
    }
  }

  /// Teacher's own attendance records (when they attend the center).
  Future<Map<String, dynamic>> getMyAttendance({
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final query = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (startDate != null) query['startDate'] = startDate;
      if (endDate != null) query['endDate'] = endDate;
      final uri = Uri.parse(ApiEndpoints.attendanceMyAttendance).replace(
        queryParameters: query,
      );
      final response = await ApiClient.instance.get(
        uri.toString(),
        requireAuth: true,
        logTag: 'TEACHER',
      );
      if (response['success'] == true) {
        final raw = response['data'];
        if (raw is Map<String, dynamic>) return raw;
        if (raw is Map) return Map<String, dynamic>.from(raw);
        if (raw is List) return <String, dynamic>{'data': raw};
        return {};
      }
      throw Exception(response['message'] ?? 'Failed to load my attendance');
    } catch (e) {
      if (kDebugMode) {
        print('❌ TeacherDashboardService.getMyAttendance: $e');
      }
      rethrow;
    }
  }
}
