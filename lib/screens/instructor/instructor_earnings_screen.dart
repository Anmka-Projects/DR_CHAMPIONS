import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_radius.dart';
import '../../core/navigation/route_names.dart';
import '../../widgets/instructor_bottom_nav.dart';
import '../../services/profile_service.dart';
import '../../services/teacher_dashboard_service.dart';
import '../../l10n/app_localizations.dart';

/// Instructor – My salary settings & calculate salary. Same theme as student flow.
class InstructorEarningsScreen extends StatefulWidget {
  const InstructorEarningsScreen({super.key});

  @override
  State<InstructorEarningsScreen> createState() =>
      _InstructorEarningsScreenState();
}

class _InstructorEarningsScreenState extends State<InstructorEarningsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _salarySettings;
  Map<String, dynamic>? _calculation;
  Map<String, dynamic>? _overview;
  List<Map<String, dynamic>> _myCourses = [];
  Map<String, double> _monthlyEarnings = {}; // "2025-01" -> amount
  double _totalSales = 0;
  int _totalSubscriptions = 0;
  Map<String, dynamic>? _reports;
  bool _reportsExpanded = false;
  String? _reportsError;
  Map<String, dynamic>? _charts;
  List<Map<String, dynamic>> _byCourse = []; // from api earnings byCourse
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    if (_endDate!.isAfter(now)) _endDate = now;
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final settings =
          await TeacherDashboardService.instance.getMySalarySettings();
      String userId = '';
      try {
        final profile = await ProfileService.instance.getProfile();
        userId = profile['id']?.toString() ?? '';
      } catch (_) {}

      Map<String, dynamic>? overview;
      Map<String, dynamic>? charts;
      try {
        overview =
            await TeacherDashboardService.instance.getDashboardOverview();
      } catch (_) {}
      try {
        charts = await TeacherDashboardService.instance.getDashboardCharts();
      } catch (_) {}

      Map<String, dynamic>? apiEarnings;
      try {
        apiEarnings =
            await TeacherDashboardService.instance.getUsersMeEarnings();
      } catch (_) {}

      List<Map<String, dynamic>> myCourses = [];
      if (userId.isNotEmpty) {
        try {
          final coursesData =
              await TeacherDashboardService.instance.getMyCourses(
            instructorId: userId,
            limit: 100,
          );
          final data = coursesData['data'];
          if (data is List) {
            myCourses =
                data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (_) {}
      }

      Map<String, double> monthlyEarnings = {};
      double totalSales = 0;
      int totalSubscriptions = 0;

      for (final c in myCourses) {
        totalSubscriptions += (c['studentsCount'] as num?)?.toInt() ?? 0;
      }

      try {
        final paymentsData = await TeacherDashboardService.instance.getPayments(
          limit: 100,
          status: 'completed',
        );
        final payList = paymentsData['data'] ?? paymentsData;
        final myCourseIds = myCourses.map((e) => e['id']?.toString()).toSet();

        if (payList is List) {
          for (final p in payList) {
            final map = p is Map ? Map<String, dynamic>.from(p) : null;
            if (map == null) continue;
            if (map['itemType'] == 'course' &&
                myCourseIds.contains(map['itemId']?.toString())) {
              final amount = (map['amount'] as num?)?.toDouble() ?? 0;
              totalSales += amount;
              final createdAt =
                  map['createdAt']?.toString() ?? map['created_at']?.toString();
              if (createdAt != null && createdAt.isNotEmpty) {
                final dt = DateTime.tryParse(createdAt);
                if (dt != null) {
                  final key =
                      '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
                  monthlyEarnings[key] = (monthlyEarnings[key] ?? 0) + amount;
                }
              }
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        // Prefer GET /admin/users/me/earnings when available
        List<Map<String, dynamic>> byCourse = [];
        if (apiEarnings != null) {
          final te = (apiEarnings['totalEarnings'] as num?)?.toDouble();
          if (te != null) totalSales = te;

          final byCourseRaw = apiEarnings['byCourse'];
          if (byCourseRaw is List) {
            byCourse = byCourseRaw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }

          final period = apiEarnings['periodEarnings'];
          if (period is List && period.isNotEmpty) {
            final merged = <String, double>{};
            for (final p in period) {
              if (p is! Map) continue;
              final m = Map<String, dynamic>.from(p);
              final month = m['month']?.toString();
              final rev = (m['revenue'] as num?)?.toDouble() ??
                  (m['amount'] as num?)?.toDouble() ??
                  0;
              if (month != null && month.isNotEmpty) {
                merged[month] = (merged[month] ?? 0) + rev;
              }
            }
            if (merged.isNotEmpty) monthlyEarnings = merged;
          }
        }

        // Else prefer API charts.revenue for monthly chart when available
        if (monthlyEarnings.isEmpty && charts != null) {
          final rev = charts['revenue'];
          if (rev is List && rev.isNotEmpty) {
            final merged = <String, double>{};
            for (var i = 0; i < rev.length; i++) {
              final item = rev[i];
              if (item is Map) {
                final m = Map<String, dynamic>.from(item);
                final month = m['month']?.toString();
                final v = (m['revenue'] as num?)?.toDouble() ?? 0;
                if (month != null) merged[month] = v;
              } else {
                final v = (item as num?)?.toDouble() ?? 0;
                final dt = DateTime.now();
                var y = dt.year;
                var m = dt.month - (rev.length - 1 - i);
                while (m < 1) {
                  m += 12;
                  y--;
                }
                merged['$y-${m.toString().padLeft(2, '0')}'] = v;
              }
            }
            if (merged.isNotEmpty) monthlyEarnings = merged;
          }
        }

        setState(() {
          _salarySettings = settings;
          _overview = overview;
          _myCourses = myCourses;
          _monthlyEarnings = monthlyEarnings;
          _totalSales = totalSales;
          _totalSubscriptions = totalSubscriptions;
          _byCourse = byCourse;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ InstructorEarningsScreen: $e');
      }
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _calculateSalary() async {
    if (_startDate == null || _endDate == null) return;
    final start = _startDate!.toIso8601String().split('T').first;
    final end = _endDate!.toIso8601String().split('T').first;
    setState(() => _isLoading = true);
    try {
      final result = await TeacherDashboardService.instance.calculateMySalary(
        startDate: start,
        endDate: end,
      );
      if (mounted) {
        setState(() {
          _calculation = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ InstructorEarningsScreen calculateMySalary: $e');
      }
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
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
          Container(
            constraints: const BoxConstraints(maxWidth: 430),
            margin: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width > 430
                  ? (MediaQuery.of(context).size.width - 430) / 2
                  : 0,
            ),
            child: Column(
              children: [
                _buildHeader(isAr),
                Expanded(
                  child: _errorMessage != null && !_isLoading
                      ? _buildError(l10n)
                      : SingleChildScrollView(
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 20,
                            bottom: 140,
                            top: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_isLoading && _salarySettings == null)
                                _buildEarningsSkeleton()
                              else ...[
                                _buildSummaryStats(isAr),
                                const SizedBox(height: 20),
                                if (_byCourse.isNotEmpty) ...[
                                  _buildEarningsByCourseCard(isAr),
                                  const SizedBox(height: 20),
                                ],
                                if (_charts != null) ...[
                                  _buildDashboardChartsSection(isAr),
                                  const SizedBox(height: 20),
                                ],
                                _buildMonthlyEarningsChart(isAr),
                                const SizedBox(height: 20),
                                _buildSalaryBreakdownChart(isAr),
                                const SizedBox(height: 20),
                                _buildAnalysisSummary(isAr),
                                const SizedBox(height: 20),
                                _buildSalarySettingsCard(isAr),
                                const SizedBox(height: 20),
                                _buildCalculateCard(isAr),
                                if (_calculation != null) ...[
                                  const SizedBox(height: 20),
                                  _buildResultCard(isAr),
                                ],
                                const SizedBox(height: 20),
                                _buildReportsCard(isAr),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          const InstructorBottomNav(activeTab: 'earnings'),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isAr) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 20,
      ),
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
      ),
      child: Row(
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
            child: Text(
              isAr ? 'الأرباح والمرتب' : 'Earnings & Salary',
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsSkeleton() {
    return Skeletonizer(
      enabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Salary settings card skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 20,
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 20),
                ...List.generate(
                    3,
                    (_) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                height: 14,
                                width: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              Container(
                                height: 14,
                                width: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ],
                          ),
                        )),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Calculate card skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 20,
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  height: 52,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Earnings by course from GET /admin/users/me/earnings byCourse.
  Widget _buildEarningsByCourseCard(bool isAr) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
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
                child: Icon(Icons.menu_book_rounded,
                    color: AppColors.purple, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                isAr ? 'الإيرادات حسب الدورة' : 'Earnings by course',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._byCourse.take(15).map((e) {
            final name = e['courseName']?.toString() ??
                e['title']?.toString() ??
                e['name']?.toString() ??
                '—';
            final amount = (e['amount'] as num?)?.toDouble() ??
                (e['revenue'] as num?)?.toDouble() ??
                (e['earnings'] as num?)?.toDouble() ??
                0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: AppColors.foreground,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    amount >= 1000
                        ? '${(amount / 1000).toStringAsFixed(1)}K'
                        : amount.toInt().toString(),
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.purple,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSummaryStats(bool isAr) {
    final totalCourses =
        _overview?['totalCourses'] as num? ?? _myCourses.length;
    final revenue = _overview?['totalRevenue'] as num? ?? _totalSales;
    final subs =
        _overview?['totalSubscriptions'] as num? ?? _totalSubscriptions;

    final items = [
      (
        revenue.toDouble(),
        isAr ? 'إجمالي المبيعات' : 'Total Sales',
        Icons.payments_rounded
      ),
      (
        totalCourses.toDouble(),
        isAr ? 'الدورات' : 'Courses',
        Icons.menu_book_rounded
      ),
      (subs.toDouble(), isAr ? 'الطلاب' : 'Students', Icons.people_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
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
                child: Icon(Icons.analytics_rounded,
                    color: AppColors.purple, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                isAr ? 'ملخص الأرباح' : 'Earnings Summary',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final (val, label, icon) = e.value;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 0 : 8,
                    right: i == items.length - 1 ? 0 : 8,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.purple.withOpacity(0.15),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(icon, color: AppColors.purple, size: 24),
                        const SizedBox(height: 8),
                        Text(
                          val >= 1000
                              ? '${(val / 1000).toStringAsFixed(1)}K'
                              : val.toInt().toString(),
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.purple,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: AppColors.mutedForeground,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardChartsSection(bool isAr) {
    final usersGrowth = _charts!['usersGrowth'] as List? ?? const [];
    final revenue = _charts!['revenue'] as List? ?? const [];
    final courseCompletion = _charts!['courseCompletion'] as List? ?? const [];

    final hasUsers = usersGrowth.isNotEmpty;
    final hasRevenue = revenue.isNotEmpty;
    final hasCompletion = courseCompletion.isNotEmpty;
    if (!hasUsers && !hasRevenue && !hasCompletion)
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
              child: Icon(Icons.insights_rounded,
                  color: AppColors.purple, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              isAr ? 'إحصائيات لوحة التحكم' : 'Dashboard Analytics',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (hasUsers) _buildUsersGrowthChart(usersGrowth, isAr),
        if (hasUsers && (hasRevenue || hasCompletion))
          const SizedBox(height: 20),
        if (hasRevenue) _buildRevenueChart(revenue, isAr),
        if (hasRevenue && hasCompletion) const SizedBox(height: 20),
        if (hasCompletion) _buildCourseCompletionChart(courseCompletion, isAr),
      ],
    );
  }

  Widget _buildChartCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Widget child,
    String? summaryText,
    Widget? extraContent,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Icon(icon, color: accentColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              if (summaryText != null && summaryText.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    summaryText,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          child,
          if (extraContent != null) ...[
            const SizedBox(height: 16),
            extraContent,
          ],
        ],
      ),
    );
  }

  Widget _buildChartDataTable(
    List<(String, String)> rows,
    String col1Label,
    String col2Label,
    bool isAr,
  ) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.beige.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  col1Label,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              Text(
                col2Label,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.$1,
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: AppColors.foreground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      r.$2,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.purple,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildUsersGrowthChart(List usersGrowth, bool isAr) {
    final items = usersGrowth.map((e) {
      final m = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      return (
        m['month']?.toString() ?? '—',
        (m['users'] as num?)?.toDouble() ?? 0
      );
    }).toList();
    final totalStudents = items.fold<double>(0, (s, e) => s + e.$2);
    final maxY = items.isEmpty
        ? 1.0
        : items.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    final maxVal = maxY > 0 ? maxY : 1.0;

    return _buildChartCard(
      title: isAr ? 'نمو الطلاب' : 'Students Growth',
      icon: Icons.school_rounded,
      accentColor: const Color(0xFF3B82F6),
      summaryText: isAr
          ? 'الإجمالي: ${totalStudents.toInt()} طالب'
          : 'Total: ${totalStudents.toInt()} students',
      extraContent: _buildChartDataTable(
        items.map((e) => (e.$1, '${e.$2.toInt()}')).toList(),
        isAr ? 'الشهر' : 'Month',
        isAr ? 'الطلاب' : 'Students',
        isAr,
      ),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal * 1.2 + 2,
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i >= 0 && i < items.length) {
                      final label = items[i].$1;
                      final short =
                          label.length > 6 ? '${label.substring(0, 6)}' : label;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          short,
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedForeground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: maxVal > 0 ? maxVal / 4 : 1,
                  getTitlesWidget: (v, meta) => Text(
                    v.toInt().toString(),
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
              getDrawingHorizontalLine: (v) => FlLine(
                color: AppColors.border.withOpacity(0.4),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: items.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.$2,
                    color: const Color(0xFF3B82F6),
                    width: 20,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ],
                showingTooltipIndicators: [],
              );
            }).toList(),
          ),
          duration: const Duration(milliseconds: 400),
        ),
      ),
    );
  }

  Widget _buildRevenueChart(List revenue, bool isAr) {
    final items = revenue.map((e) {
      final m = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      final rev = (m['revenue'] as num?)?.toDouble() ?? 0;
      return (m['month']?.toString() ?? '—', rev);
    }).toList();
    final totalRevenue = items.fold<double>(0, (s, e) => s + e.$2);
    final maxY = items.isEmpty
        ? 1.0
        : items.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    final maxVal = maxY > 0 ? maxY : 1.0;

    return _buildChartCard(
      title: isAr ? 'الإيرادات الشهرية' : 'Monthly Revenue',
      icon: Icons.payments_rounded,
      accentColor: const Color(0xFF22C55E),
      summaryText: isAr
          ? 'الإجمالي: ${totalRevenue.toInt()} ريال'
          : 'Total: ${totalRevenue.toInt()} SAR',
      extraContent: _buildChartDataTable(
        items
            .map((e) => (e.$1, '${e.$2.toInt()} ${isAr ? 'ريال' : 'SAR'}'))
            .toList(),
        isAr ? 'الشهر' : 'Month',
        isAr ? 'المبلغ' : 'Amount',
        isAr,
      ),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal * 1.2 + 2,
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i >= 0 && i < items.length) {
                      final label = items[i].$1;
                      final short =
                          label.length > 6 ? '${label.substring(0, 6)}' : label;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          short,
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedForeground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: maxVal > 0 ? maxVal / 4 : 1,
                  getTitlesWidget: (v, meta) => Text(
                    v.toInt().toString(),
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
              getDrawingHorizontalLine: (v) => FlLine(
                color: AppColors.border.withOpacity(0.4),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: items.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.$2,
                    color: const Color(0xFF22C55E),
                    width: 20,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ],
                showingTooltipIndicators: [],
              );
            }).toList(),
          ),
          duration: const Duration(milliseconds: 400),
        ),
      ),
    );
  }

  Widget _buildCourseCompletionChart(List courseCompletion, bool isAr) {
    final items = courseCompletion.map((e) {
      final m = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      final name = m['name']?.toString() ?? '—';
      final value = (m['value'] as num?)?.toDouble() ?? 0;
      final colorStr = m['color']?.toString() ?? '#64748b';
      Color color;
      try {
        color = Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
      } catch (_) {
        color = AppColors.mutedForeground;
      }
      return (name: name, value: value, color: color);
    }).toList();
    final total = items.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) {
      return _buildChartCard(
        title: isAr ? 'حالة إكمال الدورات' : 'Course Completion Status',
        icon: Icons.pie_chart_rounded,
        accentColor: AppColors.purple,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              isAr ? 'لا توجد بيانات' : 'No data',
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ),
      );
    }

    final sections = items.asMap().entries.map((e) {
      final pct = total > 0 ? (e.value.value / total * 100) : 0;
      return PieChartSectionData(
        value: e.value.value,
        title: pct >= 5 ? '${pct.toInt()}%' : '',
        color: e.value.color,
        radius: 48,
        titleStyle: GoogleFonts.cairo(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return _buildChartCard(
      title: isAr ? 'حالة إكمال الدورات' : 'Course Completion Status',
      icon: Icons.pie_chart_rounded,
      accentColor: AppColors.purple,
      summaryText:
          isAr ? 'الإجمالي: ${total.toInt()}' : 'Total: ${total.toInt()}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 2,
                    centerSpaceRadius: 24,
                  ),
                  duration: const Duration(milliseconds: 400),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: items.map((e) {
                    final pct = total > 0 ? (e.value / total * 100) : 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: e.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: e.color.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: e.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e.name,
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.foreground,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${e.value.toInt()}',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: e.color,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${pct.toStringAsFixed(1)}%)',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.beige.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: items.map((e) {
                final pct = total > 0 ? (e.value / total * 100) : 0;
                return Column(
                  children: [
                    Text(
                      e.name,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${e.value.toInt()}',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: e.color,
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyEarningsChart(bool isAr) {
    if (_monthlyEarnings.isEmpty) {
      return _buildEmptyChartCard(
        isAr,
        isAr ? 'لا توجد مبيعات شهرية بعد' : 'No monthly earnings yet',
        isAr
            ? 'ستظهر الرسوم البيانية عند وجود مدفوعات'
            : 'Charts will show when payments exist',
        icon: Icons.show_chart_rounded,
      );
    }

    final sorted = _monthlyEarnings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final last6 =
        sorted.length > 6 ? sorted.sublist(sorted.length - 6) : sorted;
    final maxY = last6.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    final spots = last6.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(Icons.show_chart_rounded, color: AppColors.purple, size: 24),
              const SizedBox(width: 10),
              Text(
                isAr ? 'المبيعات الشهرية' : 'Monthly Earnings',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.grey.withOpacity(0.2),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: maxY > 0 ? maxY / 4 : 1,
                      getTitlesWidget: (v, meta) => Text(
                        v.toInt().toString(),
                        style: GoogleFonts.cairo(
                          fontSize: 10,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i >= 0 && i < last6.length) {
                          final key = last6[i].key;
                          final parts = key.split('-');
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              parts.length >= 2 ? parts[1] : key,
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (last6.length - 1).toDouble(),
                minY: 0,
                maxY: maxY * 1.2 + 1,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.purple,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 4,
                        color: AppColors.purple,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.purple.withOpacity(0.3),
                          AppColors.purple.withOpacity(0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryBreakdownChart(bool isAr) {
    final baseSalary =
        (_salarySettings?['baseSalary'] as num?)?.toDouble() ?? 0;
    final commissionType =
        _salarySettings?['commissionType']?.toString() ?? 'percentage';
    final commissionValue =
        (_salarySettings?['commissionValue'] as num?)?.toDouble() ?? 0;

    double commissionAmount = 0;
    if (commissionType == 'percentage') {
      commissionAmount = _totalSales * (commissionValue / 100);
    } else {
      commissionAmount = commissionValue * _totalSubscriptions;
    }

    final total = baseSalary + commissionAmount;
    if (total <= 0) {
      return _buildEmptyChartCard(
        isAr,
        isAr ? 'احسب المرتب أولاً' : 'Calculate salary first',
        isAr
            ? 'اختر الفترة من الأسفل واضغط حساب لمعرفة حصتك'
            : 'Select period below and tap Calculate to see your share',
        icon: Icons.calculate_rounded,
      );
    }

    final sections = <PieChartSectionData>[];
    if (baseSalary > 0) {
      sections.add(PieChartSectionData(
        value: baseSalary,
        title: '${((baseSalary / total) * 100).toStringAsFixed(0)}%',
        color: AppColors.purple,
        radius: 60,
        titleStyle: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }
    if (commissionAmount > 0) {
      sections.add(PieChartSectionData(
        value: commissionAmount,
        title: '${((commissionAmount / total) * 100).toStringAsFixed(0)}%',
        color: AppColors.orange,
        radius: 60,
        titleStyle: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    if (sections.isEmpty) {
      return _buildEmptyChartCard(
        isAr,
        isAr ? 'احسب المرتب أولاً' : 'Calculate salary first',
        isAr
            ? 'اختر الفترة من الأسفل واضغط حساب لمعرفة حصتك'
            : 'Select period below and tap Calculate to see your share',
        icon: Icons.calculate_rounded,
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.purple.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
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
                child: Icon(Icons.pie_chart_rounded,
                    color: AppColors.purple, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                isAr ? 'توزيع المرتب' : 'Salary Breakdown',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                  ),
                  swapAnimationDuration: const Duration(milliseconds: 400),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendItem(
                      isAr ? 'المرتب الأساسي' : 'Base Salary',
                      baseSalary,
                      AppColors.purple,
                    ),
                    const SizedBox(height: 12),
                    _legendItem(
                      isAr ? 'العمولة' : 'Commission',
                      commissionAmount,
                      AppColors.orange,
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      '${total.toStringAsFixed(1)} ${isAr ? 'ريال' : 'SAR'}',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.foreground,
                      ),
                    ),
                    Text(
                      isAr ? 'الإجمالي' : 'Total',
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
        ],
      ),
    );
  }

  Widget _legendItem(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                ),
              ),
              Text(
                '${value.toStringAsFixed(1)} ${Localizations.localeOf(context).languageCode == 'ar' ? 'ريال' : 'SAR'}',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyChartCard(bool isAr, String title, String subtitle,
      {IconData icon = Icons.bar_chart_rounded}) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purple.withOpacity(0.04),
            AppColors.orange.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.purple.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.purple.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child:
                Icon(icon, size: 40, color: AppColors.purple.withOpacity(0.7)),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.cairo(
              fontSize: 14,
              height: 1.4,
              color: AppColors.mutedForeground,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisSummary(bool isAr) {
    final coursesCount = _myCourses.length;
    final totalStudents = _totalSubscriptions;
    final totalSales = _totalSales;
    final commissionType =
        _salarySettings?['commissionType']?.toString() ?? 'percentage';
    final commissionValue =
        (_salarySettings?['commissionValue'] as num?)?.toDouble() ?? 0;

    double commission = 0;
    if (commissionType == 'percentage') {
      commission = totalSales * (commissionValue / 100);
    } else {
      commission = commissionValue * totalStudents;
    }

    final baseSalary =
        (_salarySettings?['baseSalary'] as num?)?.toDouble() ?? 0;
    final estimatedTotal = baseSalary + commission;

    final avgPerStudent = totalStudents > 0 ? totalSales / totalStudents : 0.0;
    final avgPerCourse = coursesCount > 0 ? totalSales / coursesCount : 0.0;

    final insights = <String>[];
    if (totalSales > 0) {
      insights.add(isAr
          ? '• إجمالي المبيعات: ${totalSales.toStringAsFixed(1)} ريال'
          : '• Total sales: ${totalSales.toStringAsFixed(1)} SAR');
    }
    if (totalStudents > 0) {
      insights.add(isAr
          ? '• متوسط قيمة الطالب: ${avgPerStudent.toStringAsFixed(1)} ريال'
          : '• Avg per student: ${avgPerStudent.toStringAsFixed(1)} SAR');
    }
    if (coursesCount > 0 && totalSales > 0) {
      insights.add(isAr
          ? '• متوسط دخل الدورة: ${avgPerCourse.toStringAsFixed(1)} ريال'
          : '• Avg per course: ${avgPerCourse.toStringAsFixed(1)} SAR');
    }
    if (estimatedTotal > 0) {
      insights.add(isAr
          ? '• المرتب التقديري (أساسي + عمولة): ${estimatedTotal.toStringAsFixed(1)} ريال'
          : '• Est. salary (base + commission): ${estimatedTotal.toStringAsFixed(1)} SAR');
    }

    if (insights.isEmpty) {
      insights.add(isAr
          ? 'لا توجد بيانات كافية للتحليل بعد. قم بإضافة دورات وجذب طلاب.'
          : 'Not enough data for analysis yet. Add courses and attract students.');
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purple.withOpacity(0.08),
            AppColors.orange.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.purple.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, color: AppColors.purple, size: 24),
              const SizedBox(width: 10),
              Text(
                isAr ? 'تحليل الأرباح' : 'Earnings Analysis',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...insights.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                s,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: AppColors.foreground,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalarySettingsCard(bool isAr) {
    final baseSalary =
        (_salarySettings?['baseSalary'] as num?)?.toDouble() ?? 0;
    final commissionType =
        _salarySettings?['commissionType']?.toString() ?? 'percentage';
    final commissionValue =
        (_salarySettings?['commissionValue'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.purple.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
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
                child: Icon(Icons.settings_rounded,
                    color: AppColors.purple, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                isAr ? 'إعدادات المرتب' : 'Salary settings',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _row(isAr ? 'المرتب الأساسي' : 'Base salary', '$baseSalary'),
          const SizedBox(height: 8),
          _row(
            isAr ? 'نوع العمولة' : 'Commission type',
            commissionType,
          ),
          const SizedBox(height: 8),
          _row(
            isAr ? 'قيمة العمولة' : 'Commission value',
            '$commissionValue${commissionType == 'percentage' ? '%' : ''}',
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 14,
            color: AppColors.mutedForeground,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.foreground,
          ),
        ),
      ],
    );
  }

  Widget _buildCalculateCard(bool isAr) {
    final now = DateTime.now();
    final start = _startDate ?? DateTime(now.year, now.month, 1);
    final end = _endDate ?? DateTime(now.year, now.month + 1, 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppColors.purple.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.purple.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
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
                child: Icon(Icons.calculate_rounded,
                    color: AppColors.purple, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                isAr ? 'حساب المرتب لفترة' : 'Calculate salary for period',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? start,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null && mounted)
                      setState(() => _startDate = date);
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(
                    (_startDate ?? start).toIso8601String().split('T').first,
                    style: GoogleFonts.cairo(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final lastDate = DateTime.now();
                    final first =
                        _startDate ?? DateTime(now.year, now.month, 1);
                    final initial =
                        _endDate ?? (end.isAfter(lastDate) ? lastDate : end);
                    final date = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: first.isAfter(lastDate) ? lastDate : first,
                      lastDate: lastDate,
                    );
                    if (date != null && mounted)
                      setState(() => _endDate = date);
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(
                    (_endDate ?? end).toIso8601String().split('T').first,
                    style: GoogleFonts.cairo(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _calculateSalary,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.calculate_rounded, size: 22),
              label: Text(
                isAr ? 'حساب' : 'Calculate',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(bool isAr) {
    double teacherShare = 0;
    final ts = _calculation?['teacherShare'];
    if (ts != null) {
      teacherShare =
          ts is num ? ts.toDouble() : (double.tryParse(ts.toString()) ?? 0);
    } else {
      teacherShare = (_calculation?['totalEarnings'] as num?)?.toDouble() ?? 0;
    }
    final totalRevenue = _calculation?['totalRevenue'];
    final rev = totalRevenue != null
        ? (totalRevenue is num
            ? totalRevenue.toDouble()
            : double.tryParse(totalRevenue.toString()) ?? 0)
        : 0.0;
    final centerProfit = _calculation?['centerProfit'];
    final center = centerProfit != null
        ? (centerProfit is num
            ? centerProfit.toDouble()
            : double.tryParse(centerProfit.toString()) ?? 0.0)
        : 0.0;
    final sessionsCount =
        (_calculation?['sessionsCount'] as num?)?.toInt() ?? 0;
    final studentsCount =
        (_calculation?['studentsCount'] as num?)?.toInt() ?? 0;
    final sessionDetails = _calculation?['sessionDetails'] as List?;
    final period = _calculation?['period'];
    String periodStr = '';
    if (period is Map) {
      final start = period['startDate']?.toString() ?? '';
      final end = period['endDate']?.toString() ?? '';
      if (start.isNotEmpty && end.isNotEmpty) {
        periodStr = '$start ${isAr ? 'إلى' : '–'} $end';
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purple.withOpacity(0.06),
            AppColors.orange.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.purple.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.purple.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: AppColors.purple,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAr
                              ? 'نتيجة حساب المرتب'
                              : 'Salary Calculation Result',
                          style: GoogleFonts.cairo(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.foreground,
                          ),
                        ),
                        if (periodStr.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            periodStr,
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: AppColors.purple.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.purple.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        isAr ? 'حصتك' : 'Your Share',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${teacherShare.toStringAsFixed(2)} ${isAr ? 'ريال' : 'SAR'}',
                        style: GoogleFonts.cairo(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.purple,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (rev > 0)
                      Expanded(
                        child: _buildResultStatItem(
                          isAr ? 'إجمالي الإيرادات' : 'Total Revenue',
                          rev,
                          Icons.trending_up_rounded,
                          const Color(0xFF22C55E),
                        ),
                      ),
                    if (rev > 0) const SizedBox(width: 12),
                    if (center > 0)
                      Expanded(
                        child: _buildResultStatItem(
                          isAr ? 'ربح المركز' : 'Center Profit',
                          center,
                          Icons.store_rounded,
                          AppColors.orange,
                        ),
                      ),
                  ],
                ),
                if ((sessionsCount > 0 || studentsCount > 0) &&
                    (rev > 0 || center > 0))
                  const SizedBox(height: 12),
                if (sessionsCount > 0 || studentsCount > 0)
                  Row(
                    children: [
                      if (sessionsCount > 0)
                        Expanded(
                          child: _buildResultStatItem(
                            isAr ? 'جلسات' : 'Sessions',
                            sessionsCount.toDouble(),
                            Icons.event_available_rounded,
                            const Color(0xFF3B82F6),
                            isCount: true,
                          ),
                        ),
                      if (sessionsCount > 0 && studentsCount > 0)
                        const SizedBox(width: 12),
                      if (studentsCount > 0)
                        Expanded(
                          child: _buildResultStatItem(
                            isAr ? 'طلاب' : 'Students',
                            studentsCount.toDouble(),
                            Icons.people_rounded,
                            const Color(0xFF1D6FD6),
                            isCount: true,
                          ),
                        ),
                    ],
                  ),
                if (sessionDetails != null && sessionDetails.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.list_alt_rounded,
                          size: 20, color: AppColors.purple),
                      const SizedBox(width: 8),
                      Text(
                        isAr ? 'تفاصيل الجلسات' : 'Session Details',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...sessionDetails.take(8).map((s) {
                    final m = s is Map ? Map<String, dynamic>.from(s) : null;
                    if (m == null) return const SizedBox.shrink();
                    final courseName = m['courseName']?.toString() ?? '—';
                    final studentName = m['studentName']?.toString() ?? '';
                    final revStr = m['revenue']?.toString() ?? '0';
                    final revVal = double.tryParse(revStr) ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.purple.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.purple.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.play_lesson_rounded,
                              size: 20,
                              color: AppColors.purple,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  courseName,
                                  style: GoogleFonts.cairo(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.foreground,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (studentName.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    studentName,
                                    style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      color: AppColors.mutedForeground,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            '${revVal.toStringAsFixed(2)} ${isAr ? 'ريال' : 'SAR'}',
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.purple,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (sessionDetails.length > 8)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        isAr
                            ? '+ ${sessionDetails.length - 8} جلسة أخرى'
                            : '+ ${sessionDetails.length - 8} more sessions',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultStatItem(
    String label,
    double value,
    IconData icon,
    Color color, {
    bool isCount = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCount ? value.toInt().toString() : value.toStringAsFixed(2),
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsCard(bool isAr) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.purple.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () async {
              if (_reportsExpanded) {
                setState(() => _reportsExpanded = false);
                return;
              }
              setState(() => _reportsExpanded = true);
              if (_reports == null && _reportsError == null) {
                try {
                  setState(() => _reportsError = null);
                  final profile = await ProfileService.instance.getProfile();
                  final userId = profile['id']?.toString();
                  final reports = await TeacherDashboardService.instance
                      .getReports(teacherId: userId);
                  if (mounted) {
                    setState(() {
                      _reports = reports;
                      _reportsError = null;
                    });
                  }
                } catch (e) {
                  if (kDebugMode) {
                    print('❌ InstructorEarningsScreen getReports: $e');
                  }
                  if (mounted) {
                    setState(() {
                      _reports = <String, dynamic>{};
                      _reportsError =
                          e.toString().replaceFirst('Exception: ', '');
                    });
                  }
                }
              }
            },
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.assignment_rounded,
                      color: AppColors.purple, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isAr ? 'التقارير' : 'Reports',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                  Icon(
                    _reportsExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.mutedForeground,
                  ),
                ],
              ),
            ),
          ),
          if (_reportsExpanded) ...[
            Divider(height: 1, color: Colors.grey[200]),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _reports == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _buildReportsContent(isAr),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportsContent(bool isAr) {
    if (_reportsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded,
                size: 40, color: AppColors.destructive),
            const SizedBox(height: 12),
            Text(
              _reportsError!,
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                setState(() {
                  _reports = null;
                  _reportsError = null;
                });
                try {
                  final profile = await ProfileService.instance.getProfile();
                  final userId = profile['id']?.toString();
                  final reports = await TeacherDashboardService.instance
                      .getReports(teacherId: userId);
                  if (mounted) {
                    setState(() {
                      _reports = reports;
                      _reportsError = null;
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      _reports = <String, dynamic>{};
                      _reportsError =
                          e.toString().replaceFirst('Exception: ', '');
                    });
                  }
                }
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                isAr ? 'إعادة المحاولة' : 'Retry',
                style: GoogleFonts.cairo(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }
    // API may return list in 'data', 'reports', 'items', or 'list' key
    final raw = _reports!['data'] ??
        _reports!['reports'] ??
        _reports!['items'] ??
        _reports!['list'];
    final list = raw is List ? raw : const [];
    if (kDebugMode && list.isEmpty && _reports!.isNotEmpty) {
      print('📋 Reports API keys: ${_reports!.keys.toList()}');
    }
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          isAr ? 'لا توجد تقارير' : 'No reports',
          style: GoogleFonts.cairo(
            fontSize: 14,
            color: AppColors.mutedForeground,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: list.take(10).map((e) {
        final m = e is Map<String, dynamic>
            ? Map<String, dynamic>.from(e)
            : <String, dynamic>{};
        final title = m['title']?.toString() ?? m['type']?.toString() ?? '—';
        final date = m['createdAt']?.toString() ?? m['date']?.toString() ?? '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showReportDetailsSheet(context, m, isAr),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.description_outlined,
                      size: 18, color: AppColors.purple),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.foreground,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (date.isNotEmpty)
                          Text(
                            date.length > 10 ? date.substring(0, 10) : date,
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: AppColors.mutedForeground,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  static bool _isIdKey(String key) {
    final k = key.toLowerCase();
    return k == 'id' ||
        k == '_id' ||
        k.endsWith('id') ||
        k.contains('uuid') ||
        k == 'guid';
  }

  static String _labelForKey(String key, bool isAr) {
    const labels = {
      'title': 'Title',
      'type': 'Type',
      'date': 'Date',
      'createdAt': 'Created',
      'updatedAt': 'Updated',
      'period': 'Period',
      'amount': 'Amount',
      'revenue': 'Revenue',
      'totalEarnings': 'Total Earnings',
      'teacherName': 'Teacher',
      'courseName': 'Course',
      'studentName': 'Student',
      'sessionType': 'Session Type',
      'status': 'Status',
      'description': 'Description',
      'summary': 'Summary',
    };
    const labelsAr = {
      'title': 'العنوان',
      'type': 'النوع',
      'date': 'التاريخ',
      'createdAt': 'تاريخ الإنشاء',
      'updatedAt': 'آخر تحديث',
      'period': 'الفترة',
      'amount': 'المبلغ',
      'revenue': 'الإيرادات',
      'totalEarnings': 'إجمالي الأرباح',
      'teacherName': 'المدرس',
      'courseName': 'الدورة',
      'studentName': 'الطالب',
      'sessionType': 'نوع الجلسة',
      'status': 'الحالة',
      'description': 'الوصف',
      'summary': 'الملخص',
    };
    return (isAr ? labelsAr[key] : labels[key]) ?? key;
  }

  void _showReportDetailsSheet(
      BuildContext context, Map<String, dynamic> report, bool isAr) {
    final entries = report.entries
        .where((e) => !_isIdKey(e.key))
        .where((e) => e.value != null && e.value.toString().trim().isNotEmpty)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: AppColors.purple.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 14, bottom: 4),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.purple.withOpacity(0.08),
                      AppColors.orange.withOpacity(0.04),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.assessment_rounded,
                        color: AppColors.purple,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAr ? 'تفاصيل التقرير' : 'Report Details',
                            style: GoogleFonts.cairo(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isAr
                                ? 'عرض معلومات التقرير'
                                : 'View report information',
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    final key = e.key;
                    var val = e.value;
                    String displayVal;
                    if (val is DateTime) {
                      displayVal =
                          '${val.year}-${val.month.toString().padLeft(2, '0')}-${val.day.toString().padLeft(2, '0')}';
                    } else if (val is Map || val is List) {
                      displayVal = val.toString();
                    } else if (val != null) {
                      final s = val.toString().trim();
                      final dt = DateTime.tryParse(s);
                      displayVal = dt != null
                          ? '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}'
                          : s;
                    } else {
                      displayVal = '—';
                    }
                    if (displayVal.length > 100) {
                      displayVal = '${displayVal.substring(0, 100)}...';
                    }
                    final label = _labelForKey(key, isAr);
                    final isDate = key.toLowerCase().contains('date') ||
                        key.toLowerCase().contains('at');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.purple.withOpacity(0.08),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDate
                                  ? AppColors.orange.withOpacity(0.1)
                                  : AppColors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isDate
                                  ? Icons.calendar_today_rounded
                                  : Icons.info_outline_rounded,
                              size: 18,
                              color:
                                  isDate ? AppColors.orange : AppColors.purple,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  displayVal,
                                  style: GoogleFonts.cairo(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.foreground,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
              onPressed: _loadAllData,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry, style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }
}
