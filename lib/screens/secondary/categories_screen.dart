import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../core/design/app_colors.dart';
import '../../core/navigation/route_names.dart';
import '../../l10n/app_localizations.dart';
import '../../services/courses_service.dart';
import '../../widgets/bottom_nav.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _categories = const [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final categories = await CoursesService.instance.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ CategoriesScreen load failed: $e');
      }
      if (!mounted) return;
      setState(() {
        _categories = const [];
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  IconData _mapCategoryIcon(String? raw) {
    if (raw == null || raw.isEmpty) return Icons.category_rounded;
    final s = raw.toLowerCase();
    if (s.contains('book')) return Icons.menu_book_rounded;
    if (s.contains('math') || s.contains('calc')) return Icons.calculate_rounded;
    if (s.contains('code') || s.contains('program')) return Icons.code_rounded;
    if (s.contains('science') || s.contains('chem')) return Icons.science_rounded;
    if (s.contains('physics') || s.contains('bolt')) return Icons.bolt_rounded;
    if (s.contains('music')) return Icons.music_note_rounded;
    if (s.contains('design') || s.contains('palette')) return Icons.palette_rounded;
    if (s.contains('business')) return Icons.business_center_rounded;
    return Icons.category_rounded;
  }

  Widget _buildCategoryIcon({
    required String? iconUrl,
    required IconData fallback,
  }) {
    const iconTint = AppColors.primary;
    final hasNetworkUrl =
        iconUrl != null && (iconUrl.startsWith('http://') || iconUrl.startsWith('https://'));
    if (!hasNetworkUrl) {
      return Icon(fallback, color: iconTint, size: 26);
    }

    return Image.network(
      iconUrl,
      width: 26,
      height: 26,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(fallback, color: iconTint, size: 26),
    );
  }

  void _openCategory(Map<String, dynamic> category) {
    final id = category['id']?.toString();
    if (id == null || id.isEmpty) return;
    context.push(RouteNames.allCourses, extra: {
      'categoryId': id,
      'categoryName': category['name']?.toString() ?? category['name_ar']?.toString() ?? '',
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusBarHeight = MediaQuery.of(context).padding.top;

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
                _buildHeader(l10n, statusBarHeight),
                Expanded(child: _buildBody(l10n)),
              ],
            ),
          ),
          const BottomNav(activeTab: 'home'),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, double statusBarHeight) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0C52B3), Color(0xFF093F8A)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, statusBarHeight + 10, 16, 18),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.pop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.categories,
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) return _buildLoadingGrid();
    if (_hasError) return _buildErrorState();
    if (_categories.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _loadCategories,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
        itemCount: _categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final name = (category['name_ar'] ?? category['name'] ?? l10n.categories).toString();
          final count = (category['courses_count'] as num?)?.toInt() ?? 0;
          final iconUrl = category['icon']?.toString();
          final iconData = _mapCategoryIcon(iconUrl);

          return InkWell(
            onTap: () => _openCategory(category),
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
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
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: _buildCategoryIcon(
                        iconUrl: iconUrl,
                        fallback: iconData,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      l10n.coursesCount(count),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
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

  Widget _buildLoadingGrid() {
    return Skeletonizer(
      enabled: true,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.category_rounded, color: AppColors.purple, size: 38),
            ),
            const SizedBox(height: 14),
            Text(
              'لا توجد تصنيفات حالياً',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppColors.mutedForeground, size: 44),
            const SizedBox(height: 10),
            Text(
              'Failed to load categories',
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadCategories,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.purple),
              child: Text(
                'Retry',
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
