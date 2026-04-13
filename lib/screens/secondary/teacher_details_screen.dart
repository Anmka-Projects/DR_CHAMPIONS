import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_radius.dart';
import '../../core/navigation/route_names.dart';
import '../../data/sample_teachers.dart';
import '../../l10n/app_localizations.dart';
import '../../services/teachers_service.dart';
import '../../services/chat_service.dart';

class TeacherDetailsScreen extends StatefulWidget {
  const TeacherDetailsScreen({super.key, this.teacher});

  final Map<String, dynamic>? teacher;

  @override
  State<TeacherDetailsScreen> createState() => _TeacherDetailsScreenState();
}

class _TeacherDetailsScreenState extends State<TeacherDetailsScreen> {
  bool _isLoading = false;
  bool _isStartingChat = false;
  String? _errorMessage;
  Map<String, dynamic>? _teacherData;
  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();
    // If teacher has an ID, load from API; otherwise use passed data
    final teacherId = widget.teacher?['id']?.toString();
    if (teacherId != null && teacherId.isNotEmpty) {
      _loadTeacherDetails(teacherId);
    } else {
      // Use passed teacher data or fallback
      _teacherData = widget.teacher ??
          (kSampleTeachers.isNotEmpty ? kSampleTeachers.first : {});
      _courses =
          List<Map<String, dynamic>>.from(_teacherData?['courses'] ?? const []);
    }
  }

  Future<void> _loadTeacherDetails(String teacherId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final teacherDetails =
          await TeachersService.instance.getTeacherDetails(teacherId);
      setState(() {
        _teacherData = teacherDetails;
        _courses = List<Map<String, dynamic>>.from(
            teacherDetails['courses'] ?? const []);
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        // Fallback to passed teacher data or sample
        _teacherData = widget.teacher ??
            (kSampleTeachers.isNotEmpty ? kSampleTeachers.first : {});
        _courses = List<Map<String, dynamic>>.from(
            _teacherData?['courses'] ?? const []);
      });
    }
  }

  Future<void> _startChatWithTeacher() async {
    final teacherId = _teacher['id']?.toString() ??
        _teacher['userId']?.toString() ??
        _teacher['user_id']?.toString();
    if (teacherId == null || teacherId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? 'لا يمكن بدء المحادثة'
                  : 'Cannot start chat',
              style: GoogleFonts.cairo(),
            ),
          ),
        );
      }
      return;
    }
    setState(() => _isStartingChat = true);
    try {
      final conv =
          await ChatService.instance.createOrGetConversation(teacherId);
      final convId =
          conv['id']?.toString() ?? conv['conversationId']?.toString();
      if (convId == null || convId.isEmpty || !mounted) return;
      context.push(
        '/chat/$convId',
        extra: {
          'conversationId': convId,
          'otherUser': _teacher,
          'conversation': conv,
        },
      );
    } catch (e) {
      if (mounted) {
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
    } finally {
      if (mounted) setState(() => _isStartingChat = false);
    }
  }

  Map<String, dynamic> get _teacher =>
      _teacherData ??
      widget.teacher ??
      (kSampleTeachers.isNotEmpty ? kSampleTeachers.first : {});

  List<Map<String, dynamic>> get _coursesList => _courses;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.beige,
      appBar: AppBar(
        title: Text(
          _teacher['name']?.toString() ?? l10n.teacherFallback,
          style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.foreground,
        elevation: 0.5,
      ),
      body: _isLoading && _teacherData == null
          ? _buildTeacherDetailsSkeleton()
          : _errorMessage != null && _teacherData == null
              ? _buildErrorState(l10n: l10n)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppRadius.largeCard),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppRadius.largeCard),
                              ),
                              child: Image.network(
                                _teacher['avatar']?.toString() ?? '',
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: double.infinity,
                                  height: 220,
                                  color: AppColors.purple.withOpacity(0.12),
                                  child: const Icon(Icons.person,
                                      color: AppColors.purple, size: 64),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _teacher['name']?.toString() ?? '',
                                    style: GoogleFonts.cairo(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.foreground,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _teacher['title']?.toString() ?? '',
                                    style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          size: 18, color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Text(
                                        (_teacher['rating'] ?? 0).toString(),
                                        style: GoogleFonts.cairo(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Icon(Icons.people_alt_rounded,
                                          size: 18, color: AppColors.purple),
                                      const SizedBox(width: 4),
                                      Text(
                                        l10n.studentsCount(
                                            (_teacher['students'] as int?) ??
                                                0),
                                        style: GoogleFonts.cairo(
                                          fontSize: 12,
                                          color: AppColors.mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _teacher['bio']?.toString() ?? '',
                                    style: GoogleFonts.cairo(
                                      fontSize: 13,
                                      color: AppColors.foreground,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isStartingChat
                                          ? null
                                          : _startChatWithTeacher,
                                      icon: _isStartingChat
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.chat_bubble_rounded,
                                              size: 20,
                                            ),
                                      label: Text(
                                        Localizations.localeOf(context)
                                                    .languageCode ==
                                                'ar'
                                            ? 'تواصل مع المعلم'
                                            : 'Chat with teacher',
                                        style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.purple,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.teacherCoursesTitle,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._coursesList.map(
                        (course) => GestureDetector(
                          onTap: () {
                            if (mounted) {
                              context.push(RouteNames.courseDetails,
                                  extra: course);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    course['thumbnail']?.toString() ?? '',
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 80,
                                      height: 80,
                                      color: AppColors.purple.withOpacity(0.1),
                                      child: const Icon(Icons.image,
                                          color: AppColors.purple),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        course['title']?.toString() ?? '',
                                        style: GoogleFonts.cairo(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.foreground,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.schedule_rounded,
                                              size: 14,
                                              color: AppColors.purple),
                                          const SizedBox(width: 4),
                                          Text(
                                            course['duration']?.toString() ??
                                                '',
                                            style: GoogleFonts.cairo(
                                              fontSize: 12,
                                              color: AppColors.mutedForeground,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          const Icon(Icons.people_rounded,
                                              size: 14,
                                              color: AppColors.purple),
                                          const SizedBox(width: 4),
                                          Text(
                                            l10n.studentsCount(
                                                (course['students'] as int?) ??
                                                    0),
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

  /// User-friendly error UI with clear message and retry action
  Widget _buildErrorState({required AppLocalizations l10n}) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final (title, description) = _getUserFriendlyError(
      _errorMessage ?? '',
      isAr,
      false, // teacher details, not list
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.purple.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.destructive.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_off_rounded,
                    size: 40,
                    color: AppColors.destructive,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    color: AppColors.mutedForeground,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final teacherId = widget.teacher?['id']?.toString();
                      if (teacherId != null && teacherId.isNotEmpty) {
                        _loadTeacherDetails(teacherId);
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    label: Text(
                      l10n.retry,
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Convert technical error to user-friendly (title, description)
  (String, String) _getUserFriendlyError(
    String rawError,
    bool isAr,
    bool isTeachersList,
  ) {
    final err = rawError.toLowerCase();
    if (err.contains('socket') ||
        err.contains('connection') ||
        err.contains('network') ||
        err.contains('internet')) {
      return (
        isAr ? 'لا يوجد اتصال بالإنترنت' : 'No internet connection',
        isAr
            ? 'تأكد من اتصالك بالإنترنت وحاول مرة أخرى.'
            : 'Please check your internet connection and try again.',
      );
    }
    if (err.contains('timeout') || err.contains('timed out')) {
      return (
        isAr ? 'انتهت مهلة الاتصال' : 'Connection timed out',
        isAr
            ? 'استغرق الطلب وقتاً طويلاً. حاول مرة أخرى.'
            : 'The request took too long. Please try again.',
      );
    }
    if (err.contains('401') || err.contains('unauthorized')) {
      return (
        isAr ? 'يجب تسجيل الدخول' : 'Login required',
        isAr
            ? 'يرجى تسجيل الدخول لمشاهدة المحتوى.'
            : 'Please sign in to view this content.',
      );
    }
    if (err.contains('404') || err.contains('not found')) {
      return (
        isAr ? 'المحتوى غير متوفر' : 'Content not found',
        isAr
            ? 'لم يتم العثور على المحتوى المطلوب.'
            : 'The requested content could not be found.',
      );
    }
    if (err.contains('500') || err.contains('server')) {
      return (
        isAr ? 'مشكلة في الخادم' : 'Server issue',
        isAr
            ? 'هناك مشكلة مؤقتة. حاول مرة أخرى لاحقاً.'
            : 'There\'s a temporary issue. Please try again later.',
      );
    }
    final what = isTeachersList
        ? (isAr ? 'المعلمين' : 'teachers')
        : (isAr ? 'تفاصيل المعلم' : 'teacher details');
    return (
      isAr ? 'لم نتمكن من التحميل' : 'Couldn\'t load $what',
      isAr
          ? 'حدث خطأ أثناء تحميل $what. حاول مرة أخرى.'
          : 'Something went wrong while loading $what. Please try again.',
    );
  }

  Widget _buildTeacherDetailsSkeleton() {
    return Skeletonizer(
      enabled: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.largeCard),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purple.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.largeCard),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 18,
                          width: 150,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 13,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              height: 18,
                              width: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              height: 18,
                              width: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 13,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 13,
                          width: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              height: 16,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(3, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            width: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                height: 14,
                                width: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                height: 14,
                                width: 60,
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
            }),
          ],
        ),
      ),
    );
  }
}
