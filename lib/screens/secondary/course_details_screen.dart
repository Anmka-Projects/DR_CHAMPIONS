import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/course_pricing.dart';
import '../../core/course_live_meta.dart';
import '../../core/design/app_colors.dart';
import '../../core/navigation/route_names.dart';
import '../../l10n/app_localizations.dart';
import '../../services/courses_service.dart';
import '../../services/exams_service.dart';
import '../../services/live_courses_service.dart';
import '../../core/api/api_client.dart';
import '../../services/certificates_service.dart';
import '../../services/lesson_resume_service.dart';
import '../../services/profile_service.dart';
import '../../services/token_storage_service.dart';
import '../../widgets/assignment_detail_submission_sheet.dart';

bool _looksLikeContainerType(String? type) {
  if (type == null) return false;
  final normalized = type.toLowerCase();
  return normalized == 'module' ||
      normalized == 'sub_module' ||
      normalized == 'topic' ||
      normalized == 'section' ||
      normalized == 'chapter';
}

bool _hasPlayableFields(Map<String, dynamic> item) {
  final hasVideo = item['video'] != null || item['video_url'] != null;
  final hasYoutube =
      item['youtube_id'] != null || item['youtubeVideoId'] != null;
  final hasVimeo = item['vimeo_id'] != null;
  final hasAudio = item['audio_url'] != null;
  return hasVideo || hasYoutube || hasVimeo || hasAudio;
}

bool _isDirectLessonItem(Map<String, dynamic> item) {
  final itemType = item['type']?.toString();
  final hasNestedLessons = item['lessons'] is List;
  final hasSubModules = item['sub_modules'] is List;

  if (_looksLikeContainerType(itemType) || hasNestedLessons || hasSubModules) {
    return false;
  }

  if (itemType?.toLowerCase() == 'lesson') return true;

  // Some payloads omit "type", so treat media-bearing nodes as lessons.
  return _hasPlayableFields(item) || item['id'] != null;
}

Map<String, dynamic>? _findFirstLessonInItems(List<dynamic> items) {
  for (final raw in items) {
    if (raw is! Map<String, dynamic>) continue;

    if (_isDirectLessonItem(raw)) {
      return raw;
    }

    final nestedLessons = raw['lessons'];
    if (nestedLessons is List && nestedLessons.isNotEmpty) {
      final lesson = _findFirstLessonInItems(nestedLessons);
      if (lesson != null) return lesson;
    }

    final subModules = raw['sub_modules'];
    if (subModules is List && subModules.isNotEmpty) {
      final lesson = _findFirstLessonInItems(subModules);
      if (lesson != null) return lesson;
    }
  }
  return null;
}

@visibleForTesting
Map<String, dynamic>? selectFirstLessonForPlayback(
    Map<String, dynamic>? course) {
  if (course == null) return null;

  final curriculum = course['curriculum'];
  if (curriculum is List && curriculum.isNotEmpty) {
    final fromCurriculum = _findFirstLessonInItems(curriculum);
    if (fromCurriculum != null) return fromCurriculum;
  }

  final lessons = course['lessons'];
  if (lessons is List && lessons.isNotEmpty) {
    return _findFirstLessonInItems(lessons);
  }

  return null;
}

String? _resolveCourseIdFromMap(Map<String, dynamic>? course) {
  if (course == null) return null;
  for (final k in ['id', 'uuid', 'course_id']) {
    final v = course[k]?.toString().trim();
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}

/// Modern Course Details Screen with Beautiful UI
class CourseDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? course;

  const CourseDetailsScreen({super.key, this.course});

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _selectedLessonIndex = 0;
  bool _isLoading = false;
  bool _isEnrolling = false;
  bool _isEnrolled = false;
  Map<String, dynamic>? _courseData;
  List<Map<String, dynamic>> _courseExams = [];
  List<Map<String, dynamic>> _courseAssignments = [];
  List<Map<String, dynamic>> _courseLiveUpcomingSessions = [];
  List<Map<String, dynamic>> _courseLiveNowSessions = [];
  List<Map<String, dynamic>> _courseLivePastSessions = [];
  bool _isLoadingExams = false;
  bool _isLoadingLiveSessions = false;
  String? _startingExamId;
  bool _isViewingOwnCourse = false;
  final Map<String, bool> _expandedModules = {};
  final Map<String, bool> _expandedSubModules = {};
  String? _resumeLessonId;
  Map<String, dynamic>? _savedResumeData;
  Map<String, dynamic>? _courseCertificate;

  @override
  void setState(VoidCallback fn) {
    if (!mounted) return;
    super.setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadCourseDetails();
  }

  Future<void> _loadCourseDetails() async {
    // If course data is already provided, use it
    if (widget.course != null) {
      final courseId = _resolveCourseIdFromMap(widget.course);
      if (courseId != null && courseId.isNotEmpty) {
        setState(() => _isLoading = true);
        try {
          final courseDetails =
              await CoursesService.instance.getCourseDetails(courseId);

          // Print detailed response
          if (kDebugMode) {
            print(
                '═══════════════════════════════════════════════════════════');
            print('📋 COURSE DETAILS RESPONSE (getCourseDetails)');
            print(
                '═══════════════════════════════════════════════════════════');
            print('Course ID: $courseId');
            print('Response Type: ${courseDetails.runtimeType}');
            print('Response Keys: ${courseDetails.keys.toList()}');
            print(
                '───────────────────────────────────────────────────────────');
            print('Full Response JSON:');
            try {
              const encoder = JsonEncoder.withIndent('  ');
              print(encoder.convert(courseDetails));
            } catch (e) {
              print('Could not convert to JSON: $e');
              print('Raw Response: $courseDetails');
            }
            print(
                '───────────────────────────────────────────────────────────');
            print('Key Fields:');
            print('  - id: ${courseDetails['id']}');
            print('  - title: ${courseDetails['title']}');
            print('  - price: ${courseDetails['price']}');
            print('  - is_free: ${courseDetails['is_free']}');
            print('  - is_enrolled: ${courseDetails['is_enrolled']}');
            print('  - is_in_wishlist: ${courseDetails['is_in_wishlist']}');
            print('  - rating: ${courseDetails['rating']}');
            print('  - students_count: ${courseDetails['students_count']}');
            print('  - duration_hours: ${courseDetails['duration_hours']}');
            print(
                '  - curriculum length: ${(courseDetails['curriculum'] as List?)?.length ?? 0}');
            print(
                '  - lessons length: ${(courseDetails['lessons'] as List?)?.length ?? 0}');
            print(
                '───────────────────────────────────────────────────────────');
            print('📚 CURRICULUM DETAILS:');
            final curriculum = courseDetails['curriculum'] as List?;
            if (curriculum != null && curriculum.isNotEmpty) {
              print('  Total Items: ${curriculum.length}');

              // First, show summary of all topics
              print('');
              print('📁 ALL TOPICS FROM API:');
              print(
                  '═══════════════════════════════════════════════════════════');
              int topicCount = 0;
              for (int i = 0; i < curriculum.length; i++) {
                final item = curriculum[i];
                if (item is Map) {
                  // Check if this is a topic (has lessons field, even if empty)
                  // A topic is identified by having a 'lessons' field (can be empty list)
                  // OR by not having video/youtube_id fields (which indicate it's a lesson)
                  final nestedLessons = item['lessons'] as List?;
                  final hasVideo = item['video'] != null;
                  final hasYoutubeId = item['youtube_id'] != null ||
                      item['youtubeVideoId'] != null;

                  // It's a topic if:
                  // 1. It has a 'lessons' field (even if empty), OR
                  // 2. It doesn't have video/youtube_id (meaning it's a container, not a lesson)
                  final isTopic =
                      nestedLessons != null || (!hasVideo && !hasYoutubeId);

                  if (isTopic) {
                    topicCount++;
                    final lessonsCount = nestedLessons?.length ?? 0;
                    print('📁 TOPIC $topicCount:');
                    print('  - ID: ${item['id']}');
                    print('  - Title: ${item['title']}');
                    print('  - Order: ${item['order']}');
                    print('  - Type: ${item['type']}');
                    print('  - Lessons Count: $lessonsCount');
                    print('  - Duration Minutes: ${item['duration_minutes']}');
                    print('  - Has Lessons Field: ${nestedLessons != null}');
                    print('  - All Topic Keys: ${item.keys.toList()}');

                    // If it has lessons, show them
                    if (nestedLessons != null && nestedLessons.isNotEmpty) {
                      print('  - Lessons:');
                      for (int j = 0; j < nestedLessons.length; j++) {
                        final lesson = nestedLessons[j];
                        if (lesson is Map) {
                          print(
                              '      Lesson ${j + 1}: ${lesson['title'] ?? lesson['id']}');
                        }
                      }
                    } else if (nestedLessons != null && nestedLessons.isEmpty) {
                      print('  - ⚠️ This topic has an empty lessons array');
                    } else {
                      print('  - ⚠️ This topic does not have a lessons field');
                    }
                    print('');
                  }
                }
              }
              print(
                  '═══════════════════════════════════════════════════════════');
              print('Total Topics Found: $topicCount');
              print('Total Curriculum Items: ${curriculum.length}');
              print(
                  '═══════════════════════════════════════════════════════════');
              print('');

              // Then show all items in detail
              print('📋 ALL CURRICULUM ITEMS (DETAILED):');
              for (int i = 0; i < curriculum.length; i++) {
                final item = curriculum[i];
                if (item is Map) {
                  print(
                      '───────────────────────────────────────────────────────────');
                  print('  Item ${i + 1}:');
                  print('    - id: ${item['id']}');
                  print('    - title: ${item['title']}');
                  print('    - order: ${item['order']}');
                  print('    - type: ${item['type']}');
                  print('    - video: ${item['video']}');
                  print('    - youtube_id: ${item['youtube_id']}');
                  print('    - youtubeVideoId: ${item['youtubeVideoId']}');
                  print('    - duration_minutes: ${item['duration_minutes']}');
                  print('    - is_locked: ${item['is_locked']}');
                  print('    - is_completed: ${item['is_completed']}');
                  if (item['lessons'] != null) {
                    final lessonsList = item['lessons'] as List?;
                    print('    - has lessons: ${lessonsList?.length ?? 0}');
                    if (lessonsList != null && lessonsList.isNotEmpty) {
                      print('    - Lessons in this topic:');
                      for (int j = 0; j < lessonsList.length; j++) {
                        final lesson = lessonsList[j];
                        if (lesson is Map) {
                          print('      Lesson ${j + 1}:');
                          print('        - id: ${lesson['id']}');
                          print('        - title: ${lesson['title']}');
                          print('        - type: ${lesson['type']}');
                        }
                      }
                    }
                  }
                  print('    - All Keys: ${item.keys.toList()}');

                  // Print full JSON for topics
                  final nestedLessons = item['lessons'] as List?;
                  if (nestedLessons != null && nestedLessons.isNotEmpty) {
                    try {
                      const encoder = JsonEncoder.withIndent('    ');
                      print('    - Full Topic JSON:');
                      print(encoder.convert(item));
                    } catch (e) {
                      print('    - Could not convert topic to JSON: $e');
                    }
                  }
                }
              }
            } else {
              print('  Curriculum is empty or null');
            }
            print(
                '───────────────────────────────────────────────────────────');
            print('📖 LESSONS DETAILS:');
            final lessons = courseDetails['lessons'] as List?;
            if (lessons != null && lessons.isNotEmpty) {
              print('  Total Lessons: ${lessons.length}');
              for (int i = 0; i < lessons.length && i < 3; i++) {
                final lesson = lessons[i];
                if (lesson is Map) {
                  print('  Lesson $i:');
                  print('    - id: ${lesson['id']}');
                  print('    - title: ${lesson['title']}');
                  print('    - video: ${lesson['video']}');
                  print('    - All Keys: ${lesson.keys.toList()}');
                }
              }
            } else {
              print('  Lessons is empty or null');
            }
            print(
                '═══════════════════════════════════════════════════════════');
          }

          setState(() {
            _courseData = courseDetails;
            _isEnrolled = courseDetails['is_enrolled'] == true;
            _isLoading = false;
          });
          _loadResumeLessonState(courseDetails);
          _loadCourseAssignments();
          _loadCourseExams();
          _loadCourseLiveSessions(courseDetails);
          _checkIfViewingOwnCourse(courseDetails);
          if (_isEnrolled) _loadCourseCertificate(courseDetails);
        } catch (e) {
          if (kDebugMode) {
            print(
                '═══════════════════════════════════════════════════════════');
            print('❌ ERROR LOADING COURSE DETAILS');
            print(
                '═══════════════════════════════════════════════════════════');
            print('Course ID: $courseId');
            print('Error: $e');
            print('Error Type: ${e.runtimeType}');
            print(
                '═══════════════════════════════════════════════════════════');
          }
          setState(() {
            _courseData = widget.course; // Fallback to provided course
            _isLoading = false;
          });
          _loadResumeLessonState(widget.course);
          _loadCourseAssignments();
          _loadCourseLiveSessions(widget.course);
          _checkIfViewingOwnCourse(widget.course);
        }
      } else {
        setState(() {
          _courseData = widget.course;
        });
        _loadResumeLessonState(widget.course);
        _loadCourseAssignments();
        _loadCourseLiveSessions(widget.course);
        _checkIfViewingOwnCourse(widget.course);
      }
    } else {
      setState(() {
        _courseData = widget.course;
      });
      _loadResumeLessonState(widget.course);
      _loadCourseAssignments();
      _loadCourseLiveSessions(widget.course);
      _checkIfViewingOwnCourse(widget.course);
    }
  }

  Future<void> _checkIfViewingOwnCourse(Map<String, dynamic>? course) async {
    if (course == null) return;
    if (!await TokenStorageService.instance.isLoggedIn()) return;
    final instructorId = course['instructor_id']?.toString() ??
        course['instructorId']?.toString() ??
        (course['instructor'] is Map
            ? (course['instructor'] as Map)['id']?.toString()
            : null);
    if (instructorId == null || instructorId.isEmpty) return;
    try {
      final profile = await ProfileService.instance.getProfile();
      final myId = profile['id']?.toString();
      if (myId != null && myId == instructorId && mounted) {
        setState(() => _isViewingOwnCourse = true);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _getFirstLesson() {
    return selectFirstLessonForPlayback(_courseData ?? widget.course);
  }

  List<Map<String, dynamic>> _collectCourseLessons(
      Map<String, dynamic>? course) {
    if (course == null) return const [];
    final collected = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    void addLesson(Map<String, dynamic> lesson) {
      final type = lesson['type']?.toString().toLowerCase();
      if (type == 'assignment' || type == 'homework' || type == 'task') return;
      final id = lesson['id']?.toString();
      if (id == null || id.isEmpty || seenIds.contains(id)) return;
      seenIds.add(id);
      collected.add(lesson);
    }

    void scanItems(List<dynamic> items) {
      for (final raw in items) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        if (_isDirectLessonItem(item)) addLesson(item);

        final nestedLessons = item['lessons'];
        if (nestedLessons is List) scanItems(nestedLessons);
        final subModules = item['sub_modules'];
        if (subModules is List) scanItems(subModules);
        final subSections = item['subsections'];
        if (subSections is List) scanItems(subSections);
      }
    }

    final curriculum = course['curriculum'];
    if (curriculum is List && curriculum.isNotEmpty) scanItems(curriculum);
    final lessons = course['lessons'];
    if (lessons is List && lessons.isNotEmpty) scanItems(lessons);
    return collected;
  }

  Future<void> _loadResumeLessonState(Map<String, dynamic>? course) async {
    final courseId = course?['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    final saved =
        await LessonResumeService.instance.getLastOpenedLesson(courseId);
    final savedLessonId = saved?['lessonId']?.toString();
    if (savedLessonId == null || savedLessonId.isEmpty || !mounted) return;

    final lessons = _collectCourseLessons(course);
    final resumeIndex =
        lessons.indexWhere((item) => item['id']?.toString() == savedLessonId);
    if (resumeIndex < 0) return;

    setState(() {
      _resumeLessonId = savedLessonId;
      _savedResumeData = saved;
      _selectedLessonIndex = resumeIndex;
    });
  }

  Future<void> _loadCourseCertificate(Map<String, dynamic>? course) async {
    final courseId = course?['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;
    final cert =
        await CertificatesService.instance.getCertificateForCourse(courseId);
    if (!mounted) return;
    setState(() => _courseCertificate = cert);
  }

  Map<String, dynamic>? _getResumeLesson() {
    final resumeId = _resumeLessonId;
    if (resumeId == null || resumeId.isEmpty) return null;
    final lessons = _collectCourseLessons(_courseData ?? widget.course);
    for (final lesson in lessons) {
      if (lesson['id']?.toString() == resumeId) return lesson;
    }
    return null;
  }

  Future<void> _openLesson(Map<String, dynamic> lesson,
      {int? indexHint}) async {
    final course = _courseData ?? widget.course;
    final courseId = course?['id']?.toString();
    final lessonId = lesson['id']?.toString();
    final lessonTitle = lesson['title']?.toString();

    if (courseId != null &&
        courseId.isNotEmpty &&
        lessonId != null &&
        lessonId.isNotEmpty) {
      await LessonResumeService.instance.saveLastOpenedLesson(
        courseId: courseId,
        lessonId: lessonId,
        lessonTitle: lessonTitle,
      );
      if (mounted) {
        setState(() {
          _resumeLessonId = lessonId;
        });
      }
    }

    if (!mounted) return;
    if (indexHint != null && indexHint >= 0) {
      setState(() {
        _selectedLessonIndex = indexHint;
      });
    }

    final allLessons =
        _collectCourseLessons(_courseData ?? widget.course);
    final resolvedIndex = indexHint ??
        allLessons.indexWhere((l) => l['id']?.toString() == lessonId);

    await context.push(RouteNames.lessonViewer, extra: {
      'lesson': lesson,
      'courseId': courseId,
      'allLessons': allLessons,
      'lessonIndex': resolvedIndex,
    });

    if (!mounted) return;
    await _loadResumeLessonState(_courseData ?? widget.course);
    if (_isEnrolled) {
      await _loadCourseCertificate(_courseData ?? widget.course);
    }
  }

  void _playLesson(int index, Map<String, dynamic> lesson) async {
    if (kDebugMode) {
      print('═══════════════════════════════════════════════════════════');
      print('▶️ NAVIGATING TO LESSON');
      print('═══════════════════════════════════════════════════════════');
      print('Lesson Index: $index');
      print('Lesson ID: ${lesson['id']}');
      print('Lesson Title: ${lesson['title']}');
      print('All Lesson Keys: ${lesson.keys.toList()}');
      print('═══════════════════════════════════════════════════════════');
    }

    await _openLesson(lesson, indexHint: index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final course = _courseData ?? widget.course;

    if (_isLoading && _courseData == null) {
      return Scaffold(
        backgroundColor: AppColors.beige,
        body: _buildSkeleton(),
      );
    }

    if (course == null) {
      return Scaffold(
        backgroundColor: AppColors.beige,
        appBar: AppBar(
          title: Text(l10n.courseDetails),
        ),
        body: Center(
          child: Text(
            l10n.noCourseData,
            style: GoogleFonts.cairo(),
          ),
        ),
      );
    }

    // API may send `is_free=true` incorrectly for some paid courses.
    final priceValue = tryParseCourseNum(course['price']) ?? 0.0;
    final finalIsFree = courseIsEffectivelyFree(course);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.beige,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Video Player Section
              _buildVideoSection(),

              // Content Section - Scrollable
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    // Course Info Header
                    _buildCourseHeader(course, finalIsFree, priceValue),

                    // Resume Banner
                    if (_isEnrolled && _resumeLessonId != null)
                      _buildResumeBanner(course),

                    // Certificate Banner
                    if (_courseCertificate != null)
                      _buildCertificateBanner(),

                    // Tabs
                    _buildTabs(),

                    // Tab Content
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildLessonsTab(),
                          _buildAssignmentsTab(),
                          _buildAboutTab(course),
                          _buildExamsTab(),
                          _buildLiveSessionsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom Action Button
      bottomNavigationBar: _buildBottomBar(course, finalIsFree),
    );
  }

  Widget _buildVideoSection() {
    final course = _courseData ?? widget.course;
    // Get thumbnail image
    final thumbnail = course?['thumbnail']?.toString() ??
        course?['image']?.toString() ??
        course?['banner']?.toString();

    return Container(
      height: 220,
      color: Colors.black,
      child: Stack(
        children: [
          // Thumbnail Image
          if (thumbnail != null && thumbnail.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.purple.withOpacity(0.1),
                  child: const Center(
                    child: Icon(
                      Icons.image,
                      color: AppColors.purple,
                      size: 50,
                    ),
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.purple,
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              color: AppColors.purple.withOpacity(0.1),
              child: const Center(
                child: Icon(
                  Icons.image,
                  color: AppColors.purple,
                  size: 50,
                ),
              ),
            ),

          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),

          // Play Button Overlay (if enrolled)
          if (_isEnrolled)
            Positioned.fill(
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    final lessonToOpen =
                        _getResumeLesson() ?? _getFirstLesson();
                    if (lessonToOpen != null && mounted) {
                      final allLessons =
                          _collectCourseLessons(_courseData ?? widget.course);
                      final resumeIndex = allLessons.indexWhere((l) =>
                          l['id']?.toString() ==
                          lessonToOpen['id']?.toString());
                      _openLesson(lessonToOpen,
                          indexHint: resumeIndex >= 0 ? resumeIndex : null);
                    }
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.purple,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),

          // Top Bar
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.share_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseHeader(
      Map<String, dynamic>? course, bool isFree, num price) {
    final l10n = AppLocalizations.of(context)!;
    if (course == null) {
      return const SizedBox.shrink();
    }
    final hidePriceChip = courseHasPlansWithZeroBasePrice(course);
    final coursePriceText = _formatCoursePriceText(course);
    final currencyCode =
        course['currency']?.toString().toUpperCase() == 'USD' ? 'USD' : 'EGP';
    final backendOriginalPrice = _tryParseNum(course['original_price']);
    final backendDiscountPrice = _tryParseNum(course['discount_price']);
    final hasBackendDiscount = backendOriginalPrice != null &&
        backendDiscountPrice != null &&
        backendDiscountPrice > 0 &&
        backendOriginalPrice > backendDiscountPrice;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Badge & Price
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        course['category'] is Map
                            ? (course['category'] as Map)['name']?.toString() ??
                                l10n.design
                            : course['category']?.toString() ?? l10n.design,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.purple,
                        ),
                      ),
                    ),
                    if (course['is_popular'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          l10n.popular,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFEA580C),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (!hidePriceChip)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: isFree
                        ? const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                          ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isFree ? l10n.free : (coursePriceText ?? l10n.notSpecified),
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          if (!isFree && hasBackendDiscount) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _formatSingleCurrencyPrice(
                    currency: currencyCode,
                    amount: backendOriginalPrice,
                  ),
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatSingleCurrencyPrice(
                    currency: currencyCode,
                    amount: backendDiscountPrice,
                  ),
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFEA580C),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Title
          Text(
            course['title']?.toString() ?? l10n.courseTitle,
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 8),

          // Instructor
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.person, size: 16, color: AppColors.purple),
              ),
              const SizedBox(width: 8),
              Text(
                () {
                  final instructors = course['instructors'] as List?;
                  if (instructors != null && instructors.isNotEmpty) {
                    final first = instructors.first;
                    if (first is Map) {
                      final name = first['name']?.toString();
                      if (name != null && name.isNotEmpty) {
                        return name;
                      }
                    }
                  }

                  if (course['instructor'] is Map) {
                    return (course['instructor'] as Map)['name']?.toString() ??
                        l10n.instructor;
                  }
                  return course['instructor']?.toString() ?? l10n.instructor;
                }(),
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: AppColors.purple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stats Row
          Row(
            children: [
              _buildStatChip(
                Icons.star_rounded,
                _safeParseRating(course['rating']),
                Colors.amber,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                Icons.people_rounded,
                _safeParseCount(course['students_count'] ?? course['students']),
                AppColors.purple,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                Icons.access_time_rounded,
                '${_safeParseHours(course['duration_hours'] ?? course['hours'])}${AppLocalizations.of(context)!.hourShort}',
                const Color(0xFF10B981),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeBanner(Map<String, dynamic>? course) {
    final resumeLesson = _getResumeLesson();
    final lessonTitle = _savedResumeData?['lessonTitle']?.toString() ??
        resumeLesson?['title']?.toString() ??
        'الدرس السابق';

    // watchedSeconds → format as mm:ss or just minutes
    final watchedSec =
        (_savedResumeData?['watchedSeconds'] as num?)?.toInt() ?? 0;
    final positionMs =
        (_savedResumeData?['positionMs'] as num?)?.toInt() ?? 0;

    String progressLabel = '';
    if (positionMs > 0) {
      final totalSec = positionMs ~/ 1000;
      final mm = (totalSec ~/ 60).toString().padLeft(2, '0');
      final ss = (totalSec % 60).toString().padLeft(2, '0');
      progressLabel = 'توقفت عند $mm:$ss';
    } else if (watchedSec > 0) {
      if (watchedSec >= 60) {
        progressLabel = 'شاهدت ${(watchedSec / 60).toStringAsFixed(0)} دقيقة';
      } else {
        progressLabel = 'شاهدت $watchedSec ثانية';
      }
    }

    return GestureDetector(
      onTap: () {
        if (resumeLesson != null) {
          final allLessons = _collectCourseLessons(course);
          final idx = allLessons.indexWhere(
              (l) => l['id']?.toString() == resumeLesson['id']?.toString());
          _openLesson(resumeLesson, indexHint: idx >= 0 ? idx : null);
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.95),
              AppColors.primary.withOpacity(0.75),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'استكمل من حيث توقفت',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    lessonTitle,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.85),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (progressLabel.isNotEmpty)
                    Text(
                      progressLabel,
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'استكمال',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateBanner() {
    final cert = _courseCertificate!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final certNumber = cert['certificate_number']?.toString() ?? '';
    final issueDate = cert['issue_date']?.toString() ?? '';
    String dateLabel = '';
    if (issueDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(issueDate);
        dateLabel =
            '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    String resolveUrl(String? raw) {
      if (raw == null || raw.isEmpty) return '';
      if (raw.startsWith('http')) return raw;
      const host = 'https://drchampions-academy.anmka.com';
      return '$host$raw';
    }

    final previewUrl = resolveUrl(cert['preview_url']?.toString());
    final downloadUrl = resolveUrl(cert['download_url']?.toString());

    Future<void> openUrl(String url) async {
      if (url.isEmpty) return;
      final uri = Uri.parse(url);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'شهادة الإتمام' : 'Certificate of Completion',
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (certNumber.isNotEmpty)
                      Text(
                        certNumber,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    if (dateLabel.isNotEmpty)
                      Text(
                        isAr ? 'صدرت: $dateLabel' : 'Issued: $dateLabel',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (previewUrl.isNotEmpty)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => openUrl(previewUrl),
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: Text(
                      isAr ? 'معاينة' : 'Preview',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFD97706),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              if (previewUrl.isNotEmpty && downloadUrl.isNotEmpty)
                const SizedBox(width: 10),
              if (downloadUrl.isNotEmpty)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => openUrl(downloadUrl),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(
                      isAr ? 'تحميل' : 'Download',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0C52B3), Color(0xFF093F8A)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.mutedForeground,
        labelStyle:
            GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.cairo(fontSize: 13),
        padding: const EdgeInsets.all(4),
        tabs: [
          Tab(text: l10n.lessons),
          Tab(
            text: Localizations.localeOf(context).languageCode == 'ar'
                ? 'الواجبات'
                : 'Assignments',
          ),
          Tab(text: l10n.about),
          Tab(text: l10n.exams),
          Tab(text: l10n.live),
        ],
      ),
    );
  }

  Future<void> _loadCourseLiveSessions(Map<String, dynamic>? course) async {
    final currentCourseId = _resolveCourseIdFromMap(course);
    if (currentCourseId == null || currentCourseId.isEmpty) {
      setState(() {
        _courseLiveNowSessions = [];
        _courseLiveUpcomingSessions = [];
        _courseLivePastSessions = [];
        _isLoadingLiveSessions = false;
      });
      return;
    }

    setState(() => _isLoadingLiveSessions = true);
    try {
      Map<String, dynamic> response = await LiveCoursesService.instance.getLiveCourses(
        courseId: currentCourseId,
      );
      if (kDebugMode) {
        final liveNowCount = (response['live_now'] is List)
            ? (response['live_now'] as List).length
            : 0;
        final upcomingCount = (response['upcoming'] is List)
            ? (response['upcoming'] as List).length
            : 0;
        final pastCount =
            (response['past'] is List) ? (response['past'] as List).length : 0;
        print('📡 LIVE SESSIONS (FILTERED API)');
        print('  courseId: $currentCourseId');
        print('  groups => live_now: $liveNowCount, upcoming: $upcomingCount, past: $pastCount');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print('  response:');
          print(encoder.convert(response));
        } catch (_) {
          print('  response(raw): $response');
        }
      }

      List<Map<String, dynamic>> parseGroup(dynamic rawList, String fallbackStatus) {
        if (rawList is! List) return const [];
        final parsed = <Map<String, dynamic>>[];
        for (final item in rawList) {
          if (item is! Map) continue;
          final session = item.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          final meta = parseCourseLiveMeta(session['description']?.toString());
          // Trust the backend group bucket first (live_now/upcoming/past),
          // because item-level status can still be "scheduled" in live_now.
          session['api_status'] = session['status']?.toString();
          session['status'] = fallbackStatus;
          session['plain_description'] = meta.plainDescription;
          session['parsed_course_title'] = meta.courseTitle;
          parsed.add(session);
        }
        return parsed;
      }

      List<Map<String, dynamic>> keepOnlyCurrentCourse(List<Map<String, dynamic>> sessions) {
        final normalizedCurrentCourseId = currentCourseId.trim().toLowerCase();
        return sessions.where((session) {
        final directCourseId = session['course_id']?.toString() ??
            session['courseId']?.toString() ??
            session['course']?['id']?.toString();
          final metaCourseId =
              parseCourseLiveMeta(session['description']?.toString()).courseId;
        final candidateId =
              (directCourseId ?? metaCourseId ?? '').trim().toLowerCase();
          return candidateId.isEmpty || candidateId == normalizedCurrentCourseId;
        }).toList();
      }

      List<Map<String, dynamic>> sortByDate(List<Map<String, dynamic>> sessions) {
        final sorted = List<Map<String, dynamic>>.from(sessions);
        sorted.sort((a, b) {
          final da = DateTime.tryParse(
                  a['start_date']?.toString() ??
                      a['scheduled_at']?.toString() ??
                      a['start_time']?.toString() ??
                      '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final db = DateTime.tryParse(
                  b['start_date']?.toString() ??
                      b['scheduled_at']?.toString() ??
                      b['start_time']?.toString() ??
                      '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
        return sorted;
      }

      final liveNow = keepOnlyCurrentCourse(parseGroup(response['live_now'], 'live'));
      final upcoming =
          keepOnlyCurrentCourse(parseGroup(response['upcoming'], 'upcoming'));
      final past = keepOnlyCurrentCourse(parseGroup(response['past'], 'past'));

      // Backend fallback:
      // If courseId-filtered API returns empty, retry full list and filter locally.
      final isEmptyFromFilteredApi =
          liveNow.isEmpty && upcoming.isEmpty && past.isEmpty;
      if (isEmptyFromFilteredApi) {
        response = await LiveCoursesService.instance.getLiveCourses();
        if (kDebugMode) {
          final liveNowCount = (response['live_now'] is List)
              ? (response['live_now'] as List).length
              : 0;
          final upcomingCount = (response['upcoming'] is List)
              ? (response['upcoming'] as List).length
              : 0;
          final pastCount =
              (response['past'] is List) ? (response['past'] as List).length : 0;
          print('📡 LIVE SESSIONS (FALLBACK API - UNFILTERED)');
          print('  courseId: $currentCourseId');
          print(
              '  groups => live_now: $liveNowCount, upcoming: $upcomingCount, past: $pastCount');
          try {
            const encoder = JsonEncoder.withIndent('  ');
            print('  response:');
            print(encoder.convert(response));
          } catch (_) {
            print('  response(raw): $response');
          }
        }
      }

      final finalLiveNow = isEmptyFromFilteredApi
          ? keepOnlyCurrentCourse(parseGroup(response['live_now'], 'live'))
          : liveNow;
      final finalUpcoming = isEmptyFromFilteredApi
          ? keepOnlyCurrentCourse(parseGroup(response['upcoming'], 'upcoming'))
          : upcoming;
      final finalPast = isEmptyFromFilteredApi
          ? keepOnlyCurrentCourse(parseGroup(response['past'], 'past'))
          : past;

      setState(() {
        _courseLiveNowSessions = sortByDate(finalLiveNow);
        _courseLiveUpcomingSessions = sortByDate(finalUpcoming);
        _courseLivePastSessions = sortByDate(finalPast);
        _isLoadingLiveSessions = false;
      });
      if (kDebugMode) {
        print('✅ LIVE SESSIONS (FINAL AFTER LOCAL FILTER)');
        print('  courseId: $currentCourseId');
        print(
            '  final => live_now: ${_courseLiveNowSessions.length}, upcoming: ${_courseLiveUpcomingSessions.length}, past: ${_courseLivePastSessions.length}');
      }
    } catch (_) {
      setState(() {
        _courseLiveNowSessions = [];
        _courseLiveUpcomingSessions = [];
        _courseLivePastSessions = [];
        _isLoadingLiveSessions = false;
      });
    }
  }

  Widget _buildLiveSessionsTab() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoadingLiveSessions) {
      return const Center(child: CircularProgressIndicator());
    }
    final totalCount = _courseLiveNowSessions.length +
        _courseLiveUpcomingSessions.length +
        _courseLivePastSessions.length;
    if (totalCount == 0) {
      return _buildEmptyState(l10n.noLiveSessions, Icons.videocam_off_rounded);
    }

    final items = <Map<String, dynamic>>[];
    void addGroup(String title, List<Map<String, dynamic>> sessions) {
      if (sessions.isEmpty) return;
      items.add({'__header': true, 'title': title});
      items.addAll(sessions);
    }

    addGroup(l10n.liveNow, _courseLiveNowSessions);
    addGroup(l10n.upcoming, _courseLiveUpcomingSessions);
    addGroup(
      Localizations.localeOf(context).languageCode == 'ar' ? 'سابقة' : 'Past',
      _courseLivePastSessions,
    );

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final row = items[index];
        if (row['__header'] == true) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              row['title']?.toString() ?? '',
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          );
        }
        return _CourseSessionCard(session: row, formatDate: _formatDate);
      },
    );
  }

  String _formatDate(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    return DateFormat('d MMM y, h:mm a', localeTag).format(dt);
  }

  Widget _buildAssignmentsTab() {
    if (_courseAssignments.isEmpty) {
      return _buildEmptyState(
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'لا توجد واجبات حاليا'
            : 'No assignments yet',
        Icons.assignment_rounded,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: _courseAssignments.length,
      itemBuilder: (context, index) {
        return _buildAssignmentItem(_courseAssignments[index]);
      },
    );
  }

  String _safeParseRating(dynamic rating) {
    if (rating == null) return '0.0';
    if (rating is num) return rating.toStringAsFixed(1);
    if (rating is String) {
      final parsed = num.tryParse(rating);
      return parsed?.toStringAsFixed(1) ?? '0.0';
    }
    return '0.0';
  }

  String _safeParseCount(dynamic count) {
    if (count == null) return '0';
    if (count is int) return count.toString();
    if (count is num) return count.toInt().toString();
    if (count is String) {
      final parsed = int.tryParse(count);
      return parsed?.toString() ?? '0';
    }
    return '0';
  }

  int _safeParseHours(dynamic hours) {
    if (hours == null) return 0;
    if (hours is int) return hours;
    if (hours is num) return hours.toInt();
    if (hours is String) {
      final parsed = int.tryParse(hours);
      return parsed ?? 0;
    }
    return 0;
  }

  num? _tryParseNum(dynamic value) => tryParseCourseNum(value);

  String _formatNumber(num value) {
    // Keep formatting stable across locales to avoid unexpected separators.
    return NumberFormat.decimalPattern('en_US').format(value);
  }

  String _formatDualCurrencyFromValues({
    num? egp,
    num? usd,
  }) {
    final parts = <String>[];
    if (egp != null && egp != 0) parts.add('${_formatNumber(egp)} EGP');
    if (usd != null && usd != 0) parts.add('\$${_formatNumber(usd)} USD');
    return parts.join(' / ');
  }

  String _formatSingleCurrencyPrice({
    required String currency,
    required num amount,
  }) {
    final c = currency.toUpperCase();
    if (c == 'USD') return '\$${_formatNumber(amount)} USD';
    return '${_formatNumber(amount)} EGP';
  }

  String? _formatCoursePriceText(Map<String, dynamic> course) {
    // Prefer dual-currency when available (EGP + USD); per-currency discount only.
    final dualText = _formatDualCurrencyFromValues(
      egp: effectiveCoursePriceEgp(course),
      usd: effectiveCoursePriceUsd(course),
    );
    if (dualText.isNotEmpty) return dualText;

    // Spec111: single currency
    final currency = course['currency']?.toString().toUpperCase();
    final price = _tryParseNum(course['price']);
    final discount = _tryParseNum(course['discount_price']);

    if (currency == 'EGP' || currency == 'USD') {
      final finalAmount =
          (discount != null && discount > 0) ? discount : (price ?? 0);
      if (finalAmount > 0) {
        return _formatSingleCurrencyPrice(
          currency: currency!,
          amount: finalAmount,
        );
      }
    }

    // Legacy: price assumed EGP
    if (price != null && price != 0) {
      return _formatSingleCurrencyPrice(currency: 'EGP', amount: price);
    }
    return null;
  }

  String _formatPlanDuration(dynamic durationValue, dynamic durationUnit) {
    final value = _tryParseNum(durationValue)?.toInt() ?? 0;
    final unit = durationUnit?.toString().toLowerCase();
    if (value <= 0 || unit == null || unit.isEmpty) return '-';
    final l10n = AppLocalizations.of(context)!;
    switch (unit) {
      case 'day':
      case 'days':
        return l10n.planDurationDays(value);
      case 'month':
      case 'months':
        return l10n.planDurationMonths(value);
      case 'year':
      case 'years':
        return l10n.planDurationYears(value);
      default:
        return '$value $unit';
    }
  }

  /// API: `offer_ends_at` ISO date (e.g. `2026-04-06`) or null.
  String? _formatPlanOfferEndLabel(BuildContext context, dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final dt = DateTime.tryParse(s);
    if (dt == null) return null;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final formatted = DateFormat.yMMMd(localeTag).format(dt);
    return AppLocalizations.of(context)!.planOfferEndsAt(formatted);
  }

  bool _examCanStartFromData(Map<String, dynamic> exam) {
    final backendCanStart = exam['can_start'];
    if (backendCanStart is bool && backendCanStart == false) return false;

    final attemptsRemainingRaw = exam['attempts_remaining'];
    final attemptsRemaining = attemptsRemainingRaw is int
        ? attemptsRemainingRaw
        : (attemptsRemainingRaw is num
            ? attemptsRemainingRaw.toInt()
            : int.tryParse(attemptsRemainingRaw?.toString() ?? ''));
    if (attemptsRemaining != null) return attemptsRemaining > 0;

    final maxAttemptsRaw = exam['max_attempts'];
    final maxAttempts = maxAttemptsRaw is int
        ? maxAttemptsRaw
        : (maxAttemptsRaw is num
            ? maxAttemptsRaw.toInt()
            : int.tryParse(maxAttemptsRaw?.toString() ?? ''));
    final attemptsUsedRaw = exam['attempts_used'];
    final attemptsUsed = attemptsUsedRaw is int
        ? attemptsUsedRaw
        : (attemptsUsedRaw is num
            ? attemptsUsedRaw.toInt()
            : int.tryParse(attemptsUsedRaw?.toString() ?? '')) ??
            0;
    if (maxAttempts != null && maxAttempts > 0) {
      return attemptsUsed < maxAttempts;
    }

    return backendCanStart == true || backendCanStart == null;
  }

  IconData _lessonTypeIcon(Map<String, dynamic> lesson) {
    final type = lesson['type']?.toString().toLowerCase();
    switch (type) {
      case 'video':
        return Icons.play_circle_fill_rounded;
      case 'file':
        return Icons.insert_drive_file_rounded;
      case 'exam':
        return Icons.quiz_rounded;
      case 'text':
        return Icons.article_rounded;
      default:
        return Icons.play_lesson_rounded;
    }
  }

  Widget _buildLessonsTab() {
    final course = _courseData ?? widget.course;
    final curriculum = course?['curriculum'] as List?;
    final lessons = course?['lessons'] as List?;
    final List<Map<String, dynamic>> flatLessonsList = [];
    final List<Map<String, dynamic>> modulesList = [];

    void addLesson({
      required Map<String, dynamic> lesson,
      required int indent,
      String? moduleKey,
      String? subModuleKey,
    }) {
      final lessonType = lesson['type']?.toString().toLowerCase();
      if (lessonType == 'assignment' ||
          lessonType == 'homework' ||
          lessonType == 'task') {
        return;
      }
      flatLessonsList.add(lesson);
      modulesList.add({
        'type': 'lesson',
        'data': lesson,
        'indent': indent,
        'module_key': moduleKey,
        'sub_module_key': subModuleKey,
      });
    }

    if (curriculum != null && curriculum.isNotEmpty) {
      final bool looksLikeSectionSubsection = curriculum.any((item) {
        return item is Map<String, dynamic> && item.containsKey('subsections');
      });

      if (looksLikeSectionSubsection) {
        // New structure: Sections -> Subsections -> Lessons (+ direct lessons in section)
        final sections = curriculum.whereType<Map<String, dynamic>>().toList();
        sections.sort((a, b) {
          final ao = _tryParseNum(a['order'])?.toInt() ?? 0;
          final bo = _tryParseNum(b['order'])?.toInt() ?? 0;
          return ao.compareTo(bo);
        });

        for (int i = 0; i < sections.length; i++) {
          final section = sections[i];
          final sectionKey = (section['id'] ?? 'section_$i').toString();
          _expandedModules.putIfAbsent(sectionKey, () => i == 0);

          modulesList.add({
            'type': 'module',
            'data': section,
            'indent': 0,
            'module_key': sectionKey,
          });

          final subsectionsRaw = section['subsections'] as List?;
          final sectionLessonsRaw = section['lessons'] as List?;

          final subsections =
              subsectionsRaw?.whereType<Map<String, dynamic>>().toList() ?? [];
          subsections.sort((a, b) {
            final ao = _tryParseNum(a['order'])?.toInt() ?? 0;
            final bo = _tryParseNum(b['order'])?.toInt() ?? 0;
            return ao.compareTo(bo);
          });

          // Render subsections first (per spec) + their lessons
          for (int s = 0; s < subsections.length; s++) {
            final subsection = subsections[s];
            final subModuleKey =
                (subsection['id'] ?? '${sectionKey}_sub_$s').toString();
            _expandedSubModules.putIfAbsent(subModuleKey, () => false);
            modulesList.add({
              'type': 'sub_module',
              'data': subsection,
              'indent': 1,
              'module_key': sectionKey,
              'sub_module_key': subModuleKey,
            });

            final subLessons = subsection['lessons'] as List?;
            if (subLessons != null) {
              for (final lesson in subLessons) {
                if (lesson is Map<String, dynamic>) {
                  addLesson(
                    lesson: lesson,
                    indent: 2,
                    moduleKey: sectionKey,
                    subModuleKey: subModuleKey,
                  );
                }
              }
            }
          }

          // Then render direct lessons inside section
          if (sectionLessonsRaw != null) {
            for (final lesson in sectionLessonsRaw) {
              if (lesson is Map<String, dynamic>) {
                addLesson(lesson: lesson, indent: 1, moduleKey: sectionKey);
              }
            }
          }
        }
      } else {
        final hasTypeField = curriculum.any((item) {
          return item is Map<String, dynamic> && item['type'] != null;
        });

        if (hasTypeField) {
          for (int i = 0; i < curriculum.length; i++) {
            final item = curriculum[i];
            if (item is! Map<String, dynamic>) continue;

            final itemType = item['type']?.toString();
            final subModules = item['sub_modules'] as List?;
            final moduleLessons = item['lessons'] as List?;
            final isModule = itemType == 'module' || subModules != null;
            if (!isModule) {
              final hasVideo = item['video'] != null;
              final hasYoutubeId =
                  item['youtube_id'] != null || item['youtubeVideoId'] != null;
              if (itemType == 'lesson' ||
                  hasVideo ||
                  item['id'] != null ||
                  hasYoutubeId) {
                addLesson(lesson: item, indent: 0);
              }
              continue;
            }

            final moduleKey = (item['id'] ?? 'module_$i').toString();
            _expandedModules.putIfAbsent(moduleKey, () => i == 0);

            modulesList.add({
              'type': 'module',
              'data': item,
              'indent': 0,
              'module_key': moduleKey,
            });

            final hasSubModules = subModules != null && subModules.isNotEmpty;

            if (moduleLessons != null) {
              for (final lesson in moduleLessons) {
                if (lesson is Map<String, dynamic>) {
                  addLesson(
                    lesson: lesson,
                    indent: hasSubModules ? 2 : 1,
                    moduleKey: moduleKey,
                  );
                }
              }
            }

            if (subModules != null) {
              for (int subIndex = 0; subIndex < subModules.length; subIndex++) {
                final subModuleRaw = subModules[subIndex];
                if (subModuleRaw is! Map<String, dynamic>) continue;
                final subModuleKey =
                    (subModuleRaw['id'] ?? '${moduleKey}_sub_$subIndex')
                        .toString();
                _expandedSubModules.putIfAbsent(subModuleKey, () => false);

                modulesList.add({
                  'type': 'sub_module',
                  'data': subModuleRaw,
                  'indent': 1,
                  'module_key': moduleKey,
                  'sub_module_key': subModuleKey,
                });

                final subModuleLessons = subModuleRaw['lessons'] as List?;
                if (subModuleLessons == null) continue;
                for (final lesson in subModuleLessons) {
                  if (lesson is Map<String, dynamic>) {
                    addLesson(
                      lesson: lesson,
                      indent: 2,
                      moduleKey: moduleKey,
                      subModuleKey: subModuleKey,
                    );
                  }
                }
              }
            }
          }
        } else {
          // Backward compatibility: old topic -> lessons structure.
          for (int i = 0; i < curriculum.length; i++) {
            final item = curriculum[i];
            if (item is! Map<String, dynamic>) continue;

            final nestedLessons = item['lessons'] as List?;
            final hasVideo = item['video'] != null;
            final hasYoutubeId =
                item['youtube_id'] != null || item['youtubeVideoId'] != null;
            final isTopic =
                nestedLessons != null || (!hasVideo && !hasYoutubeId);

            if (isTopic) {
              final moduleKey = (item['id'] ?? 'module_$i').toString();
              _expandedModules.putIfAbsent(moduleKey, () => i == 0);
              modulesList.add({
                'type': 'module',
                'data': item,
                'indent': 0,
                'module_key': moduleKey,
              });

              if (nestedLessons != null) {
                for (final nestedLesson in nestedLessons) {
                  if (nestedLesson is Map<String, dynamic>) {
                    addLesson(
                      lesson: nestedLesson,
                      indent: 1,
                      moduleKey: moduleKey,
                    );
                  }
                }
              }
            } else if (hasVideo || item['id'] != null || hasYoutubeId) {
              addLesson(lesson: item, indent: 0);
            }
          }
        }
      }
    }

    if (modulesList.isEmpty && lessons != null && lessons.isNotEmpty) {
      for (final lesson in lessons) {
        if (lesson is Map<String, dynamic>) {
          addLesson(lesson: lesson, indent: 0);
        }
      }
    }

    if (modulesList.isEmpty) {
      return _buildEmptyState(
        AppLocalizations.of(context)!.noLessonsAvailable,
        Icons.play_lesson_rounded,
      );
    }

    final List<Map<String, dynamic>> visibleItems = [];
    for (final item in modulesList) {
      final type = item['type']?.toString();
      if (type == 'module') {
        visibleItems.add(item);
        continue;
      }

      final moduleKey = item['module_key']?.toString();
      if (moduleKey != null && !(_expandedModules[moduleKey] ?? false)) {
        continue;
      }
      if (type == 'lesson') {
        final subModuleKey = item['sub_module_key']?.toString();
        if (subModuleKey != null &&
            !(_expandedSubModules[subModuleKey] ?? false)) {
          continue;
        }
      }
      visibleItems.add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: visibleItems.length,
      itemBuilder: (context, index) {
        final item = visibleItems[index];
        final type = item['type']?.toString();
        final data = item['data'] as Map<String, dynamic>;
        final indent = (item['indent'] as int?) ?? 0;

        if (type == 'module') {
          final moduleKey = item['module_key']?.toString() ?? 'module_$index';
          final isExpanded = _expandedModules[moduleKey] ?? false;

          int lessonCount = 0;
          for (final nested in modulesList) {
            if (nested['module_key']?.toString() == moduleKey &&
                nested['type'] == 'lesson') {
              lessonCount++;
            }
          }

          return Padding(
            padding: EdgeInsets.only(left: indent * 16.0, bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedModules[moduleKey] = false;
                    } else {
                      for (final k in _expandedModules.keys.toList()) {
                        _expandedModules[k] = false;
                      }
                      _expandedModules[moduleKey] = true;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.lavenderLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          data['title']?.toString() ?? 'Module',
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                      Text(
                        '$lessonCount',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.mutedForeground,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (type == 'sub_module') {
          final moduleKey = item['module_key']?.toString();
          final subModuleKey =
              item['sub_module_key']?.toString() ?? 'sub_module_$index';
          final isExpanded = _expandedSubModules[subModuleKey] ?? false;
          int lessonCount = 0;
          for (final nested in modulesList) {
            if (nested['sub_module_key']?.toString() == subModuleKey &&
                nested['type'] == 'lesson') {
              lessonCount++;
            }
          }
          return Padding(
            padding: EdgeInsets.only(left: indent * 16.0, bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    final next = !(_expandedSubModules[subModuleKey] ?? false);
                    if (moduleKey != null && next) {
                      for (final entry in modulesList) {
                        if (entry['type'] == 'sub_module' &&
                            entry['module_key']?.toString() == moduleKey) {
                          final key = entry['sub_module_key']?.toString();
                          if (key != null) _expandedSubModules[key] = false;
                        }
                      }
                    }
                    _expandedSubModules[subModuleKey] = next;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          data['title']?.toString() ?? 'Sub module',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                      Text(
                        '$lessonCount',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.mutedForeground,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (type == 'lesson') {
          final lesson = data;
          final globalIndex = flatLessonsList.indexWhere(
              (l) => l['id']?.toString() == lesson['id']?.toString());
          final actualIndex = globalIndex >= 0 ? globalIndex : 0;

          final leftPadding = indent == 0 ? 0.0 : (indent == 1 ? 16.0 : 32.0);
          return Padding(
            padding: EdgeInsets.only(left: leftPadding),
            child: _buildLessonItem(lesson, actualIndex, flatLessonsList),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLessonItem(Map<String, dynamic> lesson, int index,
      List<Map<String, dynamic>> allLessons) {
    final isLocked = lesson['is_locked'] == true || lesson['locked'] == true;
    final isFreePreview = lesson['is_free_preview'] == true;
    final isActuallyLocked = isLocked && !isFreePreview;
    final isCompleted =
        lesson['is_completed'] == true || lesson['completed'] == true;
    final isSelected = index == _selectedLessonIndex;

    return GestureDetector(
      onTap: () {
        if (isActuallyLocked) {
          // Spec: locked lessons should open subscription/enrollment flow.
          _handlePaidCourseCheckout(_courseData ?? widget.course);
          return;
        }
        _playLesson(index, lesson);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.purple.withOpacity(0.08)
              : isActuallyLocked
                  ? Colors.grey[50]
                  : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.purple
                : isCompleted
                    ? const Color(0xFF10B981)
                    : Colors.grey.withOpacity(0.15),
            width: isSelected || isCompleted ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Index/Status Circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF0C52B3), Color(0xFF093F8A)],
                      )
                    : isCompleted
                        ? const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          )
                        : null,
                color: isActuallyLocked ? Colors.grey[200] : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: isActuallyLocked
                  ? Icon(Icons.lock_rounded, color: Colors.grey[400], size: 20)
                  : isCompleted
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20)
                      : isSelected
                          ? const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 22)
                          : Center(
                              child: Text(
                                '${index + 1}',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.purple,
                                ),
                              ),
                            ),
            ),
            const SizedBox(width: 14),

            // Lesson Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _lessonTypeIcon(lesson),
                        size: 16,
                        color: isActuallyLocked
                            ? Colors.grey[400]
                            : AppColors.purple,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lesson['title']?.toString() ??
                              AppLocalizations.of(context)!.lesson,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isActuallyLocked
                                ? Colors.grey[500]
                                : AppColors.foreground,
                          ),
                        ),
                      ),
                      if (isFreePreview) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.freePreview,
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(lesson),
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Play Icon
            if (!isActuallyLocked)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : AppColors.purple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSelected ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: AppColors.purple,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentItem(Map<String, dynamic> assignment) {
    final isLocked =
        assignment['is_locked'] == true || assignment['locked'] == true;
    final title = assignment['title']?.toString() ??
        (Localizations.localeOf(context).languageCode == 'ar'
            ? 'واجب'
            : 'Assignment');
    final description = assignment['description']?.toString() ?? '';

    return GestureDetector(
      onTap: isLocked
          ? () => _handlePaidCourseCheckout(_courseData ?? widget.course)
          : () => _openAssignmentDetails(assignment),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isLocked ? Colors.grey[50] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_rounded,
                color: AppColors.purple,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              isLocked ? Icons.lock_rounded : Icons.chevron_right_rounded,
              color: AppColors.mutedForeground,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAssignmentDetails(Map<String, dynamic> assignment) async {
    final course = _courseData ?? widget.course;
    final courseId = course?['id']?.toString();
    final assignmentId = assignment['id']?.toString();
    if (courseId == null ||
        courseId.isEmpty ||
        assignmentId == null ||
        assignmentId.isEmpty) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.purple),
      ),
    );

    try {
      final details = await CoursesService.instance
          .getCourseAssignmentDetails(courseId, assignmentId);
      if (!mounted) return;
      Navigator.of(context).pop();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: AppColors.beige,
            appBar: AppBar(
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
                  AppColors.purple,
              surfaceTintColor: Theme.of(context).appBarTheme.backgroundColor ??
                  AppColors.purple,
              elevation: 0,
              title: Text(
                Localizations.localeOf(context).languageCode == 'ar'
                    ? 'الواجب'
                    : 'Assignment',
                style: GoogleFonts.cairo(
                  color: Theme.of(context).appBarTheme.foregroundColor ??
                      Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconTheme: IconThemeData(
                color: Theme.of(context).appBarTheme.foregroundColor ??
                    Colors.white,
              ),
            ),
            body: AssignmentDetailSubmissionSheet(
              courseId: courseId,
              assignmentId: assignmentId,
              courseTitle: course?['title']?.toString(),
              details: details,
              listRow: assignment,
              onViewPdf: (url, t) {
                Future.microtask(() {
                  if (!mounted) return;
                  context.push(
                    RouteNames.pdfViewer,
                    extra: {'pdfUrl': url, 'title': t},
                  );
                });
              },
              onSubmitted: _loadCourseAssignments,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDuration(Map<String, dynamic> lesson) {
    final l10n = AppLocalizations.of(context)!;
    // Try duration_minutes first, then duration
    if (lesson['duration_minutes'] != null) {
      final minutes = lesson['duration_minutes'];
      if (minutes is int) {
        return '$minutes ${l10n.minutesUnit(minutes)}';
      } else if (minutes is num) {
        final count = minutes.toInt();
        return '$count ${l10n.minutesUnit(count)}';
      } else if (minutes is String) {
        final parsed = int.tryParse(minutes);
        if (parsed != null) return '$parsed ${l10n.minutesUnit(parsed)}';
      }
    }
    return lesson['duration']?.toString() ?? '10 ${l10n.minutesUnit(10)}';
  }

  Widget _buildAboutTab(Map<String, dynamic>? course) {
    final l10n = AppLocalizations.of(context)!;
    final courseData = _courseData ?? course;
    final description =
        courseData?['description']?.toString() ?? l10n.courseSuitable;

    // Get what_you_learn from API
    final whatYouLearn = courseData?['what_you_learn'] as List?;
    final features = <Map<String, dynamic>>[];

    if (whatYouLearn != null && whatYouLearn.isNotEmpty) {
      for (var item in whatYouLearn) {
        if (item is String) {
          features.add({'icon': Icons.check_circle_outline, 'text': item});
        } else if (item is Map) {
          features.add({
            'icon': Icons.check_circle_outline,
            'text': item['text']?.toString() ?? item.toString()
          });
        }
      }
    }

    // Add default features if empty
    if (features.isEmpty) {
      features.addAll([
        {'icon': Icons.check_circle_outline, 'text': l10n.certifiedCertificate},
        {'icon': Icons.access_time, 'text': l10n.lifetimeAccess},
        {'icon': Icons.phone_android, 'text': l10n.availableOnAllDevices},
        {'icon': Icons.download_rounded, 'text': l10n.downloadableFiles},
      ]);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.courseDescriptionTitle,
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              description,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: AppColors.mutedForeground,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.whatYouWillGet,
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        feature['icon'] as IconData,
                        size: 18,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      feature['text'] as String,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildExamsTab() {
    if (_isLoadingExams) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppColors.purple,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.loadingExam,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }

    if (_courseExams.isEmpty) {
      return _buildEmptyState(
        AppLocalizations.of(context)!.noExamsAvailable,
        Icons.quiz_rounded,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: _courseExams.length,
      itemBuilder: (context, index) {
        final exam = _courseExams[index];
        return _buildExamCard(exam, index);
      },
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam, int index) {
    final canStart = _examCanStartFromData(exam);
    final isPassed = exam['is_passed'] == true;
    final bestScoreRaw = exam['best_score'];
    final questionsCount = exam['questions_count'] ?? 0;
    final durationMinutes = (exam['duration_minutes'] is num)
        ? (exam['duration_minutes'] as num).toInt()
        : int.tryParse(exam['duration_minutes']?.toString() ?? '');
    final hasTimeLimit = (() {
      final explicit = [
        exam['has_time_limit'],
        exam['is_timed'],
        exam['timed'],
      ];
      for (final flag in explicit) {
        if (flag is bool) return flag;
        final normalized = flag?.toString().toLowerCase().trim();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
      return durationMinutes != null && durationMinutes > 0;
    })();
    final passingScore = exam['passing_score'] ?? 70;
    final maxAttempts = exam['max_attempts'];
    final attemptsUsed = exam['attempts_used'] ?? 0;
    final examId = exam['id']?.toString() ?? '';
    final examTitle =
        exam['title']?.toString() ?? AppLocalizations.of(context)!.exam;
    final examDescription = exam['description']?.toString() ?? '';
    final targetType = exam['target_type']?.toString().toLowerCase().trim() ??
        exam['targetType']?.toString().toLowerCase().trim() ??
        ((exam['lesson_id'] != null || exam['lessonId'] != null)
            ? 'lesson'
            : 'course');
    final lessonName =
        exam['lesson_name']?.toString() ?? exam['lessonName']?.toString() ?? '';
    final targetLabel = targetType == 'lesson'
        ? (Localizations.localeOf(context).languageCode == 'ar'
            ? 'امتحان الدرس'
            : 'Lesson exam')
        : (Localizations.localeOf(context).languageCode == 'ar'
            ? 'امتحان الدورة'
            : 'Course exam');
    final isStartingThisExam = _startingExamId == examId;
    final isEnabled = canStart && !isStartingThisExam;
    final hasCompletedExam =
        bestScoreRaw != null || attemptsUsed > 0 || isPassed == true;
    final bestScoreNum = bestScoreRaw is num
        ? bestScoreRaw.toDouble()
        : double.tryParse(bestScoreRaw?.toString() ?? '');
    final scorePercent = () {
      if (bestScoreNum == null) return null;
      final qCount = (questionsCount is num) ? questionsCount.toDouble() : 0.0;
      // If backend returns points (e.g. 7 out of 10), convert to percentage.
      if (qCount > 0 && bestScoreNum <= qCount) {
        return ((bestScoreNum / qCount) * 100).round();
      }
      // Otherwise treat it as already percentage.
      return bestScoreNum.round();
    }();
    final scoreText = scorePercent == null ? null : '$scorePercent%';

    // Determine if it's a trial exam
    final isTrial = exam['type'] == 'trial' ||
        exam['type'] == 'trial_exam' ||
        examTitle.contains('trial');

    return Container(
      margin: EdgeInsets.only(bottom: index < _courseExams.length - 1 ? 16 : 0),
      decoration: BoxDecoration(
        gradient: isTrial
            ? const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF0C52B3), Color(0xFF093F8A)],
              )
            : null,
        color: isTrial ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isTrial
            ? null
            : Border.all(
                color: AppColors.purple.withOpacity(0.2),
                width: 1,
              ),
        boxShadow: isTrial
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isTrial
                            ? Colors.white.withOpacity(0.2)
                            : AppColors.purple.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isTrial ? Icons.quiz_rounded : Icons.assignment_rounded,
                        size: 28,
                        color: isTrial ? Colors.white : AppColors.purple,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            examTitle,
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  isTrial ? Colors.white : AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isTrial
                                      ? Colors.white.withValues(alpha: 0.22)
                                      : AppColors.purple.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  targetLabel,
                                  style: GoogleFonts.cairo(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isTrial
                                        ? Colors.white
                                        : AppColors.purple,
                                  ),
                                ),
                              ),
                              if (lessonName.trim().isNotEmpty &&
                                  targetType == 'lesson')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isTrial
                                        ? Colors.white.withValues(alpha: 0.18)
                                        : Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    lessonName,
                                    style: GoogleFonts.cairo(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isTrial
                                          ? Colors.white
                                          : const Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (examDescription.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              examDescription,
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                color: isTrial
                                    ? Colors.white.withOpacity(0.8)
                                    : AppColors.mutedForeground,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Exam Info
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildExamInfoChip(
                      Icons.help_outline,
                      '$questionsCount ${AppLocalizations.of(context)!.question}',
                      isTrial
                          ? Colors.white.withOpacity(0.3)
                          : AppColors.purple.withOpacity(0.1),
                      isTrial ? Colors.white : AppColors.purple,
                    ),
                    _buildExamInfoChip(
                      hasTimeLimit
                          ? Icons.access_time
                          : Icons.all_inclusive_rounded,
                      hasTimeLimit
                          ? ((durationMinutes != null && durationMinutes > 0)
                              ? '$durationMinutes ${AppLocalizations.of(context)!.minutesUnit(durationMinutes)}'
                              : AppLocalizations.of(context)!.notSpecified)
                          : (Localizations.localeOf(context).languageCode == 'ar'
                              ? 'بدون وقت'
                              : 'No time limit'),
                      isTrial
                          ? Colors.white.withOpacity(0.3)
                          : AppColors.purple.withOpacity(0.1),
                      isTrial ? Colors.white : AppColors.purple,
                    ),
                    _buildExamInfoChip(
                      Icons.star,
                      AppLocalizations.of(context)!
                          .passingScoreToPass(passingScore),
                      isTrial
                          ? Colors.white.withOpacity(0.3)
                          : AppColors.purple.withOpacity(0.1),
                      isTrial ? Colors.white : AppColors.purple,
                    ),
                    if (maxAttempts != null)
                      _buildExamInfoChip(
                        Icons.repeat,
                        AppLocalizations.of(context)!.attemptsUsedOutOf(
                          attemptsUsed,
                          maxAttempts,
                        ),
                        isTrial
                            ? Colors.white.withOpacity(0.3)
                            : AppColors.purple.withOpacity(0.1),
                        isTrial ? Colors.white : AppColors.purple,
                      ),
                  ],
                ),
                if (scorePercent != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isPassed
                          ? Colors.green.withOpacity(isTrial ? 0.3 : 0.1)
                          : Colors.orange.withOpacity(isTrial ? 0.3 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPassed ? Icons.check_circle : Icons.info_outline,
                          size: 16,
                          color: isTrial
                              ? Colors.white
                              : (isPassed ? Colors.green : Colors.orange),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPassed
                              ? '${AppLocalizations.of(context)!.bestScore(scorePercent)} ✓'
                              : AppLocalizations.of(context)!
                                  .bestScore(scorePercent),
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isTrial
                                ? Colors.white
                                : (isPassed ? Colors.green : Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (hasCompletedExam) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isPassed
                          ? const Color(0xFF10B981).withValues(alpha: 0.16)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isPassed
                            ? const Color(0xFF10B981).withValues(alpha: 0.45)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.grade_rounded,
                          color: isPassed
                              ? const Color(0xFF047857)
                              : const Color(0xFFB45309),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          scoreText == null
                              ? (isPassed
                                  ? 'تم اجتياز الامتحان'
                                  : 'تم إنهاء الامتحان')
                              : 'درجتك: $scoreText',
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isPassed
                                ? const Color(0xFF047857)
                                : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Opacity(
                  opacity: isEnabled ? 1 : 0.75,
                  child: GestureDetector(
                    onTap: isEnabled ? () => _startExam(examId, exam) : null,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isEnabled
                            ? (isTrial ? Colors.white : AppColors.purple)
                            : (isTrial
                                ? Colors.white.withOpacity(0.5)
                                : Colors.grey[300]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          isStartingThisExam
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: isTrial
                                        ? AppColors.purple
                                        : Colors.white,
                                  ),
                                )
                              : Icon(
                                  isEnabled
                                      ? Icons.play_arrow_rounded
                                      : Icons.lock_rounded,
                                  color: isEnabled
                                      ? (isTrial
                                          ? AppColors.purple
                                          : Colors.white)
                                      : Colors.grey,
                                  size: 22,
                                ),
                          const SizedBox(width: 8),
                          Text(
                            isStartingThisExam
                                ? AppLocalizations.of(context)!.loadingExam
                                : canStart
                                    ? AppLocalizations.of(context)!
                                        .startExamButton
                                    : (maxAttempts != null &&
                                            attemptsUsed >= maxAttempts
                                        ? AppLocalizations.of(context)!
                                            .attemptsExhausted
                                        : AppLocalizations.of(context)!
                                            .notAvailable),
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isEnabled
                                  ? (isTrial ? AppColors.purple : Colors.white)
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamInfoChip(
    IconData icon,
    String text,
    Color bgColor, [
    Color? iconColor,
  ]) {
    final finalIconColor = iconColor ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: finalIconColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: finalIconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.purple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: AppColors.purple),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(Map<String, dynamic>? course, bool isFree) {
    if (_isViewingOwnCourse) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school_rounded, color: AppColors.purple, size: 22),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.youAreInstructorOfCourse,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.purple,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _isEnrolling
                    ? null
                    : () async {
                        final courseData = _courseData ?? course;

                        // If already enrolled, go to first lesson
                        if (_isEnrolled) {
                          final firstLesson = _getFirstLesson();
                          if (firstLesson != null && mounted) {
                            final course = _courseData ?? widget.course;
                            final courseId = course?['id']?.toString();
                            context.push(RouteNames.lessonViewer, extra: {
                              'lesson': firstLesson,
                              'courseId': courseId,
                            });
                          }
                          return;
                        }

                        // If free course, enroll directly
                        if (isFree) {
                          await _enrollInCourse();
                        } else {
                          await _handlePaidCourseCheckout(courseData);
                        }
                      },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: _isEnrolling
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF0C52B3), Color(0xFF093F8A)],
                          ),
                    color: _isEnrolling ? Colors.grey[300] : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isEnrolling)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.grey),
                          ),
                        )
                      else
                        Icon(
                          _isEnrolled
                              ? Icons.play_circle_rounded
                              : isFree
                                  ? Icons.play_circle_rounded
                                  : Icons.shopping_cart_rounded,
                          color: _isEnrolling ? Colors.grey : Colors.white,
                          size: 22,
                        ),
                      const SizedBox(width: 10),
                      Text(
                        _isEnrolling
                            ? AppLocalizations.of(context)!.enrolling
                            : _isEnrolled
                                ? AppLocalizations.of(context)!.startLearningNow
                                : isFree
                                    ? AppLocalizations.of(context)!.enrollFree
                                    : AppLocalizations.of(context)!
                                        .enrollInCourse,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isEnrolling ? Colors.grey[600] : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePaidCourseCheckout(
      Map<String, dynamic>? courseData) async {
    if (courseData == null) return;

    final subscriptionPlans = courseData['course_subscription_plans'] ??
        courseData['subscription_plans'];
    if (subscriptionPlans is List && subscriptionPlans.isNotEmpty) {
      final choice = await _showPaymentOptionsBottomSheet(
        courseData: courseData,
        plans: subscriptionPlans,
      );
      if (!mounted || choice == null) return;

      final choiceType = choice['__checkout_choice']?.toString();
      if (choiceType == 'plan') {
        final selectedPlan = choice['plan'];
        if (selectedPlan is! Map<String, dynamic>) return;
        context.push(
          RouteNames.checkout,
          extra: {...courseData, 'checkout_selected_plan': selectedPlan},
        );
      } else {
        context.push(
          RouteNames.checkout,
          extra: checkoutPayloadForFullCoursePrice(courseData),
        );
      }
      return;
    }

    context.push(
      RouteNames.checkout,
      extra: checkoutPayloadForNavigation(courseData),
    );
  }

  Future<Map<String, dynamic>?> _showPaymentOptionsBottomSheet({
    required Map<String, dynamic> courseData,
    required List plans,
  }) async {
    final parsedPlans = plans.whereType<Map>().map((plan) {
      return plan.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }).toList();
    if (parsedPlans.isEmpty) return null;

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final hasFullCoursePrice = parseCourseTotalPricing(courseData).amount > 0;
        int selectedIndex = hasFullCoursePrice ? 0 : 1;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.completePurchase,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            if (hasFullCoursePrice) ...[
                              _buildPaymentChoiceTile(
                                title: AppLocalizations.of(context)!.coursePrice,
                                subtitle: 'Full course purchase',
                                isSelected: selectedIndex == 0,
                                onTap: () =>
                                    setModalState(() => selectedIndex = 0),
                              ),
                              const SizedBox(height: 8),
                            ],
                            ...List.generate(parsedPlans.length, (index) {
                              final plan = parsedPlans[index];
                              final cardIndex = index + 1;
                              final planName = plan['name']?.toString() ??
                                  AppLocalizations.of(context)!
                                      .subscriptionPlan;
                              final durationText = _formatPlanDuration(
                                plan['duration_value'],
                                plan['duration_unit'],
                              );
                              final offerEndsLabel = _formatPlanOfferEndLabel(
                                context,
                                plan['offer_ends_at'] ?? plan['offerEndsAt'],
                              );
                              final planPriceText = () {
                                final currency =
                                    plan['currency']?.toString().toUpperCase();
                                final price = _tryParseNum(plan['price']);
                                if ((currency == 'EGP' || currency == 'USD') &&
                                    price != null &&
                                    price > 0) {
                                  return _formatSingleCurrencyPrice(
                                    currency: currency!,
                                    amount: price,
                                  );
                                }
                                final planMap = Map<String, dynamic>.from(plan);
                                final formatted = _formatDualCurrencyFromValues(
                                  egp: effectiveCoursePriceEgp(planMap),
                                  usd: effectiveCoursePriceUsd(planMap),
                                );
                                if (formatted.isNotEmpty) return formatted;
                                return AppLocalizations.of(context)!
                                    .notAvailable;
                              }();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildPlanPaymentChoiceTile(
                                  title: planName,
                                  priceText: planPriceText,
                                  durationText: durationText,
                                  offerEndsLabel: offerEndsLabel,
                                  isSelected: selectedIndex == cardIndex,
                                  onTap: () => setModalState(
                                      () => selectedIndex = cardIndex),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (hasFullCoursePrice && selectedIndex == 0) {
                            Navigator.of(context)
                                .pop({'__checkout_choice': 'full'});
                          } else {
                            final plan = parsedPlans[selectedIndex - 1];
                            Navigator.of(context).pop({
                              '__checkout_choice': 'plan',
                              'plan': plan,
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.purple,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.continueToPayment,
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentChoiceTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lavenderLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.purple : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.purple : Colors.grey.shade500,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanPaymentChoiceTile({
    required String title,
    required String priceText,
    required String durationText,
    required bool isSelected,
    required VoidCallback onTap,
    String? offerEndsLabel,
  }) {
    final unit = durationText.toLowerCase();
    final isMonthly = unit.contains('month') || unit.contains('شهر');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lavenderLight : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.purple : Colors.grey.shade300,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.purple.withOpacity(0.14),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.foreground,
                          ),
                        ),
                      ),
                      if (isMonthly)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Monthly',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.purple,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildPlanMetaChip(
                        icon: Icons.schedule_rounded,
                        text: durationText,
                      ),
                      _buildPlanMetaChip(
                        icon: Icons.payments_rounded,
                        text: priceText,
                      ),
                    ],
                  ),
                  if (offerEndsLabel != null &&
                      offerEndsLabel.trim().isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      offerEndsLabel,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: const Color(0xFFB45309),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.purple : Colors.grey.shade500,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanMetaChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.mutedForeground),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Future<Map<String, dynamic>?> _showSubscriptionPlansBottomSheet(
      List plans) async {
    final parsedPlans = plans.whereType<Map>().map((plan) {
      return plan.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }).toList();

    if (parsedPlans.isEmpty) return null;

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        int selectedIndex = 0;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.chooseSubscriptionPlan,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            ...List.generate(parsedPlans.length, (index) {
                              final plan = parsedPlans[index];
                              final isSelected = selectedIndex == index;
                              final planName = plan['name']?.toString() ??
                                  AppLocalizations.of(context)!
                                      .subscriptionPlan;
                              final legacyDurationMonths =
                                  plan['duration_months'];
                              final durationText = legacyDurationMonths != null
                                  ? () {
                                      final months =
                                          _tryParseNum(legacyDurationMonths)
                                              ?.toInt();
                                      return months == null
                                          ? legacyDurationMonths.toString()
                                          : AppLocalizations.of(context)!
                                              .monthsDuration(months);
                                    }()
                                  : _formatPlanDuration(
                                      plan['duration_value'],
                                      plan['duration_unit'],
                                    );
                              final offerEndsLabel = _formatPlanOfferEndLabel(
                                context,
                                plan['offer_ends_at'] ?? plan['offerEndsAt'],
                              );

                              final planPriceText = () {
                                // Spec111: single currency in plans
                                final currency =
                                    plan['currency']?.toString().toUpperCase();
                                final price = _tryParseNum(plan['price']);
                                if ((currency == 'EGP' || currency == 'USD') &&
                                    price != null &&
                                    price > 0) {
                                  return _formatSingleCurrencyPrice(
                                    currency: currency!,
                                    amount: price,
                                  );
                                }

                                // Fallback: dual fields / per-currency discounts
                                final planMap = Map<String, dynamic>.from(plan);
                                final formatted = _formatDualCurrencyFromValues(
                                  egp: effectiveCoursePriceEgp(planMap),
                                  usd: effectiveCoursePriceUsd(planMap),
                                );
                                if (formatted.isNotEmpty) return formatted;

                                // Legacy: single `price` assumed EGP
                                if (price != null && price != 0) {
                                  return _formatSingleCurrencyPrice(
                                    currency: 'EGP',
                                    amount: price,
                                  );
                                }

                                return AppLocalizations.of(context)!
                                    .notAvailableShort;
                              }();

                              return GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    selectedIndex = index;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.lavenderLight
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.purple
                                          : Colors.grey[200]!,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.purple
                                              : Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.calendar_month_rounded,
                                          size: 24,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey[500],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              planName,
                                              style: GoogleFonts.cairo(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.foreground,
                                              ),
                                            ),
                                            Text(
                                              durationText,
                                              style: GoogleFonts.cairo(
                                                fontSize: 12,
                                                color:
                                                    AppColors.mutedForeground,
                                              ),
                                            ),
                                            if (offerEndsLabel != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                offerEndsLabel,
                                                style: GoogleFonts.cairo(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.orange[800],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            planPriceText,
                                            style: GoogleFonts.cairo(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.purple,
                                            ),
                                          ),
                                          Container(
                                            margin:
                                                const EdgeInsets.only(top: 8),
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isSelected
                                                  ? AppColors.purple
                                                  : Colors.transparent,
                                              border: Border.all(
                                                color: isSelected
                                                    ? AppColors.purple
                                                    : Colors.grey[300]!,
                                                width: 2,
                                              ),
                                            ),
                                            child: isSelected
                                                ? const Icon(
                                                    Icons.check,
                                                    size: 16,
                                                    color: Colors.white,
                                                  )
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(
                        parsedPlans[selectedIndex],
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.purple,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            AppLocalizations.of(context)!.continueToPayment,
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _enrollInCourse() async {
    final course = _courseData ?? widget.course;
    if (course == null || course['id'] == null) return;

    final courseId = course['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    setState(() => _isEnrolling = true);

    try {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('📤 ENROLL REQUEST (enrollInCourse)');
        print('═══════════════════════════════════════════════════════════');
        print('Course ID: $courseId');
        final title = course['title']?.toString();
        if (title != null) {
          print('Course Title: $title');
        }
        print('═══════════════════════════════════════════════════════════');
      }

      final enrollment = await CoursesService.instance.enrollInCourse(courseId);

      // Print detailed response
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('✅ ENROLLMENT RESPONSE (enrollInCourse)');
        print('═══════════════════════════════════════════════════════════');
        print('Course ID: $courseId');
        print('Response Type: ${enrollment.runtimeType}');
        print('Response Keys: ${enrollment.keys.toList()}');
        print('───────────────────────────────────────────────────────────');
        print('Full Response JSON:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(enrollment));
        } catch (e) {
          print('Could not convert to JSON: $e');
          print('Raw Response: $enrollment');
        }
        print('───────────────────────────────────────────────────────────');
        print('Key Fields:');
        enrollment.forEach((key, value) {
          print('  - $key: $value (${value.runtimeType})');
        });
        print('═══════════════════════════════════════════════════════════');
      }

      setState(() {
        _isEnrolled = true;
        _isEnrolling = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.enrolledSuccessfully,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      // Navigate to first lesson if available
      final firstLesson = _getFirstLesson();
      if (firstLesson != null && mounted) {
        final course = _courseData ?? widget.course;
        final courseId = course?['id']?.toString();
        context.push(RouteNames.lessonViewer, extra: {
          'lesson': firstLesson,
          'courseId': courseId,
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error enrolling in course: $e');
      }

      setState(() => _isEnrolling = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('401') ||
                      e.toString().contains('Unauthorized')
                  ? AppLocalizations.of(context)!.mustLoginFirst
                  : AppLocalizations.of(context)!.errorEnrolling,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadCourseExams() async {
    final course = _courseData ?? widget.course;
    if (course == null || course['id'] == null) return;

    final courseId = course['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    setState(() => _isLoadingExams = true);

    try {
      var exams = await ExamsService.instance.getCourseExams(courseId);
      if (exams.isEmpty) {
        exams = _extractExamsFromCourse(course);
      }

      bool isCourseLevelExam(Map<String, dynamic> m) {
        final targetType = m['target_type']?.toString().toLowerCase().trim() ??
            m['targetType']?.toString().toLowerCase().trim() ??
            '';
        final lessonId =
            m['lesson_id']?.toString() ?? m['lessonId']?.toString();
        if (targetType == 'lesson') return false;
        if (targetType == 'course') return true;
        // If target_type is missing, treat any exam bound to a lesson as lesson exam.
        if (lessonId != null && lessonId.isNotEmpty) return false;
        return true;
      }

      // Exams tab must show course-level exams only.
      final examOnly = exams
          .map((raw) {
            final m = Map<String, dynamic>.from(raw);
            if (m['type'] == null || (m['type']?.toString().isEmpty ?? true)) {
              m['type'] = 'exam';
            }
            return m;
          })
          .where(isCourseLevelExam)
          .toList();

      // Print detailed response
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('📝 COURSE EXAMS RESPONSE (getCourseExams)');
        print('═══════════════════════════════════════════════════════════');
        print('Course ID: $courseId');
        print('Response Type: ${exams.runtimeType}');
        print('Total Exams: ${exams.length}');
        print('───────────────────────────────────────────────────────────');
        print('Full Response JSON:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(examOnly));
        } catch (e) {
          print('Could not convert to JSON: $e');
          print('Raw Response: $exams');
        }
        print('───────────────────────────────────────────────────────────');
        print('Exams Summary:');
        for (int i = 0; i < examOnly.length; i++) {
          final exam = examOnly[i];
          print('  Item ${i + 1}:');
          print('    - ID: ${exam['id']}');
          print('    - Title: ${exam['title']}');
          print('    - Type: ${exam['type']}');
          print('    - Questions Count: ${exam['questions_count']}');
          print('    - Can Start: ${exam['can_start']}');
        }
        print('═══════════════════════════════════════════════════════════');
      }

      setState(() {
        _courseExams = examOnly;
        _isLoadingExams = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('❌ ERROR LOADING COURSE EXAMS');
        print('═══════════════════════════════════════════════════════════');
        print('Course ID: $courseId');
        print('Error: $e');
        print('Error Type: ${e.runtimeType}');
        print('═══════════════════════════════════════════════════════════');
      }
      final fallback = _extractExamsFromCourse(course);
      if (fallback.isNotEmpty) {
        if (kDebugMode) {
          print(
              'ℹ️ Using exams fallback from course payload: ${fallback.length}');
        }
        setState(() {
          _courseExams = fallback.where((m) {
            final targetType =
                m['target_type']?.toString().toLowerCase().trim() ??
                    m['targetType']?.toString().toLowerCase().trim() ??
                    '';
            final lessonId =
                m['lesson_id']?.toString() ?? m['lessonId']?.toString();
            if (targetType == 'lesson') return false;
            if (targetType == 'course') return true;
            if (lessonId != null && lessonId.isNotEmpty) return false;
            return true;
          }).toList();
          _isLoadingExams = false;
        });
        return;
      }

      setState(() {
        _courseExams = [];
        _isLoadingExams = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _resolveExamsListError(e),
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _extractExamsFromCourse(
      Map<String, dynamic> course) {
    final exams = <Map<String, dynamic>>[];

    void addExam(dynamic raw) {
      if (raw is! Map) return;
      final item = Map<String, dynamic>.from(raw);
      final title = item['title']?.toString().trim();
      if (title == null || title.isEmpty) return;

      final type = item['type']?.toString().toLowerCase();
      final isExamType = type == 'exam' ||
          type == 'trial_exam' ||
          type == 'quiz' ||
          type == 'test' ||
          item['questions_count'] != null;
      if (!isExamType) return;

      exams.add({
        ...item,
        'type': item['type'] ?? 'exam',
        'can_start': item['can_start'] ?? true,
      });
    }

    final directKeys = ['exams', 'course_exams', 'quizzes', 'tests'];
    for (final key in directKeys) {
      final raw = course[key];
      if (raw is List) {
        for (final item in raw) {
          addExam(item);
        }
      }
    }

    final curriculum = course['curriculum'];
    if (curriculum is List) {
      void scanItems(List<dynamic> items) {
        for (final rawItem in items) {
          if (rawItem is! Map) continue;
          addExam(rawItem);

          final item = Map<String, dynamic>.from(rawItem);
          final nestedLessons = item['lessons'];
          if (nestedLessons is List) {
            scanItems(nestedLessons);
          }
          final nestedSubsections = item['subsections'];
          if (nestedSubsections is List) {
            scanItems(nestedSubsections);
          }
        }
      }

      scanItems(curriculum);
    }

    return exams;
  }

  String _resolveExamsListError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401) {
        return AppLocalizations.of(context)!.mustLoginFirst;
      }
      if (error.statusCode == 404) {
        return 'لا توجد امتحانات متاحة لهذا الكورس حالياً';
      }
      if (error.message.isNotEmpty) {
        return error.message;
      }
    }
    return AppLocalizations.of(context)!.errorStartingExam;
  }

  Future<void> _loadCourseAssignments() async {
    final course = _courseData ?? widget.course;
    if (course == null || course['id'] == null) return;

    final courseId = course['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    try {
      final assignments =
          await CoursesService.instance.getCourseAssignments(courseId);
      var normalized = assignments.map((item) {
        return {
          ...item,
          'type': 'assignment',
          'can_start': item['can_start'] ?? true,
        };
      }).toList();

      if (normalized.isEmpty) {
        normalized = _extractAssignmentsFromCourse(course);
      }

      if (!mounted) return;
      setState(() {
        _courseAssignments = normalized;
      });
      if (kDebugMode) {
        print('✅ Loaded course assignments: ${normalized.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Could not load course assignments endpoint: $e');
      }
      final fallback = _extractAssignmentsFromCourse(course);
      if (!mounted) return;
      setState(() {
        _courseAssignments = fallback;
      });
    }
  }

  List<Map<String, dynamic>> _extractAssignmentsFromCourse(
      Map<String, dynamic> course) {
    final assignments = <Map<String, dynamic>>[];

    void addAssignment(dynamic raw) {
      if (raw is! Map) return;
      final item = Map<String, dynamic>.from(raw);
      final title = item['title']?.toString().trim();
      if (title == null || title.isEmpty) return;
      assignments.add({
        ...item,
        'type': 'assignment',
        'can_start': item['can_start'] ?? true,
      });
    }

    final directKeys = [
      'assignments',
      'course_assignments',
      'homeworks',
      'tasks'
    ];
    for (final key in directKeys) {
      final raw = course[key];
      if (raw is List) {
        for (final item in raw) {
          addAssignment(item);
        }
      }
    }

    final curriculum = course['curriculum'];
    if (curriculum is List) {
      void scanItems(List<dynamic> items) {
        for (final rawItem in items) {
          if (rawItem is! Map) continue;
          final item = Map<String, dynamic>.from(rawItem);
          final type = item['type']?.toString().toLowerCase();
          if (type == 'assignment' || type == 'homework' || type == 'task') {
            addAssignment(item);
          }

          final nestedLessons = item['lessons'];
          if (nestedLessons is List) {
            scanItems(nestedLessons);
          }
          final nestedSubsections = item['subsections'];
          if (nestedSubsections is List) {
            scanItems(nestedSubsections);
          }
        }
      }

      scanItems(curriculum);
    }

    return assignments;
  }

  Future<void> _startExam(String examId, Map<String, dynamic> examData) async {
    if (examId.isEmpty) return;
    if (!_examCanStartFromData(examData)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No attempts remaining for this exam.',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    final course = _courseData ?? widget.course;
    if (course == null || course['id'] == null) return;

    final courseId = course['id']?.toString();
    if (courseId == null || courseId.isEmpty) return;

    try {
      setState(() => _startingExamId = examId);
      // Start exam via API
      final examSession =
          await ExamsService.instance.startExam(courseId, examId);

      // Print detailed response
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('🚀 START EXAM RESPONSE (startExam)');
        print('═══════════════════════════════════════════════════════════');
        print('Exam ID: $examId');
        print('Response Type: ${examSession.runtimeType}');
        print('Response Keys: ${examSession.keys.toList()}');
        print('───────────────────────────────────────────────────────────');
        print('Full Response JSON:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(examSession));
        } catch (e) {
          print('Could not convert to JSON: $e');
          print('Raw Response: $examSession');
        }
        print('───────────────────────────────────────────────────────────');
        print('Key Fields:');
        examSession.forEach((key, value) {
          if (key == 'questions' && value is List) {
            print('  - $key: List with ${value.length} questions');
            for (int i = 0; i < value.length && i < 2; i++) {
              print('    Question $i: ${value[i]}');
            }
          } else {
            print('  - $key: $value (${value.runtimeType})');
          }
        });
        print('═══════════════════════════════════════════════════════════');
      }

      final questions = examSession['questions'] as List?;
      final attemptId = examSession['attempt_id']?.toString();

      if (questions == null || questions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.noQuestionsAvailable,
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return;
      }

      if (mounted) {
        final submittedResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrialExamScreen(
              examId: examId,
              courseId: courseId,
              attemptId: attemptId,
              courseName:
                  (_courseData ?? widget.course)?['title']?.toString() ??
                      AppLocalizations.of(context)!.course,
              examData: examData,
              examSession: examSession,
            ),
          ),
        );

        if (!mounted) return;
        if (submittedResult is Map<String, dynamic>) {
          _applyInstantExamResult(examId, submittedResult);
        } else if (submittedResult is Map) {
          _applyInstantExamResult(
              examId, Map<String, dynamic>.from(submittedResult));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting exam: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _resolveExamStartError(e),
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _startingExamId = null);
      }
    }
  }

  String _resolveExamStartError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401) {
        return AppLocalizations.of(context)!.mustLoginFirst;
      }
      if (error.statusCode == 404) {
        return 'الامتحان أو الكورس غير موجود حالياً';
      }
      if (error.statusCode == 400) {
        return error.message.isNotEmpty
            ? error.message
            : 'لا يمكن بدء الامتحان حالياً';
      }
      if (error.message.isNotEmpty) {
        return error.message;
      }
    }

    final message = error.toString();
    if (message.contains('401') ||
        message.toLowerCase().contains('unauthorized')) {
      return AppLocalizations.of(context)!.mustLoginFirst;
    }
    if (message.contains('404')) {
      return 'الامتحان أو الكورس غير موجود حالياً';
    }
    if (message.contains('400')) {
      return 'لا يمكن بدء الامتحان حالياً';
    }
    return AppLocalizations.of(context)!.errorStartingExam;
  }

  void _applyInstantExamResult(String examId, Map<String, dynamic> result) {
    setState(() {
      _courseExams = _courseExams.map((exam) {
        final id = exam['id']?.toString();
        if (id != examId) return exam;

        final updated = Map<String, dynamic>.from(exam);
        final score = result['score'];
        if (score != null) {
          updated['best_score'] = score;
        }

        if (result['is_passed'] != null) {
          updated['is_passed'] = result['is_passed'] == true;
        }

        final attemptsUsedRaw = updated['attempts_used'];
        int attemptsUsed;
        if (attemptsUsedRaw is int) {
          attemptsUsed = attemptsUsedRaw + 1;
        } else if (attemptsUsedRaw is num) {
          attemptsUsed = attemptsUsedRaw.toInt() + 1;
        } else {
          attemptsUsed = 1;
        }
        updated['attempts_used'] = attemptsUsed;

        // Instant lock when attempts are exhausted.
        final maxAttemptsRaw = updated['max_attempts'];
        final maxAttempts = maxAttemptsRaw is int
            ? maxAttemptsRaw
            : (maxAttemptsRaw is num ? maxAttemptsRaw.toInt() : null);
        if (maxAttempts != null && maxAttempts > 0) {
          updated['can_start'] = attemptsUsed < maxAttempts;
        }

        // If backend explicitly returns availability flags, honor them.
        final backendCanStart = result['can_start'];
        if (backendCanStart is bool) {
          updated['can_start'] = backendCanStart;
        }
        final attemptsRemainingRaw = result['attempts_remaining'];
        final attemptsRemaining = attemptsRemainingRaw is int
            ? attemptsRemainingRaw
            : (attemptsRemainingRaw is num
                ? attemptsRemainingRaw.toInt()
                : null);
        if (attemptsRemaining != null) {
          updated['can_start'] = attemptsRemaining > 0;
        }

        return updated;
      }).toList();
    });
  }

  Widget _buildSkeleton() {
    return Skeletonizer(
      enabled: true,
      child: Scaffold(
        backgroundColor: AppColors.beige,
        body: SafeArea(
          child: Column(
            children: [
              // Video skeleton
              Container(
                height: 220,
                color: Colors.black,
              ),
              // Content skeleton
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header skeleton
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 80,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              Container(
                                width: 60,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 24,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 24,
                            width: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 60,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 60,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Tabs skeleton
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Lessons skeleton
                          ...List.generate(5, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trial Exam Screen
class TrialExamScreen extends StatefulWidget {
  final String examId;
  final String courseId;
  final String? attemptId;
  final String courseName;
  final Map<String, dynamic>? examData;
  final Map<String, dynamic>? examSession;
  final List<Map<String, dynamic>>? questions; // Fallback for static questions

  const TrialExamScreen({
    super.key,
    required this.examId,
    required this.courseId,
    this.attemptId,
    required this.courseName,
    this.examData,
    this.examSession,
    this.questions,
  });

  @override
  State<TrialExamScreen> createState() => _TrialExamScreenState();
}

class _TrialExamScreenState extends State<TrialExamScreen> {
  int _currentQuestionIndex = 0;
  final Map<int, List<String>> _selectedAnswers =
      {}; // For multiple choice questions
  final Map<int, String?> _singleAnswers = {}; // For single choice questions
  final Map<int, TextEditingController> _textAnswerControllers = {};
  bool _showResult = false;
  bool _isSubmitting = false;
  Map<String, dynamic>? _examResult;
  List<Map<String, dynamic>> _questions = [];
  String? _attemptId;
  final Map<int, bool> _submittedQuestions = {};
  final Map<int, bool> _questionCorrectness = {};
  final Map<int, bool> _questionEvaluated = {};
  final Map<int, String?> _questionExplanations = {};
  final Map<int, String?> _questionUserAnswerText = {};
  final Map<int, String?> _questionCorrectAnswerText = {};
  Timer? _examTimer;
  int _remainingSeconds = 0;
  bool _timerExpired = false;
  bool _isTimedExam = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  void _loadQuestions() {
    // Get questions from exam session or use fallback
    if (widget.examSession != null &&
        widget.examSession!['questions'] != null) {
      final questions = widget.examSession!['questions'] as List;
      _questions = questions.map((q) => q as Map<String, dynamic>).toList();
      _attemptId =
          widget.examSession!['attempt_id']?.toString() ?? widget.attemptId;
    } else if (widget.questions != null) {
      _questions = List<Map<String, dynamic>>.from(widget.questions!);
    }

    // Initialize answers
    for (int i = 0; i < _questions.length; i++) {
      _singleAnswers[i] = null;
      _selectedAnswers[i] = [];
      _textAnswerControllers[i] = TextEditingController();
      _submittedQuestions[i] = false;
      _questionCorrectness[i] = false;
      _questionEvaluated[i] = false;
      _questionExplanations[i] = null;
      _questionUserAnswerText[i] = null;
      _questionCorrectAnswerText[i] = null;
    }

    _startExamTimer();
  }

  bool _resolveHasTimeLimitFlag() {
    final explicitFlags = [
      widget.examSession?['has_time_limit'],
      widget.examData?['has_time_limit'],
      widget.examSession?['is_timed'],
      widget.examData?['is_timed'],
      widget.examSession?['timed'],
      widget.examData?['timed'],
    ];
    for (final flag in explicitFlags) {
      if (flag is bool) return flag;
      final normalized = flag?.toString().toLowerCase().trim();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return true;
  }

  int? _resolveExamDurationMinutes() {
    final candidates = [
      widget.examSession?['duration_minutes'],
      widget.examData?['duration_minutes'],
      widget.examSession?['duration'],
      widget.examData?['duration'],
    ];
    for (final c in candidates) {
      if (c is int && c > 0) return c;
      final parsed = int.tryParse(c?.toString() ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  void _startExamTimer() {
    _examTimer?.cancel();
    final durationMinutes = _resolveExamDurationMinutes();
    final hasTimeLimit = _resolveHasTimeLimitFlag();
    _isTimedExam = hasTimeLimit && durationMinutes != null;
    if (!_isTimedExam) {
      _remainingSeconds = 0;
      _timerExpired = false;
      return;
    }
    _remainingSeconds = durationMinutes! * 60;
    _timerExpired = false;
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_showResult || _isSubmitting) return;
      if (_remainingSeconds <= 1) {
        setState(() {
          _remainingSeconds = 0;
          _timerExpired = true;
        });
        timer.cancel();
        _submitExam();
        return;
      }
      setState(() {
        _remainingSeconds--;
      });
    });
  }

  String _formatRemainingTime() {
    final mins = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  bool _isTextQuestion(Map<String, dynamic> question) {
    final type = question['type']?.toString().toLowerCase().trim() ?? '';
    final answerType =
        question['answer_type']?.toString().toLowerCase().trim() ?? '';
    final format =
        question['answer_format']?.toString().toLowerCase().trim() ?? '';
    final options = question['options'] as List? ?? [];
    if (options.isEmpty) return true;
    return type.contains('text') ||
        type.contains('essay') ||
        answerType.contains('text') ||
        answerType.contains('essay') ||
        format.contains('text') ||
        format.contains('essay');
  }

  bool _isMultipleSelectQuestion(Map<String, dynamic> question) {
    if (question['is_multiple'] == true) return true;
    final type = question['type']?.toString().toLowerCase().trim() ?? '';
    return type == 'multiple_select' ||
        type == 'multi_select' ||
        type == 'checkbox';
  }

  void _selectAnswer(int optionIndex) {
    setState(() {
      final question = _questions[_currentQuestionIndex];

      final isMultiple = _isMultipleSelectQuestion(question);

      if (isMultiple) {
        final selected = _selectedAnswers[_currentQuestionIndex] ?? [];
        final optionId = question['options']?[optionIndex]?['id']?.toString() ??
            question['options']?[optionIndex]?['option_id']?.toString();

        if (selected.contains(optionId)) {
          selected.remove(optionId);
        } else {
          selected.add(optionId ?? optionIndex.toString());
        }
        _selectedAnswers[_currentQuestionIndex] = selected;
      } else {
        // Single choice
        final optionId = question['options']?[optionIndex]?['id']?.toString() ??
            question['options']?[optionIndex]?['option_id']?.toString();
        _singleAnswers[_currentQuestionIndex] =
            optionId ?? optionIndex.toString();
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _submitExam();
    }
  }

  bool get _isCurrentQuestionSubmitted =>
      _submittedQuestions[_currentQuestionIndex] == true;

  String? _extractQuestionExplanation(Map<String, dynamic> question) {
    final candidates = [
      question['explanation'],
      question['answer_explanation'],
      question['feedback'],
      question['solution'],
    ];
    for (final c in candidates) {
      final text = c?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  String _normalizeAnswerText(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      final parts = <String>[];
      for (final item in value) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final text = map['text']?.toString().trim();
          final token = map['id']?.toString() ??
              map['value']?.toString() ??
              map['index']?.toString();
          if (text != null && text.isNotEmpty) {
            parts.add(text);
          } else if (token != null && token.trim().isNotEmpty) {
            parts.add(token.trim());
          }
          continue;
        }
        final itemText = item?.toString().trim();
        if (itemText != null && itemText.isNotEmpty) {
          parts.add(itemText);
        }
      }
      return parts.join(', ');
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final text = map['text']?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
      final token = map['id']?.toString() ??
          map['value']?.toString() ??
          map['index']?.toString();
      return token?.trim() ?? '';
    }
    return value.toString().trim();
  }

  String? _extractExplanationFromSubmitResponse(Map<String, dynamic> data) {
    final candidates = [
      data['explanation'],
      data['answer_explanation'],
      data['feedback'],
      data['solution'],
    ];
    for (final c in candidates) {
      final text = c?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  String _optionLabel(int index) {
    if (index < 26) return String.fromCharCode(65 + index); // A-Z
    final first = ((index ~/ 26) - 1).clamp(0, 25);
    final second = index % 26;
    return '${String.fromCharCode(65 + first)}${String.fromCharCode(65 + second)}';
  }

  bool _isExamTimeExpiredError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('انتهى وقت الامتحان') ||
        text.contains('time') &&
            text.contains('exam') &&
            text.contains('end') ||
        text.contains('time is over') ||
        text.contains('time expired') ||
        text.contains('attempt expired');
  }

  void _submitCurrentQuestionAnswer() {
    unawaited(_submitCurrentQuestionAnswerAsync());
  }

  Future<void> _submitCurrentQuestionAnswerAsync() async {
    if (!_hasSelectedAnswer || _isCurrentQuestionSubmitted) return;
    if (_isSubmitting) return;
    if (_attemptId == null || _attemptId!.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to submit answer: missing attempt id')),
      );
      return;
    }

    final question = _questions[_currentQuestionIndex];
    final questionId =
        question['id']?.toString() ?? question['question_id']?.toString() ?? '';
    if (questionId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to submit answer: missing question id')),
      );
      return;
    }

    final isText = _isTextQuestion(question);
    final isMultiple = _isMultipleSelectQuestion(question);
    final answerTextRaw =
        _textAnswerControllers[_currentQuestionIndex]?.text.trim() ?? '';

    String? answer;
    List<String> selectedOptions = const [];
    String? answerText;

    if (isText) {
      answer = null;
      selectedOptions = const [];
      answerText = answerTextRaw.isEmpty ? null : answerTextRaw;
    } else if (isMultiple) {
      selectedOptions =
          List<String>.from(_selectedAnswers[_currentQuestionIndex] ?? []);
      answer = selectedOptions.isNotEmpty ? selectedOptions.first : null;
      answerText = null;
    } else {
      final selected = _singleAnswers[_currentQuestionIndex];
      answer = selected;
      selectedOptions = selected != null ? [selected] : const [];
      answerText = null;
    }

    var shouldFinalizeExam = false;
    setState(() => _isSubmitting = true);
    try {
      final submitData = await ExamsService.instance.submitExamQuestion(
        widget.courseId,
        widget.examId,
        attemptId: _attemptId!,
        questionId: questionId,
        answer: answer,
        selectedOptions: selectedOptions,
        answerText: answerText,
      );

      final hasEvaluation = submitData['is_correct'] is bool;
      final isCorrect = submitData['is_correct'] == true;

      final userAnswerTextFromApi =
          _normalizeAnswerText(submitData['user_answer']).trim();
      final correctAnswerTextFromApi =
          _normalizeAnswerText(submitData['correct_answer']).trim();
      final explanation = _extractExplanationFromSubmitResponse(submitData) ??
          _extractQuestionExplanation(question);

      if (!mounted) return;
      setState(() {
        _submittedQuestions[_currentQuestionIndex] = true;
        _questionEvaluated[_currentQuestionIndex] = hasEvaluation;
        _questionCorrectness[_currentQuestionIndex] = isCorrect;
        _questionExplanations[_currentQuestionIndex] = explanation;
        _questionUserAnswerText[_currentQuestionIndex] = userAnswerTextFromApi
                .isNotEmpty
            ? userAnswerTextFromApi
            : (isText
                ? (answerTextRaw.isNotEmpty ? answerTextRaw : 'Not answered')
                : 'Not answered');
        _questionCorrectAnswerText[_currentQuestionIndex] =
            correctAnswerTextFromApi.isNotEmpty
                ? correctAnswerTextFromApi
                : '—';
      });
    } catch (e) {
      shouldFinalizeExam = _isExamTimeExpiredError(e);
      if (shouldFinalizeExam && mounted) {
        setState(() => _timerExpired = true);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldFinalizeExam
                ? 'Exam time is over... showing your result'
                : 'Question submission failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
    if (shouldFinalizeExam && mounted && !_showResult) {
      await _submitExam();
    }
  }

  bool get _hasSelectedAnswer {
    final question = _questions[_currentQuestionIndex];
    final isText = _isTextQuestion(question);
    if (isText) {
      return (_textAnswerControllers[_currentQuestionIndex]
              ?.text
              .trim()
              .isNotEmpty ??
          false);
    }
    final isMultiple = _isMultipleSelectQuestion(question);

    if (isMultiple) {
      final selected = _selectedAnswers[_currentQuestionIndex] ?? [];
      return selected.isNotEmpty;
    } else {
      return _singleAnswers[_currentQuestionIndex] != null;
    }
  }

  Future<void> _submitExam() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      // Prepare answers in API format
      final answers = <Map<String, dynamic>>[];

      for (int i = 0; i < _questions.length; i++) {
        final question = _questions[i];
        final questionId = question['id']?.toString() ??
            question['question_id']?.toString() ??
            'q_$i';

        final isMultiple = _isMultipleSelectQuestion(question);
        final isText = _isTextQuestion(question);

        if (isText) {
          final textAnswer = _textAnswerControllers[i]?.text.trim() ?? '';
          if (textAnswer.isNotEmpty) {
            answers.add({
              'question_id': questionId,
              'answer': textAnswer,
            });
          }
        } else if (isMultiple) {
          final selected = _selectedAnswers[i] ?? [];
          final answerValue = selected.join(',');
          answers.add({
            'question_id': questionId,
            'answer': answerValue,
            'selected_options': selected,
          });
        } else {
          final selected = _singleAnswers[i];
          if (selected != null) {
            answers.add({
              'question_id': questionId,
              'answer': selected,
              'selected_options': [selected],
            });
          }
        }
      }

      if (_attemptId == null || _attemptId!.isEmpty) {
        throw Exception('Attempt ID is missing');
      }

      // Print answers before submission
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('📤 SUBMITTING EXAM');
        print('═══════════════════════════════════════════════════════════');
        print('Exam ID: ${widget.examId}');
        print('Attempt ID: $_attemptId');
        print('Total Questions: ${_questions.length}');
        print('Answers to Submit:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(answers));
        } catch (e) {
          print('Could not convert answers to JSON: $e');
          print('Raw Answers: $answers');
        }
        print('═══════════════════════════════════════════════════════════');
      }

      final result = await ExamsService.instance.submitExam(
        widget.courseId,
        widget.examId,
        attemptId: _attemptId!,
        answers: answers,
      );

      // Print detailed response
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('✅ EXAM SUBMISSION RESPONSE (submitExam)');
        print('═══════════════════════════════════════════════════════════');
        print('Exam ID: ${widget.examId}');
        print('Attempt ID: $_attemptId');
        print('Response Type: ${result.runtimeType}');
        print('Response Keys: ${result.keys.toList()}');
        print('───────────────────────────────────────────────────────────');
        print('Full Response JSON:');
        try {
          const encoder = JsonEncoder.withIndent('  ');
          print(encoder.convert(result));
        } catch (e) {
          print('Could not convert to JSON: $e');
          print('Raw Response: $result');
        }
        print('───────────────────────────────────────────────────────────');
        print('Key Fields:');
        result.forEach((key, value) {
          print('  - $key: $value (${value.runtimeType})');
        });
        print('───────────────────────────────────────────────────────────');
        print('Summary:');
        print('  - Score: ${result['score']}%');
        print('  - Is Passed: ${result['is_passed']}');
        print(
            '  - Correct Answers: ${result['correct_answers']}/${result['total_questions']}');
        if (result['time_taken_minutes'] != null) {
          print('  - Time Taken: ${result['time_taken_minutes']} minutes');
        }
        print('═══════════════════════════════════════════════════════════');
      }

      setState(() {
        _examResult = result;
        _showResult = true;
        _isSubmitting = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error submitting exam: $e');
      }

      setState(() => _isSubmitting = false);

      final errorMessage = () {
        if (e is ApiException && e.message.isNotEmpty) {
          return e.message;
        }

        final message = e.toString();
        if (message.contains('401') ||
            message.toLowerCase().contains('unauthorized')) {
          return AppLocalizations.of(context)!.mustLoginFirst;
        }

        return message.isNotEmpty
            ? message
            : AppLocalizations.of(context)!.errorSubmittingExam;
      }();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: GoogleFonts.cairo()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _examTimer?.cancel();
    for (final c in _textAnswerControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.beige,
        appBar: AppBar(
          backgroundColor: AppColors.purple,
          title: Text(
            'Exam',
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: AppColors.purple,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading questions...',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_showResult) {
      return _buildResultScreen();
    }

    final question = _questions[_currentQuestionIndex];
    final options = question['options'] as List? ?? [];
    final isText = _isTextQuestion(question);
    final isMultiple = _isMultipleSelectQuestion(question);

    return Scaffold(
      backgroundColor: AppColors.beige,
      appBar: AppBar(
        backgroundColor: AppColors.purple,
        title: Text(
          'Exam',
          style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isTimedExam
                      ? ((_remainingSeconds <= 60)
                          ? Colors.red.withOpacity(0.18)
                          : Colors.white.withOpacity(0.16))
                      : Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isTimedExam ? Icons.timer_outlined : Icons.all_inclusive,
                      size: 16,
                      color: _isTimedExam && _remainingSeconds <= 60
                          ? Colors.red.shade100
                          : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isTimedExam
                          ? _formatRemainingTime()
                          : (Localizations.localeOf(context).languageCode == 'ar'
                              ? 'بدون وقت'
                              : 'No time limit'),
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                '${_currentQuestionIndex + 1}/${_questions.length}',
                style: GoogleFonts.cairo(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question ${_currentQuestionIndex + 1}',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.purple,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    question['question']?.toString() ??
                        question['text']?.toString() ??
                        'Question',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.foreground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (isText) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.purple.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Write your answer',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _textAnswerControllers[_currentQuestionIndex],
                      minLines: 4,
                      maxLines: 8,
                      readOnly: _isCurrentQuestionSubmitted,
                      textInputAction: TextInputAction.newline,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Write your text answer here...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.35),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.purple,
                            width: 1.4,
                          ),
                        ),
                      ),
                      style: GoogleFonts.cairo(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ...List.generate(options.length, (index) {
                final option = options[index];
                final optionId = option['id']?.toString() ??
                    option['option_id']?.toString() ??
                    index.toString();

                bool isSelected = false;
                if (isMultiple) {
                  final selected =
                      _selectedAnswers[_currentQuestionIndex] ?? [];
                  isSelected = selected.contains(optionId);
                } else {
                  isSelected =
                      _singleAnswers[_currentQuestionIndex] == optionId;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: _isCurrentQuestionSubmitted
                        ? null
                        : () => _selectAnswer(index),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.purple.withOpacity(0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.purple
                              : Colors.grey.withOpacity(0.2),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.purple
                                  : Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: isSelected && isMultiple
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : Text(
                                      _optionLabel(index),
                                      style: GoogleFonts.cairo(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.mutedForeground,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              option['text']?.toString() ??
                                  option['option']?.toString() ??
                                  option.toString(),
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? AppColors.purple
                                    : AppColors.foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 20),

            if (_isCurrentQuestionSubmitted) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_questionEvaluated[_currentQuestionIndex] == true)
                      ? ((_questionCorrectness[_currentQuestionIndex] == true)
                          ? Colors.green.shade50
                          : Colors.red.shade50)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (_questionEvaluated[_currentQuestionIndex] == true)
                        ? ((_questionCorrectness[_currentQuestionIndex] == true)
                            ? Colors.green.shade200
                            : Colors.red.shade200)
                        : Colors.blue.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          (_questionEvaluated[_currentQuestionIndex] == true)
                              ? ((_questionCorrectness[_currentQuestionIndex] ==
                                      true)
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded)
                              : Icons.info_outline_rounded,
                          size: 20,
                          color: (_questionEvaluated[_currentQuestionIndex] ==
                                  true)
                              ? ((_questionCorrectness[_currentQuestionIndex] ==
                                      true)
                                  ? Colors.green
                                  : Colors.red)
                              : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          (_questionEvaluated[_currentQuestionIndex] == true)
                              ? ((_questionCorrectness[_currentQuestionIndex] ==
                                      true)
                                  ? 'Your answer is correct'
                                  : 'Your answer is incorrect')
                              : 'Answer submitted',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.foreground,
                          ),
                        ),
                      ],
                    ),
                    if ((_questionExplanations[_currentQuestionIndex] ?? '')
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Explanation: ${_questionExplanations[_currentQuestionIndex]}',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: AppColors.foreground,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your answer: ${_questionUserAnswerText[_currentQuestionIndex] ?? 'Not answered'}',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Correct answer: ${_questionCorrectAnswerText[_currentQuestionIndex] ?? '—'}',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Navigation buttons: Previous + Submit/Next/Finish
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: (_isSubmitting || _currentQuestionIndex == 0)
                        ? null
                        : () {
                            setState(() {
                              _currentQuestionIndex--;
                            });
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: (_isSubmitting || _currentQuestionIndex == 0)
                            ? Colors.grey[300]
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: (_isSubmitting || _currentQuestionIndex == 0)
                              ? Colors.grey.shade300
                              : AppColors.purple.withOpacity(0.35),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Previous',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: (_isSubmitting || _currentQuestionIndex == 0)
                                ? Colors.grey[500]
                                : AppColors.purple,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _isSubmitting
                        ? null
                        : (_timerExpired
                            ? null
                            : (_isCurrentQuestionSubmitted
                                ? (_currentQuestionIndex ==
                                        _questions.length - 1
                                    ? _submitExam
                                    : _nextQuestion)
                                : (_hasSelectedAnswer
                                    ? _submitCurrentQuestionAnswer
                                    : null))),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: ((_isCurrentQuestionSubmitted ||
                                    _hasSelectedAnswer) &&
                                !_isSubmitting)
                            ? const LinearGradient(
                                colors: [Color(0xFF0C52B3), Color(0xFF093F8A)])
                            : null,
                        color: ((!_isCurrentQuestionSubmitted &&
                                    !_hasSelectedAnswer) ||
                                _isSubmitting)
                            ? Colors.grey[300]
                            : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.grey),
                                ),
                              )
                            : Text(
                                _isCurrentQuestionSubmitted
                                    ? (_currentQuestionIndex ==
                                            _questions.length - 1
                                        ? 'Finish Exam'
                                        : 'Next')
                                    : 'Submit Answer',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: (_isCurrentQuestionSubmitted ||
                                          _hasSelectedAnswer)
                                      ? Colors.white
                                      : Colors.grey[500],
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    int score = 0;
    bool passed = false;
    int correctAnswers = 0;
    int totalQuestions = _questions.length;
    String? message;

    double? parseNum(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '');
    }

    if (_examResult != null) {
      passed = _examResult!['is_passed'] == true;
      correctAnswers = parseNum(_examResult!['correct_answers'])?.toInt() ?? 0;
      totalQuestions = parseNum(_examResult!['total_questions'])?.toInt() ??
          _questions.length;
      message = _examResult!['message']?.toString();

      final percentageRaw = parseNum(_examResult!['percentage']);
      final scoreRaw = parseNum(_examResult!['score']);
      if (percentageRaw != null) {
        score = percentageRaw.round();
      } else if (scoreRaw != null) {
        // Some backends return score as points earned, not percent.
        if (totalQuestions > 0 && scoreRaw <= totalQuestions) {
          score = ((scoreRaw / totalQuestions) * 100).round();
        } else {
          score = scoreRaw.round();
        }
      } else if (totalQuestions > 0) {
        score = ((correctAnswers / totalQuestions) * 100).round();
      } else {
        score = 0;
      }
    } else {
      // Fallback calculation (should not happen if API works)
      score = 0;
      passed = false;
    }

    final normalizedMessage = message?.trim().toLowerCase() ?? '';
    final fallbackEnglishMessage = passed ? 'Well done!' : 'Try again.';
    final englishMessage = normalizedMessage.isEmpty
        ? fallbackEnglishMessage
        : (normalizedMessage.contains('pass') ||
                normalizedMessage.contains('congrat') ||
                normalizedMessage.contains('success') ||
                normalizedMessage.contains('excellent') ||
                normalizedMessage.contains('great'))
            ? 'Congratulations'
            : (normalizedMessage.contains('fail') ||
                    normalizedMessage.contains('retry') ||
                    normalizedMessage.contains('try again'))
                ? 'You did not pass this time. Please try again.'
                : fallbackEnglishMessage;

    return Scaffold(
      backgroundColor: AppColors.beige,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: passed
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF97316),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          passed
                              ? Icons.emoji_events_rounded
                              : Icons.refresh_rounded,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        englishMessage,
                        style: GoogleFonts.cairo(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.foreground,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your score: $score%',
                        style: GoogleFonts.cairo(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: passed
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF97316),
                        ),
                      ),
                      Text(
                        'Correct answers: $correctAnswers out of $totalQuestions',
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      if (_examResult != null &&
                          _examResult!['time_taken_minutes'] != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Time taken: ${(_examResult!["time_taken_minutes"] as num?)?.toInt() ?? 0} minutes',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => Navigator.pop(context, _examResult),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFF0C52B3), Color(0xFF093F8A)]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              'Finish',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A live-session card that ticks every second to show a live countdown
/// and swaps the button to "Enter the session" once the session time arrives.
class _CourseSessionCard extends StatefulWidget {
  final Map<String, dynamic> session;
  final String Function(String) formatDate;

  const _CourseSessionCard({
    required this.session,
    required this.formatDate,
  });

  @override
  State<_CourseSessionCard> createState() => _CourseSessionCardState();
}

class _CourseSessionCardState extends State<_CourseSessionCard> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _sessionStarted = false;

  @override
  void initState() {
    super.initState();
    _computeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _computeRemaining();
    });
  }

  void _computeRemaining() {
    final session = widget.session;
    final startRaw = session['start_date']?.toString() ??
        session['start_time']?.toString() ??
        session['date']?.toString() ??
        session['scheduled_at']?.toString() ??
        '';
    final isLiveStatus = session['status'] == 'live' ||
        session['status'] == 'live_now' ||
        session['is_live'] == true;
    final isPastStatus = session['status'] == 'past' ||
        session['status'] == 'ended' ||
        session['status'] == 'completed';

    if (isLiveStatus || isPastStatus) {
      setState(() {
        _remaining = Duration.zero;
        _sessionStarted = true;
      });
      return;
    }

    if (startRaw.isEmpty) {
      setState(() => _sessionStarted = false);
      return;
    }

    final startDt = DateTime.tryParse(startRaw);
    if (startDt == null) {
      setState(() => _sessionStarted = false);
      return;
    }

    final diff = startDt.difference(DateTime.now());
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
      _sessionStarted = diff.isNegative || diff == Duration.zero;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _openJoinUrl() async {
    final session = widget.session;
    final rawUrl = session['join_url']?.toString() ??
        session['meeting_link']?.toString() ??
        session['meeting_url']?.toString() ??
        session['zoom_link']?.toString() ??
        session['platformLink']?.toString() ??
        session['platform_link']?.toString() ??
        '';
    if (rawUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.sessionLinkUnavailable),
          ),
        );
      }
      return;
    }
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;
    final didLaunch = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!didLaunch && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.sessionLinkUnavailable),
        ),
      );
    }
  }

  void _handlePaidLockedTap(Map<String, dynamic> session) {
    if (!mounted) return;
    final meta = parseCourseLiveMeta(session['description']?.toString());
    final courseId = session['course_id']?.toString() ??
        session['courseId']?.toString() ??
        session['course']?['id']?.toString() ??
        meta.courseId ??
        session['id']?.toString() ??
        '';
    final title = session['title']?.toString().trim().isNotEmpty == true
        ? session['title'].toString()
        : (meta.courseTitle ?? AppLocalizations.of(context)!.liveSession);
    final price = (session['price'] is num)
        ? (session['price'] as num).toDouble()
        : (double.tryParse(session['price']?.toString() ?? '') ?? 0.0);
    final currency =
        session['currency']?.toString() ?? session['currency_code']?.toString() ?? 'EGP';

    context.push(
      RouteNames.checkout,
      extra: {
        'id': courseId,
        'title': title,
        'price': price,
        'currency': currency,
        'is_free': false,
        'live_session_id': session['id']?.toString(),
        'live_session_price': price,
        'checkout_for': 'live_session',
      },
    );
  }

  bool _isPaidSession(Map<String, dynamic> session) {
    final isFreeValue = session['is_free'];
    if (isFreeValue != null) {
      final normalized = isFreeValue.toString().trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return false;
      }
      return true;
    }
    final amountCandidates = [
      session['price'],
      session['amount'],
      session['session_price'],
      session['price_amount'],
      session['cost'],
    ];
    for (final raw in amountCandidates) {
      final parsed = raw is num ? raw : num.tryParse(raw?.toString() ?? '');
      if (parsed != null && parsed > 0) return true;
    }
    return false;
  }

  String _countdownLabel() {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = widget.session;

    final title = session['title']?.toString().trim().isNotEmpty == true
        ? session['title'].toString()
        : l10n.liveSession;
    final plainDescription =
        session['plain_description']?.toString().trim() ?? '';
    final instructor = session['instructor'] is Map
        ? (session['instructor'] as Map)['name']?.toString() ?? l10n.instructor
        : (session['instructor']?.toString() ?? l10n.instructor);
    final startRaw = session['start_date']?.toString() ??
        session['start_time']?.toString() ??
        session['date']?.toString() ??
        session['scheduled_at']?.toString() ??
        '';
    final isLiveStatus = session['status'] == 'live' ||
        session['status'] == 'live_now' ||
        session['is_live'] == true;
    final isPastStatus = session['status'] == 'past' ||
        session['status'] == 'ended' ||
        session['status'] == 'completed';
    final isLockedPaid = _isPaidSession(session);
    final bool isEnded = isPastStatus || (_sessionStarted && !isLiveStatus);
    final bool canEnter =
        (isLiveStatus || _sessionStarted) && !isEnded && !isLockedPaid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isLiveStatus
                      ? Colors.red.withOpacity(0.1)
                      : isPastStatus || (_sessionStarted && !isLiveStatus)
                          ? Colors.grey.withOpacity(0.12)
                          : AppColors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isLiveStatus
                      ? l10n.liveNow
                      : isLockedPaid
                          ? l10n.paid
                      : isPastStatus || (_sessionStarted && !isLiveStatus)
                          ? (Localizations.localeOf(context).languageCode == 'ar'
                              ? 'منتهية'
                              : 'Ended')
                          : l10n.upcoming,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isLiveStatus
                        ? Colors.red
                        : isLockedPaid
                            ? const Color(0xFFB45309)
                        : isPastStatus || (_sessionStarted && !isLiveStatus)
                            ? Colors.grey.shade600
                            : AppColors.purple,
                  ),
                ),
              ),
            ],
          ),
          if (plainDescription.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              plainDescription,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 14, color: AppColors.mutedForeground),
                  const SizedBox(width: 4),
                  Text(
                    startRaw.isEmpty
                        ? l10n.undefinedDate
                        : widget.formatDate(startRaw),
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.mutedForeground),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 14, color: AppColors.mutedForeground),
                  const SizedBox(width: 4),
                  Text(
                    instructor,
                    style: GoogleFonts.cairo(
                        fontSize: 11, color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLockedPaid
                  ? () => _handlePaidLockedTap(session)
                  : (canEnter ? _openJoinUrl : null),
              icon: Icon(
                isLockedPaid
                    ? Icons.lock_rounded
                    : isEnded
                    ? Icons.event_busy_rounded
                    : canEnter
                    ? Icons.play_arrow_rounded
                    : Icons.access_time_rounded,
                size: 18,
              ),
              label: Text(
                isLockedPaid
                    ? l10n.completePurchase
                    : isEnded
                    ? 'Session ended'
                    : canEnter
                        ? l10n.joinNow
                        : _remaining == Duration.zero
                            ? l10n.remindMe
                            : _countdownLabel(),
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLockedPaid
                    ? const Color(0xFFF59E0B)
                    : isEnded
                    ? Colors.grey
                    : canEnter
                        ? Colors.green
                        : AppColors.purple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: isEnded ? Colors.grey : AppColors.purple,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
