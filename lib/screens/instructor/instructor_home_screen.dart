import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_radius.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/navigation/route_names.dart';
import '../../widgets/instructor_bottom_nav.dart';
import '../../services/profile_service.dart';
import '../../services/teacher_dashboard_service.dart';
import '../../l10n/app_localizations.dart';

/// Instructor dashboard – welcome card, stats, quick actions, my courses.
class InstructorHomeScreen extends StatefulWidget {
  const InstructorHomeScreen({super.key});

  @override
  State<InstructorHomeScreen> createState() => _InstructorHomeScreenState();
}

class _InstructorHomeScreenState extends State<InstructorHomeScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _welcomeController;
  late Animation<double> _welcomeFade;
  late Animation<double> _bannerScale;
  String? _errorMessage;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _activity;
  Map<String, dynamic>? _charts;
  List<Map<String, dynamic>> _myCourses = [];
  double _totalSales = 0;
  int _totalSubscriptions = 0;

  @override
  void initState() {
    super.initState();
    _welcomeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _welcomeFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _welcomeController, curve: Curves.easeOut),
    );
    _bannerScale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _welcomeController, curve: Curves.easeOutBack),
    );
    _welcomeController.forward();
    _loadData();
  }

  @override
  void dispose() {
    _welcomeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Load profile, overview, activity, and charts in parallel (reference: dashboard/charts)
      Map<String, dynamic>? profile;
      Map<String, dynamic>? overview;
      Map<String, dynamic>? activity;
      // ignore: unused_local_variable - used in setState(_charts = charts)
      Map<String, dynamic>? charts;

      await Future.wait([
        ProfileService.instance
            .getProfile()
            .then((p) => profile = p)
            .catchError((e) {
          if (kDebugMode) print('❌ Profile load failed: $e');
          profile = null;
          return <String, dynamic>{};
        }),
        TeacherDashboardService.instance
            .getDashboardOverview()
            .then((o) => overview = o)
            .catchError((_) {
          overview = null;
          return <String, dynamic>{};
        }),
        TeacherDashboardService.instance
            .getDashboardActivity()
            .then((a) => activity = a)
            .catchError((_) {
          activity = null;
          return <String, dynamic>{};
        }),
        TeacherDashboardService.instance
            .getDashboardCharts()
            .then((c) => charts = c)
            .catchError((_) {
          charts = null;
          return <String, dynamic>{};
        }),
      ]);

      // Demo data when activity is empty (to show payment/enrollment UI)
      final payments = activity?['recentPayments'] as List? ?? const [];
      final enrollments = activity?['recentEnrollments'] as List? ?? const [];
      if (activity == null || (payments.isEmpty && enrollments.isEmpty)) {
        activity = _getDemoActivity(context);
      }

      final userId = profile?['id']?.toString() ?? '';

      List<Map<String, dynamic>> myCourses = [];
      if (userId.isNotEmpty) {
        try {
          final coursesData =
              await TeacherDashboardService.instance.getMyCourses(
            instructorId: userId,
            limit: 100,
          );
          if (kDebugMode) {
            print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            print('📚 MY COURSES API RESPONSE');
            print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            print('  keys: ${coursesData.keys.toList()}');
            print('  full response: $coursesData');
            print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          }
          // Handle { data: [...] } or direct list from API
          final data = coursesData['data'] ?? coursesData;
          if (data is List) {
            myCourses =
                data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            if (kDebugMode) {
              print('  parsed courses count: ${myCourses.length}');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ My courses API error: $e');
          }
        }
      }

      int subscriptions = 0;
      double sales = 0;
      for (final c in myCourses) {
        subscriptions += (c['studentsCount'] as num?)?.toInt() ?? 0;
      }
      try {
        final paymentsData = await TeacherDashboardService.instance.getPayments(
          limit: 100,
          status: 'completed',
        );
        final payList = paymentsData['data'] ?? paymentsData;
        if (payList is List) {
          final myCourseIds = myCourses.map((e) => e['id']?.toString()).toSet();
          for (final p in payList) {
            final map = p is Map ? Map<String, dynamic>.from(p) : null;
            if (map == null) continue;
            if (map['itemType'] == 'course' &&
                myCourseIds.contains(map['itemId']?.toString())) {
              sales += (map['amount'] as num?)?.toDouble() ?? 0;
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _profile = profile;
          _overview = overview;
          _activity = activity;
          _myCourses = myCourses;
          _totalSubscriptions = subscriptions;
          _totalSales = sales;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ InstructorHomeScreen: $e');
      }
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        final isTimeout = msg.toLowerCase().contains('timeout') ||
            msg.toLowerCase().contains('timeoutexception');
        setState(() {
          _errorMessage = isTimeout
              ? (Localizations.localeOf(context).languageCode == 'ar'
                  ? 'انتهت مهلة الاتصال. تحقق من الشبكة وحاول مرة أخرى.'
                  : 'Connection timed out. Check your network and try again.')
              : msg;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.beige,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 430
                    ? (MediaQuery.of(context).size.width - 430) / 2
                    : 0,
              ),
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  _buildHeader(context, statusBarHeight, l10n, isAr),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _errorMessage != null
                        ? _buildError(l10n)
                        : _isLoading
                            ? _buildLoading()
                            : SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(
                                  left: 20,
                                  right: 20,
                                  bottom: 140,
                                  top: 8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildWelcomeCard(isAr),
                                    _buildStatsGrid(isAr),
                                    if (_charts != null) ...[
                                      const SizedBox(height: 16),
                                      _buildChartsCard(isAr),
                                      const SizedBox(height: 16),
                                    ],
                                    if (_activity != null) ...[
                                      const SizedBox(height: 16),
                                      _buildRecentActivity(isAr),
                                      const SizedBox(height: 20),
                                    ],
                                    _buildSectionTitle(
                                      isAr ? 'دوراتي' : 'My Courses',
                                      () => context
                                          .go(RouteNames.instructorCourses),
                                    ),
                                    const SizedBox(height: 12),
                                    _myCourses.isEmpty
                                        ? _buildEmptyCourses(context, isAr)
                                        : _buildCourseList(context),
                                  ],
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ),
          const InstructorBottomNav(activeTab: 'home'),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    double statusBarHeight,
    AppLocalizations l10n,
    bool isAr,
  ) {
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
      child: Stack(
        children: [
          // Decorative background icons (teacher/dashboard theme)
          Positioned(
            top: statusBarHeight + 50,
            right: 20,
            child: Icon(
              Icons.school_rounded,
              size: 42,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Positioned(
            top: statusBarHeight + 24,
            left: 36,
            child: Icon(
              Icons.menu_book_rounded,
              size: 32,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Positioned(
            bottom: 72,
            right: 56,
            child: Icon(
              Icons.insights_rounded,
              size: 36,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
          Positioned(
            bottom: 88,
            left: 24,
            child: Icon(
              Icons.person_rounded,
              size: 28,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  // Avatar (person) – same style as student header
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
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
                              loadingBuilder:
                                  (context, child, loadingProgress) {
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
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildAvatarPlaceholder(),
                            )
                          : _buildAvatarPlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isAr ? 'لوحة المدرب' : 'Instructor Dashboard',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _profile?['name']?.toString() ?? l10n.instructor,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Settings & Notifications
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeaderIconButton(
                        icon: Icons.settings_outlined,
                        onTap: () => context.push(RouteNames.settings),
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderIconButton(
                        icon: Icons.notifications_none_rounded,
                        onTap: () => context.push(RouteNames.notifications),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      color: Colors.white.withOpacity(0.9),
      child: const Icon(
        Icons.person_rounded,
        color: AppColors.purple,
        size: 28,
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildWelcomeCard(bool isAr) {
    final name = _profile?['name']?.toString() ?? '';
    final greeting = isAr
        ? (name.isNotEmpty ? 'مرحباً، $name' : 'مرحباً بك')
        : (name.isNotEmpty ? 'Welcome, $name' : 'Welcome');
    final subtitle = isAr
        ? 'هنا ملخص لوحتك وما تحتاجه للوصول السريع'
        : 'Here’s your dashboard and quick access to what you need';

    return AnimatedBuilder(
      animation: _welcomeController,
      builder: (context, child) {
        final rawValue = _bannerScale.value;
        final scaleValue = (rawValue.isNaN || rawValue.isInfinite)
            ? 1.0
            : rawValue.clamp(0.0, 1.0);
        final opacityValue = _welcomeFade.value.clamp(0.0, 1.0);
        return Transform.scale(
          scale: scaleValue,
          alignment: Alignment.center,
          child: Opacity(
            opacity: opacityValue,
            child: child,
          ),
        );
      },
      child: SizedBox(
        height: 140,
        width: double.infinity,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0C52B3),
                Color(0xFF093F8A),
                Color(0xFF072F68),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0C52B3).withOpacity(0.4),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -30,
                  left: 60,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Transform.translate(
                        offset: const Offset(-10, 10),
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            size: 64,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              greeting,
                              style: GoogleFonts.cairo(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.85),
                                height: 1.3,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildQuickActions(BuildContext context, bool isAr) {
    final actions = [
      (
        RouteNames.instructorCourses,
        Icons.menu_book_rounded,
        isAr ? 'دوراتي' : 'My Courses'
      ),
      (
        RouteNames.instructorEarnings,
        Icons.payments_rounded,
        isAr ? 'الأرباح' : 'Earnings'
      ),
      (
        RouteNames.instructorProfile,
        Icons.person_rounded,
        isAr ? 'حسابي' : 'My Account'
      ),
    ];

    return Row(
      children: List.generate(actions.length, (i) {
        final e = actions[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : 6,
              right: i == actions.length - 1 ? 0 : 6,
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.smallCard),
              child: InkWell(
                onTap: () => context.go(e.$1),
                borderRadius: BorderRadius.circular(AppRadius.smallCard),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.smallCard),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(e.$2, color: AppColors.purple, size: 26),
                      const SizedBox(height: 8),
                      Text(
                        e.$3,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStatsGrid(bool isAr) {
    final totalCourses =
        _overview?['totalCourses'] as num? ?? _myCourses.length;
    final subs =
        _overview?['totalSubscriptions'] as num? ?? _totalSubscriptions;
    final revenue = _overview?['totalRevenue'] as num? ?? _totalSales;
    final totalUsers = _overview?['totalUsers'] as num? ?? _totalSubscriptions;

    final usersGrowth = _overview?['usersGrowth'] as num?;
    final coursesGrowth = _overview?['coursesGrowth'] as num?;
    final subsGrowth = _overview?['subscriptionsGrowth'] as num?;
    final revenueGrowth = _overview?['revenueGrowth'] as num?;

    final cards = [
      (
        totalUsers.toDouble(),
        isAr ? 'طلابي' : 'My Students',
        Icons.people_rounded,
        usersGrowth ?? subsGrowth
      ),
      (
        totalCourses.toDouble(),
        isAr ? 'دوراتي' : 'My Courses',
        Icons.menu_book_rounded,
        coursesGrowth
      ),
      (
        subs.toDouble(),
        isAr ? 'اشتراكات' : 'Subscriptions',
        Icons.subscriptions_rounded,
        subsGrowth ?? usersGrowth
      ),
      (
        revenue.toDouble(),
        isAr ? 'المبيعات' : 'Sales',
        Icons.payments_rounded,
        revenueGrowth
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1,
      children: cards.map((e) {
        final value = e.$1;
        final label = e.$2;
        final icon = e.$3;
        final growth = e.$4;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.purple, size: 26),
              const SizedBox(height: 6),
              Text(
                value >= 1000000
                    ? '${(value / 1000000).toStringAsFixed(1)}M'
                    : value >= 1000
                        ? '${(value / 1000).toStringAsFixed(1)}K'
                        : value.toInt().toString(),
                style: GoogleFonts.cairo(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
              if (growth != null) ...[
                const SizedBox(height: 2),
                _buildGrowthChip(growth.toDouble(), isAr),
              ],
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Dashboard charts from reference: revenue[], courseCompletion[].
  Widget _buildChartsCard(bool isAr) {
    final revenue = _charts!['revenue'] as List? ?? [];
    final courseCompletion = _charts!['courseCompletion'] as List? ?? [];
    final hasRevenue = revenue.isNotEmpty;
    final hasCompletion = courseCompletion.isNotEmpty;
    if (!hasRevenue && !hasCompletion) return const SizedBox.shrink();

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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bar_chart_rounded,
                  size: 22,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isAr ? 'نظرة سريعة' : 'Quick overview',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          if (hasRevenue) ...[
            const SizedBox(height: 14),
            Text(
              isAr ? 'إيرادات الشهور' : 'Revenue by month',
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            ...revenue.take(5).map((e) {
              final m =
                  e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
              final month = m['month']?.toString() ?? '—';
              final value = (m['revenue'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      month,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      value >= 1000
                          ? '${(value / 1000).toStringAsFixed(1)}K'
                          : value.toInt().toString(),
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.purple,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (hasCompletion) ...[
            if (hasRevenue) const SizedBox(height: 14),
            Text(
              isAr ? 'إكمال الدورات' : 'Course completion',
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: courseCompletion.map((e) {
                final m = e is Map
                    ? Map<String, dynamic>.from(e)
                    : <String, dynamic>{};
                final name = m['name']?.toString() ?? '—';
                final value = (m['value'] as num?)?.toInt() ?? 0;
                final colorStr = m['color']?.toString();
                Color color = AppColors.purple;
                if (colorStr != null && colorStr.isNotEmpty) {
                  try {
                    color = Color(int.parse(
                      colorStr.replaceFirst('#', '0xFF'),
                      radix: 16,
                    ));
                  } catch (_) {}
                }
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$name: $value',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.foreground,
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
    );
  }

  Widget _buildGrowthChip(double percent, bool isAr) {
    final isPositive = percent >= 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          size: 14,
          color: isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
        ),
        const SizedBox(width: 4),
        Text(
          '${isPositive ? '+' : ''}${percent.toStringAsFixed(1)}%',
          style: GoogleFonts.cairo(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color:
                isPositive ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }

  /// Demo activity data for debug mode when API returns empty
  Map<String, dynamic> _getDemoActivity(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return {
      'recentPayments': [
        {
          'amount': 299,
          'user': {'name': isAr ? 'أحمد محمد' : 'Ahmad Mohammed'},
          'userName': isAr ? 'أحمد محمد' : 'Ahmad Mohammed',
          'course': {
            'title': isAr
                ? 'برمجة Flutter للمبتدئين'
                : 'Flutter Programming for Beginners'
          },
          'courseName': isAr
              ? 'برمجة Flutter للمبتدئين'
              : 'Flutter Programming for Beginners',
          'createdAt': DateTime.now()
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
        },
        {
          'amount': 199,
          'user': {'name': isAr ? 'سارة علي' : 'Sara Ali'},
          'userName': isAr ? 'سارة علي' : 'Sara Ali',
          'course': {'title': isAr ? 'تصميم الواجهات' : 'UI/UX Design'},
          'courseName': isAr ? 'تصميم الواجهات' : 'UI/UX Design',
          'createdAt': DateTime.now()
              .subtract(const Duration(hours: 5))
              .toIso8601String(),
        },
        {
          'amount': 449,
          'user': {'name': isAr ? 'خالد عمر' : 'Khaled Omar'},
          'userName': isAr ? 'خالد عمر' : 'Khaled Omar',
          'course': {
            'title': isAr ? 'تطوير تطبيقات الجوال' : 'Mobile App Development'
          },
          'courseName':
              isAr ? 'تطوير تطبيقات الجوال' : 'Mobile App Development',
          'createdAt': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
        },
      ],
      'recentEnrollments': [
        {
          'user': {'name': isAr ? 'فاطمة حسن' : 'Fatima Hassan'},
          'userName': isAr ? 'فاطمة حسن' : 'Fatima Hassan',
          'course': {
            'title': isAr
                ? 'برمجة Flutter للمبتدئين'
                : 'Flutter Programming for Beginners'
          },
          'courseName': isAr
              ? 'برمجة Flutter للمبتدئين'
              : 'Flutter Programming for Beginners',
          'createdAt': DateTime.now()
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
        },
        {
          'user': {'name': isAr ? 'محمد يوسف' : 'Mohammed Yusuf'},
          'userName': isAr ? 'محمد يوسف' : 'Mohammed Yusuf',
          'course': {'title': isAr ? 'تصميم الواجهات' : 'UI/UX Design'},
          'courseName': isAr ? 'تصميم الواجهات' : 'UI/UX Design',
          'createdAt': DateTime.now()
              .subtract(const Duration(hours: 3))
              .toIso8601String(),
        },
      ],
    };
  }

  Widget _buildRecentActivity(bool isAr) {
    final recentPayments = _activity!['recentPayments'] as List? ?? const [];
    final recentEnrollments =
        _activity!['recentEnrollments'] as List? ?? const [];
    final recentUsers = _activity!['recentUsers'] as List? ?? const [];
    final hasPayments = recentPayments.isNotEmpty;
    final hasEnrollments = recentEnrollments.isNotEmpty;
    final hasUsers = recentUsers.isNotEmpty;
    if (!hasPayments && !hasEnrollments && !hasUsers)
      return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.insights_rounded,
                size: 22,
                color: AppColors.purple,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isAr ? 'النشاط الأخير' : 'Recent Activity',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Reference: recentPayments have userName, amount, itemName, createdAt
        if (hasPayments)
          _buildActivitySubsection(
            isAr ? 'مدفوعات حديثة' : 'Recent payments',
            recentPayments,
            Icons.payments_rounded,
            const Color(0xFF22C55E),
            (m) => m['amount']?.toString(),
            (m) => m['user'] is Map
                ? (m['user'] as Map)['name']?.toString()
                : m['userName']?.toString(),
            (m) => m['course'] is Map
                ? ((m['course'] as Map)['title'] ??
                        (m['course'] as Map)['name'])
                    ?.toString()
                : m['courseName']?.toString() ?? m['itemName']?.toString(),
            isAr,
            (m) => m['createdAt']?.toString(),
          ),
        if (hasPayments && hasEnrollments) const SizedBox(height: 14),
        // Reference: recentEnrollments have userName, courseName, enrolledAt
        if (hasEnrollments)
          _buildActivitySubsection(
            isAr ? 'تسجيلات حديثة' : 'Recent enrollments',
            recentEnrollments,
            Icons.person_add_rounded,
            const Color(0xFF3B82F6),
            null,
            (m) => m['user'] is Map
                ? (m['user'] as Map)['name']?.toString()
                : m['userName']?.toString() ?? m['studentName']?.toString(),
            (m) => m['course'] is Map
                ? ((m['course'] as Map)['title'] ??
                        (m['course'] as Map)['name'])
                    ?.toString()
                : m['courseName']?.toString(),
            isAr,
            (m) => m['enrolledAt']?.toString() ?? m['createdAt']?.toString(),
          ),
        if ((hasPayments || hasEnrollments) && hasUsers)
          const SizedBox(height: 14),
        // Reference: dashboard/activity recentUsers (optional)
        if (hasUsers)
          _buildActivitySubsection(
            isAr ? 'مستخدمون حديثون' : 'Recent users',
            recentUsers,
            Icons.people_rounded,
            const Color(0xFF1D6FD6),
            null,
            (m) =>
                m['name']?.toString() ??
                m['userName']?.toString() ??
                m['email']?.toString(),
            (m) => m['email']?.toString(),
            isAr,
            (m) => m['createdAt']?.toString(),
          ),
      ],
    );
  }

  Widget _buildActivitySubsection(
    String title,
    List list,
    IconData icon,
    Color accentColor,
    String? Function(Map<String, dynamic>)? amountExtractor,
    String? Function(Map<String, dynamic>) nameExtractor,
    String? Function(Map<String, dynamic>)? courseExtractor,
    bool isAr, [
    String? Function(Map<String, dynamic>)? dateExtractor,
  ]) {
    final items = list.take(5).map((e) {
      final m = e is Map
          ? Map<String, dynamic>.from(e as Map<String, dynamic>)
          : <String, dynamic>{};
      final name = nameExtractor(m) ?? (isAr ? '—' : '—');
      final amount = amountExtractor?.call(m);
      final course = courseExtractor?.call(m);
      final date = dateExtractor?.call(m) ??
          m['createdAt']?.toString() ??
          m['enrolledAt']?.toString() ??
          m['date']?.toString();
      return (name: name, amount: amount, course: course, date: date);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: accentColor),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...items.map((e) => _buildActivityItemCard(e, accentColor, isAr)),
      ],
    );
  }

  Widget _buildActivityItemCard(
    ({String name, String? amount, String? course, String? date}) e,
    Color accentColor,
    bool isAr,
  ) {
    final dateStr = e.date != null && e.date!.length >= 10
        ? e.date!.substring(0, 10)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_rounded, size: 22, color: accentColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e.name,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (e.course != null && e.course!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.menu_book_rounded,
                          size: 12, color: AppColors.mutedForeground),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          e.course!,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.mutedForeground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (dateStr != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppColors.mutedForeground.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (e.amount != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${e.amount} ${isAr ? 'ريال' : 'SAR'}',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF22C55E),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isAr ? 'انضم' : 'Enrolled',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3B82F6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.foreground,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCourses(BuildContext context, bool isAr) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
              color: AppColors.purple.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.menu_book_rounded,
              size: 40,
              color: AppColors.purple.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isAr ? 'لا توجد دورات بعد' : 'No courses yet',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'عند إضافة دوراتك ستظهر هنا'
                : 'Your courses will appear here when you add them',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppColors.mutedForeground,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => context.go(RouteNames.instructorCourses),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.purple,
              side: BorderSide(color: AppColors.purple.withOpacity(0.6)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(
              isAr ? 'عرض دوراتي' : 'View my courses',
              style:
                  GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseList(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      children: _myCourses.take(5).map((c) {
        final title = c['title']?.toString() ?? '';
        final level =
            c['level']?.toString() ?? c['levelName']?.toString() ?? '';
        final category = c['category'] is Map
            ? (c['category'] as Map)['name']?.toString() ??
                (c['category'] as Map)['nameAr']?.toString() ??
                ''
            : c['categoryName']?.toString() ?? c['category']?.toString() ?? '';
        final price = (c['price'] as num?)?.toDouble();
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

        Color levelColor(String lv) {
          final lower = lv.toLowerCase();
          if (lower.contains('beginner') || lower.contains('مبتدئ'))
            return const Color(0xFF22C55E);
          if (lower.contains('intermediate') || lower.contains('متوسط'))
            return const Color(0xFFF59E0B);
          if (lower.contains('advanced') || lower.contains('متقدم'))
            return const Color(0xFFEF4444);
          return AppColors.purple;
        }

        return InkWell(
          onTap: () =>
              context.push(RouteNames.instructorCourseDetails, extra: c),
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
                //  crossAxisAlignment: CrossAxisAlignment.,
                textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  // Image on side – fixed size, not full height
                  _buildCourseCardImage(isAr, imageUrl, isFeatured),

                  const SizedBox(
                    width: 12,
                  ), // Content: name + level side by side, then category, then price + duration + lessons
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
                                    color: levelColor(level).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: levelColor(level).withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    level,
                                    style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: levelColor(level),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // Category under title+level
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
                          // Bottom: Price (Riyal), Duration (h/min), Students, Lessons
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              if (price != null && price > 0)
                                _buildStatChip(
                                  context,
                                  Icons.payments_rounded,
                                  '${price.toInt()} ${isAr ? 'ريال' : 'SAR'}',
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
                              _buildStatChip(
                                context,
                                Icons.people_rounded,
                                isAr
                                    ? '$studentsCount طالب'
                                    : '$studentsCount students',
                                const Color(0xFF3B82F6),
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
      }).toList(),
    );
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

  /// Image on side: fixed small size with padding, rounded corners. Not full card height.
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

  /// Format duration as "X h Y m" or "X س Y د" (Arabic). Accepts hours (e.g. 1.5) or minutes (e.g. 90).
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
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry, style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Skeletonizer(
      enabled: true,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: 140,
          top: 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card skeleton
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 18,
                            width: 140,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 14,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 12,
                            width: 180,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Stats grid skeleton
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
              children: List.generate(4, (_) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 20,
                        width: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 12,
                        width: 70,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            // Section title
            Container(
              height: 20,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            // Course list skeleton
            ...List.generate(3, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
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
                            height: 14,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 12,
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
                                height: 16,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                height: 16,
                                width: 50,
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
