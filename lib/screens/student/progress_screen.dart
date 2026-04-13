import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_text_styles.dart';
import '../../core/navigation/route_names.dart';
import '../../widgets/bottom_nav.dart';
import '../../l10n/app_localizations.dart';
import '../../services/progress_service.dart';

/// Progress Screen - Pixel-perfect match to React version
/// Matches: components/screens/progress-screen.tsx
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String _period = 'weekly';
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _progressData;

  // Chart data from API
  List<Map<String, dynamic>> _chartData = [];

  // Top students from API
  List<Map<String, dynamic>> _topStudents = [];

  @override
  void initState() {
    super.initState();
    _fetchProgressData();
  }

  Future<void> _fetchProgressData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ProgressService.instance.getProgressData(_period);
      setState(() {
        _progressData = data;
        _isLoading = false;

        // Extract chart data based on period
        if (data['chart_data'] != null) {
          final chartData = data['chart_data'] as Map<String, dynamic>;
          _chartData = List<Map<String, dynamic>>.from(
            chartData[_period] as List? ?? [],
          );
        }

        // Extract top students
        if (data['top_students'] != null) {
          _topStudents = List<Map<String, dynamic>>.from(
            data['top_students'] as List? ?? [],
          );
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16, // px-4
                                            vertical: 8, // py-2
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.lavenderLight,
                                            borderRadius: BorderRadius.circular(
                                                999), // rounded-full
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.bar_chart,
                                                size: 16, // w-4 h-4
                                                color: AppColors.purple,
                                              ),
                                              const SizedBox(width: 8), // gap-2
                                              Text(
                                                AppLocalizations.of(context)!
                                                    .allSubjects,
                                                style: AppTextStyles.bodySmall(
                                                  color: AppColors.purple,
                                                ).copyWith(
                                                    fontWeight:
                                                        FontWeight.w500),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.keyboard_arrow_down,
                                                size: 16, // w-4 h-4
                                                color: AppColors.purple,
                                              ),
                                            ],
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
                                    const SizedBox(height: 16), // space-y-4

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
                            ? 'مرحباً، $userName'
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
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44, // w-11
                  height: 44, // h-11
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
                    size: 20, // w-5 h-5
                    color: AppColors.purple,
                  ),
                ),
                const SizedBox(width: 8), // gap-2
                GestureDetector(
                  onTap: () => context.push(RouteNames.notifications),
                  child: Container(
                    width: 44, // w-11
                    height: 44, // h-11
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
                    child: Stack(
                      children: [
                        const Center(
                          child: Icon(
                            Icons.notifications,
                            size: 20, // w-5 h-5
                            color: AppColors.foreground,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8, // w-2
                            height: 8, // h-2
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
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
