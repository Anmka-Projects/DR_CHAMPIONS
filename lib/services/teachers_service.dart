import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Service for fetching teachers data
class TeachersService {
  TeachersService._();

  static final TeachersService instance = TeachersService._();

  /// Helper method to process teacher data and add base URL to images
  Map<String, dynamic> _processTeacherData(Map<String, dynamic> teacher) {
    final processedTeacher = Map<String, dynamic>.from(teacher);

    // Add base URL to avatar if it exists and is a relative path
    if (processedTeacher['avatar'] != null) {
      processedTeacher['avatar'] = ApiEndpoints.getImageUrl(
        processedTeacher['avatar']?.toString(),
      );
    }

    // Process courses if they exist
    if (processedTeacher['courses'] != null) {
      final courses = processedTeacher['courses'] as List?;
      if (courses != null) {
        processedTeacher['courses'] = courses.map((course) {
          if (course is Map<String, dynamic>) {
            final processedCourse = Map<String, dynamic>.from(course);
            // Add base URL to course thumbnail if it exists
            if (processedCourse['thumbnail'] != null) {
              processedCourse['thumbnail'] = ApiEndpoints.getImageUrl(
                processedCourse['thumbnail']?.toString(),
              );
            }
            if (processedCourse['image'] != null) {
              processedCourse['image'] = ApiEndpoints.getImageUrl(
                processedCourse['image']?.toString(),
              );
            }
            return processedCourse;
          }
          return course;
        }).toList();
      }
    }

    return processedTeacher;
  }

  /// Helper method to process list of teachers
  List<Map<String, dynamic>> _processTeachersList(List<dynamic> teachers) {
    return teachers.map((teacher) {
      if (teacher is Map<String, dynamic>) {
        return _processTeacherData(teacher);
      }
      return teacher as Map<String, dynamic>;
    }).toList();
  }

  /// Get all teachers with optional filters
  Future<Map<String, dynamic>> getTeachers({
    int page = 1,
    int perPage = 20,
    String? search,
    String? sort = 'rating', // rating, students, newest
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
        'sort': sort ?? 'rating',
      };

      // Add optional search parameter
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final queryString = Uri(queryParameters: queryParams).query;
      final url = '${ApiEndpoints.teachers}?$queryString';

      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📤 TEACHERS API REQUEST');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('Method: GET');
        print('URL: $url');
        print('Query Params: $queryParams');
        print('Require Auth: true');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      final response = await ApiClient.instance.get(
        url,
        requireAuth: true,
      );

      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📥 TEACHERS API RESPONSE');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('URL: $url');
        print('Success: ${response['success']}');
        print('Message: ${response['message'] ?? 'N/A'}');
        if (response['data'] != null) {
          final data = response['data'];
          if (data is Map<String, dynamic> && data['teachers'] != null) {
            final teachers = data['teachers'] as List?;
            print('Teachers Count: ${teachers?.length ?? 0}');
          } else if (data is List) {
            print('Teachers Count: ${data.length}');
          }
        }
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        final processedResponse = Map<String, dynamic>.from(response);

        // Process teachers list
        if (data is Map<String, dynamic> && data['teachers'] != null) {
          // Case 1: Data is a Map with 'teachers' key (paginated response)
          final teachers = data['teachers'] as List?;
          if (teachers != null) {
            processedResponse['data'] = {
              ...data,
              'teachers': _processTeachersList(teachers),
            };
          }
        } else if (data is List) {
          // Case 2: Data is directly a list of teachers
          processedResponse['data'] = _processTeachersList(data);
        }

        if (kDebugMode) {
          print('✅ Teachers data processed - Image URLs updated');
        }

        return processedResponse;
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch teachers');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Teachers API Error: $e');
      }
      rethrow;
    }
  }

  /// Get teacher details by ID
  Future<Map<String, dynamic>> getTeacherDetails(String teacherId) async {
    try {
      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📤 TEACHER DETAILS API REQUEST');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('Method: GET');
        print('URL: ${ApiEndpoints.teacher(teacherId)}');
        print('Teacher ID: $teacherId');
        print('Require Auth: true');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      final response = await ApiClient.instance.get(
        ApiEndpoints.teacher(teacherId),
        requireAuth: true,
      );

      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📥 TEACHER DETAILS API RESPONSE');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('URL: ${ApiEndpoints.teacher(teacherId)}');
        print('Success: ${response['success']}');
        print('Message: ${response['message'] ?? 'N/A'}');
        if (response['data'] != null) {
          final teacher = response['data'] as Map<String, dynamic>;
          print('Teacher Name: ${teacher['name'] ?? 'N/A'}');
          print('Courses Count: ${(teacher['courses'] as List?)?.length ?? 0}');
        }
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      if (response['success'] == true && response['data'] != null) {
        final teacherData = response['data'] as Map<String, dynamic>;
        return _processTeacherData(teacherData);
      } else {
        throw Exception(
            response['message'] ?? 'Failed to fetch teacher details');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Teacher Details API Error: $e');
      }
      rethrow;
    }
  }

  /// Get teacher courses
  Future<Map<String, dynamic>> getTeacherCourses(
    String teacherId, {
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      final queryString = Uri(queryParameters: queryParams).query;
      final url = '${ApiEndpoints.teacherCourses(teacherId)}?$queryString';

      if (kDebugMode) {
        print('📤 Teacher Courses API Request:');
        print('  URL: $url');
        print('  Teacher ID: $teacherId');
      }

      final response = await ApiClient.instance.get(
        url,
        requireAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
        // Process courses to add base URL to images
        final data = response['data'];
        if (data is Map<String, dynamic> && data['courses'] != null) {
          final courses = data['courses'] as List?;
          if (courses != null) {
            final processedCourses = courses.map((course) {
              if (course is Map<String, dynamic>) {
                final processedCourse = Map<String, dynamic>.from(course);
                if (processedCourse['thumbnail'] != null) {
                  processedCourse['thumbnail'] = ApiEndpoints.getImageUrl(
                    processedCourse['thumbnail']?.toString(),
                  );
                }
                if (processedCourse['image'] != null) {
                  processedCourse['image'] = ApiEndpoints.getImageUrl(
                    processedCourse['image']?.toString(),
                  );
                }
                return processedCourse;
              }
              return course;
            }).toList();
            data['courses'] = processedCourses;
          }
        } else if (data is List) {
          // If data is directly a list of courses
          final processedCourses = data.map((course) {
            if (course is Map<String, dynamic>) {
              final processedCourse = Map<String, dynamic>.from(course);
              if (processedCourse['thumbnail'] != null) {
                processedCourse['thumbnail'] = ApiEndpoints.getImageUrl(
                  processedCourse['thumbnail']?.toString(),
                );
              }
              if (processedCourse['image'] != null) {
                processedCourse['image'] = ApiEndpoints.getImageUrl(
                  processedCourse['image']?.toString(),
                );
              }
              return processedCourse;
            }
            return course;
          }).toList();
          response['data'] = processedCourses;
        }
        return response;
      } else {
        throw Exception(
            response['message'] ?? 'Failed to fetch teacher courses');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Teacher Courses API Error: $e');
      }
      rethrow;
    }
  }
}

