import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../core/course_pricing.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_radius.dart';
import '../../core/api/api_endpoints.dart';

import '../../services/teacher_dashboard_service.dart';
import '../../core/navigation/route_names.dart';
import '../../widgets/instructor_question_banks_panel.dart';

/// Instructor – Course details (uses GET /api/admin/courses/:id).
/// Shows course overview, stats, sections, and enrolled students
/// with a teacher-focused, read-only UI.
class InstructorCourseDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? course;

  const InstructorCourseDetailsScreen({super.key, this.course});

  @override
  State<InstructorCourseDetailsScreen> createState() =>
      _InstructorCourseDetailsScreenState();
}

class _InstructorCourseDetailsScreenState
    extends State<InstructorCourseDetailsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _course;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _sections = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCourse();
  }

  Future<void> _loadCourse() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final initial = _course ?? widget.course ?? {};
      final courseId = (initial['id'] ?? initial['courseId'])?.toString();
      if (courseId == null || courseId.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Course ID is missing';
        });
        return;
      }
      final data =
          await TeacherDashboardService.instance.getCourseDetails(courseId);
      if (!mounted) return;
      final studentsRaw = data['students'];
      final sectionsRaw = data['sections'];
      _students = studentsRaw is List
          ? studentsRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : [];
      _sections = sectionsRaw is List
          ? sectionsRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : [];
      setState(() {
        _course = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) {
        print('❌ InstructorCourseDetailsScreen.loadCourse: $e');
      }
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final course = _course ?? widget.course ?? {};

    final priceValue = tryParseCourseNum(course['price']) ?? 0.0;
    final finalIsFree = courseIsEffectivelyFree(course);

    return Scaffold(
      backgroundColor: AppColors.beige,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.purple,
              ),
            )
          : _errorMessage != null
              ? _buildError(isAr)
              : SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Header image section with course thumbnail & title
                        _buildVideoSection(course, isAr),

                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                          ),
                          child: Column(
                            children: [
                              _buildCourseHeader(
                                  course, finalIsFree, priceValue),
                              const SizedBox(height: 12),
                              _buildTabs(isAr),
                              const SizedBox(height: 12),
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.6,
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    // Technical details + description
                                    _buildCourseDetailsTab(
                                        context, course, isAr),
                                    // Sessions
                                    _buildSessionsTab(course, isAr),
                                    // Students
                                    _buildStudentsTab(isAr),
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
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildTabs(bool isAr) {
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
          Tab(
            icon: const Icon(Icons.info_rounded, size: 18),
            text: isAr ? 'بيانات + وصف' : 'Details & desc',
          ),
          Tab(
            icon: const Icon(Icons.view_list_rounded, size: 18),
            text: isAr ? 'الجلسات' : 'Sessions',
          ),
          Tab(
            icon: const Icon(Icons.people_alt_rounded, size: 18),
            text: isAr ? 'الطلاب' : 'Students',
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection(Map<String, dynamic> course, bool isAr) {
    final rawThumb = course['thumbnail']?.toString() ??
        course['image']?.toString() ??
        course['banner']?.toString();
    final thumbnail = (rawThumb != null && rawThumb.isNotEmpty)
        ? ApiEndpoints.getImageUrl(
            rawThumb,
          )
        : null;
    final title =
        course['title']?.toString() ?? (isAr ? 'عنوان الدورة' : 'Course title');

    return Container(
      height: 300,
      color: Colors.black,
      child: Stack(
        children: [
          // Thumbnail Image
          if (thumbnail != null && thumbnail.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                thumbnail,
                fit: BoxFit.fill,
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
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),

          // Back button & title overlay
          Positioned(
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () => GoRouter.of(context).pop(),
                  ),
                ),
                SizedBox(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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

  Widget _buildCourseHeader(
      Map<String, dynamic>? course, bool isFree, num price) {
    if (course == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Badge & Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  course['categoryName'] == null || course['categoryName'] == ''
                      ? 'التصميم'
                      : course['categoryName']?.toString() ?? 'التصميم',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.purple,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isFree
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [const Color(0xFFF97316), const Color(0xFFEA580C)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isFree ? 'مجاني' : '${price.toInt()} ج.م',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title + status
          Row(
            children: [
              Expanded(
                child: Text(
                  course['title']?.toString() ?? 'عنوان الدورة',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusChip(course,
                  isAr: Localizations.localeOf(context).languageCode == 'ar'),
              if (course['isFeatured'] == true ||
                  course['featured'] == true ||
                  course['is_featured'] == true) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.95),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ],
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
                course['instructor'] is Map
                    ? (course['instructor'] as Map)['name']?.toString() ??
                        'المدرب'
                    : course['instructor']?.toString() ??
                        course['instructorName']?.toString() ??
                        'المدرب',
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
                _safeParseCount(course['studentsCount'] ??
                    course['students_count'] ??
                    course['students']),
                AppColors.purple,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                Icons.access_time_rounded,
                '${_safeParseHours(_deriveDurationHours(course))}س',
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

  /// Derive course duration in hours from multiple possible fields.
  /// - Prefer explicit hours fields (duration_hours / hours)
  /// - Fallback to `duration` in minutes from admin/instructor API.
  int _deriveDurationHours(Map<String, dynamic> course) {
    final directHours =
        _safeParseHours(course['duration_hours'] ?? course['hours']);
    if (directHours > 0) return directHours;

    final minutes = (course['duration'] as num?)?.toInt();
    if (minutes == null || minutes <= 0) return 0;

    // Round up to the nearest hour so 97 minutes -> 2h
    return (minutes / 60).ceil();
  }

  Widget _buildStatusChip(Map<String, dynamic> course, {required bool isAr}) {
    final rawStatus = (course['status'] ?? '').toString().toLowerCase();
    if (rawStatus.isEmpty) return const SizedBox.shrink();

    String label;
    Color color;
    Color bg;

    switch (rawStatus) {
      case 'published':
        label = isAr ? 'منشورة' : 'Published';
        color = const Color(0xFF16A34A);
        bg = const Color(0xFF22C55E).withOpacity(0.12);
        break;
      case 'draft':
        label = isAr ? 'مسودة' : 'Draft';
        color = const Color(0xFFD97706);
        bg = const Color(0xFFF59E0B).withOpacity(0.12);
        break;
      case 'archived':
        label = isAr ? 'مؤرشفة' : 'Archived';
        color = const Color(0xFF4B5563);
        bg = const Color(0xFF6B7280).withOpacity(0.12);
        break;
      default:
        label = rawStatus;
        color = AppColors.purple;
        bg = AppColors.purple.withOpacity(0.08);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            rawStatus == 'published'
                ? Icons.check_circle_rounded
                : rawStatus == 'draft'
                    ? Icons.edit_rounded
                    : Icons.info_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(bool isAr) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.destructive,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? (isAr ? 'حدث خطأ ما' : 'Something went wrong'),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _loadCourse,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                isAr ? 'إعادة المحاولة' : 'Retry',
                style: GoogleFonts.cairo(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseDetailsTab(
      BuildContext context, Map<String, dynamic> course, bool isAr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((course['description']?.toString().isNotEmpty ?? false))
            _buildSectionCard(
              isAr: isAr,
              icon: Icons.notes_rounded,
              title: isAr ? 'وصف الدورة' : 'Course description',
              child: Text(
                course['description']?.toString() ?? '',
                textAlign: TextAlign.start,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.foreground,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionsTab(Map<String, dynamic> course, bool isAr) {
    final courseId = (course['id'] ?? course['courseId'])?.toString() ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (courseId.isNotEmpty) const SizedBox(height: 20),
          if (courseId.isNotEmpty) _buildAddSectionBlock(courseId, isAr),
          if (courseId.isNotEmpty) const SizedBox(height: 12),
          if (courseId.isNotEmpty)
            InstructorQuestionBanksPanel(courseId: courseId, isAr: isAr),
          if (courseId.isNotEmpty) const SizedBox(height: 12),
          _sections.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      isAr
                          ? 'لا توجد جلسات / أقسام بعد'
                          : 'No sessions/sections yet',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                )
              : _buildSectionsCard(course, isAr),
        ],
      ),
    );
  }

  /// Add curriculum section (قسم المنهج) above the sections list.
  Widget _buildAddSectionBlock(String courseId, bool isAr) {
    return _AddSectionBlock(
      courseId: courseId,
      isAr: isAr,
      sectionsCount: _sections.length,
      onAdded: _loadCourse,
    );
  }

  Widget _buildLecturesCard(String courseId, bool isAr) {
    return _LecturesCard(courseId: courseId, isAr: isAr);
  }

  Widget _buildStudentsTab(bool isAr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: _buildStudentsCard(isAr),
    );
  }

  /// Key-value technical details card so teacher can see all important fields
  /// coming from the admin course details API (id, instructor, dates, flags...).
  Widget _buildMetaCard(Map<String, dynamic> course, bool isAr) {
    final rows = <Widget>[];

    void addRow(String label, dynamic value) {
      if (value == null) return;
      final text = value.toString();
      if (text.isEmpty) return;
      rows.add(_buildMetaRow(label, text));
    }

    addRow(isAr ? 'الحالة' : 'Status', course['status']);
    addRow(isAr ? 'مميّزة؟' : 'Featured?', course['isFeatured']);
    addRow(isAr ? 'التصنيف' : 'Category', course['categoryName']);
    addRow(isAr ? 'المعلّم' : 'Instructor', course['instructorName']);
    addRow(isAr ? 'تاريخ الإنشاء' : 'Created at', course['createdAt']);
    addRow(isAr ? 'تاريخ التحديث' : 'Updated at', course['updatedAt']);
    addRow(isAr ? 'عدد التقييمات' : 'Ratings count', course['ratingsCount']);
    addRow(isAr ? 'عدد الطلاب' : 'Students count', course['studentsCount']);
    addRow(isAr ? 'عدد الدروس' : 'Lessons count', course['lessonsCount']);

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
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
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_rounded,
                  size: 18,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isAr ? 'تفاصيل تقنية' : 'Technical details',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCard({
    required BuildContext context,
    required bool isAr,
    required String title,
    required String level,
    required String category,
    required String status,
    required double? price,
    required bool isFree,
    required double? rating,
    required int studentsCount,
    required int lessonsCount,
    required int durationMinutes,
    required String? thumbnail,
  }) {
    final imageUrl = thumbnail != null && thumbnail.isNotEmpty
        ? ApiEndpoints.getImageUrl(
            thumbnail,
          )
        : null;
    String statusLabel = '';
    Color statusColor = AppColors.purple;
    Color statusBg = AppColors.purple.withOpacity(0.08);

    if (status.isNotEmpty) {
      if (status == 'published') {
        statusLabel = isAr ? 'منشورة' : 'Published';
        statusColor = const Color(0xFF16A34A);
        statusBg = const Color(0xFF22C55E).withOpacity(0.12);
      } else if (status == 'draft') {
        statusLabel = isAr ? 'مسودة' : 'Draft';
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFF59E0B).withOpacity(0.12);
      } else if (status == 'archived') {
        statusLabel = isAr ? 'مؤرشفة' : 'Archived';
        statusColor = const Color(0xFF4B5563);
        statusBg = const Color(0xFF6B7280).withOpacity(0.12);
      } else {
        statusLabel = status;
      }
    }

    String durationText = '';
    if (durationMinutes > 0) {
      final h = durationMinutes ~/ 60;
      final m = durationMinutes % 60;
      if (isAr) {
        if (h > 0 && m > 0) {
          durationText = '$h س $m د';
        } else if (h > 0) {
          durationText = '$h س';
        } else {
          durationText = '$m د';
        }
      } else {
        if (h > 0 && m > 0) {
          durationText = '${h}h ${m}m';
        } else if (h > 0) {
          durationText = '${h}h';
        } else {
          durationText = '${m}m';
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 88,
                  height: 88,
                  color: AppColors.purple.withOpacity(0.08),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.menu_book_rounded,
                            color: AppColors.purple.withOpacity(0.7),
                            size: 40,
                          ),
                        )
                      : Icon(
                          Icons.menu_book_rounded,
                          color: AppColors.purple.withOpacity(0.7),
                          size: 40,
                        ),
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.foreground,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (level.isNotEmpty)
                          _buildChip(
                            icon: Icons.bar_chart_rounded,
                            label: level,
                            color: const Color(0xFF0C52B3),
                          ),
                        if (category.isNotEmpty)
                          _buildChip(
                            icon: Icons.category_rounded,
                            label: category,
                            color: AppColors.purple,
                          ),
                        if (statusLabel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: statusColor.withOpacity(0.8),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  status == 'published'
                                      ? Icons.check_circle_rounded
                                      : status == 'draft'
                                          ? Icons.edit_rounded
                                          : Icons.archive_rounded,
                                  size: 14,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusLabel,
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatTile(
                icon: Icons.people_rounded,
                label: isAr ? 'الطلاب' : 'Students',
                value: studentsCount.toString(),
                color: const Color(0xFF3B82F6),
              ),
              _buildStatTile(
                icon: Icons.play_circle_outline_rounded,
                label: isAr ? 'الدروس' : 'Lessons',
                value: lessonsCount.toString(),
                color: const Color(0xFF14B8A6),
              ),
              _buildStatTile(
                icon: Icons.schedule_rounded,
                label: isAr ? 'المدة' : 'Duration',
                value: durationText.isEmpty ? (isAr ? '-' : '-') : durationText,
                color: const Color(0xFF64748B),
              ),
              _buildStatTile(
                icon: Icons.star_rounded,
                label: isAr ? 'التقييم' : 'Rating',
                value: rating != null ? rating.toStringAsFixed(1) : '-',
                color: const Color(0xFFFACC15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text(
              isFree
                  ? (isAr ? 'الدورة مجانية' : 'This course is free')
                  : (price != null
                      ? (isAr
                          ? 'سعر الدورة: ${price.toInt()} ج.م'
                          : 'Price: ${price.toInt()} EGP')
                      : (isAr ? 'السعر غير محدد' : 'Price not set')),
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: isFree
                    ? const Color(0xFF16A34A)
                    : AppColors.mutedForeground,
                fontWeight: isFree ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isAr,
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.purple),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSectionsCard(Map<String, dynamic> course, bool isAr) {
    final courseId = (course['id'] ?? course['courseId'])?.toString() ?? '';
    return _buildSectionCard(
      isAr: isAr,
      icon: Icons.view_list_rounded,
      title: isAr ? 'الجلسات / الأقسام' : 'Sessions / sections',
      child: Column(
        children: _sections.map((section) {
          final title = section['title']?.toString() ??
              (isAr ? 'قسم بدون عنوان' : 'Untitled section');
          final lessons = (section['lessons'] as List?) ?? const [];
          return InkWell(
            onTap: courseId.isEmpty
                ? null
                : () async {
                    final result = await context.push<bool>(
                      RouteNames.instructorSessionDetails,
                      extra: {
                        'courseId': courseId,
                        'course': course,
                        'section': section,
                      },
                    );
                    if (result == true && mounted) await _loadCourse();
                  },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.purple.withOpacity(0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder_rounded,
                          size: 18, color: AppColors.purple),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAr
                            ? '${lessons.length} درس'
                            : '${lessons.length} lessons',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: AppColors.destructive,
                        ),
                        onPressed: () => _confirmDeleteSection(
                          context,
                          courseId,
                          section,
                          isAr,
                        ),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        tooltip: isAr ? 'حذف القسم' : 'Delete section',
                      ),
                    ],
                  ),
                  if (lessons.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Column(
                      children: lessons.map((l) {
                        final m = l is Map
                            ? Map<String, dynamic>.from(l as Map)
                            : <String, dynamic>{};
                        final t =
                            m['title']?.toString() ?? (isAr ? 'درس' : 'Lesson');
                        final isFree = m['isFree'] == true ||
                            m['is_free'] == true ||
                            m['free'] == true;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.play_circle_fill_rounded,
                                size: 16,
                                color: AppColors.purple.withOpacity(0.9),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  t,
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    color: AppColors.foreground,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isFree)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF22C55E)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    isAr ? 'مجاني' : 'Free',
                                    style: GoogleFonts.cairo(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _confirmDeleteSection(
    BuildContext context,
    String courseId,
    Map<String, dynamic> section,
    bool isAr,
  ) async {
    final sectionId = section['id']?.toString();
    if (sectionId == null || sectionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr
                ? 'لا يمكن حذف القسم: معرف غير متوفر'
                : 'Cannot delete: section id missing',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final sectionTitle =
        section['title']?.toString() ?? (isAr ? 'هذا القسم' : 'This section');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isAr ? 'حذف قسم المنهج' : 'Delete section',
          style: GoogleFonts.cairo(),
        ),
        content: Text(
          isAr
              ? 'هل أنت متأكد من حذف "$sectionTitle"؟ سيتم حذف كل الدروس فيه.'
              : 'Are you sure you want to delete "$sectionTitle"? All lessons in it will be removed.',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel', style: GoogleFonts.cairo()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            child: Text(isAr ? 'حذف' : 'Delete', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await TeacherDashboardService.instance.deleteCurriculumSection(
        courseId,
        sectionId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'تم حذف القسم بنجاح' : 'Section deleted successfully',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadCourse();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showEditParentPhoneDialog(
    BuildContext context,
    bool isAr,
    String studentName,
    String studentId,
    String currentPhone,
    void Function(String updated) onSaved,
  ) async {
    final controller = TextEditingController(text: currentPhone);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isAr ? 'تحديث رقم ولي الأمر' : 'Update Parent Phone',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              studentName,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: isAr ? 'رقم ولي الأمر' : 'Parent phone number',
                hintText: isAr ? '+201234567890' : '+201234567890',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              style: GoogleFonts.cairo(),
              onSubmitted: (_) => Navigator.of(ctx).pop(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final phone = controller.text.trim();
              try {
                await TeacherDashboardService.instance.updateStudentParentPhone(
                  studentId: studentId,
                  parentPhone: phone,
                );
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        isAr
                            ? 'تم تحديث رقم ولي الأمر'
                            : 'Parent phone updated',
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
                onSaved(phone);
              } catch (e) {
                if (kDebugMode) {
                  print('❌ updateStudentParentPhone: $e');
                }
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        isAr ? 'فشل التحديث' : 'Update failed',
                      ),
                      backgroundColor: AppColors.destructive,
                    ),
                  );
                }
              }
            },
            child: Text(isAr ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsCard(bool isAr) {
    return _buildSectionCard(
      isAr: isAr,
      icon: Icons.people_alt_rounded,
      title: isAr ? 'الطلاب المسجلون في الدورة' : 'Enrolled students in course',
      child: _students.isEmpty
          ? Text(
              isAr ? 'لا يوجد طلاب حتى الآن' : 'No students yet',
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            )
          : Column(
              children: _students.map((s) {
                final m = s;
                final name = m['name']?.toString() ??
                    m['fullName']?.toString() ??
                    (isAr ? 'طالب' : 'Student');
                final email = m['email']?.toString() ?? '';
                final progress = (m['progress'] as num?)?.toInt() ??
                    (m['completion'] as num?)?.toInt() ??
                    0;
                final avatar = m['avatar']?.toString();
                final avatarUrl = avatar != null && avatar.isNotEmpty
                    ? ApiEndpoints.getImageUrl(
                        avatar,
                      )
                    : null;
                final studentId = m['id']?.toString() ?? '';
                final parentPhone = m['parentPhone']?.toString() ??
                    m['parent_phone']?.toString() ??
                    '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.purple.withOpacity(0.15),
                        backgroundImage:
                            avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.purple,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.foreground,
                              ),
                            ),
                            if (email.isNotEmpty)
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            if (parentPhone.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.phone_outlined,
                                        size: 12,
                                        color: AppColors.mutedForeground),
                                    const SizedBox(width: 4),
                                    Text(
                                      parentPhone,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.cairo(
                                        fontSize: 11,
                                        color: AppColors.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (studentId.isNotEmpty)
                        GestureDetector(
                          onTap: () => _showEditParentPhoneDialog(
                            context,
                            isAr,
                            name,
                            studentId,
                            parentPhone,
                            (updated) {
                              final idx = _students.indexWhere((x) =>
                                  (x['id']?.toString() ?? '') == studentId);
                              if (idx >= 0) {
                                setState(() {
                                  _students[idx] = Map<String, dynamic>.from(
                                    _students[idx]
                                      ..['parentPhone'] = updated
                                      ..['parent_phone'] = updated,
                                  );
                                });
                              }
                            },
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.phone_in_talk_rounded,
                              size: 18,
                              color: AppColors.purple,
                            ),
                          ),
                        ),
                      if (studentId.isNotEmpty && progress > 0)
                        const SizedBox(width: 8),
                      if (progress > 0)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$progress%',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.purple,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SizedBox(
                              width: 60,
                              height: 4,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: (progress.clamp(0, 100)) / 100,
                                  backgroundColor:
                                      AppColors.purple.withOpacity(0.12),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          AppColors.purple),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

/// Add curriculum section block – above sections list. Calls API then [onAdded].
class _AddSectionBlock extends StatefulWidget {
  final String courseId;
  final bool isAr;
  final int sectionsCount;
  final VoidCallback onAdded;

  const _AddSectionBlock({
    required this.courseId,
    required this.isAr,
    required this.sectionsCount,
    required this.onAdded,
  });

  @override
  State<_AddSectionBlock> createState() => _AddSectionBlockState();
}

class _AddSectionBlockState extends State<_AddSectionBlock> {
  bool _adding = false;

  Future<void> _addSection() async {
    final isAr = widget.isAr;
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isAr ? 'إضافة قسم المنهج' : 'Add curriculum section',
          style: GoogleFonts.cairo(),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: isAr ? 'عنوان القسم' : 'Section title',
            border: const OutlineInputBorder(),
          ),
          style: GoogleFonts.cairo(),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إلغاء' : 'Cancel', style: GoogleFonts.cairo()),
          ),
          FilledButton(
            onPressed: () {
              final t = controller.text.trim();
              if (t.isNotEmpty) Navigator.pop(ctx, t);
            },
            child: Text(isAr ? 'إضافة' : 'Add', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
    if (title == null || title.isEmpty || !mounted) return;
    setState(() => _adding = true);
    try {
      await TeacherDashboardService.instance.addCurriculumSection(
        widget.courseId,
        title: title,
        order: widget.sectionsCount + 1,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'تم إضافة القسم بنجاح' : 'Section added successfully',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onAdded();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Icon(Icons.add_circle_outline_rounded,
              color: AppColors.purple, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAr ? 'إضافة قسم المنهج' : 'Add curriculum section',
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: _adding ? null : _addSection,
            icon: _adding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_rounded, size: 18),
            label: Text(
              isAr ? 'إضافة قسم' : 'Add section',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card to fetch lectures (GET /api/admin/courses/:id/lectures)
class _LecturesCard extends StatefulWidget {
  final String courseId;
  final bool isAr;

  const _LecturesCard({required this.courseId, required this.isAr});

  @override
  State<_LecturesCard> createState() => _LecturesCardState();
}

class _LecturesCardState extends State<_LecturesCard> {
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _fetchLectures() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final res = await TeacherDashboardService.instance
          .getCourseLectures(widget.courseId);
      if (mounted) {
        setState(() {
          _loading = false;
          _result = res;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.video_library_rounded,
                  color: AppColors.purple, size: 22),
              const SizedBox(width: 10),
              Text(
                widget.isAr ? 'المحاضرات' : 'Lectures',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _fetchLectures,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.list_rounded, size: 20),
              label: Text(
                widget.isAr ? 'جلب المحاضرات' : 'Load lectures',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.destructive.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: AppColors.destructive, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: AppColors.destructive,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.isAr
                    ? 'تم جلب المحاضرات بنجاح'
                    : 'Lectures loaded successfully',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
