import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import 'token_storage_service.dart';

/// Service for courses, categories, and enrollments
class CoursesService {
  CoursesService._();

  static final CoursesService instance = CoursesService._();

  /// Helper method to process course data and add base URL to images
  Map<String, dynamic> _processCourseData(Map<String, dynamic> course) {
    final processedCourse = Map<String, dynamic>.from(course);

    // Add base URL to thumbnail if it exists and is a relative path
    if (processedCourse['thumbnail'] != null) {
      processedCourse['thumbnail'] = ApiEndpoints.getImageUrl(
        processedCourse['thumbnail']?.toString(),
      );
    }

    // Add base URL to other image fields if they exist
    if (processedCourse['image'] != null) {
      processedCourse['image'] = ApiEndpoints.getImageUrl(
        processedCourse['image']?.toString(),
      );
    }

    if (processedCourse['cover_image'] != null) {
      processedCourse['cover_image'] = ApiEndpoints.getImageUrl(
        processedCourse['cover_image']?.toString(),
      );
    }

    // Process instructor avatar if exists
    if (processedCourse['instructor'] != null) {
      final instructor = processedCourse['instructor'] as Map<String, dynamic>?;
      if (instructor != null && instructor['avatar'] != null) {
        instructor['avatar'] = ApiEndpoints.getImageUrl(
          instructor['avatar']?.toString(),
        );
      }
    }

    // Backend uses `is_wishlisted`; UI historically checks `is_in_wishlist`
    if (processedCourse['is_in_wishlist'] == null &&
        processedCourse['is_wishlisted'] != null) {
      processedCourse['is_in_wishlist'] = processedCourse['is_wishlisted'];
    }

    // List payloads sometimes omit `id` but include `uuid` / `course_id`.
    final idStr = processedCourse['id']?.toString().trim();
    if (idStr == null || idStr.isEmpty) {
      final alt = processedCourse['uuid']?.toString().trim() ??
          processedCourse['course_id']?.toString().trim();
      if (alt != null && alt.isNotEmpty) {
        processedCourse['id'] = alt;
      }
    }

    return processedCourse;
  }

  /// Helper method to process list of courses
  List<Map<String, dynamic>> _processCoursesList(List<dynamic> courses) {
    return courses.map((course) {
      if (course is Map<String, dynamic>) {
        return _processCourseData(course);
      }
      return course as Map<String, dynamic>;
    }).toList();
  }

  /// Fallback source for categories when `/api/categories` is unavailable.
  Future<List<Map<String, dynamic>>> _getCategoriesFromHome() async {
    final response = await ApiClient.instance.get(
      ApiEndpoints.home,
      requireAuth: true,
    );

    if (response['success'] != true || response['data'] == null) {
      return <Map<String, dynamic>>[];
    }

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final categoriesRaw = data['categories'];
    if (categoriesRaw is! List) {
      return <Map<String, dynamic>>[];
    }

    final categories = List<Map<String, dynamic>>.from(categoriesRaw);
    return categories.map((category) {
      final processedCategory = Map<String, dynamic>.from(category);
      if (processedCategory['icon'] != null) {
        final iconValue = processedCategory['icon']?.toString();
        if (iconValue != null && iconValue.isNotEmpty) {
          processedCategory['icon'] = ApiEndpoints.getImageUrl(iconValue);
        }
      }
      return processedCategory;
    }).toList();
  }

  /// Get all courses with filters
  Future<Map<String, dynamic>> getCourses({
    int page = 1,
    int perPage = 20,
    String? search,
    String? categoryId,
    String? subcategoryId,
    String? instructorId,
    String price = 'all', // all, free, paid
    String level = 'all', // all, beginner, intermediate, advanced
    String sort = 'newest', // newest, popular, rating, price_low, price_high
    String duration = 'all', // all, short, medium, long
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
        'price': price,
        'level': level,
        'sort': sort,
        'duration': duration,
      };

      // Add optional parameters only if they have non-empty values
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      if (categoryId != null && categoryId.trim().isNotEmpty) {
        queryParams['category_id'] = categoryId.trim();
      }

      if (subcategoryId != null && subcategoryId.trim().isNotEmpty) {
        queryParams['subcategory_id'] = subcategoryId.trim();
      }

      if (instructorId != null && instructorId.trim().isNotEmpty) {
        queryParams['instructor_id'] = instructorId.trim();
      }

      // Build URL manually to match API expectations
      // API expects search and category_id even if empty
      final baseUrl = ApiEndpoints.courses;
      final queryParts = <String>[];

      queryParts.add('page=${page.toString()}');
      queryParts.add('per_page=${perPage.toString()}');
      queryParts.add(
          'search=${search != null && search.trim().isNotEmpty ? Uri.encodeComponent(search.trim()) : ''}');
      queryParts.add(
          'category_id=${categoryId != null && categoryId.trim().isNotEmpty ? Uri.encodeComponent(categoryId.trim()) : ''}');

      if (subcategoryId != null && subcategoryId.trim().isNotEmpty) {
        queryParts
            .add('subcategory_id=${Uri.encodeComponent(subcategoryId.trim())}');
      }

      if (instructorId != null && instructorId.trim().isNotEmpty) {
        queryParts
            .add('instructor_id=${Uri.encodeComponent(instructorId.trim())}');
      }

      queryParts.add('price=$price');
      queryParts.add('level=$level');
      queryParts.add('sort=$sort');
      queryParts.add('duration=$duration');

      final finalUrl = '$baseUrl?${queryParts.join('&')}';

      if (kDebugMode) {
        print('🔍 Courses API Request:');
        print('  URL: $finalUrl');
        print('  Query Params: $queryParams');
      }

      final response = await ApiClient.instance.get(
        finalUrl,
        requireAuth: true,
      );

      if (kDebugMode) {
        print('📦 Courses API Response:');
        print('  Success: ${response['success']}');
        print('  Message: ${response['message']}');
        print('  Full Response: $response');

        // Check if data exists and has courses
        if (response['data'] != null) {
          final data = response['data'];
          print('  Data Type: ${data.runtimeType}');

          if (data is Map<String, dynamic>) {
            print('  Data Keys: ${data.keys.toList()}');

            // Check for courses list
            if (data['courses'] != null) {
              final courses = data['courses'] as List?;
              print('  Courses Count: ${courses?.length ?? 0}');

              // Print first course details to check for images
              if (courses != null && courses.isNotEmpty) {
                final firstCourse = courses[0] as Map<String, dynamic>?;
                if (firstCourse != null) {
                  print('  📸 First Course Image Fields:');
                  print('    All Keys: ${firstCourse.keys.toList()}');
                  print('    thumbnail: ${firstCourse['thumbnail']}');
                  print('    image: ${firstCourse['image']}');
                  print('    thumbnail_url: ${firstCourse['thumbnail_url']}');
                  print('    image_url: ${firstCourse['image_url']}');
                  print('    cover_image: ${firstCourse['cover_image']}');
                  print('    cover: ${firstCourse['cover']}');
                  print('    Full First Course: $firstCourse');
                }
              }
            }
          } else if (data is List) {
            print('  Courses Count: ${data.length}');
            if (data.isNotEmpty) {
              final firstCourse = data[0] as Map<String, dynamic>?;
              if (firstCourse != null) {
                print('  📸 First Course Image Fields:');
                print('    All Keys: ${firstCourse.keys.toList()}');
                print('    thumbnail: ${firstCourse['thumbnail']}');
                print('    image: ${firstCourse['image']}');
                print('    thumbnail_url: ${firstCourse['thumbnail_url']}');
                print('    image_url: ${firstCourse['image_url']}');
                print('    cover_image: ${firstCourse['cover_image']}');
                print('    cover: ${firstCourse['cover']}');
                print('    Full First Course: $firstCourse');
              }
            }
          }
        } else {
          print('  ⚠️ No data in response');
        }
      }

      if (response['success'] == true) {
        // Process courses to add base URL to images
        if (response['data'] != null) {
          final data = response['data'];
          if (data is Map<String, dynamic> && data['courses'] != null) {
            final courses = data['courses'] as List?;
            if (courses != null) {
              data['courses'] = _processCoursesList(courses);
            }
          } else if (data is List) {
            response['data'] = _processCoursesList(data);
          }
        }
        return response;
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch courses');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Parses course rows from a [getCourses] response (list root or `data.courses`).
  List<Map<String, dynamic>> coursesListFromCoursesResponse(
      Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map<String, dynamic>) {
      final c = data['courses'];
      if (c is List) {
        return c
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return [];
  }

  int? _parsePositiveInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v > 0 ? v : null;
    if (v is num) {
      final i = v.toInt();
      return i > 0 ? i : null;
    }
    return int.tryParse(v.toString());
  }

  /// First non-empty identifier across common API shapes (for dedupe / details).
  String? _courseStableId(Map<String, dynamic> row) {
    for (final k in ['id', 'uuid', 'course_id']) {
      final v = row[k]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  void _appendCoursesDeduped(
    List<Map<String, dynamic>> merged,
    Set<String> seenIds,
    List<Map<String, dynamic>> batch,
  ) {
    for (final row in batch) {
      final key = _courseStableId(row);
      if (key != null) {
        if (seenIds.contains(key)) continue;
        seenIds.add(key);
      }
      merged.add(row);
    }
  }

  /// Calls [getCourses] repeatedly until every page is loaded (fixes UI showing
  /// only the first `per_page` items).
  Future<Map<String, dynamic>> getCoursesAllPages({
    int perPage = 50,
    String? search,
    String? categoryId,
    String? subcategoryId,
    String? instructorId,
    String price = 'all',
    String level = 'all',
    String sort = 'newest',
    String duration = 'all',
    int maxPages = 100,
  }) async {
    final merged = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    var page = 1;

    while (page <= maxPages) {
      final response = await getCourses(
        page: page,
        perPage: perPage,
        search: search,
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        instructorId: instructorId,
        price: price,
        level: level,
        sort: sort,
        duration: duration,
      );

      if (response['success'] != true) {
        return response;
      }

      final batch = coursesListFromCoursesResponse(response);
      _appendCoursesDeduped(merged, seenIds, batch);

      Map<String, dynamic>? meta;
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final m = data['meta'];
        if (m is Map) meta = Map<String, dynamic>.from(m);
      }
      meta ??= response['meta'] is Map
          ? Map<String, dynamic>.from(response['meta'] as Map)
          : null;

      if (batch.isEmpty) break;

      final lastPage = _parsePositiveInt(meta?['last_page']) ??
          _parsePositiveInt(meta?['lastPage']);
      final currentPage = _parsePositiveInt(meta?['current_page']) ??
          _parsePositiveInt(meta?['currentPage']) ??
          page;

      if (lastPage != null && currentPage >= lastPage) break;
      // Do not stop on meta.total alone: some backends return an incorrect total
      // when category_id or other filters are applied, which hid courses (e.g. EEG).
      if (batch.length < perPage) break;

      page++;
    }

    final processed = _processCoursesList(merged);
    final displayTotal = processed.length;
    return {
      'success': true,
      'data': {
        'courses': processed,
        'meta': {
          'total': displayTotal,
          'per_page': perPage,
        },
      },
      'meta': {
        'total': displayTotal,
      },
    };
  }

  /// Get course details
  Future<Map<String, dynamic>> getCourseDetails(String courseId) async {
    final endpoint = ApiEndpoints.course(courseId);
    if (kDebugMode) {
      print('═══════════════════════════════════════════════════════════');
      print('📤 COURSE DETAILS REQUEST (teacher/student)');
      print('═══════════════════════════════════════════════════════════');
      print('  Method: GET');
      print('  Endpoint: $endpoint');
      print('  Course ID: $courseId');
      print('───────────────────────────────────────────────────────────');
    }
    try {
      final requireAuth = await TokenStorageService.instance.isLoggedIn();
      final response = await ApiClient.instance.get(
        endpoint,
        requireAuth: requireAuth,
      );

      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('📥 COURSE DETAILS RESPONSE (teacher/student)');
        print('═══════════════════════════════════════════════════════════');
        print('  Course ID: $courseId');
        print('  success: ${response['success']}');
        print('  message: ${response['message']}');
        print('  Full response keys: ${response.keys.toList()}');
        try {
          print('  Full response JSON:');
          print(const JsonEncoder.withIndent('    ').convert(response));
        } catch (_) {
          print('  Raw response: $response');
        }
        print('───────────────────────────────────────────────────────────');
        print('📦 Course Details API Response (legacy):');
        print('  Course ID: $courseId');
        print('  Success: ${response['success']}');
        print('  Message: ${response['message']}');

        if (response['data'] != null) {
          final courseData = response['data'] as Map<String, dynamic>;
          print('  📸 Course Image Fields:');
          print('    All Keys: ${courseData.keys.toList()}');
          print('    thumbnail: ${courseData['thumbnail']}');
          print('    image: ${courseData['image']}');
          print('    thumbnail_url: ${courseData['thumbnail_url']}');
          print('    image_url: ${courseData['image_url']}');
          print('    cover_image: ${courseData['cover_image']}');
          print('    cover: ${courseData['cover']}');
          print('    Full Course Data: $courseData');
        } else {
          print('  ⚠️ No course data in response');
        }
      }

      if (response['success'] == true && response['data'] != null) {
        final courseData = response['data'] as Map<String, dynamic>;
        return _processCourseData(courseData);
      } else {
        throw Exception(
            response['message'] ?? 'Failed to fetch course details');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get lesson details
  Future<Map<String, dynamic>> getLessonDetails(
    String courseId,
    String lessonId,
  ) async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.courseLesson(courseId, lessonId),
        requireAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(
            response['message'] ?? 'Failed to fetch lesson details');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get course assignments for student
  Future<List<Map<String, dynamic>>> getCourseAssignments(String courseId) async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.courseAssignments(courseId),
        requireAuth: true,
      );

      List<Map<String, dynamic>> toList(dynamic raw) {
        if (raw is! List) return <Map<String, dynamic>>[];
        return raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }

      if (response['success'] != true) {
        throw Exception(
            response['message'] ?? 'Failed to fetch course assignments');
      }

      final data = response['data'];

      // Common payload shapes:
      // 1) { data: [ ... ] }
      final fromDirectData = toList(data);
      if (fromDirectData.isNotEmpty) return fromDirectData;

      // 2) { data: { assignments: [...] | data: [...] | items: [...] | rows: [...] } }
      if (data is Map<String, dynamic>) {
        for (final key in ['assignments', 'data', 'items', 'rows']) {
          final parsed = toList(data[key]);
          if (parsed.isNotEmpty) return parsed;
        }
      }

      // 3) { assignments: [...] } on root
      for (final key in ['assignments', 'items', 'rows']) {
        final parsed = toList(response[key]);
        if (parsed.isNotEmpty) return parsed;
      }

      if (kDebugMode) {
        print('⚠️ Assignments response parsed empty for course: $courseId');
        print('   response keys: ${response.keys.toList()}');
        print('   data type: ${data.runtimeType}');
      }

      return <Map<String, dynamic>>[];
    } on ApiException catch (e) {
      // Production often returns Next.js HTML 404 when the route is not mounted
      // on the API (same host as the web app). Treat as empty list so the UI
      // can still use curriculum-based fallbacks without a thrown error.
      if (e.statusCode == 404) {
        if (kDebugMode) {
          print(
            '⚠️ GET .../courses/$courseId/assignments returned 404 (no API route '
            'or assignment module not deployed). Using empty list.');
        }
        return <Map<String, dynamic>>[];
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Get single assignment details for student
  Future<Map<String, dynamic>> getCourseAssignmentDetails(
    String courseId,
    String assignmentId,
  ) async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.courseAssignmentDetails(courseId, assignmentId),
        requireAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }

      throw Exception(response['message'] ?? 'Failed to fetch assignment details');
    } catch (e) {
      rethrow;
    }
  }

  /// Submit or resubmit assignment (see `docs/FLUTTER_ASSIGNMENT_STUDENT_LOGIC.md`).
  /// Upload files first via [UploadService], then pass returned URL paths in [answerFiles] / [answerImages].
  Future<void> submitCourseAssignment(
    String courseId,
    String assignmentId, {
    String? answerText,
    List<String> answerImages = const [],
    List<String> answerFiles = const [],
  }) async {
    final trimmed = answerText?.trim() ?? '';
    final body = <String, dynamic>{
      if (trimmed.isNotEmpty) 'answer_text': trimmed,
      'answer_images': answerImages,
      'answer_files': answerFiles,
    };

    final response = await ApiClient.instance.post(
      ApiEndpoints.courseAssignmentSubmit(courseId, assignmentId),
      body: body,
      requireAuth: true,
    );

    if (response['success'] != true) {
      throw Exception(response['message']?.toString() ?? 'Failed to submit assignment');
    }
  }

  /// Get lesson content
  Future<Map<String, dynamic>> getLessonContent(
    String courseId,
    String lessonId,
  ) async {
    try {
      Map<String, dynamic> response;
      try {
        response = await ApiClient.instance.get(
          ApiEndpoints.courseLessonContent(courseId, lessonId),
          requireAuth: true,
        );
      } on ApiException catch (e) {
        // Some backend deployments expose lesson details at:
        // /courses/:courseId/lessons/:lessonId
        // without a dedicated /content sub-route.
        if (e.statusCode != 404) rethrow;
        if (kDebugMode) {
          print(
              '⚠️ Lesson content endpoint returned 404; falling back to lesson details endpoint.');
        }
        response = await ApiClient.instance.get(
          ApiEndpoints.courseLesson(courseId, lessonId),
          requireAuth: true,
        );
      }

      if (kDebugMode) {
        print('📦 Lesson Content API Response:');
        print('  Course ID: $courseId');
        print('  Lesson ID: $lessonId');
        print('  Success: ${response['success']}');
        print('  Message: ${response['message']}');
        if (response['data'] != null) {
          print(
              '  Data Keys: ${(response['data'] as Map<String, dynamic>).keys.toList()}');
        }
      }

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(
            response['message'] ?? 'Failed to fetch lesson content');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching lesson content: $e');
      }
      rethrow;
    }
  }

  /// Update lesson progress
  Future<Map<String, dynamic>> updateLessonProgress(
    String courseId,
    String lessonId, {
    required int watchedSeconds,
    required bool isCompleted,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.courseLessonProgress(courseId, lessonId),
        body: {
          'watched_seconds': watchedSeconds,
          'is_completed': isCompleted,
        },
        requireAuth: true,
      );

      if (response['success'] == true) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(
            response['message'] ?? 'Failed to update lesson progress');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get all categories. Uses admin endpoint when [useAdmin] is true (for instructors).
  Future<List<Map<String, dynamic>>> getCategories(
      {bool useAdmin = false}) async {
    final url =
        useAdmin ? ApiEndpoints.adminCategories : ApiEndpoints.categories;
    if (kDebugMode) {
      print('═══════════════════════════════════════════════════════════');
      print('📤 CATEGORIES REQUEST');
      print('═══════════════════════════════════════════════════════════');
      print('  Method: GET');
      print('  URL: $url');
      print('  requireAuth: true');
      print('───────────────────────────────────────────────────────────');
    }
    try {
      final response = await ApiClient.instance.get(
        url,
        requireAuth: true,
      );

      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('📥 CATEGORIES RESPONSE (success)');
        print('═══════════════════════════════════════════════════════════');
        print('  URL: $url');
        print('  success: ${response['success']}');
        print('  message: ${response['message']}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📦 CATEGORIES API RESPONSE');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📦 Full Response JSON:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(response));
        } catch (e) {
          print('  Error formatting JSON: $e');
          print('  Raw response: $response');
        }
        print('');
        print('📊 Response Structure:');
        print('  ✅ success: ${response['success']}');
        print('  📝 message: ${response['message'] ?? 'N/A'}');
        print('  📦 data type: ${response['data']?.runtimeType}');

        if (response['data'] != null) {
          if (response['data'] is List) {
            final categories = response['data'] as List;
            print('  📏 Categories Count: ${categories.length}');
            if (categories.isNotEmpty) {
              print('  📄 First Category Structure:');
              final first = categories[0];
              if (first is Map) {
                print('     Keys: ${first.keys.toList()}');
                first.forEach((key, value) {
                  if (key == 'icon') {
                    print('     🔵 $key: ${value.runtimeType} = $value');
                  } else {
                    print('     $key: ${value.runtimeType} = $value');
                  }
                });
              }
              print('');
              print('  📋 All Categories Icons:');
              for (var i = 0; i < categories.length; i++) {
                final cat = categories[i] as Map<String, dynamic>?;
                if (cat != null) {
                  print('     Category ${i + 1}:');
                  print('       id: ${cat['id']}');
                  print('       name: ${cat['name']} / ${cat['name_ar']}');
                  print('       icon: ${cat['icon']}');
                  print('       icon type: ${cat['icon']?.runtimeType}');
                  print('       color: ${cat['color']}');
                }
              }
            }
          }
        }
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      if (response['success'] == true && response['data'] != null) {
        final categories =
            List<Map<String, dynamic>>.from(response['data'] as List);

        // Process categories to add base URL to icons if needed
        final processedCategories = categories.map((category) {
          final processedCategory = Map<String, dynamic>.from(category);

          // Add base URL to icon if it exists and is a relative path
          if (processedCategory['icon'] != null) {
            final iconValue = processedCategory['icon']?.toString();
            if (iconValue != null && iconValue.isNotEmpty) {
              processedCategory['icon'] = ApiEndpoints.getImageUrl(iconValue);
            }
          }

          return processedCategory;
        }).toList();

        return processedCategories;
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch categories');
      }
    } catch (e) {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('❌ CATEGORIES RESPONSE (error)');
        print('═══════════════════════════════════════════════════════════');
        print('  URL: $url');
        print('  Error: $e');
        print('  Error type: ${e.runtimeType}');
        print('───────────────────────────────────────────────────────────');
      }

      // Student/public flow:
      // If public categories endpoint is unavailable (404), do not hit admin
      // endpoint because it requires instructor privileges.
      if (!useAdmin && e.toString().contains('status 404')) {
        if (kDebugMode) {
          print('ℹ️ Public categories endpoint not found (404).');
          print('↩️ Retrying categories using /api/home fallback...');
        }
        try {
          final homeCategories = await _getCategoriesFromHome();
          if (kDebugMode) {
            print(
                '✅ Loaded categories from /api/home fallback: ${homeCategories.length}');
          }
          return homeCategories;
        } catch (fallbackError) {
          if (kDebugMode) {
            print('⚠️ /api/home fallback failed: $fallbackError');
            print('ℹ️ Returning empty categories list.');
          }
        }
        return <Map<String, dynamic>>[];
      }
      rethrow;
    }
  }

  /// Get category courses
  Future<Map<String, dynamic>> getCategoryCourses(
    String categoryId, {
    int page = 1,
    int perPage = 20,
    String sort = 'newest',
    String price = 'all',
    String level = 'all',
    String? subcategoryId,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
        'sort': sort,
        'price': price,
        'level': level,
        if (subcategoryId != null && subcategoryId.isNotEmpty)
          'subcategory_id': subcategoryId,
      };

      final queryString = Uri(queryParameters: queryParams).query;
      final url = '${ApiEndpoints.categoryCourses(categoryId)}?$queryString';

      final response = await ApiClient.instance.get(
        url,
        requireAuth: true,
      );

      if (kDebugMode) {
        print('📦 Category Courses API Response:');
        print('  Category ID: $categoryId');
        print('  Success: ${response['success']}');
        print('  Full Response: $response');

        if (response['data'] != null) {
          final data = response['data'];
          if (data is Map<String, dynamic> && data['courses'] != null) {
            final courses = data['courses'] as List?;
            if (courses != null && courses.isNotEmpty) {
              final firstCourse = courses[0] as Map<String, dynamic>?;
              if (firstCourse != null) {
                print('  📸 First Course Image Fields:');
                print('    thumbnail: ${firstCourse['thumbnail']}');
                print('    image: ${firstCourse['image']}');
              }
            }
          }
        }
      }

      if (response['success'] == true) {
        // Process courses to add base URL to images
        if (response['data'] != null) {
          final data = response['data'];
          if (data is Map<String, dynamic> && data['courses'] != null) {
            final courses = data['courses'] as List?;
            if (courses != null) {
              data['courses'] = _processCoursesList(courses);
            }
          }
        }
        return response;
      } else {
        throw Exception(
            response['message'] ?? 'Failed to fetch category courses');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Paginates [getCategoryCourses] until the category list is complete. Prefer this
  /// when the generic `/courses?category_id=` filter misses rows for some categories.
  Future<Map<String, dynamic>> getCategoryCoursesAllPages(
    String categoryId, {
    int perPage = 50,
    String sort = 'newest',
    String price = 'all',
    String level = 'all',
    String? subcategoryId,
    int maxPages = 100,
  }) async {
    final merged = <Map<String, dynamic>>[];
    final seenIds = <String>{};
    var page = 1;

    while (page <= maxPages) {
      final response = await getCategoryCourses(
        categoryId,
        page: page,
        perPage: perPage,
        sort: sort,
        price: price,
        level: level,
        subcategoryId: subcategoryId,
      );

      if (response['success'] != true) {
        return response;
      }

      final batch = coursesListFromCoursesResponse(response);
      _appendCoursesDeduped(merged, seenIds, batch);

      Map<String, dynamic>? meta;
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final m = data['meta'];
        if (m is Map) meta = Map<String, dynamic>.from(m);
      }
      meta ??= response['meta'] is Map
          ? Map<String, dynamic>.from(response['meta'] as Map)
          : null;

      if (batch.isEmpty) break;

      final lastPage = _parsePositiveInt(meta?['last_page']) ??
          _parsePositiveInt(meta?['lastPage']);
      final currentPage = _parsePositiveInt(meta?['current_page']) ??
          _parsePositiveInt(meta?['currentPage']) ??
          page;

      if (lastPage != null && currentPage >= lastPage) break;
      if (batch.length < perPage) break;

      page++;
    }

    final processed = _processCoursesList(merged);
    final displayTotal = processed.length;
    return {
      'success': true,
      'data': {
        'courses': processed,
        'meta': {
          'total': displayTotal,
          'per_page': perPage,
        },
      },
      'meta': {
        'total': displayTotal,
      },
    };
  }

  /// Enroll in a course
  Future<Map<String, dynamic>> enrollInCourse(String courseId) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.enrollCourse(courseId),
        requireAuth: true,
      );

      if (response['success'] == true) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to enroll in course');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get user enrollments
  Future<Map<String, dynamic>> getEnrollments({
    String status = 'all', // all, in_progress, completed
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'status': status,
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      final queryString = Uri(queryParameters: queryParams).query;
      final url = '${ApiEndpoints.enrollments}?$queryString';

      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📤 ENROLLMENTS REQUEST DETAILS');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('🔗 URL: $url');
        print('📋 Query Parameters:');
        queryParams.forEach((key, value) {
          print('   $key: $value');
        });
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      final response = await ApiClient.instance.get(
        url,
        requireAuth: true,
      );

      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📥 ENROLLMENTS RESPONSE DETAILS');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📦 Full Response JSON:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(response));
        } catch (e) {
          print('  Error formatting JSON: $e');
          print('  Raw response: $response');
        }
        print('');
        print('📊 Response Structure:');
        print('  ✅ success: ${response['success']}');
        print('  📝 message: ${response['message'] ?? 'N/A'}');
        print('  📦 data type: ${response['data']?.runtimeType}');
        print('  📋 data is List: ${response['data'] is List}');
        print('  📋 data is Map: ${response['data'] is Map}');
        print('  📋 data is Null: ${response['data'] == null}');

        if (response['data'] != null) {
          if (response['data'] is List) {
            final dataList = response['data'] as List;
            print('  📏 data length: ${dataList.length}');
            if (dataList.isNotEmpty) {
              print('  📄 First enrollment structure:');
              final first = dataList[0];
              if (first is Map) {
                print('     Keys: ${first.keys.toList()}');
                first.forEach((key, value) {
                  if (value is Map) {
                    print('     $key: Map with keys: ${value.keys.toList()}');
                  } else if (value is List) {
                    print('     $key: List with ${value.length} items');
                  } else {
                    print('     $key: ${value.runtimeType} = $value');
                  }
                });
              }
            }
          } else if (response['data'] is Map) {
            final dataMap = response['data'] as Map;
            print('  📋 data keys: ${dataMap.keys.toList()}');
            dataMap.forEach((key, value) {
              if (value is List) {
                print('     $key: List with ${value.length} items');
              } else if (value is Map) {
                print('     $key: Map with keys: ${value.keys.toList()}');
              } else {
                print('     $key: ${value.runtimeType} = $value');
              }
            });
          }
        }

        if (response['meta'] != null) {
          print('  📊 meta: ${response['meta']}');
        }
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      // Handle response even if success is not explicitly true
      // Some APIs might return data without success field
      final isSuccess = response['success'] == true ||
          (response['data'] != null && response['error'] == null);

      if (isSuccess) {
        // Process enrollments courses to add base URL to images
        if (response['data'] != null) {
          final data = response['data'];

          if (data is Map<String, dynamic> && data['courses'] != null) {
            // Case 1: Data is a Map with 'courses' key
            final courses = data['courses'] as List?;
            if (courses != null) {
              data['courses'] = _processCoursesList(courses);
            }
            if (kDebugMode) {
              print(
                  '  ✅ Processed Map with courses: ${courses?.length ?? 0} courses');
            }
          } else if (data is List) {
            // Case 2: Data is directly a list of enrollments
            if (kDebugMode) {
              print('  ✅ Processing List of enrollments: ${data.length} items');
            }

            final processedData = data.map((enrollment) {
              if (enrollment is Map<String, dynamic>) {
                final processedEnrollment =
                    Map<String, dynamic>.from(enrollment);
                if (processedEnrollment['course'] != null) {
                  processedEnrollment['course'] = _processCourseData(
                    processedEnrollment['course'] as Map<String, dynamic>,
                  );
                }
                return processedEnrollment;
              }
              return enrollment;
            }).toList();
            response['data'] = processedData;

            if (kDebugMode) {
              print('  ✅ Processed ${processedData.length} enrollments');
            }
          } else if (data is Map<String, dynamic>) {
            // Case 3: Data is a Map but without 'courses' key
            // Try to find enrollments in other possible keys
            if (kDebugMode) {
              print('  ⚠️ Data is Map but no courses key found');
              print('  Available keys: ${data.keys.toList()}');
            }
          } else {
            if (kDebugMode) {
              print('  ⚠️ Unknown data type: ${data.runtimeType}');
            }
          }
        } else {
          if (kDebugMode) {
            print('  ⚠️ Response data is null');
          }
          // Ensure data is an empty list if null
          response['data'] = [];
        }

        return response;
      } else {
        final errorMessage = response['message'] ??
            response['error'] ??
            'Failed to fetch enrollments';
        if (kDebugMode) {
          print('  ❌ Error: $errorMessage');
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (kDebugMode) {
        print('  ❌ Exception in getEnrollments: $e');
      }
      rethrow;
    }
  }

  /// Get course reviews
  Future<Map<String, dynamic>> getCourseReviews(
    String courseId, {
    int page = 1,
    int perPage = 20,
    int? rating,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
        if (rating != null) 'rating': rating.toString(),
      };

      final queryString = Uri(queryParameters: queryParams).query;
      final url = '${ApiEndpoints.courseReviews(courseId)}?$queryString';

      final response = await ApiClient.instance.get(
        url,
        requireAuth: true,
      );

      if (response['success'] == true) {
        return response;
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch reviews');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Add course review
  Future<Map<String, dynamic>> addCourseReview(
    String courseId, {
    required int rating,
    required String title,
    required String comment,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.courseReviews(courseId),
        body: {
          'rating': rating,
          'title': title,
          'comment': comment,
        },
        requireAuth: true,
      );

      if (response['success'] == true) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to add review');
      }
    } catch (e) {
      rethrow;
    }
  }
}
