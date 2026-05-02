import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/course_pricing.dart';
import '../core/design/app_colors.dart';
import '../l10n/app_localizations.dart';

/// Premium Course Card - Modern and Attractive Design
class PremiumCourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback onTap;

  const PremiumCourseCard({
    super.key,
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final isFree = courseIsEffectivelyFree(course);
    final hasPricePlans = courseHasSubscriptionPlans(course);
    final hidePriceBadge = courseHasPlansWithZeroBasePrice(course);
    final imagePath = course['thumbnail'] ?? course['image'] ?? '';
    final categoryName = courseCategoryEnglishLabel(course['category']);
    final title = course['title'] ?? '';
    final instructorName = course['instructor'] is Map
        ? (course['instructor']?['name'] ?? '')
        : (course['instructor'] ?? '');
    final rating = courseCardRatingNum(course);
    final hours = courseCardDurationHoursNum(course) ?? 0;
    final lessons = course['lessons_count'] ?? course['lessons'] ?? 0;
    final fallbackAmount = courseCardDisplayAmount(course) ??
        tryParseCourseNum(course['price']) ??
        0;
    final currencyCode =
        course['currency']?.toString().toUpperCase() ?? 'EGP';
    final backendFinalPrice = tryParseCourseNum(course['price']);
    final backendOriginalPrice = tryParseCourseNum(course['original_price']);
    final backendDiscountPrice = tryParseCourseNum(course['discount_price']);
    final hasBackendDiscount = backendDiscountPrice != null &&
        backendOriginalPrice != null &&
        backendDiscountPrice > 0 &&
        backendOriginalPrice > backendDiscountPrice;
    final discountedCurrentPriceText = hasBackendDiscount
        ? formatSingleCurrencyPrice(
            currency: currencyCode == 'USD' ? 'USD' : 'EGP',
            amount: backendDiscountPrice,
          )
        : null;
    final discountedOriginalPriceText = hasBackendDiscount
        ? formatSingleCurrencyPrice(
            currency: currencyCode == 'USD' ? 'USD' : 'EGP',
            amount: backendOriginalPrice,
          )
        : null;
    final paidPriceLabel = () {
      if (backendFinalPrice != null && backendFinalPrice > 0) {
        return formatSingleCurrencyPrice(
          currency: currencyCode == 'USD' ? 'USD' : 'EGP',
          amount: backendFinalPrice,
        );
      }
      final compact = formatCoursePriceCompact(course);
      if (compact != null && compact.isNotEmpty) return compact;
      if (fallbackAmount > 0) {
        return formatSingleCurrencyPrice(
          currency: currencyCode == 'USD' ? 'USD' : 'EGP',
          amount: fallbackAmount,
        );
      }
      return '';
    }();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with overlay
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Stack(
                    children: [
                      Container(
                        height: 130,
                        width: double.infinity,
                        color: AppColors.purple.withOpacity(0.1),
                        child: imagePath.toString().isNotEmpty
                            ? (imagePath.toString().startsWith('http') || imagePath.toString().startsWith('https')
                                ? Image.network(
                                    imagePath.toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: AppColors.purple.withOpacity(0.1),
                                      child: const Icon(Icons.image, color: AppColors.purple, size: 40),
                                    ),
                                  )
                                : Image.asset(
                                    imagePath.toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: AppColors.purple.withOpacity(0.1),
                                      child: const Icon(Icons.image, color: AppColors.purple, size: 40),
                                    ),
                                  ))
                            : Container(
                                color: AppColors.purple.withOpacity(0.1),
                                child: const Icon(Icons.image, color: AppColors.purple, size: 40),
                              ),
                      ),
                      Container(
                        height: 130,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Category Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          categoryName.toString(),
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Price/Free Badge
                if (!hidePriceBadge)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: isFree
                            ? const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)])
                            : const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: ((isFree
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B)))
                                .withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        isFree ? l10n.free : paidPriceLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                if (hasPricePlans)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C52B3).withOpacity(0.92),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sell_rounded,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            isAr ? 'يوجد خطط أسعار' : 'Plans available',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Play button overlay
                Positioned(
                  bottom: -20,
                  left: 16,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0C52B3), Color(0xFF093F8A)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.purple.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 28, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toString(),
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.foreground,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  if (hasBackendDiscount) ...[
                    Row(
                      children: [
                        Text(
                          discountedOriginalPriceText!,
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: AppColors.mutedForeground,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          discountedCurrentPriceText!,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFEA580C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Instructor
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.purple.withOpacity(0.1),
                        ),
                        child: const Icon(Icons.person, size: 14, color: AppColors.purple),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        instructorName.toString(),
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Stats Row
                  Row(
                    children: [
                      // Rating
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                            const SizedBox(width: 3),
                            Text(
                              rating.toStringAsFixed(1),
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Hours
                      Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 3),
                      Text(
                        l10n.hoursUnitShort(hours),
                        style: GoogleFonts.cairo(fontSize: 11, color: AppColors.mutedForeground),
                      ),
                      const SizedBox(width: 8),
                      // Lessons
                      Icon(Icons.menu_book_rounded, size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 3),
                      Text(
                        l10n.lessonsCount(
                          () {
                            if (lessons is int) return lessons;
                            if (lessons is num) return lessons.toInt();
                            return int.tryParse('$lessons') ?? 0;
                          }(),
                        ),
                        style: GoogleFonts.cairo(fontSize: 11, color: AppColors.mutedForeground),
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
  }
}
