import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/course_pricing.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_radius.dart';
import '../../core/navigation/route_names.dart';
import '../../core/api/api_endpoints.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/premium_course_card.dart';
import '../../services/home_service.dart';
import '../../services/profile_service.dart';
import '../../services/notifications_service.dart';
import '../../services/teachers_service.dart';
import '../../services/certificates_service.dart';
import '../../l10n/app_localizations.dart';
import '../../data/sample_teachers.dart';

/// Home Screen - Enhanced with 3D Banner & Modern Design
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  late AnimationController _bannerController;
  late Animation<double> _bannerAnimation;

  // API Data
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _homeData;
  Map<String, dynamic>? _userProfile;
  int _notificationsCount = 0;
  int? _certificatesCountOverride;
  List<Map<String, dynamic>> _featuredCourses = [];
  List<Map<String, dynamic>> _popularCourses = [];
  List<Map<String, dynamic>> _continueLearning = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _teachers = [];

  @override
  void initState() {
    super.initState();
    _bannerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _bannerAnimation = CurvedAnimation(
      parent: _bannerController,
      curve: Curves.easeOutBack,
    );
    _bannerController.forward();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Load home data
      final homeData = await HomeService.instance.getHomeData();
      if (!mounted) return;

      // Load user profile if logged in
      try {
        final profile = await ProfileService.instance.getProfile();
        if (kDebugMode) {
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          print('🖼️ HOME SCREEN - PROFILE AVATAR');
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
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        }
        if (!mounted) return;
        setState(() => _userProfile = profile);
      } catch (e) {
        // User might not be logged in, continue
        if (kDebugMode) {
          print('❌ Error loading profile in home screen: $e');
        }
      }

      // Load notifications count if logged in
      try {
        final notifications =
            await NotificationsService.instance.getNotifications(
          unreadOnly: true,
          perPage: 1,
        );
        if (!mounted) return;
        setState(() =>
            _notificationsCount = notifications['meta']?['unread_count'] ?? 0);
      } catch (e) {
        // User might not be logged in, continue
      }

      // Keep certificates stat in sync with certificates screen source.
      try {
        final certResponse = await CertificatesService.instance.getCertificates();
        final certCount = _extractCertificatesCount(certResponse);
        if (!mounted) return;
        setState(() => _certificatesCountOverride = certCount);
      } catch (_) {
        // Keep home summary count as fallback when certificates endpoint fails.
      }

      // Load teachers from API
      List<Map<String, dynamic>> teachers = [];
      try {
        final teachersResponse = await TeachersService.instance.getTeachers(
          page: 1,
          perPage: 10, // Load first 10 teachers for the slider
          sort: 'rating',
        );
        final data = teachersResponse['data'];
        if (data is Map<String, dynamic> && data['teachers'] != null) {
          teachers = List<Map<String, dynamic>>.from(data['teachers']);
        } else if (data is List) {
          teachers = List<Map<String, dynamic>>.from(data);
        }
      } catch (e) {
        // Fallback to sample teachers if API fails
        teachers = List<Map<String, dynamic>>.from(kSampleTeachers);
      }

      if (!mounted) return;
      setState(() {
        _homeData = homeData;
        _featuredCourses = List<Map<String, dynamic>>.from(
          homeData['featured_courses'] ?? [],
        );
        _popularCourses = List<Map<String, dynamic>>.from(
          homeData['popular_courses'] ?? [],
        );
        _continueLearning = List<Map<String, dynamic>>.from(
          homeData['continue_learning'] ?? [],
        );
        _categories = List<Map<String, dynamic>>.from(
          homeData['categories'] ?? [],
        );
        _teachers = teachers;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      // Show error message instead of fallback data
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
        _featuredCourses = [];
        _popularCourses = [];
        _continueLearning = [];
        _categories = [];
      });
    }
  }

  int _extractCertificatesCount(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List) return data.length;
    if (data is Map<String, dynamic>) {
      final nested = data['certificates'] ?? data['items'] ?? data['data'];
      if (nested is List) return nested.length;
    }
    final root = response['certificates'] ?? response['items'];
    if (root is List) return root.length;
    return 0;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _allCourses =>
      [..._featuredCourses, ..._popularCourses, ..._continueLearning];

  void _handleTeacherTap(Map<String, dynamic> teacher) {
    if (!mounted) return;
    context.push(RouteNames.teacherDetails, extra: teacher);
  }

  void _handleCourseClick(Map<String, dynamic> course) async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('hasLaunched') ?? false;
    final isFree = courseIsEffectivelyFree(course);

    if (!isFree && !isLoggedIn) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(l10n.loginRequired),
            content: Text(l10n.loginRequired),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.purple),
                child: Text(l10n.login,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (result == true && mounted) {
          context.push(RouteNames.login);
        }
      }
      return;
    }

    if (mounted) {
      context.push(RouteNames.courseDetails, extra: course);
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

    final statusBarHeight = MediaQuery.of(context).padding.top;
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
                // Enhanced Header
                _buildHeader(statusBarHeight),
                const SizedBox(height: 15),

                // Content
                Expanded(
                  child: Transform.translate(
                    offset: const Offset(0, -10),
                    child: RefreshIndicator(
                      onRefresh: _loadHomeData,
                      child: _errorMessage != null
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              children: [
                                const SizedBox(height: 36),
                                _buildErrorView(),
                              ],
                            )
                          : SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                // 3D Banner
                                if (_isLoading)
                                  _build3DBannerSkeleton()
                                else
                                  _build3DBanner(),

                                const SizedBox(height: 24),

                                // Quick Stats Row
                                if (_isLoading)
                                  _buildQuickStatsSkeleton()
                                else
                                  _buildQuickStats(),

                                const SizedBox(height: 24),

                                // Teachers slider
                                _buildSectionHeader(l10n.teachers, () {
                                  context.push(
                                    RouteNames.teachers,
                                    extra: _teachers,
                                  );
                                }),
                                const SizedBox(height: 16),
                                if (_isLoading && _teachers.isEmpty)
                                  _buildTeachersSliderSkeleton()
                                else
                                  _buildTeachersSlider(l10n),

                                const SizedBox(height: 28),

                                // Featured Courses
                                if (_isLoading) ...[
                                  _buildSectionHeader(
                                      AppLocalizations.of(context)!
                                          .featuredCourses,
                                      () {}),
                                  const SizedBox(height: 16),
                                  _buildFeaturedCoursesSkeleton(),
                                  const SizedBox(height: 28),
                                ] else if (_featuredCourses.isNotEmpty) ...[
                                  _buildSectionHeader(
                                      AppLocalizations.of(context)!
                                          .featuredCourses, () {
                                    context.push(RouteNames.allCourses);
                                  }),
                                  const SizedBox(height: 16),
                                  _buildFeaturedCourses(),
                                  const SizedBox(height: 28),
                                ],

                                // Categories
                                if (_isLoading) ...[
                                  _buildSectionHeader(
                                      AppLocalizations.of(context)!.categories,
                                      () {}),
                                  const SizedBox(height: 16),
                                  _buildCategoriesSkeleton(),
                                  const SizedBox(height: 28),
                                ] else if (_categories.isNotEmpty) ...[
                                  _buildSectionHeader(
                                      AppLocalizations.of(context)!.categories,
                                      () {
                                    context.push(RouteNames.categories);
                                  }),
                                  const SizedBox(height: 16),
                                  _buildCategories(),
                                  const SizedBox(height: 28),
                                ],

                                // Continue Learning
                                if (_isLoading) ...[
                                  _buildSectionHeader(
                                      AppLocalizations.of(context)!
                                          .continueLearning,
                                      () {}),
                                  const SizedBox(height: 16),
                                  _buildContinueLearningSkeleton(),
                                  const SizedBox(height: 28),
                                ] else if (_continueLearning.isNotEmpty) ...[
                                  _buildSectionHeader(
                                      AppLocalizations.of(context)!
                                          .continueLearning, () {
                                    context.push(RouteNames.enrolled);
                                  }),
                                  const SizedBox(height: 16),
                                  _buildContinueLearning(),
                                  const SizedBox(height: 28),
                                ],

                                // Popular Courses
                                if (_isLoading) ...[
                                  _buildSectionHeader(
                                      AppLocalizations.of(context)!
                                          .recommendedCourses,
                                      () {}),
                                  const SizedBox(height: 16),
                                  _buildRecommendedCoursesSkeleton(),
                                ] else if (_popularCourses.isNotEmpty) ...[
                                  _buildSectionHeader(
                                      AppLocalizations.of(context)!
                                          .recommendedCourses, () {
                                    context.push(RouteNames.allCourses);
                                  }),
                                  const SizedBox(height: 16),
                                  _buildRecommendedCourses(),
                                ],

                                  const SizedBox(height: 140),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Navigation
          const BottomNav(activeTab: 'home'),
        ],
      ),
    );
  }

  Widget _buildHeader(double statusBarHeight) {
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
          // Decorative educational icons - transparent
          Positioned(
            top: statusBarHeight + 60,
            right: 20,
            child: Icon(
              Icons.menu_book_rounded,
              size: 40,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Positioned(
            top: statusBarHeight + 30,
            left: 40,
            child: Icon(
              Icons.lightbulb_outline_rounded,
              size: 30,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Positioned(
            bottom: 80,
            right: 60,
            child: Icon(
              Icons.science_outlined,
              size: 35,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
          Positioned(
            bottom: 100,
            left: 20,
            child: Icon(
              Icons.calculate_outlined,
              size: 28,
              color: Colors.white.withOpacity(0.06),
            ),
          ),

          Padding(
            padding: EdgeInsets.only(
              top: statusBarHeight + 16,
              left: 20,
              right: 20,
              bottom: 56,
            ),
            child: Column(
              children: [
                // Top Row - Student Avatar, User & Notifications
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Student Avatar and welcome
                    Expanded(
                      child: Row(
                        children: [
                          // Student Avatar instead of logo
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
                              child: _userProfile?['avatar'] != null
                                  ? Image.network(
                                      ApiEndpoints.getImageUrl(
                                        _userProfile!['avatar']?.toString(),
                                      ),
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
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
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        if (kDebugMode) {
                                          print(
                                              '❌ Error loading avatar image: $error');
                                          print(
                                              '   Avatar URL: ${ApiEndpoints.getImageUrl(_userProfile!['avatar']?.toString())}');
                                          print('   Stack trace: $stackTrace');
                                        }
                                        return Image.asset(
                                          'assets/images/student-avatar.png',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            color: Colors.white,
                                            child: const Icon(
                                              Icons.person,
                                              color: AppColors.purple,
                                              size: 28,
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : Image.asset(
                                      'assets/images/student-avatar.png',
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                        color: Colors.white,
                                        child: const Icon(
                                          Icons.person,
                                          color: AppColors.purple,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.welcome(
                                      _userProfile?['name']?.toString() ??
                                          AppLocalizations.of(context)!
                                              .visitor),
                                  style: GoogleFonts.cairo(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star,
                                                color: Colors.amber, size: 14),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                AppLocalizations.of(context)!
                                                    .excellentStudent,
                                                style: GoogleFonts.cairo(
                                                  fontSize: 11,
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
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
                        ],
                      ),
                    ),
                    // Actions
                    Row(
                      children: [
                        // Settings
                        _buildHeaderButton(
                          icon: Icons.settings_outlined,
                          onTap: () => context.push(RouteNames.settings),
                        ),
                        const SizedBox(width: 8),
                        // Notifications with badge
                        _buildHeaderButton(
                          icon: Icons.notifications_none_rounded,
                          badge: _notificationsCount > 0
                              ? _notificationsCount.toString()
                              : null,
                          onTap: () => context.push(RouteNames.notifications),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Enhanced Oval Search Bar
                _buildSearchBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(
      {required IconData icon, String? badge, required VoidCallback onTap}) {
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
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            if (badge != null)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.cairo(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30), // Oval shape
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
        style: GoogleFonts.cairo(
          fontSize: 15,
          color: AppColors.foreground,
        ),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.searchPlaceholder,
          hintStyle: GoogleFonts.cairo(
            fontSize: 14,
            color: AppColors.mutedForeground,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(right: 20, left: 12),
            child:
                Icon(Icons.search_rounded, color: AppColors.purple, size: 24),
          ),
          suffixIcon: Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0C52B3), Color(0xFF093F8A)],
              ),
              borderRadius: BorderRadius.circular(20), // Oval suffix
            ),
            child:
                const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
        onTap: () {
          // Show search overlay
          _showSearchOverlay(context);
        },
        readOnly: true,
      ),
    );
  }

  void _showSearchOverlay(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchOverlay(
        allCourses: _allCourses,
        onCourseSelected: (course) {
          Navigator.pop(context);
          _handleCourseClick(course);
        },
      ),
    );
  }

  Widget _build3DBanner() {
    final heroBanner = _homeData?['hero_banner'] as Map<String, dynamic>?;
    final title = heroBanner?['title']?.toString();
    final subtitle = heroBanner?['subtitle']?.toString();
    final buttonText = heroBanner?['button_text']?.toString();
    final imageUrl = heroBanner?['image']?.toString();

    // Don't show banner if no data
    if (title == null && subtitle == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedBuilder(
        animation: _bannerAnimation,
        builder: (context, child) {
          // Clamp animation value to ensure it stays within 0.0-1.0 range
          // Use max/min to ensure safety even if value is NaN or Infinity
          final rawValue = _bannerAnimation.value;
          final animationValue = (rawValue.isNaN || rawValue.isInfinite)
              ? 1.0
              : rawValue.clamp(0.0, 1.0);
          return Transform.scale(
            scale: 0.9 + (animationValue * 0.1),
            child: Opacity(
              opacity: animationValue,
              child: child,
            ),
          );
        },
        child: Container(
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
                // Decorative circles
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

                // Main Row - Text on right, Character on left
                Row(
                  children: [
                    // 3D Character - Inside banner on left
                    Expanded(
                      flex: 4,
                      child: Transform.translate(
                        offset: const Offset(-10, 10),
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/images/student-character.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Container(
                                    margin: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.school_rounded,
                                      size: 60,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                              )
                            : Image.asset(
                                'assets/images/student-character.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  margin: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.school_rounded,
                                    size: 60,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                      ),
                    ),

                    // Content on right
                    Expanded(
                      flex: 6,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (heroBanner?['badge'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.local_fire_department,
                                        color: Colors.orange, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      heroBanner?['badge']?.toString() ??
                                          AppLocalizations.of(context)!
                                              .specialOffer,
                                      style: GoogleFonts.cairo(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (title != null) ...[
                              if (heroBanner?['badge'] != null)
                                const SizedBox(height: 8),
                              Text(
                                title,
                                style: GoogleFonts.cairo(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                            ],
                            if (subtitle != null) ...[
                              if (title != null) const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ],
                            if (buttonText != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  buttonText,
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0C52B3),
                                  ),
                                ),
                              ),
                            ],
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

  Widget _build3DBannerSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Skeletonizer(
        enabled: true,
        child: Container(
          height: 165,
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
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 20,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 18,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 14,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 32,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    // Get user summary from API
    final userSummary = _homeData?['user_summary'] as Map<String, dynamic>?;
    final enrolledCourses = userSummary?['enrolled_courses'] ?? 0;
    final certificates = _certificatesCountOverride ?? (userSummary?['certificates'] ?? 0);
    final totalHours = userSummary?['total_hours'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatCard(
            icon: Icons.play_circle_fill_rounded,
            value: enrolledCourses.toString(),
            label: AppLocalizations.of(context)!.enrolledCourse,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: Icons.emoji_events_rounded,
            value: certificates.toString(),
            label: AppLocalizations.of(context)!.certificates,
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: Icons.access_time_filled_rounded,
            value: totalHours.toString(),
            label: AppLocalizations.of(context)!.learningHours,
            color: const Color(0xFF0C52B3),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Skeletonizer(
        enabled: true,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 20,
                      width: 30,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 11,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 20,
                      width: 30,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 11,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 20,
                      width: 30,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 11,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 20,
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
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onViewAll) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
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
          GestureDetector(
            onTap: onViewAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context)!.viewMore,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.purple,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios,
                      size: 12, color: AppColors.purple),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeachersSlider(AppLocalizations l10n) {
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: 20, right: 8),
        itemCount: _teachers.length,
        itemBuilder: (context, index) {
          final teacher = _teachers[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _handleTeacherTap(teacher),
              child: Container(
                width: 220,
                padding: const EdgeInsets.all(14),
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
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.purple.withOpacity(0.1),
                          backgroundImage: NetworkImage(
                            teacher['avatar']?.toString() ?? '',
                          ),
                          onBackgroundImageError: (_, __) {},
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                teacher['name']?.toString() ?? '',
                                style: GoogleFonts.cairo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.foreground,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                teacher['title']?.toString() ?? '',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: AppColors.mutedForeground,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      teacher['bio']?.toString() ?? '',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          (teacher['rating'] ?? 0).toString(),
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.people_alt_rounded,
                            size: 16, color: AppColors.purple),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            l10n.studentsCount(
                                (teacher['students'] as int?) ?? 0),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            l10n.coursesCount(
                              (teacher['courses_count'] as int?) ??
                                  (teacher['courses'] as List?)?.length ??
                                  0,
                            ),
                            style: GoogleFonts.cairo(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTeachersSliderSkeleton() {
    return Skeletonizer(
      enabled: true,
      child: SizedBox(
        height: 150,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(left: 20, right: 8),
          itemCount: 3,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                width: 220,
                padding: const EdgeInsets.all(14),
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
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.grey[300],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 14,
                                width: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: 12,
                                width: 60,
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
                    const SizedBox(height: 12),
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 12,
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          height: 16,
                          width: 30,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 16,
                          width: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 24,
                          width: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeaturedCourses() {
    if (_featuredCourses.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 285,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: 20, right: 8),
        itemCount: _featuredCourses.length,
        itemBuilder: (context, index) {
          final course = _featuredCourses[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PremiumCourseCard(
              course: course,
              onTap: () => _handleCourseClick(course),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorView() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 80,
              color: Colors.red[300],
            ),
            const SizedBox(height: 24),
            Text(
              l10n.errorTitle,
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? l10n.unexpectedError,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                _loadHomeData();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                l10n.retry,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getCategoryIcon(dynamic iconValue) {
    const iconColor = AppColors.primary;
    const iconSize = 24.0;

    if (iconValue == null) {
      return Icon(Icons.category_rounded, color: iconColor, size: iconSize);
    }

    if (iconValue is IconData) {
      return Icon(iconValue, color: iconColor, size: iconSize);
    }

    if (iconValue is String) {
      final iconMap = {
        'design_services': Icons.design_services_rounded,
        'code': Icons.code_rounded,
        'trending_up': Icons.trending_up_rounded,
        'analytics': Icons.analytics_rounded,
        'school': Icons.school_rounded,
        'computer': Icons.computer_rounded,
        'business': Icons.business_rounded,
        'science': Icons.science_rounded,
        'palette': Icons.palette_rounded,
        'language': Icons.language_rounded,
        'music_note': Icons.music_note_rounded,
        'fitness_center': Icons.fitness_center_rounded,
        'restaurant': Icons.restaurant_rounded,
        'local_movies': Icons.local_movies_rounded,
        'photo_camera': Icons.photo_camera_rounded,
        'briefcase': Icons.business_center_rounded,
        'book': Icons.menu_book_rounded,
        'calculate': Icons.calculate_rounded,
        'bolt': Icons.bolt_rounded,
      };

      final iconName = iconValue.toLowerCase().replaceAll(' ', '_');
      final iconData = iconMap[iconName];

      if (iconData != null) {
        return Icon(iconData, color: iconColor, size: iconSize);
      }

      if (iconValue.startsWith('http://') ||
          iconValue.startsWith('https://') ||
          iconValue.startsWith('/')) {
        return Image.network(
          iconValue,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.category_rounded, color: iconColor, size: iconSize);
          },
        );
      }
    }

    return Icon(Icons.category_rounded, color: iconColor, size: iconSize);
  }

  Widget _buildCategories() {
    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final id = cat['id']?.toString() ?? '';
          final name = (cat['name_ar'] ?? cat['name'] ?? cat['label'] ?? '')
              .toString();
          final raw = cat['courses_count'] ?? cat['count'] ?? 0;
          final count = raw is int
              ? raw
              : raw is num
                  ? raw.toInt()
                  : int.tryParse(raw.toString()) ?? 0;

          return GestureDetector(
            onTap: () {
              if (id.isNotEmpty) {
                context.push(RouteNames.allCourses, extra: {
                  'categoryId': id,
                  'categoryName': name,
                });
              } else {
                context.push(RouteNames.categories);
              }
            },
            child: Container(
              width: 108,
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.lavenderLight,
                          AppColors.primary.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.18),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: _getCategoryIcon(cat['icon']),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                        height: 1.2,
                      ),
                    ),
                  ),
                  Text(
                    l10n.coursesCount(count),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecommendedCourses() {
    if (_popularCourses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _popularCourses.take(4).map((course) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildHorizontalCourseCard(course),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContinueLearning() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _continueLearning.take(4).map((course) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildHorizontalCourseCard(course),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHorizontalCourseCard(Map<String, dynamic> course) {
    final lastLesson = course['last_lesson'] as Map<String, dynamic>?;
    return GestureDetector(
      onTap: () {
        if (lastLesson != null && lastLesson['id'] != null) {
          final courseId = course['id']?.toString();
          context.push(RouteNames.lessonViewer, extra: {
            'lesson': lastLesson,
            'courseId': courseId,
          });
        } else {
          _handleCourseClick(course);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
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
        child: Row(
          children: [
            // Image
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: course['thumbnail'] != null
                    ? Image.network(
                        course['thumbnail']?.toString() ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => course['image'] != null
                            ? Image.asset(
                                course['image']?.toString() ?? '',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppColors.purple.withOpacity(0.1),
                                  child: const Icon(Icons.image,
                                      color: AppColors.purple, size: 30),
                                ),
                              )
                            : Container(
                                color: AppColors.purple.withOpacity(0.1),
                                child: const Icon(Icons.image,
                                    color: AppColors.purple, size: 30),
                              ),
                      )
                    : course['image'] != null
                        ? Image.asset(
                            course['image']?.toString() ?? '',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.purple.withOpacity(0.1),
                              child: const Icon(Icons.image,
                                  color: AppColors.purple, size: 30),
                            ),
                          )
                        : Container(
                            color: AppColors.purple.withOpacity(0.1),
                            child: const Icon(Icons.image,
                                color: AppColors.purple, size: 30),
                          ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          courseCategoryEnglishLabel(course['category']),
                          style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: AppColors.purple,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      if (courseIsEffectivelyFree(course))
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.free,
                            style: GoogleFonts.cairo(
                                fontSize: 10,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    courseDisplayTitle(
                      course,
                      fallback: AppLocalizations.of(context)!.courseTitle,
                    ),
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    courseDisplayInstructor(
                      course,
                      fallback: AppLocalizations.of(context)!.instructor,
                    ),
                    style: GoogleFonts.cairo(
                        fontSize: 12, color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        courseCardRatingNum(course).toStringAsFixed(1),
                        style: GoogleFonts.cairo(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time_rounded,
                          size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        courseListCardDurationText(
                          course,
                          AppLocalizations.of(context)!.hoursUnitShort,
                        ),
                        style: GoogleFonts.cairo(
                            fontSize: 11, color: AppColors.mutedForeground),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.people_rounded,
                          size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        '${courseCardStudentsCount(course)}',
                        style: GoogleFonts.cairo(
                            fontSize: 11, color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                  if (lastLesson != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.play_circle_outline_rounded,
                            size: 12, color: AppColors.purple),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.continueLesson(
                              (lastLesson['title'] ?? '').toString(),
                            ),
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              color: AppColors.purple,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Skeleton Loading Widgets
  Widget _buildFeaturedCoursesSkeleton() {
    return Skeletonizer(
      enabled: true,
      child: SizedBox(
        height: 285,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(left: 20, right: 8),
          itemCount: 3,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                width: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 12,
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 16,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 14,
                            width: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                height: 12,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                height: 12,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(6),
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoriesSkeleton() {
    return Skeletonizer(
      enabled: true,
      child: SizedBox(
        height: 124,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) {
            return Container(
              width: 108,
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  Container(
                    height: 8,
                    width: 56,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContinueLearningSkeleton() {
    return Skeletonizer(
      enabled: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: List.generate(2, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 12,
                            width: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 14,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 12,
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                height: 10,
                                width: 30,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                height: 10,
                                width: 30,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(6),
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
            );
          }),
        ),
      ),
    );
  }

  Widget _buildRecommendedCoursesSkeleton() {
    return Skeletonizer(
      enabled: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 12,
                            width: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 14,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 12,
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                height: 10,
                                width: 30,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                height: 10,
                                width: 30,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(6),
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
            );
          }),
        ),
      ),
    );
  }
}

// Search Overlay Widget
class _SearchOverlay extends StatefulWidget {
  final List<Map<String, dynamic>> allCourses;
  final Function(Map<String, dynamic>) onCourseSelected;

  const _SearchOverlay({
    required this.allCourses,
    required this.onCourseSelected,
  });

  @override
  State<_SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<_SearchOverlay> {
  final _searchController = TextEditingController();
  String _query = '';

  List<Map<String, dynamic>> get _filteredCourses {
    if (_query.isEmpty) return widget.allCourses;
    return widget.allCourses.where((course) {
      final title = course['title']?.toString() ?? '';
      final instructor = course['instructor'] is Map
          ? (course['instructor'] as Map)['name']?.toString() ?? ''
          : course['instructor']?.toString() ?? '';
      final category = course['category'] is Map
          ? (course['category'] as Map)['name']?.toString() ?? ''
          : course['category']?.toString() ?? '';

      return title.contains(_query) ||
          instructor.contains(_query) ||
          category.contains(_query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.beige,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.cairo(fontSize: 15),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.searchPlaceholder,
                  hintStyle: GoogleFonts.cairo(
                    fontSize: 14,
                    color: AppColors.mutedForeground,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(right: 16, left: 12),
                    child: Icon(Icons.search_rounded, color: AppColors.purple),
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          ),

          // Results
          Expanded(
            child: _filteredCourses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.noResultsFound,
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filteredCourses.length,
                    itemBuilder: (context, index) {
                      final course = _filteredCourses[index];
                      return GestureDetector(
                        onTap: () => widget.onCourseSelected(course),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.beige,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: (course['thumbnail'] != null ||
                                        course['image'] != null)
                                    ? Image.network(
                                        course['thumbnail']?.toString() ?? '',
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => course[
                                                    'image'] !=
                                                null
                                            ? Image.asset(
                                                course['image']?.toString() ??
                                                    '',
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                  width: 60,
                                                  height: 60,
                                                  color: AppColors.purple
                                                      .withOpacity(0.1),
                                                  child: const Icon(Icons.image,
                                                      color: AppColors.purple),
                                                ),
                                              )
                                            : Container(
                                                width: 60,
                                                height: 60,
                                                color: AppColors.purple
                                                    .withOpacity(0.1),
                                                child: const Icon(Icons.image,
                                                    color: AppColors.purple),
                                              ),
                                      )
                                    : course['image'] != null
                                        ? Image.asset(
                                            course['image']?.toString() ?? '',
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              width: 60,
                                              height: 60,
                                              color: AppColors.purple
                                                  .withOpacity(0.1),
                                              child: const Icon(Icons.image,
                                                  color: AppColors.purple),
                                            ),
                                          )
                                        : Container(
                                            width: 60,
                                            height: 60,
                                            color: AppColors.purple
                                                .withOpacity(0.1),
                                            child: const Icon(Icons.image,
                                                color: AppColors.purple),
                                          ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      course['title']?.toString() ?? '',
                                      style: GoogleFonts.cairo(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      course['instructor'] is Map
                                          ? (course['instructor']
                                                      as Map)['name']
                                                  ?.toString() ??
                                              ''
                                          : course['instructor']?.toString() ??
                                              '',
                                      style: GoogleFonts.cairo(
                                        fontSize: 12,
                                        color: AppColors.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (courseIsEffectivelyFree(course))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    AppLocalizations.of(context)!.free,
                                    style: GoogleFonts.cairo(
                                      fontSize: 11,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


// 1- وفيها زرار عرض المزيد تدخلك علي صفحه كل المعلمين  اعمل سلايدر المعلمون
// 2- لو ضغط علي اي معلم يفتح صفحه سينجل للمدرس تعرض الصوره واسمو بشكل رايق ونبذه عنو وتحتها كورساتو 