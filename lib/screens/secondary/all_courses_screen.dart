import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/course_pricing.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_radius.dart';
import '../../core/localization/localization_helper.dart';
import '../../core/navigation/route_names.dart';
import '../../widgets/bottom_nav.dart';
import '../../services/courses_service.dart';

/// All Courses Screen - With Filters & Modern Card Design
class AllCoursesScreen extends StatefulWidget {
  const AllCoursesScreen({super.key});

  @override
  State<AllCoursesScreen> createState() => _AllCoursesScreenState();
}

class _AllCoursesScreenState extends State<AllCoursesScreen> {
  bool _isLoading = true;
  String? _selectedCategoryId;
  final String _selectedPrice = 'all'; // all, free, paid
  final String _sortBy = 'newest'; // newest, rating, popular
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _courses = [];
  int _totalCourses = 0;

  List<Map<String, dynamic>> _extractCategoriesFromCourses(
      List<Map<String, dynamic>> courses) {
    final seenIds = <String>{};
    final extracted = <Map<String, dynamic>>[];

    for (final course in courses) {
      final categoryRaw = course['category'];
      Map<String, dynamic>? categoryMap;

      if (categoryRaw is Map<String, dynamic>) {
        categoryMap = categoryRaw;
      } else if (categoryRaw is String && categoryRaw.trim().isNotEmpty) {
        categoryMap = {
          'id': course['category_id']?.toString() ?? categoryRaw,
          'name': categoryRaw,
          'name_ar': categoryRaw,
        };
      }

      if (categoryMap == null) continue;

      final id = categoryMap['id']?.toString() ??
          categoryMap['name']?.toString() ??
          categoryMap['name_ar']?.toString();
      if (id == null || id.isEmpty || seenIds.contains(id)) continue;

      seenIds.add(id);
      extracted.add(categoryMap);
    }

    return extracted;
  }

  List<Map<String, dynamic>> _getPriceFilters(BuildContext context) => [
        {'value': 'all', 'label': context.l10n.all},
        {'value': 'free', 'label': context.l10n.free},
        {'value': 'paid', 'label': context.l10n.paid},
      ];

  List<Map<String, dynamic>> _getSortOptions(BuildContext context) => [
        {'value': 'newest', 'label': context.l10n.newest},
        {'value': 'rating', 'label': context.l10n.highestRated},
        {'value': 'popular', 'label': context.l10n.bestSelling},
        {'value': 'price_low', 'label': context.l10n.priceLowToHigh},
        {'value': 'price_high', 'label': context.l10n.priceHighToLow},
      ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text != _searchQuery) {
        setState(() {
          _searchQuery = _searchController.text;
        });
        _loadCourses();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Keep courses loading even if categories fail.
      final categoriesFuture =
          CoursesService.instance.getCategories().catchError((e) {
        if (kDebugMode) {
          print('⚠️ Categories failed, continuing without categories: $e');
        }
        return <Map<String, dynamic>>[];
      });

      await _loadCourses();
      final categories = await categoriesFuture;

      if (!mounted) return;
      setState(() {
        _categories = categories.isNotEmpty
            ? categories
            : _extractCategoriesFromCourses(_courses);
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading data: $e');
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCourses() async {
    try {
      setState(() => _isLoading = true);

      final String? categoryIdRaw = _selectedCategoryId;
      final String? categoryId =
          categoryIdRaw != null && categoryIdRaw.trim().isNotEmpty
              ? categoryIdRaw.trim()
              : null;
      String price = _selectedPrice;

      // Map sort options to API format
      String apiSort = 'newest';
      if (_sortBy == 'rating') {
        apiSort = 'rating';
      } else if (_sortBy == 'popular') {
        apiSort = 'popular';
      } else if (_sortBy == 'price_low') {
        apiSort = 'price_low';
      } else if (_sortBy == 'price_high') {
        apiSort = 'price_high';
      }

      Map<String, dynamic> response;

      final hasCategory = categoryId != null;
      final hasSearch = _searchQuery.trim().isNotEmpty;

      // Category-scoped listing: `/categories/{id}/courses` is often more complete
      // than `/courses?category_id=` (some categories missed rows, e.g. EEG).
      if (hasCategory && !hasSearch) {
        final cid = categoryId;
        try {
          response = await CoursesService.instance.getCategoryCoursesAllPages(
            cid,
            perPage: 50,
            sort: apiSort,
            price: price,
            level: 'all',
          );
          if (response['success'] != true) {
            response = await CoursesService.instance.getCoursesAllPages(
              perPage: 50,
              search: null,
              categoryId: cid,
              price: price,
              sort: apiSort,
              level: 'all',
              duration: 'all',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            print(
                '⚠️ Category courses endpoint failed, falling back to /courses: $e');
          }
          response = await CoursesService.instance.getCoursesAllPages(
            perPage: 50,
            search: null,
            categoryId: cid,
            price: price,
            sort: apiSort,
            level: 'all',
            duration: 'all',
          );
        }
      } else {
        response = await CoursesService.instance.getCoursesAllPages(
          perPage: 50,
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
          categoryId: categoryId,
          price: price,
          sort: apiSort,
          level: 'all', // Can be extended later
          duration: 'all', // Can be extended later
        );
      }

      if (kDebugMode) {
        Object? nestedMetaTotal;
        if (response['data'] is Map<String, dynamic>) {
          final dataMap = response['data'] as Map<String, dynamic>;
          final meta = dataMap['meta'];
          if (meta is Map<String, dynamic>) {
            nestedMetaTotal = meta['total'];
          }
        }
        print('✅ Courses loaded with filters:');
        print('  categoryId: $categoryId');
        print('  price: $price');
        print('  sort: $apiSort');
        print('  search: $_searchQuery');
        print('  total: ${nestedMetaTotal ?? response['meta']?['total'] ?? 0}');
      }

      List<Map<String, dynamic>> coursesList = [];
      if (response['data'] != null) {
        if (response['data'] is List) {
          coursesList = List<Map<String, dynamic>>.from(
            response['data'] as List,
          );
        } else if (response['data'] is Map) {
          final dataMap = response['data'] as Map<String, dynamic>;
          if (dataMap['courses'] != null && dataMap['courses'] is List) {
            coursesList = List<Map<String, dynamic>>.from(
              dataMap['courses'] as List,
            );
          }
        }
      }

      // Safely parse total courses
      int totalCoursesValue = coursesList.length;
      Object? totalFromDataMeta;
      if (response['data'] is Map<String, dynamic>) {
        final dataMap = response['data'] as Map<String, dynamic>;
        final meta = dataMap['meta'];
        if (meta is Map<String, dynamic>) {
          totalFromDataMeta = meta['total'];
        }
      }
      final totalRaw = totalFromDataMeta ?? response['meta']?['total'];
      if (totalRaw != null) {
        final total = totalRaw;
        if (total is int) {
          totalCoursesValue = total;
        } else if (total is num) {
          totalCoursesValue = total.toInt();
        } else if (total is String) {
          totalCoursesValue = int.tryParse(total) ?? coursesList.length;
        }
      }

      setState(() {
        _courses = coursesList;
        _totalCourses = totalCoursesValue;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading courses: $e');
        print('  Stack trace: ${StackTrace.current}');
      }
      setState(() {
        _courses = [];
        _totalCourses = 0;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.errorLoadingCourses,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getCategoryList(BuildContext context) {
    final List<Map<String, dynamic>> list = [
      {'id': null, 'name': context.l10n.all, 'name_ar': context.l10n.all},
    ];
    list.addAll(_categories);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      body: Stack(
        children: [
          Column(
            children: [
              // Header
              _buildHeader(context),

              // Filters
              _buildFilters(),

              // Courses Grid
              Expanded(
                child: _isLoading
                    ? _buildCoursesSkeleton()
                    : _courses.isEmpty
                        ? _buildEmptyState()
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
                            physics: const BouncingScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 0.60,
                            ),
                            itemCount: _courses.length,
                            itemBuilder: (context, index) {
                              return _buildCourseCard(_courses[index]);
                            },
                          ),
              ),
            ],
          ),
          // Bottom Navigation
          const BottomNav(activeTab: 'courses'),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      child: Column(
        children: [
          // Title Row
          Row(
            children: [
              GestureDetector(
                onTap: () => context.go(RouteNames.home),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.allCourses,
                      style: GoogleFonts.cairo(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      context.l10n.coursesAvailable(_totalCourses),
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search Bar - Oval like Home
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
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
              style: GoogleFonts.cairo(fontSize: 14),
              decoration: InputDecoration(
                hintText: context.l10n.searchCourse,
                hintStyle: GoogleFonts.cairo(
                    color: AppColors.mutedForeground, fontSize: 14),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(right: 16, left: 12),
                  child: Icon(Icons.search_rounded,
                      color: AppColors.purple, size: 24),
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              ),
              onChanged: (value) {
                // Search is handled by _onSearchChanged listener
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          // Category Filter
          SizedBox(
            height: 40,
            child: _isLoading && _categories.isEmpty
                ? _buildCategoriesSkeleton()
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _getCategoryList(context).length,
                    itemBuilder: (context, index) {
                      final category = _getCategoryList(context)[index];
                      final categoryId = category['id']?.toString();
                      final isSelected = _selectedCategoryId == categoryId;
                      final categoryName = category['name']?.toString() ??
                          category['name_ar']?.toString() ??
                          context.l10n.all;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategoryId = categoryId;
                            });
                            _loadCourses();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(colors: [
                                      Color(0xFF0C52B3),
                                      Color(0xFF093F8A)
                                    ])
                                  : null,
                              color: isSelected ? null : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? AppColors.purple.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                categoryName,
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.foreground,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // const SizedBox(height: 12),

          // // Price & Sort Filters
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 20),
          //   child: Row(
          //     children: [
          //       // Price Filter
          //       Expanded(
          //         child: Builder(
          //           builder: (context) {
          //             final priceFilters = _getPriceFilters(context);
          //             return _buildDropdownFilter(
          //               value: priceFilters.firstWhere(
          //                 (item) => item['value'] == _selectedPrice,
          //                 orElse: () => priceFilters[0],
          //               )['label'] as String,
          //               items: priceFilters
          //                   .map((e) => e['label'] as String)
          //                   .toList(),
          //               icon: Icons.attach_money_rounded,
          //               onChanged: (value) {
          //                 final selected = priceFilters.firstWhere(
          //                   (item) => item['label'] == value,
          //                 );
          //                 setState(() {
          //                   _selectedPrice = selected['value'] as String;
          //                 });
          //                 _loadCourses();
          //               },
          //             );
          //           },
          //         ),
          //       ),
          //       const SizedBox(width: 12),
          //       // Sort Filter
          //       Expanded(
          //         child: Builder(
          //           builder: (context) {
          //             final sortOptions = _getSortOptions(context);
          //             return _buildDropdownFilter(
          //               value: sortOptions.firstWhere(
          //                 (item) => item['value'] == _sortBy,
          //                 orElse: () => sortOptions[0],
          //               )['label'] as String,
          //               items: sortOptions
          //                   .map((e) => e['label'] as String)
          //                   .toList(),
          //               icon: Icons.sort_rounded,
          //               onChanged: (value) {
          //                 final selected = sortOptions.firstWhere(
          //                   (item) => item['label'] == value,
          //                 );
          //                 setState(() {
          //                   _sortBy = selected['value'] as String;
          //                 });
          //                 _loadCourses();
          //               },
          //             );
          //           },
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.purple),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              underline: const SizedBox(),
              style:
                  GoogleFonts.cairo(fontSize: 13, color: AppColors.foreground),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              items: items
                  .map((item) =>
                      DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    final priceValue = tryParseCourseNum(course['price']) ?? 0;
    final isFree = courseIsEffectivelyFree(course);
    final hasPricePlans = courseHasSubscriptionPlans(course);
    final hidePriceBadge = courseHasPlansWithZeroBasePrice(course);
    final showPriceBadge = !hidePriceBadge;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final currencyCode =
        course['currency']?.toString().toUpperCase() == 'USD' ? 'USD' : 'EGP';
    final backendFinalPrice = tryParseCourseNum(course['price']);
    final backendOriginalPrice = tryParseCourseNum(course['original_price']);
    final backendDiscountPrice = tryParseCourseNum(course['discount_price']);
    final hasBackendDiscount = backendDiscountPrice != null &&
        backendOriginalPrice != null &&
        backendDiscountPrice > 0 &&
        backendOriginalPrice > backendDiscountPrice;
    final oldPriceText = hasBackendDiscount
        ? formatSingleCurrencyPrice(
            currency: currencyCode,
            amount: backendOriginalPrice,
          )
        : null;
    final newPriceText = hasBackendDiscount
        ? formatSingleCurrencyPrice(
            currency: currencyCode,
            amount: backendDiscountPrice,
          )
        : null;
    final badgeAmount = courseCardDisplayAmount(course) ?? priceValue;
    final priceBadgeText = isFree
        ? null
        : ((backendFinalPrice != null && backendFinalPrice > 0)
            ? formatSingleCurrencyPrice(
                currency: currencyCode,
                amount: backendFinalPrice,
              )
            : formatCoursePriceCompact(course)) ??
            (badgeAmount > 0
                ? '${badgeAmount.toInt()} ${context.l10n.egyptianPoundShort}'
                : null);

    final thumbnail = course['thumbnail']?.toString() ?? '';
    final categoryName = courseCategoryEnglishLabel(course['category']);
    final instructorName = courseDisplayInstructor(course);
    final courseTitle =
        courseDisplayTitle(course, fallback: context.l10n.noTitle);

    final ratingValue = courseCardRatingNum(course);
    final studentsCountValue = courseCardStudentsCount(course);
    final durationLabel =
        courseListCardDurationText(course, context.l10n.hoursUnitShort);

    return GestureDetector(
      onTap: () {
        context.push(RouteNames.courseDetails, extra: course);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
            // Image
            Stack(
              children: [
                Container(
                  height: 132,
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    gradient: thumbnail.isNotEmpty
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.purple.withOpacity(0.1),
                              AppColors.orange.withOpacity(0.1),
                            ],
                          ),
                    color: thumbnail.isEmpty ? AppColors.lavenderLight : null,
                  ),
                  child: thumbnail.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20)),
                          child: Image.network(
                            thumbnail,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 100,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildNoImagePlaceholder(),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: AppColors.lavenderLight,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.purple,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : _buildNoImagePlaceholder(),
                ),
                // Gradient overlay only when image exists
                if (thumbnail.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.2)
                        ],
                      ),
                    ),
                  ),
                // Price Badge
                if (showPriceBadge)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: isFree
                            ? const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)])
                            : const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        isFree
                            ? context.l10n.free
                            : (priceBadgeText ?? context.l10n.notAvailableShort),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                if (hasPricePlans)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C52B3).withOpacity(0.92),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sell_rounded,
                              size: 11, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            isAr ? 'يوجد خطط أسعار' : 'Plans available',
                            style: GoogleFonts.cairo(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category
                    if (categoryName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          categoryName,
                          style: GoogleFonts.cairo(
                              fontSize: 9,
                              color: AppColors.purple,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (categoryName.isNotEmpty) const SizedBox(height: 6),
                    // Title
                    Text(
                      courseTitle,
                      style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.foreground),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (hasBackendDiscount) ...[
                      Row(
                        children: [
                          Text(
                            oldPriceText!,
                            style: GoogleFonts.cairo(
                              fontSize: 9,
                              color: AppColors.mutedForeground,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            newPriceText!,
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                    ],
                    // Instructor
                    if (instructorName.isNotEmpty)
                      Text(
                        instructorName,
                        style: GoogleFonts.cairo(
                            fontSize: 10, color: AppColors.mutedForeground),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Spacer(),
                    // Stats: rating, duration, learners (field names vary by endpoint).
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 12, color: Colors.amber),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            ratingValue.toStringAsFixed(1),
                            style: GoogleFonts.cairo(
                                fontSize: 10, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.access_time_rounded,
                            size: 11, color: Colors.grey[400]),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            durationLabel,
                            style: GoogleFonts.cairo(
                                fontSize: 9,
                                color: AppColors.mutedForeground),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.people_rounded,
                            size: 11, color: Colors.grey[400]),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            studentsCountValue.toString(),
                            style: GoogleFonts.cairo(
                                fontSize: 9,
                                color: AppColors.mutedForeground),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoImagePlaceholder() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purple.withOpacity(0.15),
            AppColors.orange.withOpacity(0.15),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: AppColors.purple,
                size: 32,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.purple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded,
                size: 50, color: AppColors.purple),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.noResults,
            style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.foreground),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.tryDifferentSearch,
            style: GoogleFonts.cairo(
                fontSize: 14, color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSkeleton() {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Container(
              width: 100,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoursesSkeleton() {
    return Skeletonizer(
      enabled: true,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.60,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
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
                        const SizedBox(height: 6),
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
                          height: 14,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const Spacer(),
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
                            const Spacer(),
                            Container(
                              height: 12,
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
