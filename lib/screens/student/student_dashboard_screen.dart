import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_radius.dart';
import '../../core/navigation/route_names.dart';
import '../../core/api/api_endpoints.dart';
import '../../widgets/bottom_nav.dart';
import '../../services/auth_service.dart';
import '../../services/certificates_service.dart';
import '../../services/courses_service.dart';
import '../../services/exams_service.dart';
import '../../services/live_courses_service.dart';
import '../../services/profile_service.dart';
import '../../l10n/app_localizations.dart';

/// Student Dashboard Screen - Simple Modern Design
class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _statistics;
  int _myEnteredExamsCount = 0;
  int? _enrolledCoursesCountOverride;
  int? _certificatesCountOverride;
  int? _liveSessionsCountOverride;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profileFuture = ProfileService.instance.getProfile();
      final myExamsFuture = ExamsService.instance.getMyExams();
      final enrollmentsFuture = CoursesService.instance.getEnrollments(
        status: 'all',
        page: 1,
        perPage: 1,
      );
      final certificatesFuture = CertificatesService.instance.getCertificates();
      final liveSessionsFuture =
          LiveCoursesService.instance.getLiveCourses(requireAuth: true);
      final profile = await profileFuture;
      Map<String, dynamic>? myExamsResponse;
      Map<String, dynamic>? enrollmentsResponse;
      Map<String, dynamic>? certificatesResponse;
      Map<String, dynamic>? liveSessionsResponse;
      try {
        myExamsResponse = await myExamsFuture;
      } catch (_) {
        myExamsResponse = null;
      }
      try {
        enrollmentsResponse = await enrollmentsFuture;
      } catch (_) {
        enrollmentsResponse = null;
      }
      try {
        certificatesResponse = await certificatesFuture;
      } catch (_) {
        certificatesResponse = null;
      }
      try {
        liveSessionsResponse = await liveSessionsFuture;
      } catch (_) {
        liveSessionsResponse = null;
      }
      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('🖼️ STUDENT DASHBOARD - PROFILE AVATAR');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('Profile avatar raw: ${profile['avatar']}');
        print('Profile avatar type: ${profile['avatar']?.runtimeType}');
        if (profile['avatar'] != null) {
          final avatarUrl =
              ApiEndpoints.getImageUrl(profile['avatar']?.toString());
          print('Profile avatar URL: $avatarUrl');
          print('Avatar URL length: ${avatarUrl.length}');
          print('Avatar URL is empty: ${avatarUrl.isEmpty}');
        } else {
          print('⚠️ Profile avatar is null');
        }
        print('✅ Profile loaded: ${profile['name']}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }
      int enteredExamsCount = 0;
      if (myExamsResponse != null) {
        final completed = myExamsResponse['completed'];
        if (completed is List) {
          enteredExamsCount = completed.length;
        } else if (myExamsResponse['results'] is List) {
          enteredExamsCount = (myExamsResponse['results'] as List).length;
        } else if (myExamsResponse['items'] is List) {
          enteredExamsCount = (myExamsResponse['items'] as List).length;
        }
      }

      int? enrolledCoursesCount;
      if (enrollmentsResponse != null) {
        final meta = enrollmentsResponse['meta'];
        if (meta is Map<String, dynamic>) {
          final total = meta['total'] ??
              meta['total_enrolled'] ??
              meta['total_courses'] ??
              meta['count'];
          if (total is num) enrolledCoursesCount = total.toInt();
          if (total is String) enrolledCoursesCount = int.tryParse(total);
        }
        if (enrolledCoursesCount == null) {
          final data = enrollmentsResponse['data'];
          if (data is List) {
            enrolledCoursesCount = data.length;
          } else if (data is Map<String, dynamic>) {
            final courses = data['courses'];
            if (courses is List) enrolledCoursesCount = courses.length;
          }
        }
      }

      int? certificatesCount;
      if (certificatesResponse != null) {
        final data = certificatesResponse['data'];
        if (data is List) {
          certificatesCount = data.length;
        } else if (data is Map<String, dynamic>) {
          final nested = data['certificates'] ?? data['items'] ?? data['data'];
          if (nested is List) certificatesCount = nested.length;
        }
      }

      int? liveSessionsCount;
      if (liveSessionsResponse != null) {
        final upcoming = liveSessionsResponse['upcoming'];
        final liveNow = liveSessionsResponse['live_now'];
        final past = liveSessionsResponse['past'];
        final upcomingCount = upcoming is List ? upcoming.length : 0;
        final liveNowCount = liveNow is List ? liveNow.length : 0;
        final pastCount = past is List ? past.length : 0;
        liveSessionsCount = upcomingCount + liveNowCount + pastCount;
      }

      setState(() {
        _profile = profile;
        _statistics = profile['statistics'] as Map<String, dynamic>?;
        _myEnteredExamsCount = enteredExamsCount;
        _enrolledCoursesCountOverride = enrolledCoursesCount;
        _certificatesCountOverride = certificatesCount;
        _liveSessionsCountOverride = liveSessionsCount;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading profile: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          AppLocalizations.of(context)!.logout,
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          AppLocalizations.of(context)!.confirmLogout,
          style: GoogleFonts.cairo(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: GoogleFonts.cairo(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              AppLocalizations.of(context)!.logout,
              style: GoogleFonts.cairo(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !context.mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.loggingOut,
                style: GoogleFonts.cairo(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Call logout API
      await AuthService.instance.logout();

      if (!context.mounted) return;

      // Clear local preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('hasLaunched');

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Navigate to splash/login screen
      if (context.mounted) {
        context.go(RouteNames.splash);
      }
    } catch (e) {
      if (!context.mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!
                .errorLoggingOut(e.toString().replaceFirst('Exception: ', '')),
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    final enrolledCourses =
        _enrolledCoursesCountOverride ?? (_statistics?['enrolled_courses'] ?? 0);
    final certificates =
        _certificatesCountOverride ?? (_statistics?['certificates_earned'] ?? 0);
    final totalHours = _statistics?['total_learning_hours'] ?? 0;
    final l10n = AppLocalizations.of(context)!;

    // Get student type from profile
    final studentType = _profile?['studentType'] as String? ??
        _profile?['student_type'] as String?;

    // Build all menu items
    final allMenuItems = [
      {
        'icon': Icons.assignment_rounded,
        'label': l10n.myExams,
        'subtitle': _myEnteredExamsCount > 0
            ? (Localizations.localeOf(context).languageCode == 'ar'
                ? 'دخلت $_myEnteredExamsCount امتحان'
                : 'You entered $_myEnteredExamsCount exams')
            : l10n.viewAllExams,
        'color': const Color(0xFFF97316),
        'bgColor': const Color(0xFFFFF7ED),
        'onTap': () => context.push(RouteNames.myExams),
        'showFor': ['online', 'offline'], // Show for both
      },
      {
        'icon': Icons.videocam_rounded,
        'label': l10n.liveCourses,
        'subtitle': _liveSessionsCountOverride != null
            ? (_liveSessionsCountOverride == 0
                ? l10n.comingSoon
                : (_liveSessionsCountOverride == 1
                    ? '1 live session'
                    : '${_liveSessionsCountOverride!} live sessions'))
            : l10n.comingSoon,
        'color': const Color(0xFF10B981),
        'bgColor': const Color(0xFFD1FAE5),
        'onTap': () => context.push(RouteNames.liveCourses),
        'showFor': ['online'], // Only for online
      },
      {
        'icon': Icons.emoji_events_rounded,
        'label': l10n.certificates,
        'subtitle': '$certificates ${l10n.certificates}',
        'color': const Color(0xFFEAB308),
        'bgColor': const Color(0xFFFEF9C3),
        'onTap': () => context.push(RouteNames.certificates),
        'showFor': ['online', 'offline'], // Show for both
      },
      {
        'icon': Icons.download_rounded,
        'label': l10n.downloads,
        'subtitle': l10n.savedFiles,
        'color': const Color(0xFF3B82F6),
        'bgColor': const Color(0xFFDBEAFE),
        'onTap': () => context.push(RouteNames.downloads),
        'showFor': ['online'], // Only for online
      },
      {
        'icon': Icons.settings_rounded,
        'label': l10n.settings,
        'subtitle': l10n.customizeApp,
        'color': const Color(0xFF6B7280),
        'bgColor': const Color(0xFFF3F4F6),
        'onTap': () => context.push(RouteNames.settings),
        'showFor': ['online', 'offline'], // Show for both
      },
    ];

    // Filter menu items based on student type
    final menuItems = allMenuItems.where((item) {
      final showFor = item['showFor'] as List<String>;
      // If studentType is null, show all items (fallback)
      if (studentType == null) return true;
      return showFor.contains(studentType);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.beige,
      body: Stack(
        children: [
          Column(
            children: [
              // Header
              _buildHeader(context, enrolledCourses, certificates, totalHours),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.mainMenu,
                              style: GoogleFonts.cairo(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.foreground,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Menu Grid
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.1,
                              ),
                              itemCount: menuItems.length,
                              itemBuilder: (context, index) {
                                final item = menuItems[index];
                                return _buildMenuItem(
                                  icon: item['icon'] as IconData,
                                  label: item['label'] as String,
                                  subtitle: item['subtitle'] as String,
                                  color: item['color'] as Color,
                                  bgColor: item['bgColor'] as Color,
                                  onTap: item['onTap'] as VoidCallback,
                                );
                              },
                            ),

                            const SizedBox(height: 24),

                            // Logout Button
                            GestureDetector(
                              onTap: () => _handleLogout(context),
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.red.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.logout_rounded,
                                        color: Colors.red[600], size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppLocalizations.of(context)!.logout,
                                      style: GoogleFonts.cairo(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Delete Account
                            Center(
                              child: TextButton(
                                onPressed: () {},
                                child: Text(
                                  AppLocalizations.of(context)!.deleteAccount,
                                  style: GoogleFonts.cairo(
                                      fontSize: 13, color: Colors.red[300]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),

          // Bottom Navigation
          const BottomNav(activeTab: 'dashboard'),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int enrolledCourses,
      int certificates, int totalHours) {
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
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => context.go(RouteNames.home),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.myAccount,
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push(RouteNames.settings),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Profile Section
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.4),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _profile?['avatar'] != null
                      ? Image.network(
                          ApiEndpoints.getImageUrl(
                            _profile!['avatar']?.toString(),
                          ),
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.white,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.purple,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            if (kDebugMode) {
                              print(
                                  '❌ Error loading avatar image in dashboard: $error');
                              print(
                                  '   Avatar URL: ${ApiEndpoints.getImageUrl(_profile!['avatar']?.toString())}');
                              print('   Stack trace: $stackTrace');
                            }
                            return Image.asset(
                              'assets/images/student-avatar.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.white,
                                child: const Icon(
                                  Icons.person,
                                  size: 45,
                                  color: AppColors.purple,
                                ),
                              ),
                            );
                          },
                        )
                      : Image.asset(
                          'assets/images/student-avatar.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.white,
                            child: const Icon(
                              Icons.person,
                              size: 45,
                              color: AppColors.purple,
                            ),
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                _profile?['name']?.toString() ??
                    AppLocalizations.of(context)!.user,
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                _profile?['email']?.toString() ?? '',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),

              const SizedBox(height: 16),

              // Stats Row
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStat(
                        '$enrolledCourses',
                        AppLocalizations.of(context)!.course,
                        Icons.play_circle_fill_rounded),
                    Container(
                      width: 1,
                      height: 25,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: Colors.white.withOpacity(0.3),
                    ),
                    _buildStat(
                        '$certificates',
                        AppLocalizations.of(context)!.certificates,
                        Icons.emoji_events_rounded),
                    Container(
                      width: 1,
                      height: 25,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: Colors.white.withOpacity(0.3),
                    ),
                    _buildStat(
                        '$totalHours',
                        AppLocalizations.of(context)!.hour,
                        Icons.access_time_filled_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withOpacity(0.8)),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 11,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
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
    );
  }
}
