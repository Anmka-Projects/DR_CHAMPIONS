import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/course_pricing.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_radius.dart';
import '../../core/navigation/route_names.dart';
import '../../core/api/api_endpoints.dart';
import '../../widgets/instructor_bottom_nav.dart';
import '../../services/profile_service.dart';
import '../../services/teacher_dashboard_service.dart';
import '../../l10n/app_localizations.dart';

/// Instructor – My Courses list. Same theme as student flow.
class InstructorCoursesScreen extends StatefulWidget {
  const InstructorCoursesScreen({super.key});

  @override
  State<InstructorCoursesScreen> createState() =>
      _InstructorCoursesScreenState();
}

class _InstructorCoursesScreenState extends State<InstructorCoursesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _courses = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text != _searchQuery && mounted) {
        setState(() => _searchQuery = _searchController.text);
      }
    });
  }

  List<Map<String, dynamic>> get _displayCourses {
    if (_searchQuery.trim().isEmpty) return _courses;
    final q = _searchQuery.trim().toLowerCase();
    return _courses.where((c) {
      final title = c['title']?.toString().toLowerCase() ?? '';
      final category = c['category'] is Map
          ? ((c['category'] as Map)['name']?.toString() ??
                  (c['category'] as Map)['nameAr']?.toString() ??
                  '')
              .toLowerCase()
          : (c['categoryName']?.toString() ?? c['category']?.toString() ?? '')
              .toLowerCase();
      final level = (c['level']?.toString() ?? c['levelName']?.toString() ?? '')
          .toLowerCase();
      return title.contains(q) || category.contains(q) || level.contains(q);
    }).toList();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final profile = await ProfileService.instance.getProfile();
      final userId = profile['id']?.toString() ?? '';
      if (userId.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load profile';
        });
        return;
      }
      final data = await TeacherDashboardService.instance.getMyCourses(
        instructorId: userId,
        limit: 50,
      );
      if (kDebugMode) {
        print('═══════════════════════════════════════════════════════════');
        print('📋 INSTRUCTOR COURSES RESPONSE');
        print('═══════════════════════════════════════════════════════════');
        print('👤 instructorId: $userId');
        print('🔑 Top-level keys: ${data.keys.toList()}');
        final rawList = data['data'] ?? data['courses'] ?? data;
        if (rawList is List) {
          print('📦 Total courses: ${rawList.length}');
          for (var i = 0; i < rawList.length; i++) {
            final course = rawList[i];
            if (course is Map) {
              final m = Map<String, dynamic>.from(course as Map);
              print(
                  '──────────────────────────────────────────────────────────');
              print('📚 Course #${i + 1}');
              print('  id: ${m['id']}');
              print('  title: ${m['title']}');
              print(
                  '  status: ${m['status'] ?? m['courseStatus'] ?? m['state']}');
              print('  price: ${m['price']}');
              print('  is_free: ${m['is_free'] ?? m['isFree'] ?? m['free']}');
              print('  level: ${m['level'] ?? m['levelName']}');
              print('  category: ${m['categoryName'] ?? m['category']}');
              print('  studentsCount: ${m['studentsCount']}');
              print(
                  '  lessonsCount: ${m['lessonsCount'] ?? (m['lessons'] as List?)?.length}');
            }
          }
        } else {
          print(
              '⚠️ Unexpected data format for courses list: ${rawList.runtimeType}');
        }
        print('═══════════════════════════════════════════════════════════');
      }
      final list = data['data'] ?? data;
      if (list is List) {
        setState(() {
          _courses =
              list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ InstructorCoursesScreen: $e');
      }
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.beige,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                _buildHeader(context, isAr, l10n),
                Expanded(
                  child: _errorMessage != null
                      ? _buildError(l10n)
                      : _isLoading
                          ? _buildCoursesSkeleton()
                          : _displayCourses.isEmpty
                              ? _buildEmpty(isAr)
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      20, 20, 20, 140),
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: _displayCourses.length,
                                  itemBuilder: (context, index) {
                                    final c = _displayCourses[index];
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: _buildCourseCard(c, isAr),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
          const InstructorBottomNav(activeTab: 'courses'),
        ],
      ),
    );
  }

  /// Header like all_courses_screen: back button, title, count, and search bar.
  Widget _buildHeader(BuildContext context, bool isAr, AppLocalizations l10n) {
    final title = isAr ? 'دوراتي' : l10n.myCourses;
    final count = _displayCourses.length;

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
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      child: Column(
        children: [
          // Title Row with back button
          Row(
            children: [
              GestureDetector(
                onTap: () => context.go(RouteNames.instructorHome),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                      title,
                      style: GoogleFonts.cairo(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      l10n.coursesAvailable(count),
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.cairo(fontSize: 14),
              decoration: InputDecoration(
                hintText: l10n.searchCourse,
                hintStyle: GoogleFonts.cairo(
                    color: AppColors.mutedForeground, fontSize: 14),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(right: 16, left: 12),
                  child: Icon(Icons.search_rounded,
                      color: AppColors.purple, size: 24),
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _levelColor(String lv) {
    final lower = lv.toLowerCase();
    if (lower.contains('beginner') || lower.contains('مبتدئ'))
      return const Color(0xFF22C55E);
    if (lower.contains('intermediate') || lower.contains('متوسط'))
      return const Color(0xFFF59E0B);
    if (lower.contains('advanced') || lower.contains('متقدم'))
      return const Color(0xFFEF4444);
    return AppColors.purple;
  }

  Widget _buildStatChip(
    BuildContext context,
    IconData icon,
    String value,
    Color color,
    bool isAr,
  ) {
    return Row(
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
    );
  }

  Widget _buildStudentsChip(
    BuildContext context,
    Map<String, dynamic> course,
    int studentsCount,
    bool isAr,
  ) {
    final color = const Color(0xFF3B82F6);
    return GestureDetector(
      onTap: () => _showCourseStudentsSheet(
        context,
        course,
        isAr,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            isAr ? '$studentsCount طالب' : '$studentsCount students',
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.arrow_forward_ios_rounded, size: 10, color: color),
        ],
      ),
    );
  }

  Future<void> _showCourseStudentsSheet(
    BuildContext context,
    Map<String, dynamic> course,
    bool isAr,
  ) async {
    final courseId = course['id']?.toString();
    final courseTitle =
        course['title']?.toString() ?? (isAr ? 'الدورة' : 'Course');
    if (courseId == null || courseId.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.people_rounded,
                        color: AppColors.purple, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAr ? 'طلاب الدورة' : 'Course Students',
                            style: GoogleFonts.cairo(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            courseTitle,
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              color: AppColors.mutedForeground,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: TeacherDashboardService.instance.getAttendance(
                    courseId: courseId,
                    action: 'course-enrollments',
                  ),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                isAr
                                    ? 'حدث خطأ في تحميل قائمة الطلاب'
                                    : 'Failed to load students',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  color: AppColors.mutedForeground,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final data = snap.data ?? {};
                    final list = data['data'] is List
                        ? data['data'] as List
                        : data['enrollments'] is List
                            ? data['enrollments'] as List
                            : data['students'] is List
                                ? data['students'] as List
                                : const [];
                    if (list.isEmpty) {
                      return Center(
                        child: Text(
                          isAr
                              ? 'لا يوجد طلاب مسجلين في هذه الدورة'
                              : 'No students enrolled in this course',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: AppColors.mutedForeground,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final m = list[i] is Map
                            ? Map<String, dynamic>.from(list[i] as Map)
                            : <String, dynamic>{};
                        final user = m['user'] is Map
                            ? Map<String, dynamic>.from(m['user'] as Map)
                            : m;
                        final student = m['student'] is Map
                            ? Map<String, dynamic>.from(m['student'] as Map)
                            : m;
                        final name = user['name']?.toString() ??
                            user['fullName']?.toString() ??
                            student['name']?.toString() ??
                            student['fullName']?.toString() ??
                            m['name']?.toString() ??
                            (isAr ? 'طالب ${i + 1}' : 'Student ${i + 1}');
                        final email = user['email']?.toString() ??
                            student['email']?.toString() ??
                            m['email']?.toString() ??
                            '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.purple.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.purple.withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor:
                                      AppColors.purple.withOpacity(0.2),
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: GoogleFonts.cairo(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.purple,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.cairo(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.foreground,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (email.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          email,
                                          style: GoogleFonts.cairo(
                                            fontSize: 13,
                                            color: AppColors.mutedForeground,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Image on side: fixed 80x80, rounded corners. Matches instructor_home_screen.
  Widget _buildCourseCardImage(bool isAr, String? imageUrl, bool isFeatured) {
    const size = 80.0;
    final borderRadius = BorderRadius.circular(12);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: borderRadius,
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    ApiEndpoints.getImageUrl(imageUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _buildCourseImagePlaceholder(),
                  )
                : _buildCourseImagePlaceholder(),
          ),
          if (isFeatured)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade600,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(Icons.star_rounded,
                    color: Colors.white, size: 14),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDurationAsHoursMinutes(dynamic durationRaw, bool isAr) {
    if (durationRaw == null) return '';
    int totalMinutes = 0;
    if (durationRaw is num) {
      final n = durationRaw.toDouble();
      if (n >= 60 && n == n.round()) {
        totalMinutes = n.toInt();
      } else {
        totalMinutes = (n * 60).round();
      }
    } else if (durationRaw is String) {
      final s = durationRaw.trim();
      final parsed = num.tryParse(s);
      if (parsed != null) {
        if (parsed >= 60 && parsed == parsed.truncate()) {
          totalMinutes = parsed.toInt();
        } else {
          totalMinutes = (parsed * 60).round();
        }
      }
    }
    if (totalMinutes <= 0) return '';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (isAr) {
      if (h > 0 && m > 0) return '$h س $m د';
      if (h > 0) return '$h س';
      return '$m د';
    }
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  Widget _buildCourseImagePlaceholder() {
    return Container(
      color: AppColors.purple.withOpacity(0.12),
      child: const Icon(
        Icons.menu_book_rounded,
        size: 40,
        color: AppColors.purple,
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> c, bool isAr) {
    final title = c['title']?.toString() ?? '';
    final level = c['level']?.toString() ?? c['levelName']?.toString() ?? '';
    final rawStatus =
        (c['status'] ?? c['courseStatus'] ?? c['state'])?.toString() ?? '';
    final status = rawStatus.toLowerCase();
    final category = c['category'] is Map
        ? (c['category'] as Map)['name']?.toString() ??
            (c['category'] as Map)['nameAr']?.toString() ??
            ''
        : c['categoryName']?.toString() ?? c['category']?.toString() ?? '';
    final price = (c['price'] as num?)?.toDouble();
    final hasPaidCourse = courseHasPaidAmount(c);
    final durationRaw =
        c['duration'] ?? c['durationHours'] ?? c['durationMinutes'];
    final durationStr = _formatDurationAsHoursMinutes(durationRaw, isAr);
    final studentsCount = (c['studentsCount'] as num?)?.toInt() ?? 0;
    final lessonsCount = (c['lessonsCount'] as num?)?.toInt() ??
        (c['lessons'] as List?)?.length ??
        (c['lecturesCount'] as num?)?.toInt() ??
        0;
    final isFeatured = c['featured'] == true ||
        c['isFeatured'] == true ||
        c['is_featured'] == true;
    final imageUrl = c['image']?.toString() ??
        c['thumbnail']?.toString() ??
        c['coverImage']?.toString();

    return InkWell(
      onTap: () => context.push(RouteNames.instructorCourseDetails, extra: c),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            //  crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCourseCardImage(isAr, imageUrl, isFeatured),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 0, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.foreground,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (level.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _levelColor(level).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _levelColor(level).withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                level,
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _levelColor(level),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (category.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.category_rounded,
                                size: 14, color: AppColors.purple),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                category,
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.purple,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          if (status.isNotEmpty)
                            _buildStatChip(
                              context,
                              status == 'published'
                                  ? Icons.check_circle_rounded
                                  : status == 'draft'
                                      ? Icons.edit_rounded
                                      : Icons.archive_rounded,
                              () {
                                if (status == 'published') {
                                  return isAr ? 'منشورة' : 'Published';
                                }
                                if (status == 'draft') {
                                  return isAr ? 'مسودة' : 'Draft';
                                }
                                if (status == 'archived') {
                                  return isAr ? 'مؤرشفة' : 'Archived';
                                }
                                return rawStatus;
                              }(),
                              () {
                                if (status == 'published') {
                                  return const Color(0xFF16A34A);
                                }
                                if (status == 'draft') {
                                  return const Color(0xFFD97706);
                                }
                                if (status == 'archived') {
                                  return const Color(0xFF4B5563);
                                }
                                return AppColors.purple;
                              }(),
                              isAr,
                            ),
                          if (!hasPaidCourse)
                            _buildStatChip(
                              context,
                              Icons.workspace_premium_rounded,
                              isAr ? 'مجانية' : 'Free',
                              const Color(0xFF22C55E),
                              isAr,
                            ),
                          if (hasPaidCourse && price != null && price > 0)
                            _buildStatChip(
                              context,
                              Icons.payments_rounded,
                              '${price.toInt()} ${isAr ? 'ج.م' : 'EGP'}',
                              const Color(0xFF0C52B3),
                              isAr,
                            ),
                          if (hasPaidCourse && (price == null || price == 0))
                            _buildStatChip(
                              context,
                              Icons.payments_rounded,
                              isAr ? 'مدفوع' : 'Paid',
                              const Color(0xFF0C52B3),
                              isAr,
                            ),
                          if (durationStr.isNotEmpty)
                            _buildStatChip(
                              context,
                              Icons.schedule_rounded,
                              durationStr,
                              const Color(0xFF64748B),
                              isAr,
                            ),
                          _buildStudentsChip(
                            context,
                            c,
                            studentsCount,
                            isAr,
                          ),
                          _buildStatChip(
                            context,
                            Icons.play_circle_outline_rounded,
                            isAr
                                ? '$lessonsCount دروس'
                                : '$lessonsCount lessons',
                            const Color(0xFF14B8A6),
                            isAr,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoursesSkeleton() {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
        physics: const BouncingScrollPhysics(),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            height: 16,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 16,
                            width: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 16,
                            width: 45,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
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
        },
      ),
    );
  }

  Widget _buildEmpty(bool isAr) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            isAr ? 'لا توجد دورات' : 'No courses yet',
            style: GoogleFonts.cairo(
                fontSize: 16, color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.destructive),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                  fontSize: 14, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _loadCourses,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry, style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }
}
