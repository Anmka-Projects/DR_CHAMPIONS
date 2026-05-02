import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/course_pricing.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_radius.dart';
import '../../core/localization/localization_helper.dart';
import '../../core/navigation/route_names.dart';
import '../../widgets/bottom_nav.dart';
import '../../services/courses_service.dart';
import '../../services/lesson_bookmark_service.dart';

/// Enrolled Screen - My Courses with Modern Design
class EnrolledScreen extends StatefulWidget {
  const EnrolledScreen({super.key});

  @override
  State<EnrolledScreen> createState() => _EnrolledScreenState();
}

class _EnrolledScreenState extends State<EnrolledScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _enrolledCourses = [];
  List<Map<String, dynamic>> _bookmarkedLessons = [];
  Map<String, dynamic>? _meta;

  @override
  void initState() {
    super.initState();
    _loadEnrollments();
    _loadBookmarks();
  }

  Future<void> _loadEnrollments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await CoursesService.instance.getEnrollments(
        status: 'all',
        page: 1,
        perPage: 20,
      );
      if (!mounted) return;

      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📋 ENROLLMENTS SCREEN - PROCESSING RESPONSE');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📦 Full Response Received:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(response));
        } catch (e) {
          print('  Error formatting JSON: $e');
          print('  Raw response: $response');
        }
        print('');
        print('📊 Response Analysis:');
        print('  📋 response keys: ${response.keys.toList()}');
        print('  📦 data type: ${response['data']?.runtimeType}');
        print('  📋 data is List: ${response['data'] is List}');
        print('  📋 data is Map: ${response['data'] is Map}');
        print('  📋 data is Null: ${response['data'] == null}');

        if (response['data'] is List) {
          final dataList = response['data'] as List;
          print('  📏 data length: ${dataList.length}');
          if (dataList.isNotEmpty) {
            print('  📄 First Enrollment Details:');
            final first = dataList[0];
            if (first is Map) {
              print('     All Keys: ${first.keys.toList()}');
              first.forEach((key, value) {
                if (key == 'course' && value is Map) {
                  print('     📚 $key:');
                  print('        Keys: ${value.keys.toList()}');
                  value.forEach((courseKey, courseValue) {
                    if (courseValue is Map) {
                      print(
                          '        $courseKey: Map with keys: ${courseValue.keys.toList()}');
                    } else if (courseValue is List) {
                      print(
                          '        $courseKey: List with ${courseValue.length} items');
                    } else {
                      print(
                          '        $courseKey: ${courseValue.runtimeType} = $courseValue');
                    }
                  });
                } else if (value is Map) {
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
          print('  📋 Data is Map structure');
          final dataMap = response['data'] as Map;
          print('     Keys: ${dataMap.keys.toList()}');
        }

        if (response['meta'] != null) {
          print('  📊 meta: ${response['meta']}');
        }
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      setState(() {
        if (response['data'] != null) {
          if (response['data'] is List) {
            final dataList = response['data'] as List;
            _enrolledCourses = dataList
                .whereType<Map<String, dynamic>>()
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();

            if (kDebugMode) {
              print('✅ Loaded ${_enrolledCourses.length} enrolled courses');
            }
          } else if (response['data'] is Map<String, dynamic>) {
            // Try to extract from Map structure
            final dataMap = response['data'] as Map<String, dynamic>;
            if (dataMap['courses'] != null && dataMap['courses'] is List) {
              _enrolledCourses = List<Map<String, dynamic>>.from(
                dataMap['courses']!,
              );
              if (kDebugMode) {
                print(
                    '✅ Loaded ${_enrolledCourses.length} courses from Map structure');
              }
            } else {
              _enrolledCourses = [];
              if (kDebugMode) {
                print('⚠️ Data is Map but no courses found');
              }
            }
          } else {
            _enrolledCourses = [];
            if (kDebugMode) {
              print(
                  '⚠️ Data is not List or Map: ${response['data']?.runtimeType}');
            }
          }
        } else {
          _enrolledCourses = [];
          if (kDebugMode) {
            print('⚠️ Response data is null');
          }
        }

        _meta = response['meta'] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading enrollments: $e');
        print('  Error type: ${e.runtimeType}');
      }
      if (!mounted) return;
      setState(() {
        _enrolledCourses = [];
        _meta = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBookmarks() async {
    final items = await LessonBookmarkService.instance.getBookmarks();
    if (!mounted) return;
    setState(() {
      _bookmarkedLessons = items;
    });
  }

  void _handleOpenCourse(
      BuildContext context, Map<String, dynamic> enrollment) {
    // Extract course data from enrollment
    final course = enrollment['course'] as Map<String, dynamic>?;
    if (course == null) return;

    final courseData = {
      ...course,
      'id': course['id']?.toString(),
      'isFree': courseIsEffectivelyFree(course),
      'price': course['price'] ?? 0.0,
      'progress': enrollment['progress'] ?? 0,
      'completed_lessons': enrollment['completed_lessons'] ?? 0,
      'total_lessons':
          enrollment['total_lessons'] ?? course['lessons_count'] ?? 0,
      'is_enrolled': true,
    };
    context.push(RouteNames.courseDetails, extra: courseData);
  }

  Future<void> _refreshPage() async {
    await Future.wait([
      _loadEnrollments(),
      _loadBookmarks(),
    ]);
  }

  void _openBookmarkedLesson(BuildContext context, Map<String, dynamic> item) {
    final lessonId = item['lessonId']?.toString() ?? '';
    final courseId = item['courseId']?.toString() ?? '';
    if (lessonId.isEmpty || courseId.isEmpty) return;
    final lesson = item['lesson'];
    final lessonMap = lesson is Map<String, dynamic>
        ? lesson
        : <String, dynamic>{
            'id': lessonId,
            'title': item['lessonTitle']?.toString() ?? 'Lesson',
            'course_id': courseId,
          };
    context.push(RouteNames.lessonViewer, extra: {
      'lesson': lessonMap,
      'courseId': courseId,
    });
  }

  String _formatTimeAgo(BuildContext context, String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return context.l10n.timeAgo;
    }
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return context.l10n.daysAgo(difference.inDays);
      } else if (difference.inHours > 0) {
        return context.l10n.hoursAgo(difference.inHours);
      } else if (difference.inMinutes > 0) {
        return context.l10n.minutesAgo(difference.inMinutes);
      } else {
        return context.l10n.now;
      }
    } catch (e) {
      return context.l10n.timeAgo;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      body: Stack(
        children: [
          Column(
            children: [
              // Header
              _buildHeader(context),

              // Content
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _enrolledCourses.isEmpty
                        ? _buildEmptyState(context)
                        : RefreshIndicator(
                            onRefresh: _refreshPage,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 0, 20, 140),
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _enrolledCourses.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return _buildBookmarkedLessonsEntry(context);
                                }
                                final courseIndex = index - 1;
                                final enrollment = _enrolledCourses[courseIndex];
                                return TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: Duration(
                                      milliseconds: 400 + (index * 100)),
                                  curve: Curves.easeOut,
                                  builder: (context, value, child) {
                                    return Transform.translate(
                                      offset: Offset(0, 20 * (1 - value)),
                                      child: Opacity(
                                        opacity: value,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _buildCourseCard(context, enrollment),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
          // Bottom Navigation
          const BottomNav(activeTab: 'enrolled'),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final totalProgress = _enrolledCourses.isEmpty
        ? 0
        : (_enrolledCourses
                    .map((c) => _enrollmentProgress(c))
                    .reduce((a, b) => a + b) /
                _enrolledCourses.length)
            .round();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0C52B3), Color(0xFF093F8A)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.largeCard),
          bottomRight: Radius.circular(AppRadius.largeCard),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            children: [
              // Title Row
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.myCourses,
                          style: GoogleFonts.cairo(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          context.l10n.enrolledCoursesCount(
                            _meta?['total_enrolled'] ?? _enrolledCourses.length,
                          ),
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Stats Row
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.play_circle_fill_rounded,
                        value:
                            '${_meta?['total_enrolled'] ?? _enrolledCourses.length}',
                        label: context.l10n.courses,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.check_circle_rounded,
                        value: '$totalProgress%',
                        label: context.l10n.averageProgress,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        icon: Icons.emoji_events_rounded,
                        value:
                            '${_meta?['completed'] ?? _enrolledCourses.where((c) => _enrollmentProgress(c) >= 100).length}',
                        label: context.l10n.completed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
      {required IconData icon, required String value, required String label}) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 11,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // Helper function to safely convert to num (handles both String and num)
  num _parseNum(dynamic value, [num defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is num) return value;
    if (value is String) {
      final cleaned = value.replaceAll('%', '').trim();
      final parsed = num.tryParse(cleaned);
      return parsed ?? defaultValue;
    }
    return defaultValue;
  }

  // Helper function to safely convert to int
  int _parseInt(dynamic value, [int defaultValue = 0]) {
    return _parseNum(value, defaultValue).toInt();
  }

  // Helper function to safely convert to double
  double _parseDouble(dynamic value, [double defaultValue = 0.0]) {
    return _parseNum(value, defaultValue).toDouble();
  }

  int _enrollmentProgress(Map<String, dynamic> enrollment) {
    final status = enrollment['status']?.toString().toLowerCase();
    if (status == 'completed') return 100;

    final course = enrollment['course'] is Map<String, dynamic>
        ? enrollment['course'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final courseProgress = enrollment['course_progress'];
    if (courseProgress is Map) {
      final p = courseProgress['percentage'] ?? courseProgress['progress'];
      if (p != null) return _parseInt(p).clamp(0, 100);
    }

    final completed = _enrollmentCompletedLessons(enrollment);
    final total = _enrollmentTotalLessons(enrollment, course);
    if (total > 0 && completed >= total) return 100;

    final direct = enrollment['progress'] ??
        enrollment['progress_percentage'] ??
        enrollment['completion_percentage'] ??
        course['progress'] ??
        course['progress_percentage'] ??
        course['completion_percentage'];
    if (direct != null) {
      final raw = _parseDouble(direct);
      // Some APIs return progress as 0..1 fraction.
      final normalized = raw > 0 && raw <= 1 ? raw * 100 : raw;
      return normalized.round().clamp(0, 100);
    }
    return 0;
  }

  int _enrollmentCompletedLessons(Map<String, dynamic> enrollment) {
    final courseProgress = enrollment['course_progress'];
    if (courseProgress is Map) {
      final v =
          courseProgress['completed_lessons'] ?? courseProgress['completed'];
      if (v != null) return _parseInt(v);
    }
    return _parseInt(
      enrollment['completed_lessons'] ??
          enrollment['completed_lessons_count'] ??
          enrollment['completed'],
    );
  }

  int _enrollmentTotalLessons(
      Map<String, dynamic> enrollment, Map<String, dynamic> course) {
    final courseProgress = enrollment['course_progress'];
    if (courseProgress is Map) {
      final v = courseProgress['total_lessons'] ?? courseProgress['total'];
      if (v != null) return _parseInt(v);
    }
    final value = enrollment['total_lessons'] ??
        enrollment['lessons_count'] ??
        enrollment['total_lessons_count'] ??
        course['lessons_count'];
    return _parseInt(value);
  }

  Widget _buildBookmarkedLessonsEntry(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bookmark_rounded,
                  color: Color(0xFFF59E0B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bookmarked Lessons',
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      '${_bookmarkedLessons.length} saved lessons',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_bookmarkedLessons.isEmpty)
            Text(
              'No bookmarked lessons yet.',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            )
          else
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _bookmarkedLessons.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = _bookmarkedLessons[index];
                  final lessonTitle =
                      item['lessonTitle']?.toString() ?? 'Lesson';
                  return GestureDetector(
                    onTap: () => _openBookmarkedLesson(context, item),
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBF2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.play_circle_fill_rounded,
                            color: Color(0xFFF59E0B),
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  lessonTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.foreground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: Color(0xFFF59E0B),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(
      BuildContext context, Map<String, dynamic> enrollment) {
    // Extract course data from enrollment
    final course = enrollment['course'] as Map<String, dynamic>?;
    if (course == null) return const SizedBox.shrink();

    final progress = _enrollmentProgress(enrollment);
    final completedLessons = _enrollmentCompletedLessons(enrollment);
    final totalLessons = _enrollmentTotalLessons(enrollment, course);
    final courseTitle = course['title']?.toString() ?? '';
    final instructor = course['instructor'] is Map
        ? (course['instructor'] as Map)['name']?.toString() ?? ''
        : course['instructor']?.toString() ?? '';
    final rating = _parseDouble(course['rating'], 0.0);
    final durationHours = _parseNum(course['duration_hours']);
    final thumbnail = course['thumbnail']?.toString();
    final category = course['category'] is Map
        ? (course['category'] as Map)['name']?.toString() ?? ''
        : course['category']?.toString() ?? '';
    final enrolledAt = enrollment['enrolled_at']?.toString();
    final progressColor = progress >= 70
        ? const Color(0xFF10B981)
        : progress >= 40
            ? const Color(0xFFF59E0B)
            : AppColors.purple;

    return GestureDetector(
      onTap: () => _handleOpenCourse(context, enrollment),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.purple.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Minimalist Header with gradient overlay
            Container(
              height: 90,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    progressColor.withOpacity(0.15),
                    progressColor.withOpacity(0.05),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Course Icon/Emoji
                  Positioned(
                    right: 20,
                    top: 20,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: progressColor.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: thumbnail != null && thumbnail.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                thumbnail,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.menu_book_rounded,
                                  size: 24,
                                  color: AppColors.purple,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.menu_book_rounded,
                              size: 24,
                              color: AppColors.purple,
                            ),
                    ),
                  ),
                  // Progress Circle
                  Positioned(
                    left: 20,
                    top: 15,
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background circle
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              value: progress / 100,
                              strokeWidth: 5,
                              backgroundColor: Colors.white,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(progressColor),
                            ),
                          ),
                          // Progress text
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$progress',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: progressColor,
                                ),
                              ),
                              Text(
                                '%',
                                style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  color: progressColor.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Category Badge
                  Positioned(
                    left: 90,
                    top: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: progressColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category.isNotEmpty ? category : context.l10n.course,
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: progressColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Course Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    courseTitle,
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.foreground,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Instructor & Rating
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          instructor.isNotEmpty
                              ? instructor
                              : context.l10n.instructor,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.mutedForeground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.star_rounded,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Progress Bar (Slim Design)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerRight,
                            widthFactor: progress / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    progressColor.withOpacity(0.6),
                                    progressColor
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$completedLessons/$totalLessons',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Current Lesson Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.beige,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                progressColor.withOpacity(0.2),
                                progressColor.withOpacity(0.1)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.play_arrow_rounded,
                              color: progressColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.continueLearning,
                                style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                              Text(
                                completedLessons < totalLessons
                                    ? context.l10n.lessonFrom(
                                        completedLessons + 1, totalLessons)
                                    : context.l10n.allLessonsCompleted,
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.foreground,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: progressColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back_ios_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Footer Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMiniStat(Icons.access_time_rounded,
                          '${durationHours.toInt()}${context.l10n.hourShort}'),
                      _buildMiniStat(Icons.play_lesson_rounded,
                          context.l10n.lessonsCount(totalLessons)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.update_rounded,
                                size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              _formatTimeAgo(context, enrolledAt),
                              style: GoogleFonts.cairo(
                                fontSize: 10,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 11,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            height: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.purple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_rounded,
                size: 60, color: AppColors.purple),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.noEnrolledCourses,
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.startLearningJourney,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.go(RouteNames.home),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0C52B3), Color(0xFF093F8A)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purple.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                context.l10n.exploreCourses,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
