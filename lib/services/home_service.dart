import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Service for fetching home page data
class HomeService {
  HomeService._();

  static final HomeService instance = HomeService._();

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

  /// Helper method to process category data and add base URL to images
  Map<String, dynamic> _processCategoryData(Map<String, dynamic> category) {
    final processedCategory = Map<String, dynamic>.from(category);

    // Add base URL to category image/icon if it exists
    if (processedCategory['image'] != null) {
      processedCategory['image'] = ApiEndpoints.getImageUrl(
        processedCategory['image']?.toString(),
      );
    }

    if (processedCategory['icon'] != null) {
      processedCategory['icon'] = ApiEndpoints.getImageUrl(
        processedCategory['icon']?.toString(),
      );
    }

    if (processedCategory['thumbnail'] != null) {
      processedCategory['thumbnail'] = ApiEndpoints.getImageUrl(
        processedCategory['thumbnail']?.toString(),
      );
    }

    return processedCategory;
  }

  /// Helper method to process list of categories
  List<Map<String, dynamic>> _processCategoriesList(List<dynamic> categories) {
    return categories.map((category) {
      if (category is Map<String, dynamic>) {
        return _processCategoryData(category);
      }
      return category as Map<String, dynamic>;
    }).toList();
  }

  /// Helper method to process hero banner data and add base URL to images
  Map<String, dynamic>? _processHeroBanner(Map<String, dynamic>? banner) {
    if (banner == null) return null;

    final processedBanner = Map<String, dynamic>.from(banner);

    // Add base URL to banner image if it exists
    if (processedBanner['image'] != null) {
      processedBanner['image'] = ApiEndpoints.getImageUrl(
        processedBanner['image']?.toString(),
      );
    }

    if (processedBanner['background_image'] != null) {
      processedBanner['background_image'] = ApiEndpoints.getImageUrl(
        processedBanner['background_image']?.toString(),
      );
    }

    return processedBanner;
  }

  /// Fetch home page data
  Future<Map<String, dynamic>> getHomeData() async {
    try {
      // Log request details
      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📤 HOME API REQUEST');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('Method: GET');
        print('URL: ${ApiEndpoints.home}');
        print('Require Auth: true');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      final response = await ApiClient.instance.get(
        ApiEndpoints.home,
        requireAuth: true,
      );

      // Log response details
      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📥 HOME API RESPONSE');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('URL: ${ApiEndpoints.home}');
        try {
          final prettyJson =
              const JsonEncoder.withIndent('  ').convert(response);
          print('Response Body:');
          print(prettyJson);
        } catch (e) {
          print('Response: $response');
        }
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        // Log specific data sections
        if (response['data'] != null) {
          final data = response['data'] as Map<String, dynamic>;
          print('📊 Home Data Summary:');
          print(
              '  - User Summary: ${data['user_summary'] != null ? "✓" : "✗"}');
          print('  - Hero Banner: ${data['hero_banner'] != null ? "✓" : "✗"}');
          print(
              '  - Categories Count: ${(data['categories'] as List?)?.length ?? 0}');
          print(
              '  - Featured Courses Count: ${(data['featured_courses'] as List?)?.length ?? 0}');
          print(
              '  - Popular Courses Count: ${(data['popular_courses'] as List?)?.length ?? 0}');
          print(
              '  - Continue Learning Count: ${(data['continue_learning'] as List?)?.length ?? 0}');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        }
      }

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final processedData = Map<String, dynamic>.from(data);

        // Process featured courses
        if (processedData['featured_courses'] != null) {
          final featuredCourses = processedData['featured_courses'] as List?;
          if (featuredCourses != null) {
            processedData['featured_courses'] =
                _processCoursesList(featuredCourses);
          }
        }

        // Process popular courses
        if (processedData['popular_courses'] != null) {
          final popularCourses = processedData['popular_courses'] as List?;
          if (popularCourses != null) {
            processedData['popular_courses'] =
                _processCoursesList(popularCourses);
          }
        }

        // Process continue learning courses
        if (processedData['continue_learning'] != null) {
          final continueLearning = processedData['continue_learning'] as List?;
          if (continueLearning != null) {
            processedData['continue_learning'] =
                _processCoursesList(continueLearning);
          }
        }

        // Process categories
        if (processedData['categories'] != null) {
          final categories = processedData['categories'] as List?;
          if (categories != null) {
            processedData['categories'] = _processCategoriesList(categories);
          }
        }

        // Process hero banner
        if (processedData['hero_banner'] != null) {
          final heroBanner = processedData['hero_banner'];
          if (heroBanner is Map<String, dynamic>) {
            processedData['hero_banner'] = _processHeroBanner(heroBanner);
          }
        }

        // Process user summary avatar if exists
        if (processedData['user_summary'] != null) {
          final userSummary =
              processedData['user_summary'] as Map<String, dynamic>?;
          if (userSummary != null && userSummary['avatar'] != null) {
            userSummary['avatar'] = ApiEndpoints.getImageUrl(
              userSummary['avatar']?.toString(),
            );
          }
        }

        if (kDebugMode) {
          print('✅ Home data processed - Images URLs updated');
        }

        return processedData;
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch home data');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Home API Error: $e');
      }
      rethrow;
    }
  }
}
