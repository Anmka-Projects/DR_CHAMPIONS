import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_text_styles.dart';
import '../../core/design/app_radius.dart';
import '../../core/localization/localization_helper.dart';
import '../../services/live_courses_service.dart';

/// Live Courses Screen - Pixel-perfect match to React version
/// Matches: components/screens/live-courses-screen.tsx
class LiveCoursesScreen extends StatefulWidget {
  const LiveCoursesScreen({super.key});

  @override
  State<LiveCoursesScreen> createState() => _LiveCoursesScreenState();
}

class _LiveCoursesScreenState extends State<LiveCoursesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _upcoming = [];
  List<Map<String, dynamic>> _liveNow = [];

  @override
  void initState() {
    super.initState();
    _loadLiveCourses();
  }

  Future<void> _loadLiveCourses() async {
    setState(() => _isLoading = true);
    try {
      final response = await LiveCoursesService.instance.getLiveCourses();

      if (kDebugMode) {
        print('✅ Live courses loaded:');
        print('  upcoming: ${response['upcoming']?.length ?? 0}');
        print('  live_now: ${response['live_now']?.length ?? 0}');
        print('  past: ${response['past']?.length ?? 0}');
      }

      setState(() {
        if (response['upcoming'] is List) {
          _upcoming = List<Map<String, dynamic>>.from(
            response['upcoming'] as List,
          );
        }
        if (response['live_now'] is List) {
          _liveNow = List<Map<String, dynamic>>.from(
            response['live_now'] as List,
          );
        }
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading live courses: $e');
      }
      setState(() {
        _upcoming = [];
        _liveNow = [];
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _allCourses {
    final all = <Map<String, dynamic>>[];
    // Add live_now first (highest priority)
    for (var course in _liveNow) {
      all.add({...course, 'status': 'live'});
    }
    // Add upcoming
    for (var course in _upcoming) {
      all.add({...course, 'status': 'upcoming'});
    }
    // Add past (optional, if you want to show them)
    // for (var course in _past) {
    //   all.add({...course, 'status': 'past'});
    // }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header - Orange gradient like exams page
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadius.largeCard),
                  bottomRight: Radius.circular(AppRadius.largeCard),
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16, // pt-4
                bottom: 32, // pb-8
                left: 16, // px-4
                right: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button and title - matches React: gap-4 mb-4
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 40, // w-10
                          height: 40, // h-10
                          decoration: const BoxDecoration(
                            color: AppColors.whiteOverlay20, // bg-white/20
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 20, // w-5 h-5
                          ),
                        ),
                      ),
                      const SizedBox(width: 16), // gap-4
                      Text(
                        context.l10n.liveCourses,
                        style: AppTextStyles.h3(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16), // mb-4
                  // Sessions count - matches React: gap-2
                  Row(
                    children: [
                      Icon(
                        Icons.videocam,
                        size: 20, // w-5 h-5
                        color: Colors.white.withOpacity(0.7), // white/70
                      ),
                      const SizedBox(width: 8), // gap-2
                      Text(
                        context.l10n.liveSessionsCount(
                          _upcoming.length + _liveNow.length,
                          _liveNow.isNotEmpty
                              ? context.l10n.live
                              : context.l10n.upcoming,
                        ),
                        style: AppTextStyles.bodyMedium(
                          color: Colors.white.withOpacity(0.7), // white/70
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content - matches React: px-4 -mt-4 space-y-4
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -16), // -mt-4
                child: _isLoading
                    ? _buildLoadingState()
                    : _allCourses.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadLiveCourses,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16), // px-4
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _allCourses.length,
                              itemBuilder: (context, index) {
                                final course = _allCourses[index];
                                return TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: Duration(
                                      milliseconds: 500 + (index * 100)),
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
                                  child: _LiveCourseCard(
                                    course: course,
                                    onRegister: () => _handleRegister(course),
                                    onJoin: () => _handleJoin(course),
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRegister(Map<String, dynamic> course) async {
    final sessionId = course['id']?.toString();
    if (sessionId == null || sessionId.isEmpty) return;

    try {
      final result =
          await LiveCoursesService.instance.registerForLiveCourse(sessionId);
      if (kDebugMode) {
        print('✅ Registered for live course: $result');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.registeredForSession,
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

      // Refresh the list
      _loadLiveCourses();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error registering for live course: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('401') ||
                      e.toString().contains('Unauthorized')
                  ? context.l10n.mustLoginFirst
                  : context.l10n.errorRegistering,
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

  void _handleJoin(Map<String, dynamic> course) {
    final joinUrl = course['join_url']?.toString() ??
        course['meeting_url']?.toString() ??
        course['zoom_link']?.toString();
    if (joinUrl != null && joinUrl.isNotEmpty) {
      // TODO: Open URL in browser or app
      if (kDebugMode) {
        print('🔗 Join URL: $joinUrl');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.willOpenSessionLink,
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppColors.purple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.sessionLinkUnavailable,
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
  }

  Widget _buildLoadingState() {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.videocam_off_rounded,
              size: 60,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.noLiveSessions,
            style: AppTextStyles.h2(
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.sessionsComingSoon,
            style: AppTextStyles.bodyMedium(
              color: AppColors.mutedForeground,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LiveCourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback? onRegister;
  final VoidCallback? onJoin;

  const _LiveCourseCard({
    required this.course,
    this.onRegister,
    this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = course['status'] == 'live' ||
        course['status'] == 'live_now' ||
        course['is_live'] == true;
    final isUpcoming =
        course['status'] == 'upcoming' || course['status'] == 'scheduled';
    final courseTitle = course['title']?.toString() ?? context.l10n.liveSession;
    final instructor = course['instructor'] is Map
        ? (course['instructor'] as Map)['name']?.toString() ?? ''
        : course['instructor']?.toString() ?? context.l10n.instructor;
    final startDate = course['start_date']?.toString() ??
        course['date']?.toString() ??
        course['scheduled_at']?.toString();
    final duration = course['duration']?.toString() ??
        course['duration_minutes']?.toString() ??
        context.l10n.oneHour;
    final participants = course['participants'] as int? ??
        course['participants_count'] as int? ??
        0;
    final thumbnail = course['thumbnail']?.toString() ??
        course['image']?.toString() ??
        course['banner']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16), // space-y-4
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24), // rounded-3xl
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Course Image - matches React: relative h-40
          Stack(
            children: [
              Container(
                height: 160, // h-40
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: thumbnail != null && thumbnail.isNotEmpty
                      ? Image.network(
                          thumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            color: AppColors.purple.withOpacity(0.1),
                            child: const Icon(
                              Icons.video_library,
                              size: 48,
                              color: AppColors.purple,
                            ),
                          ),
                        )
                      : Container(
                          color: AppColors.purple.withOpacity(0.1),
                          child: const Icon(
                            Icons.video_library,
                            size: 48,
                            color: AppColors.purple,
                          ),
                        ),
                ),
              ),
              // Status badge - matches React
              if (isLive)
                Positioned(
                  top: 12, // top-3
                  right: 12, // right-3
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, // px-3
                      vertical: 4, // py-1
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(999), // rounded-full
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8, // w-2
                          height: 8, // h-2
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4), // gap-1
                        Text(
                          context.l10n.liveNow,
                          style: AppTextStyles.bodySmall(
                            color: Colors.white,
                          ).copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                )
              else if (isUpcoming)
                Positioned(
                  top: 12, // top-3
                  right: 12, // right-3
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12, // px-3
                      vertical: 4, // py-1
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.purple,
                      borderRadius: BorderRadius.circular(999), // rounded-full
                    ),
                    child: Text(
                      context.l10n.comingSoon,
                      style: AppTextStyles.bodySmall(
                        color: Colors.white,
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
            ],
          ),

          // Course Info - matches React: p-4
          Padding(
            padding: const EdgeInsets.all(16), // p-4
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courseTitle,
                  style: AppTextStyles.bodyMedium(
                    color: AppColors.foreground,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8), // mb-2
                Text(
                  instructor,
                  style: AppTextStyles.bodySmall(
                    color: AppColors.purple,
                  ),
                ),
                const SizedBox(height: 12), // mb-3

                // Info row - matches React: gap-4 text-xs mb-4
                Padding(
                  padding: const EdgeInsets.only(bottom: 16), // mb-4
                  child: Row(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16, // w-4 h-4
                            color: AppColors.mutedForeground,
                          ),
                          const SizedBox(width: 4), // gap-1
                          Text(
                            startDate != null
                                ? _formatDate(context, startDate)
                                : context.l10n.undefinedDate,
                            style: AppTextStyles.labelSmall(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16), // gap-4
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16, // w-4 h-4
                            color: AppColors.mutedForeground,
                          ),
                          const SizedBox(width: 4), // gap-1
                          Text(
                            duration,
                            style: AppTextStyles.labelSmall(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16), // gap-4
                      Row(
                        children: [
                          const Icon(
                            Icons.people,
                            size: 16, // w-4 h-4
                            color: AppColors.mutedForeground,
                          ),
                          const SizedBox(width: 4), // gap-1
                          Text(
                            '$participants',
                            style: AppTextStyles.labelSmall(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Countdown or Join button
                if (isUpcoming) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16), // mb-4
                    child: Column(
                      children: [
                        Text(
                          context.l10n.startsIn,
                          style: AppTextStyles.labelSmall(
                            color: AppColors.mutedForeground,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8), // mb-2
                        startDate != null
                            ? _CountdownTimer(targetDate: startDate)
                            : const SizedBox.shrink(),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onRegister,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12), // py-3
                      decoration: BoxDecoration(
                        color: AppColors.purple,
                        borderRadius: BorderRadius.circular(16), // rounded-2xl
                      ),
                      child: Center(
                        child: Text(
                          context.l10n.remindMe,
                          style: AppTextStyles.bodyMedium(
                            color: Colors.white,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  GestureDetector(
                    onTap: onJoin,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12), // py-3
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(16), // rounded-2xl
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.play_arrow,
                            size: 20, // w-5 h-5
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8), // gap-2
                          Text(
                            context.l10n.joinNow,
                            style: AppTextStyles.bodyMedium(
                              color: Colors.white,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
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

  String _formatDate(BuildContext context, String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final weekdays = [
        context.l10n.sunday,
        context.l10n.monday,
        context.l10n.tuesday,
        context.l10n.wednesday,
        context.l10n.thursday,
        context.l10n.friday,
        context.l10n.saturday,
      ];
      final months = [
        context.l10n.monthJanuary,
        context.l10n.monthFebruary,
        context.l10n.monthMarch,
        context.l10n.monthApril,
        context.l10n.monthMay,
        context.l10n.monthJune,
        context.l10n.monthJuly,
        context.l10n.monthAugust,
        context.l10n.monthSeptember,
        context.l10n.monthOctober,
        context.l10n.monthNovember,
        context.l10n.monthDecember,
      ];
      return '${weekdays[date.weekday % 7]}، ${date.day} ${months[date.month - 1]}';
    } catch (e) {
      return dateStr;
    }
  }
}

class _CountdownTimer extends StatefulWidget {
  final String targetDate;

  const _CountdownTimer({required this.targetDate});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeLeft();
    });
  }

  void _updateTimeLeft() {
    try {
      final target = DateTime.parse(widget.targetDate);
      final now = DateTime.now();
      final difference = target.difference(now);
      if (mounted) {
        setState(() {
          _timeLeft = difference.isNegative ? Duration.zero : difference;
        });
      }
    } catch (e) {
      // Ignore parse errors
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _timeLeft.inDays;
    final hours = _timeLeft.inHours.remainder(24);
    final minutes = _timeLeft.inMinutes.remainder(60);
    final seconds = _timeLeft.inSeconds.remainder(60);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimeUnit(context, days, context.l10n.day),
        const SizedBox(width: 8), // gap-2
        _buildTimeUnit(context, hours, context.l10n.hour),
        const SizedBox(width: 8), // gap-2
        _buildTimeUnit(context, minutes, context.l10n.minute),
        const SizedBox(width: 8), // gap-2
        _buildTimeUnit(context, seconds, context.l10n.second),
      ],
    );
  }

  Widget _buildTimeUnit(BuildContext context, int value, String label) {
    return Container(
      width: 50, // min-w-[50px]
      padding: const EdgeInsets.all(8), // p-2
      decoration: BoxDecoration(
        color: AppColors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12), // rounded-xl
      ),
      child: Column(
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: AppTextStyles.h4(
              color: AppColors.purple,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.labelSmall(
              color: AppColors.mutedForeground,
            ).copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
