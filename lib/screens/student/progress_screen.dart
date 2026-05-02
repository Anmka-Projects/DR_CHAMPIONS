import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_text_styles.dart';
import '../../core/navigation/route_names.dart';
import '../../widgets/bottom_nav.dart';
import '../../l10n/app_localizations.dart';
import '../../services/progress_service.dart';
import '../../services/courses_service.dart';

/// Progress Screen - Pixel-perfect match to React version
/// Matches: components/screens/progress-screen.tsx
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with WidgetsBindingObserver {
  String _period = 'weekly';
  String _selectedSubjectKey = 'all';
  bool _isLoading = true;
  bool _isLoadingEnrollments = true;
  String? _error;
  Map<String, dynamic>? _progressData;
  List<Map<String, dynamic>> _enrolledCourses = [];
  Map<String, dynamic>? _selectedCourse;

  // Chart data from API
  List<Map<String, dynamic>> _chartData = [];

  // Top students from API
  List<Map<String, dynamic>> _topStudents = [];
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchProgressData();
    _fetchEnrollments();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshProgressState();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      _refreshProgressState();
    });
  }

  Future<void> _refreshProgressState() async {
    await Future.wait([
      _fetchEnrollments(),
      _fetchProgressData(),
    ]);
  }

  Future<void> _fetchProgressData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ProgressService.instance.getProgressData(_period);
      if (!mounted) return;
      setState(() {
        _progressData = data;
        _isLoading = false;

        if (data['chart_data'] != null) {
          final chartData = data['chart_data'] as Map<String, dynamic>;
          _chartData = List<Map<String, dynamic>>.from(
            chartData[_period] as List? ?? [],
          );
        }

        if (data['top_students'] != null) {
          _topStudents = List<Map<String, dynamic>>.from(
            data['top_students'] as List? ?? [],
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchEnrollments() async {
    setState(() => _isLoadingEnrollments = true);
    try {
      final result = await CoursesService.instance.getEnrollments(
        status: 'all',
        page: 1,
        perPage: 100,
      );
      if (!mounted) return;
      final List<Map<String, dynamic>> courses = [];
      final dynamic data = result['data'];

      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) courses.add(item);
        }
      } else if (data is Map<String, dynamic>) {
        final nested = data['courses'] ?? data['enrollments'] ?? data['items'];
        if (nested is List) {
          for (final item in nested) {
            if (item is Map<String, dynamic>) courses.add(item);
          }
        }
      }

      final direct = result['enrollments'];
      if (courses.isEmpty && direct is List) {
        for (final item in direct) {
          if (item is Map<String, dynamic>) courses.add(item);
        }
      }
      setState(() {
        _enrolledCourses = courses;
        _isLoadingEnrollments = false;
        final selectedExists = _selectedSubjectKey == 'all' ||
            courses.any((e) => _courseId(e) == _selectedSubjectKey);
        if (!selectedExists) {
          _selectedSubjectKey = 'all';
        }
        if (courses.isNotEmpty) {
          if (_selectedSubjectKey == 'all') {
            _selectedCourse = courses.first;
          } else {
            _selectedCourse = courses.firstWhere(
              (e) => _courseId(e) == _selectedSubjectKey,
              orElse: () => courses.first,
            );
          }
        } else {
          _selectedCourse = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingEnrollments = false);
    }
  }

  void _onPeriodChanged(String period) {
    if (_period != period) {
      setState(() {
        _period = period;
      });
      _fetchProgressData();
    }
  }

  List<Map<String, String>> _subjectOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final all = [
      {'key': 'all', 'label': l10n.allSubjects},
    ];
    for (final enrollment in _enrolledCourses) {
      final id = _courseId(enrollment);
      final title = _courseTitle(enrollment);
      if (id.isNotEmpty) {
        all.add({'key': id, 'label': title});
      }
    }
    return all;
  }

  String _selectedSubjectLabel(BuildContext context) {
    final options = _subjectOptions(context);
    return options.firstWhere(
      (o) => o['key'] == _selectedSubjectKey,
      orElse: () => options.first,
    )['label']!;
  }

  List<Map<String, dynamic>> _displayedEnrollments() {
    if (_selectedSubjectKey == 'all') return _enrolledCourses;
    return _enrolledCourses
        .where((e) => _courseId(e) == _selectedSubjectKey)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 400),
              margin: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 400
                    ? (MediaQuery.of(context).size.width - 400) / 2
                    : 0,
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _error!,
                                style: AppTextStyles.bodyMedium(
                                  color: Colors.red,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchProgressData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header - matches React Header component
                              _buildHeader(context),

                              // Content - matches React: px-4 space-y-4
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16), // px-4
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 16),

                                    // Title and filter - matches React: flex items-center justify-between
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context)!
                                              .progress,
                                          style: AppTextStyles.h2(
                                            color: AppColors.foreground,
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          onSelected: (value) {
                                            if (_selectedSubjectKey == value) {
                                              return;
                                            }
                                            setState(() {
                                              _selectedSubjectKey = value;
                                              if (value == 'all') {
                                                _selectedCourse =
                                                    _enrolledCourses.isNotEmpty
                                                        ? _enrolledCourses.first
                                                        : null;
                                              } else {
                                                _selectedCourse = _enrolledCourses
                                                    .firstWhere(
                                                  (e) =>
                                                      _courseId(e) == value,
                                                  orElse: () => _enrolledCourses
                                                          .isNotEmpty
                                                      ? _enrolledCourses.first
                                                      : <String, dynamic>{},
                                                );
                                              }
                                            });
                                          },
                                          itemBuilder: (context) {
                                            final options =
                                                _subjectOptions(context);
                                            return options
                                                .map(
                                                  (option) => PopupMenuItem<
                                                      String>(
                                                    value: option['key']!,
                                                    child: Text(
                                                      option['label']!,
                                                      style: AppTextStyles
                                                          .bodySmall(
                                                        color: AppColors
                                                            .foreground,
                                                      ).copyWith(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList();
                                          },
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          color: Colors.white,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16, // px-4
                                              vertical: 8, // py-2
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.lavenderLight,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      999), // rounded-full
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.bar_chart,
                                                  size: 16, // w-4 h-4
                                                  color: AppColors.purple,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _selectedSubjectLabel(
                                                      context),
                                                  style:
                                                      AppTextStyles.bodySmall(
                                                    color: AppColors.purple,
                                                  ).copyWith(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.keyboard_arrow_down,
                                                  size: 16,
                                                  color: AppColors.purple,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16), // space-y-4

                                    // Stats card - matches React: bg-white rounded-3xl p-5 shadow-sm
                                    Container(
                                      padding: const EdgeInsets.all(20), // p-5
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                            24), // rounded-3xl
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          // Header row - matches React: mb-4
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 16), // mb-4
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Container(
                                                  width: 32, // w-8
                                                  height: 32, // h-8
                                                  decoration: BoxDecoration(
                                                    color:
                                                        AppColors.purpleLight,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8), // rounded-lg
                                                  ),
                                                  child: const Icon(
                                                    Icons.bar_chart,
                                                    size: 16, // w-4 h-4
                                                    color: AppColors.purple,
                                                  ),
                                                ),
                                                // Period toggle - matches React: bg-gray-100 rounded-full p-1
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                      4), // p-1
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[100],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999), // rounded-full
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      GestureDetector(
                                                        onTap: () =>
                                                            _onPeriodChanged(
                                                                'weekly'),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal:
                                                                16, // px-4
                                                            vertical: 4, // py-1
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: _period ==
                                                                    'weekly'
                                                                ? Colors.white
                                                                : Colors
                                                                    .transparent,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        999),
                                                            boxShadow:
                                                                _period ==
                                                                        'weekly'
                                                                    ? [
                                                                        BoxShadow(
                                                                          color: Colors
                                                                              .black
                                                                              .withOpacity(0.1),
                                                                          blurRadius:
                                                                              4,
                                                                          offset: const Offset(
                                                                              0,
                                                                              2),
                                                                        ),
                                                                      ]
                                                                    : null,
                                                          ),
                                                          child: Text(
                                                            AppLocalizations.of(
                                                                    context)!
                                                                .weekly,
                                                            style: AppTextStyles
                                                                .bodySmall(
                                                              color: AppColors
                                                                  .foreground,
                                                            ).copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500),
                                                          ),
                                                        ),
                                                      ),
                                                      GestureDetector(
                                                        onTap: () =>
                                                            _onPeriodChanged(
                                                                'monthly'),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal:
                                                                16, // px-4
                                                            vertical: 4, // py-1
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: _period ==
                                                                    'monthly'
                                                                ? Colors.white
                                                                : Colors
                                                                    .transparent,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        999),
                                                            boxShadow:
                                                                _period ==
                                                                        'monthly'
                                                                    ? [
                                                                        BoxShadow(
                                                                          color: Colors
                                                                              .black
                                                                              .withOpacity(0.1),
                                                                          blurRadius:
                                                                              4,
                                                                          offset: const Offset(
                                                                              0,
                                                                              2),
                                                                        ),
                                                                      ]
                                                                    : null,
                                                          ),
                                                          child: Text(
                                                            AppLocalizations.of(
                                                                    context)!
                                                                .monthly,
                                                            style: AppTextStyles
                                                                .bodySmall(
                                                              color: AppColors
                                                                  .foreground,
                                                            ).copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Stats - matches React: gap-8 mb-6
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 24), // mb-6
                                            child: Row(
                                              children: [
                                                // Lessons count
                                                RichText(
                                                  text: TextSpan(
                                                    children: [
                                                      TextSpan(
                                                        text:
                                                            '${_progressData?['statistics']?['completed_lessons'] ?? 0} ',
                                                        style: AppTextStyles.h1(
                                                          color: AppColors
                                                              .foreground,
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text:
                                                            AppLocalizations.of(
                                                                    context)!
                                                                .lesson,
                                                        style: AppTextStyles
                                                            .bodyMedium(
                                                          color: AppColors
                                                              .mutedForeground,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(
                                                    width: 32), // gap-8
                                                // Hours count
                                                RichText(
                                                  text: TextSpan(
                                                    children: [
                                                      TextSpan(
                                                        text:
                                                            '${_progressData?['statistics']?['total_hours'] ?? 0} ',
                                                        style: AppTextStyles.h1(
                                                          color: AppColors
                                                              .foreground,
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text:
                                                            AppLocalizations.of(
                                                                    context)!
                                                                .hour,
                                                        style: AppTextStyles
                                                            .bodyMedium(
                                                          color: AppColors
                                                              .mutedForeground,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Horizontal bar chart - matches React HorizontalBarChart
                                          _buildHorizontalBarChart(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // ──────────────────────────────────────
                                    // My Courses Progress
                                    // ──────────────────────────────────────
                                    _buildCoursesProgressSection(context),

                                    const SizedBox(height: 16),

                                    // Rating of students - matches React: bg-white rounded-3xl p-5 shadow-sm
                                    Container(
                                      padding: const EdgeInsets.all(20), // p-5
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                            24), // rounded-3xl
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 40, // w-10
                                                height: 40, // h-10
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      Colors.yellow[300]!,
                                                      Colors.yellow[600]!,
                                                    ],
                                                  ),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Center(
                                                  child: Text('⭐',
                                                      style: TextStyle(
                                                          fontSize: 18)),
                                                ),
                                              ),
                                              const SizedBox(
                                                  width: 12), // gap-3
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    AppLocalizations.of(
                                                            context)!
                                                        .studentRating,
                                                    style: AppTextStyles
                                                        .bodyMedium(
                                                      color:
                                                          AppColors.foreground,
                                                    ).copyWith(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  Text(
                                                    AppLocalizations.of(
                                                            context)!
                                                        .top10Students,
                                                    style:
                                                        AppTextStyles.bodySmall(
                                                      color: AppColors
                                                          .mutedForeground,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                '• • •',
                                                style: AppTextStyles.bodyMedium(
                                                  color:
                                                      AppColors.mutedForeground,
                                                ),
                                              ),
                                              const SizedBox(width: 8), // mr-2
                                              // Student avatars - matches React: flex -space-x-2
                                              SizedBox(
                                                width:
                                                    72, // 3 circles with overlap
                                                height: 32,
                                                child: Stack(
                                                  children: _topStudents
                                                      .take(3)
                                                      .toList()
                                                      .asMap()
                                                      .entries
                                                      .map((entry) {
                                                    final index = entry.key;
                                                    final student = entry.value;
                                                    final avatarUrl =
                                                        student['avatar']
                                                            as String?;
                                                    return Positioned(
                                                      left: index * 16.0,
                                                      child: Container(
                                                        width: 32, // w-8
                                                        height: 32, // h-8
                                                        decoration:
                                                            BoxDecoration(
                                                          color: AppColors
                                                              .orangeLight,
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                            color: Colors.white,
                                                            width: 2,
                                                          ),
                                                        ),
                                                        child: ClipOval(
                                                          child: avatarUrl !=
                                                                      null &&
                                                                  avatarUrl
                                                                      .isNotEmpty
                                                              ? Image.network(
                                                                  avatarUrl,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  errorBuilder: (context,
                                                                          error,
                                                                          stackTrace) =>
                                                                      const Icon(
                                                                    Icons
                                                                        .person,
                                                                    size: 16,
                                                                    color: AppColors
                                                                        .purple,
                                                                  ),
                                                                )
                                                              : Image.asset(
                                                                  'assets/images/user-avatar.png',
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  errorBuilder: (context,
                                                                          error,
                                                                          stackTrace) =>
                                                                      const Icon(
                                                                    Icons
                                                                        .person,
                                                                    size: 16,
                                                                    color: AppColors
                                                                        .purple,
                                                                  ),
                                                                ),
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16), // space-y-4

                                    // My exams button - matches React: w-full bg-white rounded-3xl p-5
                                    GestureDetector(
                                      onTap: () =>
                                          context.push(RouteNames.myExams),
                                      child: Container(
                                        padding:
                                            const EdgeInsets.all(20), // p-5
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                              24), // rounded-3xl
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 48, // w-12
                                              height: 48, // h-12
                                              decoration: BoxDecoration(
                                                color: AppColors.orange
                                                    .withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        16), // rounded-2xl
                                              ),
                                              child: const Icon(
                                                Icons.description,
                                                size: 24, // w-6 h-6
                                                color: AppColors.orange,
                                              ),
                                            ),
                                            const SizedBox(width: 16), // gap-4
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    AppLocalizations.of(
                                                            context)!
                                                        .myExamsButton,
                                                    style: AppTextStyles
                                                        .bodyMedium(
                                                      color:
                                                          AppColors.foreground,
                                                    ).copyWith(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  Text(
                                                    AppLocalizations.of(
                                                            context)!
                                                        .viewAllCompletedExams,
                                                    style:
                                                        AppTextStyles.bodySmall(
                                                      color: AppColors
                                                          .mutedForeground,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Transform.rotate(
                                              angle:
                                                  1.5708, // 90 degrees = -90deg in React
                                              child: const Icon(
                                                Icons.keyboard_arrow_down,
                                                size: 20, // w-5 h-5
                                                color:
                                                    AppColors.mutedForeground,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    const SizedBox(
                                        height: 150), // Space for bottom nav
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
            ),

            // Bottom Navigation
            const BottomNav(activeTab: 'progress'),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = _progressData?['user'] as Map<String, dynamic>?;
    final userName = user?['name'] as String? ?? '';
    final userAvatar = user?['avatar'] as String?;
    final overallProgress = (user?['overall_progress'] as num?)?.toInt() ?? 76;

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 48, // w-12
                  height: 48, // h-12
                  decoration: const BoxDecoration(
                    color: AppColors.orangeLight,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: userAvatar != null && userAvatar.isNotEmpty
                        ? Image.network(
                            userAvatar,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                              'assets/images/user-avatar.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.person,
                                      color: AppColors.purple),
                            ),
                          )
                        : Image.asset(
                            'assets/images/user-avatar.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.person, color: AppColors.purple),
                          ),
                  ),
                ),
                const SizedBox(width: 12), // gap-3
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userName.isNotEmpty
                            ? 'Hello, $userName'
                            : AppLocalizations.of(context)!.helloJacob,
                        style: AppTextStyles.h4(color: AppColors.foreground),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.flash_on,
                            size: 16, // w-4 h-4
                            color: AppColors.orange,
                          ),
                          const SizedBox(width: 4), // gap-1
                          Flexible(
                            child: Text(
                              AppLocalizations.of(context)!
                                  .progressPercent(overallProgress),
                              style: AppTextStyles.bodySmall(
                                color: AppColors.mutedForeground,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.verified_user,
              size: 20,
              color: AppColors.purple,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Courses Progress Section
  // ──────────────────────────────────────────────────────────────────────────

  String _courseTitle(Map<String, dynamic> enrollment) {
    final course = enrollment['course'];
    if (course is Map) {
      return course['title']?.toString() ??
          course['name']?.toString() ??
          enrollment['title']?.toString() ??
          enrollment['course_title']?.toString() ??
          '';
    }
    return enrollment['title']?.toString() ??
        enrollment['course_title']?.toString() ??
        '';
  }

  String? _courseThumbnail(Map<String, dynamic> enrollment) {
    final course = enrollment['course'];
    if (course is Map) {
      return course['thumbnail']?.toString() ??
          course['image']?.toString() ??
          course['cover_image']?.toString();
    }
    return enrollment['thumbnail']?.toString() ?? enrollment['image']?.toString();
  }

  String _courseId(Map<String, dynamic> enrollment) {
    final course = enrollment['course'];
    if (course is Map) {
      return course['id']?.toString() ?? enrollment['course_id']?.toString() ?? '';
    }
    return enrollment['course_id']?.toString() ??
        enrollment['id']?.toString() ??
        '';
  }

  double _courseProgress(Map<String, dynamic> enrollment) {
    final status = enrollment['status']?.toString().toLowerCase();
    if (status == 'completed') return 100.0;

    final completed = _completedLessons(enrollment);
    final total = _totalLessons(enrollment);
    if (total > 0 && completed >= total) return 100.0;

    final courseProgress = enrollment['course_progress'];
    if (courseProgress is Map) {
      final cp = courseProgress['percentage'] ?? courseProgress['progress'];
      if (cp is num) return cp.toDouble().clamp(0.0, 100.0);
      if (cp is String) {
        final parsed = double.tryParse(cp);
        if (parsed != null) return parsed.clamp(0.0, 100.0);
      }
    }

    final raw = enrollment['progress'] ??
        enrollment['completion_percentage'] ??
        enrollment['progress_percentage'];
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble().clamp(0.0, 100.0);
    if (raw is String) {
      final parsed = double.tryParse(raw);
      if (parsed != null) return parsed.clamp(0.0, 100.0);
    }
    return 0.0;
  }

  int _completedLessons(Map<String, dynamic> enrollment) {
    final v = enrollment['completed_lessons'] ??
        enrollment['completed_lessons_count'];
    if (v == null) return 0;
    return (v as num).toInt();
  }

  int _totalLessons(Map<String, dynamic> enrollment) {
    final v = enrollment['total_lessons'] ??
        enrollment['lessons_count'] ??
        enrollment['total_lessons_count'];
    if (v == null) return 0;
    return (v as num).toInt();
  }

  int _watchedMinutes(Map<String, dynamic> enrollment) {
    // Server may return watched_minutes, watched_seconds, or total_watch_time
    final mins = enrollment['watched_minutes'] ?? enrollment['total_watch_time'];
    if (mins != null) return (mins as num).toInt();
    final secs = enrollment['watched_seconds'];
    if (secs != null) return ((secs as num).toDouble() / 60).ceil();
    return 0;
  }

  Widget _buildCoursesProgressSection(BuildContext context) {
    final displayedCourses = _displayedEnrollments();
    final selectedInDisplayed = _selectedCourse != null &&
        displayedCourses
            .any((e) => _courseId(e) == _courseId(_selectedCourse!));
    final effectiveSelectedCourse = selectedInDisplayed
        ? _selectedCourse
        : (displayedCourses.isNotEmpty ? displayedCourses.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Courses Progress',
              style: AppTextStyles.h4(color: AppColors.foreground),
            ),
            if (displayedCourses.length > 1)
              GestureDetector(
                onTap: () => context.push(RouteNames.enrolled),
                child: Text(
                  'View all',
                  style: AppTextStyles.bodySmall(color: AppColors.purple)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Courses horizontal scroll picker
        if (_isLoadingEnrollments)
          SizedBox(
            height: 48,
            child: Skeletonizer(
              enabled: true,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, __) => Container(
                  width: 140,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          )
        else if (displayedCourses.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school_outlined, color: Colors.grey[400], size: 20),
                const SizedBox(width: 8),
                Text(
                  'You have not enrolled in any course yet',
                  style: AppTextStyles.bodySmall(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          )
        else ...[
          // Horizontal scrollable course chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: displayedCourses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final enrollment = displayedCourses[idx];
                final title = _courseTitle(enrollment);
                final isSelected =
                    _courseId(enrollment) ==
                        _courseId(effectiveSelectedCourse ?? {});
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCourse = enrollment);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.purple : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: isSelected
                            ? AppColors.purple
                            : Colors.grey.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      title.isNotEmpty ? title : 'Course',
                      style: AppTextStyles.bodySmall(
                        color: isSelected ? Colors.white : AppColors.foreground,
                      ).copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Selected course progress card
          if (effectiveSelectedCourse != null)
            _buildSelectedCourseCard(context, effectiveSelectedCourse),
        ],
      ],
    );
  }

  Widget _buildSelectedCourseCard(
      BuildContext context, Map<String, dynamic> enrollment) {
    final title = _courseTitle(enrollment);
    final thumbnail = _courseThumbnail(enrollment);
    final progress = _courseProgress(enrollment);
    final completed = _completedLessons(enrollment);
    final total = _totalLessons(enrollment);
    final watchedMins = _watchedMinutes(enrollment);
    final courseId = _courseId(enrollment);

    final progressFraction = progress / 100.0;
    final Color progressColor = progress >= 80
        ? Colors.green
        : progress >= 40
            ? AppColors.orange
            : AppColors.purple;

    return GestureDetector(
      onTap: () {
        final courseMap = enrollment['course'];
        if (courseMap is Map<String, dynamic>) {
          context.push(RouteNames.courseDetails, extra: courseMap);
        } else if (courseId.isNotEmpty) {
          context.push(RouteNames.courseDetails, extra: enrollment);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course title row + thumbnail
            Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 60,
                    height: 60,
                    color: AppColors.purpleLight,
                    child: thumbnail != null && thumbnail.isNotEmpty
                        ? Image.network(
                            thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.play_circle_outline,
                              color: AppColors.purple,
                              size: 28,
                            ),
                          )
                        : const Icon(
                            Icons.play_circle_outline,
                            color: AppColors.purple,
                            size: 28,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                // Title + lessons count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isNotEmpty ? title : 'Course',
                        style: AppTextStyles.bodyMedium(
                          color: AppColors.foreground,
                        ).copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (total > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '$completed / $total lessons completed',
                          style: AppTextStyles.bodySmall(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Progress circle
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progressFraction.clamp(0.0, 1.0),
                        strokeWidth: 5,
                        backgroundColor: Colors.grey[200],
                        valueColor:
                            AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                      Text(
                        '${progress.toInt()}%',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: progressColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: AppTextStyles.labelSmall(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    Text(
                      '${progress.toInt()}%',
                      style: AppTextStyles.labelSmall(
                        color: progressColor,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressFraction.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Stats row
            Row(
              children: [
                _buildStatChip(
                  icon: Icons.check_circle_outline_rounded,
                  value: '$completed',
                  label: 'Completed lessons',
                  color: Colors.green,
                ),
                const SizedBox(width: 10),
                _buildStatChip(
                  icon: Icons.access_time_rounded,
                  value: watchedMins >= 60
                      ? '${(watchedMins / 60).toStringAsFixed(1)} hrs'
                      : '$watchedMins mins',
                  label: 'Watch time',
                  color: AppColors.orange,
                ),
                if (total > 0) ...[
                  const SizedBox(width: 10),
                  _buildStatChip(
                    icon: Icons.menu_book_rounded,
                    value: '$total',
                    label: 'Total lessons',
                    color: AppColors.purple,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 14),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final courseMap = enrollment['course'];
                  if (courseMap is Map<String, dynamic>) {
                    context.push(RouteNames.courseDetails, extra: courseMap);
                  } else if (courseId.isNotEmpty) {
                    context.push(RouteNames.courseDetails, extra: enrollment);
                  }
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(
                  progress == 0 ? 'Start course' : 'Resume course',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: AppTextStyles.labelSmall(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalBarChart() {
    if (_chartData.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxValue = _chartData
        .map((d) => (d['value'] as num?)?.toInt() ?? 0)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: _chartData.map((data) {
        final value = (data['value'] as num?)?.toInt() ?? 0;
        final stripes = data['stripes'] as bool? ?? false;
        final progress = maxValue > 0 ? value / maxValue : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  data['day'] as String,
                  style: AppTextStyles.labelSmall(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerRight,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: stripes ? null : AppColors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: stripes
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CustomPaint(
                                painter: _StripePainter(),
                                child: Container(),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text(
                  '$value',
                  style: AppTextStyles.labelSmall(
                    color: AppColors.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.orange
      ..style = PaintingStyle.fill;

    final stripePaint = Paint()
      ..color = AppColors.orange.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(12),
      ),
      stripePaint,
    );

    // Stripes
    const stripeWidth = 8.0;
    const gap = 8.0;
    for (double x = -size.height;
        x < size.width + size.height;
        x += stripeWidth + gap) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + stripeWidth, size.height)
        ..lineTo(x + stripeWidth + size.height, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
