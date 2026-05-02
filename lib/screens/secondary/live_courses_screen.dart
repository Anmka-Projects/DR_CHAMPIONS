import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_text_styles.dart';
import '../../core/design/app_radius.dart';
import '../../core/course_live_meta.dart';
import '../../core/localization/localization_helper.dart';
import '../../core/navigation/route_names.dart';
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
  List<Map<String, dynamic>> _past = [];

  @override
  void initState() {
    super.initState();
    _loadLiveCourses();
  }

  Future<void> _loadLiveCourses() async {
    setState(() => _isLoading = true);
    try {
      final response = await LiveCoursesService.instance.getLiveCourses();
      if (!mounted) return;

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
        if (response['past'] is List) {
          _past = List<Map<String, dynamic>>.from(
            response['past'] as List,
          );
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) {
        print('❌ Error loading live courses: $e');
      }
      setState(() {
        _upcoming = [];
        _liveNow = [];
        _past = [];
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _liveCourses {
    return _liveNow.map((course) => {...course, 'status': 'live'}).toList()
      ..sort(
          (a, b) => _extractSessionDate(b).compareTo(_extractSessionDate(a)));
  }

  List<Map<String, dynamic>> get _upcomingCourses {
    return _upcoming.map((course) => {...course, 'status': 'upcoming'}).toList()
      ..sort(
          (a, b) => _extractSessionDate(b).compareTo(_extractSessionDate(a)));
  }

  List<Map<String, dynamic>> get _pastCourses {
    return _past.map((course) => {...course, 'status': 'past'}).toList()
      ..sort(
          (a, b) => _extractSessionDate(b).compareTo(_extractSessionDate(a)));
  }

  DateTime _extractSessionDate(Map<String, dynamic> session) {
    final raw = session['start_date']?.toString() ??
        session['start_time']?.toString() ??
        session['date']?.toString() ??
        session['scheduled_at']?.toString() ??
        '';
    return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    final liveCourses = _liveCourses;
    final upcomingCourses = _upcomingCourses;
    final pastCourses = _pastCourses;
    final totalSessionsCount =
        liveCourses.length + upcomingCourses.length + pastCourses.length;

    return Scaffold(
      backgroundColor: AppColors.beige,
      body: DefaultTabController(
        length: 3,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Header - main app primary gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
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
                          'Live Sessions',
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
                            totalSessionsCount,
                            Localizations.localeOf(context).languageCode == 'ar'
                                ? 'الإجمالي'
                                : 'total',
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

              _SessionsTabBar(
                liveCount: liveCourses.length,
                upcomingCount: upcomingCourses.length,
                pastCount: pastCourses.length,
              ),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : totalSessionsCount == 0
                        ? _buildEmptyState()
                        : TabBarView(
                            children: [
                              _buildSessionsList(
                                liveCourses,
                                emptyMessage: 'No live sessions now',
                              ),
                              _buildSessionsList(
                                upcomingCourses,
                                emptyMessage: 'No upcoming sessions',
                              ),
                              _buildSessionsList(
                                pastCourses,
                                emptyMessage: 'No ended sessions yet',
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

  Widget _buildSessionsList(
    List<Map<String, dynamic>> sessions, {
    required String emptyMessage,
  }) {
    if (sessions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadLiveCourses,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.videocam_off_rounded,
                    size: 34,
                    color: AppColors.mutedForeground.withOpacity(0.7),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    emptyMessage,
                    style: AppTextStyles.bodyMedium(
                      color: AppColors.mutedForeground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLiveCourses,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          final course = sessions[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 500 + (index * 100)),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: _LiveCourseCard(
              course: course,
              onJoin: () => _handleJoin(course),
              onRequirePurchase: () => _handlePaidSessionTap(course),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleJoin(Map<String, dynamic> course) async {
    final joinUrl = course['join_url']?.toString() ??
        course['meeting_link']?.toString() ??
        course['meeting_url']?.toString() ??
        course['zoom_link']?.toString() ??
        course['platformLink']?.toString() ??
        course['platform_link']?.toString() ??
        '';
    if (joinUrl.isEmpty) {
      if (!mounted) return;
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
      return;
    }
    final uri = Uri.tryParse(joinUrl);
    if (uri == null) return;
    final didLaunch =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!didLaunch && mounted) {
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

  void _handlePaidSessionTap(Map<String, dynamic> session) {
    if (!mounted) return;
    context.push(RouteNames.checkout,
        extra: _buildLiveSessionCheckoutPayload(session));
  }

  Map<String, dynamic> _buildLiveSessionCheckoutPayload(
    Map<String, dynamic> session,
  ) {
    final meta = parseCourseLiveMeta(session['description']?.toString());
    final courseId = session['course_id']?.toString() ??
        session['courseId']?.toString() ??
        session['course']?['id']?.toString() ??
        meta.courseId ??
        session['id']?.toString() ??
        '';
    final title = session['title']?.toString().trim().isNotEmpty == true
        ? session['title'].toString()
        : (meta.courseTitle ?? context.l10n.liveSession);
    final price = (session['price'] is num)
        ? (session['price'] as num).toDouble()
        : (double.tryParse(session['price']?.toString() ?? '') ?? 0.0);
    final currency = session['currency']?.toString() ??
        session['currency_code']?.toString() ??
        'EGP';

    return {
      'id': courseId,
      'title': title,
      'price': price,
      'currency': currency,
      'is_free': false,
      'live_session_id': session['id']?.toString(),
      'live_session_price': price,
      'checkout_for': 'live_session',
    };
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
  final Future<void> Function()? onJoin;
  final VoidCallback? onRequirePurchase;

  const _LiveCourseCard({
    required this.course,
    this.onJoin,
    this.onRequirePurchase,
  });

  @override
  Widget build(BuildContext context) {
    final isLive = course['status'] == 'live' ||
        course['status'] == 'live_now' ||
        course['is_live'] == true;
    final startDate = course['start_date']?.toString() ??
        course['start_time']?.toString() ??
        course['date']?.toString() ??
        course['scheduled_at']?.toString();
    final sessionDate = startDate != null ? DateTime.tryParse(startDate) : null;
    final now = DateTime.now();
    final isEndedByTime = sessionDate != null && !sessionDate.isAfter(now);
    final isPast = course['status'] == 'past' ||
        course['status'] == 'ended' ||
        course['status'] == 'completed' ||
        (!isLive && isEndedByTime);
    final isUpcoming =
        (course['status'] == 'upcoming' || course['status'] == 'scheduled') &&
            !isPast;
    final isPaidSession = _isPaidSession(course);
    final hasPurchaseAccess = _hasPurchaseAccess(course);
    final isLockedPaidSession = isPaidSession && !hasPurchaseAccess;
    final canJoin = isLive && !isLockedPaidSession;
    final courseTitle = course['title']?.toString() ?? context.l10n.liveSession;
    final instructor = course['instructor'] is Map
        ? (course['instructor'] as Map)['name']?.toString() ?? ''
        : course['instructor']?.toString() ?? context.l10n.instructor;
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
              else if (isPast)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade600,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Ended',
                      style: AppTextStyles.bodySmall(
                        color: Colors.white,
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                )
              else if (isLockedPaidSession)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      context.l10n.paid,
                      style: AppTextStyles.bodySmall(
                        color: Colors.white,
                      ).copyWith(fontWeight: FontWeight.w600),
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

                _LiveSessionActionButton(
                  startDate: startDate,
                  isEnded: isPast,
                  isPaidLocked: isLockedPaidSession,
                  canJoin: canJoin,
                  onJoin: onJoin,
                  onRequirePurchase: onRequirePurchase,
                ),
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

  bool _isPaidSession(Map<String, dynamic> session) {
    final isFreeValue = session['is_free'];
    if (isFreeValue != null) {
      if (_asBool(isFreeValue)) return false;
      return true;
    }

    final paidFlags = [
      session['is_paid'],
      session['paid'],
      session['requires_payment'],
      session['payment_required'],
      session['is_premium'],
    ];
    for (final flag in paidFlags) {
      if (_asBool(flag)) return true;
    }
    final amountCandidates = [
      session['price'],
      session['amount'],
      session['session_price'],
      session['price_amount'],
      session['cost'],
    ];
    for (final raw in amountCandidates) {
      final parsed = _asNum(raw);
      if (parsed != null && parsed > 0) return true;
    }
    return false;
  }

  bool _hasPurchaseAccess(Map<String, dynamic> session) {
    final accessFlags = [
      session['has_access'],
      session['can_join'],
      session['is_purchased'],
      session['purchased'],
      session['is_enrolled'],
      session['enrolled'],
      session['is_registered'],
      session['registered'],
    ];
    for (final flag in accessFlags) {
      if (_asBool(flag)) return true;
    }
    return false;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  num? _asNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }
}

class _CountdownTimer extends StatefulWidget {
  final String targetDate;

  const _CountdownTimer({required this.targetDate});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _LiveSessionActionButton extends StatefulWidget {
  final String? startDate;
  final bool isEnded;
  final bool isPaidLocked;
  final bool canJoin;
  final Future<void> Function()? onJoin;
  final VoidCallback? onRequirePurchase;

  const _LiveSessionActionButton({
    required this.startDate,
    required this.isEnded,
    required this.isPaidLocked,
    required this.canJoin,
    this.onJoin,
    this.onRequirePurchase,
  });

  @override
  State<_LiveSessionActionButton> createState() =>
      _LiveSessionActionButtonState();
}

class _LiveSessionActionButtonState extends State<_LiveSessionActionButton> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final raw = widget.startDate;
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    final diff =
        parsed == null ? Duration.zero : parsed.difference(DateTime.now());
    if (!mounted) return;
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _countdown() {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnded = widget.isEnded;
    final bool isPaidLocked = widget.isPaidLocked;
    final bool canJoin = widget.canJoin;
    final bool showCountdown =
        !isEnded && !isPaidLocked && !canJoin && _remaining > Duration.zero;
    final label = isPaidLocked
        ? context.l10n.completePurchase
        : isEnded
            ? 'Session ended'
            : canJoin
                ? context.l10n.joinNow
                : showCountdown
                    ? _countdown()
                    : context.l10n.remindMe;
    final bgColor = isPaidLocked
        ? const Color(0xFFF59E0B)
        : isEnded
            ? Colors.grey
            : canJoin
                ? Colors.green
                : AppColors.purple;

    return GestureDetector(
      onTap: isPaidLocked
          ? widget.onRequirePurchase
          : (canJoin ? () => widget.onJoin?.call() : null),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPaidLocked
                  ? Icons.lock_rounded
                  : isEnded
                      ? Icons.event_busy_rounded
                      : canJoin
                          ? Icons.play_arrow
                          : Icons.access_time_rounded,
              size: 20,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodyMedium(
                color: Colors.white,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
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

/// Custom tab bar that sits below the header gradient —
/// white card background with a full solid-pill active indicator.
class _SessionsTabBar extends StatefulWidget {
  final int liveCount;
  final int upcomingCount;
  final int pastCount;

  const _SessionsTabBar({
    required this.liveCount,
    required this.upcomingCount,
    required this.pastCount,
  });

  @override
  State<_SessionsTabBar> createState() => _SessionsTabBarState();
}

class _SessionsTabBarState extends State<_SessionsTabBar> {
  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    final labels = [
      ('Live', widget.liveCount, Colors.red.shade600),
      ('Upcoming', widget.upcomingCount, AppColors.primary),
      ('Ended', widget.pastCount, Colors.grey.shade600),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final current = controller.index;
          return Row(
            children: List.generate(labels.length, (i) {
              final (label, count, color) = labels[i];
              final isActive = i == current;
              return Expanded(
                child: GestureDetector(
                  onTap: () => controller.animateTo(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    margin: EdgeInsets.only(
                      left: i == 0 ? 0 : 5,
                      right: i == labels.length - 1 ? 0 : 5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.52),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? color.withOpacity(0.35)
                            : Colors.white.withOpacity(0.60),
                        width: 1.5,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$count',
                          style: GoogleFonts.cairo(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isActive ? color : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          label,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w500,
                            color: isActive ? color : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
