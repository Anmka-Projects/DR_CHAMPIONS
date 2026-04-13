import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_text_styles.dart';
import '../../core/design/app_radius.dart';
import '../../core/navigation/route_names.dart';
import '../../widgets/bottom_nav.dart';
import '../../services/courses_service.dart';

/// Categories Screen - Pixel-perfect match to React version
/// Matches: components/screens/categories-screen.tsx
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await CoursesService.instance.getCategories();

      if (kDebugMode) {
        print('✅ Categories loaded: ${categories.length}');
        print('📋 Categories data in screen:');
        for (var i = 0; i < categories.length; i++) {
          final cat = categories[i];
          print('  Category ${i + 1}:');
          print('    id: ${cat['id']}');
          print('    name: ${cat['name']} / ${cat['name_ar']}');
          print('    icon: ${cat['icon']}');
          print('    icon type: ${cat['icon']?.runtimeType}');
          print('    color: ${cat['color']}');
        }
      }

      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading categories: $e');
      }
      setState(() {
        _categories = [];
        _isLoading = false;
      });
    }
  }

  Color _parseColor(dynamic colorValue) {
    // Return default if null
    if (colorValue == null) {
      return AppColors.purple;
    }

    // If already a Color, return it
    if (colorValue is Color) {
      return colorValue;
    }

    // If it's a String, try to parse it
    if (colorValue is String) {
      try {
        // Remove # if present and trim whitespace
        String hex = colorValue.replaceAll('#', '').trim();

        // Handle empty string
        if (hex.isEmpty) {
          return AppColors.purple;
        }

        // Parse hex color
        if (hex.length == 6) {
          return Color(int.parse('FF$hex', radix: 16));
        } else if (hex.length == 8) {
          return Color(int.parse(hex, radix: 16));
        } else {
          if (kDebugMode) {
            print(
                '⚠️ Invalid hex color length: $hex (expected 6 or 8 characters)');
          }
          return AppColors.purple;
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Error parsing color "$colorValue": $e');
        }
        return AppColors.purple;
      }
    }

    // For any other type, return default
    if (kDebugMode) {
      print('⚠️ Unknown color type: ${colorValue.runtimeType}');
    }
    return AppColors.purple;
  }

  IconData _getCategoryIcon(String? iconUrl) {
    // Map common icon names to IconData
    if (iconUrl == null || iconUrl.isEmpty) {
      return Icons.category_rounded;
    }

    // If it's a URL, return default icon
    if (iconUrl.startsWith('http')) {
      return Icons.category_rounded;
    }

    // Map string names to icons
    final iconMap = {
      'book': Icons.menu_book,
      'calculate': Icons.calculate,
      'science': Icons.science,
      'language': Icons.language,
      'bolt': Icons.bolt,
      'code': Icons.code,
      'palette': Icons.palette,
      'music': Icons.music_note,
      'business': Icons.business,
      'favorite': Icons.favorite,
      'design': Icons.palette,
      'math': Icons.calculate,
      'chemistry': Icons.science,
      'physics': Icons.bolt,
      'programming': Icons.code,
    };

    final lowerIcon = iconUrl.toLowerCase();
    for (var entry in iconMap.entries) {
      if (lowerIcon.contains(entry.key)) {
        return entry.value;
      }
    }

    return Icons.category_rounded;
  }

  Widget _buildCategoryIcon({
    required String? iconUrl,
    required IconData icon,
    required Color color,
  }) {
    // If iconUrl is null or empty, show default icon
    if (iconUrl == null || iconUrl.isEmpty) {
      if (kDebugMode) {
        print('📌 No icon URL, showing default icon');
      }
      return Icon(
        icon,
        size: 32,
        color: color,
      );
    }

    // Check if it's a URL (http/https) or relative path (/path)
    final isUrl = iconUrl.startsWith('http://') ||
        iconUrl.startsWith('https://') ||
        iconUrl.startsWith('/');

    if (kDebugMode) {
      print('🖼️ Building category icon:');
      print('   URL: $iconUrl');
      print('   Is URL: $isUrl');
    }

    if (isUrl) {
      // Display image from URL
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          iconUrl,
          width: 64,
          height: 64,
          fit: BoxFit.contain, // Use contain instead of cover for icons
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              if (kDebugMode) {
                print('✅ Icon loaded successfully: $iconUrl');
              }
              return child;
            }
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: color,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            if (kDebugMode) {
              print('❌ Error loading category icon: $iconUrl');
              print('   Error: $error');
              print('   StackTrace: $stackTrace');
            }
            // Fallback to default icon on error
            return Icon(
              icon,
              size: 32,
              color: color,
            );
          },
        ),
      );
    } else {
      // Not a URL, show default icon
      if (kDebugMode) {
        print('📌 Icon is not a URL, showing default icon');
      }
      return Icon(
        icon,
        size: 32,
        color: color,
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleCategoryClick(Map<String, dynamic> category) {
    final categoryId = category['id']?.toString();
    if (categoryId == null || categoryId.isEmpty) return;

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        // Navigate to all courses screen with category filter
        context.push(RouteNames.allCourses, extra: {
          'categoryId': categoryId,
          'categoryName': category['name']?.toString() ??
              category['name_ar']?.toString() ??
              'التصنيف',
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      body: Stack(
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 400),
            margin: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width > 400
                  ? (MediaQuery.of(context).size.width - 400) / 2
                  : 0,
            ),
            child: Column(
              children: [
                // Header - matches React: bg-[var(--purple)] rounded-b-[3rem] pt-4 pb-8 px-4
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.purple,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(AppRadius.largeCard),
                      bottomRight: Radius.circular(AppRadius.largeCard),
                    ),
                  ),
                  padding: const EdgeInsets.only(
                    top: 16, // pt-4
                    bottom: 32, // pb-8
                    left: 16, // px-4
                    right: 16,
                  ),
                  child: Column(
                    children: [
                      // Back button and title - matches React: gap-4 mb-4
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Container(
                              width: 40, // w-10
                              height: 100, // h-10
                              decoration: const BoxDecoration(
                                color: AppColors.whiteOverlay20, // bg-white/20
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 20, // w-5 h-5
                              ),
                            ),
                          ),
                          const SizedBox(width: 16), // gap-4
                          Text(
                            'التصنيفات',
                            style: AppTextStyles.h2(color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16), // mb-4
                      // Subtitle
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'اختر المادة التي تريد تعلمها',
                          style: AppTextStyles.bodyMedium(
                            color: Colors.white.withOpacity(0.7), // white/70
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Categories Grid - matches React: px-4 -mt-6
                SizedBox(
                  height: 700,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        SizedBox(
                          child: Transform.translate(
                            offset: const Offset(0, -24), // -mt-6 = -24px
                            child: _isLoading
                                ? _buildLoadingState()
                                : _categories.isEmpty
                                    ? _buildEmptyState()
                                    : RefreshIndicator(
                                        onRefresh: _loadCategories,
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16), // px-4
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          child: GridView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            gridDelegate:
                                                const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 2,
                                              crossAxisSpacing: 16, // gap-4
                                              mainAxisSpacing: 16, // gap-4
                                              childAspectRatio: 0.85,
                                            ),
                                            itemCount: _categories.length,
                                            itemBuilder: (context, index) {
                                              final category =
                                                  _categories[index];
                                              final colorValue =
                                                  category['color'];
                                              final Color color =
                                                  _parseColor(colorValue);
                                              final iconUrl =
                                                  category['icon']?.toString();
                                              final icon =
                                                  _getCategoryIcon(iconUrl);
                                              final name = category['name_ar']
                                                      ?.toString() ??
                                                  category['name']
                                                      ?.toString() ??
                                                  'التصنيف';
                                              final coursesCount =
                                                  (category['courses_count']
                                                              as num?)
                                                          ?.toInt() ??
                                                      0;

                                              return TweenAnimationBuilder<
                                                  double>(
                                                tween:
                                                    Tween(begin: 0.0, end: 1.0),
                                                duration: Duration(
                                                    milliseconds:
                                                        500 + (index * 50)),
                                                builder:
                                                    (context, value, child) {
                                                  return Opacity(
                                                    opacity: value,
                                                    child: Transform.scale(
                                                      scale:
                                                          0.8 + (value * 0.2),
                                                      child: child,
                                                    ),
                                                  );
                                                },
                                                child: GestureDetector(
                                                  onTap: () =>
                                                      _handleCategoryClick(
                                                          category),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              24), // rounded-3xl
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(
                                                                  0.05), // shadow-sm
                                                          blurRadius: 4,
                                                          offset: const Offset(
                                                              0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Stack(
                                                      children: [
                                                        // Gradient overlay on hover (simulated)
                                                        Positioned.fill(
                                                          child: Container(
                                                            decoration:
                                                                BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          24),
                                                              gradient:
                                                                  LinearGradient(
                                                                begin: Alignment
                                                                    .topLeft,
                                                                end: Alignment
                                                                    .bottomRight,
                                                                colors: [
                                                                  color
                                                                      .withOpacity(
                                                                          0.1),
                                                                  color
                                                                      .withOpacity(
                                                                          0.05),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),

                                                        // Content - matches React: p-5
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(
                                                                  20), // p-5
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              // Icon - matches React: w-16 h-16 rounded-2xl mb-4
                                                              Container(
                                                                width:
                                                                    64, // w-16
                                                                height:
                                                                    64, // h-16
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: color
                                                                      .withOpacity(
                                                                          0.15), // color15
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              16), // rounded-2xl
                                                                ),
                                                                child:
                                                                    _buildCategoryIcon(
                                                                  iconUrl:
                                                                      iconUrl,
                                                                  icon: icon,
                                                                  color: color,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height:
                                                                      16), // mb-4

                                                              // Title - matches React: font-bold text-lg mb-1
                                                              Text(
                                                                name,
                                                                style:
                                                                    AppTextStyles
                                                                        .h4(
                                                                  color: AppColors
                                                                      .foreground,
                                                                ),
                                                                maxLines: 2,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                              const SizedBox(
                                                                  height:
                                                                      4), // mb-1

                                                              // Courses count - matches React: text-sm
                                                              Text(
                                                                '$coursesCount ${coursesCount == 1 ? 'دورة' : 'دورات'}',
                                                                style: AppTextStyles
                                                                    .bodySmall(
                                                                  color: AppColors
                                                                      .mutedForeground,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),

                                                        // Animated corner accent
                                                        Positioned(
                                                          bottom: -16,
                                                          left: -16,
                                                          child: Container(
                                                            width: 64, // w-16
                                                            height: 64, // h-16
                                                            decoration:
                                                                BoxDecoration(
                                                              color: color
                                                                  .withOpacity(
                                                                      0.2),
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
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

          // Bottom Navigation
          const BottomNav(activeTab: 'home'),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Skeletonizer(
      enabled: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                    height: 12,
                    width: 60,
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.category_rounded,
                size: 48,
                color: AppColors.purple,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد تصنيفات',
              style: AppTextStyles.h4(
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'سيتم إضافة التصنيفات قريباً',
              style: AppTextStyles.bodyMedium(
                color: AppColors.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
