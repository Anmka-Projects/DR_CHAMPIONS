import 'package:flutter/material.dart';
import '../core/design/app_colors.dart';
import '../core/design/app_text_styles.dart';
import '../core/design/app_radius.dart';
import '../core/design/app_shadows.dart';

/// Course Card Widget - Pixel-perfect match to React version
/// Matches: components/screens/home-screen.tsx featured courses
class CourseCard extends StatelessWidget {
  final String title;
  final String instructor;
  final double rating;
  final int hours;
  final double price;
  final String? imageUrl;
  final String? category;
  final VoidCallback? onTap;
  final bool isHorizontal;
  final bool? isFree;

  const CourseCard({
    super.key,
    required this.title,
    required this.instructor,
    required this.rating,
    required this.hours,
    required this.price,
    this.imageUrl,
    this.category,
    this.onTap,
    this.isHorizontal = false,
    this.isFree,
  });

  @override
  Widget build(BuildContext context) {
    if (isHorizontal) {
      return _buildRecommendedCard(context);
    }
    return _buildFeaturedCard(context);
  }

  // Featured Course Card - matches React: w-[280px] h-36 rounded-3xl
  Widget _buildFeaturedCard(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280, // w-[280px]
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24), // rounded-3xl
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05), // shadow-sm
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image - matches React: h-36
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Container(
                    height: 144, // h-36 = 144px
                    width: double.infinity,
                    color: AppColors.purple.withOpacity(0.1),
                    child: imageUrl != null
                        ? (imageUrl!.startsWith('assets/')
                            ? Image.asset(
                                imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildPlaceholder(),
                              )
                            : Image.network(
                                imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildPlaceholder(),
                              ))
                        : _buildPlaceholder(),
                  ),
                ),
                // Category badge - matches React: top-3 right-3 bg-white/90
                if (category != null)
                  Positioned(
                    top: 12, // top-3
                    right: 12, // right-3
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, // px-2
                        vertical: 4, // py-1
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9), // bg-white/90
                        borderRadius: BorderRadius.circular(8), // rounded-lg
                      ),
                      child: Text(
                        category!,
                        style: AppTextStyles.labelSmall(
                          color: AppColors.purple,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Content - matches React: p-4
            Padding(
              padding: const EdgeInsets.all(16), // p-4
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title - matches React: font-bold mb-2 line-clamp-1
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium(
                      color: AppColors.foreground,
                    ).copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8), // mb-2
                  // Instructor - matches React: text-sm mb-3
                  Text(
                    instructor,
                    style: AppTextStyles.bodySmall(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 12), // mb-3
                  // Rating and price - matches React: gap-3 text-xs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 12, // w-3 h-3
                            color: AppColors.orange,
                          ),
                          const SizedBox(width: 4), // gap-1
                          Text(
                            rating.toString(),
                            style: AppTextStyles.labelSmall(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          const SizedBox(width: 12), // gap-3
                          const Icon(
                            Icons.access_time,
                            size: 12, // w-3 h-3
                            color: AppColors.mutedForeground,
                          ),
                          const SizedBox(width: 4), // gap-1
                          Text(
                            '${hours}س',
                            style: AppTextStyles.labelSmall(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isFree == true
                            ? 'مجاني'
                            : '${price.toStringAsFixed(0)} جنيه',
                        style: AppTextStyles.bodyMedium(
                          color: isFree == true
                              ? AppColors.orange
                              : AppColors.purple,
                        ).copyWith(fontWeight: FontWeight.bold),
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

  // Recommended Course Card - matches React: grid-cols-2 h-24 rounded-2xl
  Widget _buildRecommendedCard(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16), // rounded-2xl
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05), // shadow-sm
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image - matches React: h-24
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Container(
                height: 96, // h-24 = 96px
                width: double.infinity,
                color: AppColors.purple.withOpacity(0.1),
                child: imageUrl != null
                    ? (imageUrl!.startsWith('assets/')
                        ? Image.asset(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(),
                          )
                        : Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(),
                          ))
                    : _buildPlaceholder(),
              ),
            ),
            // Content - matches React: p-3
            Padding(
              padding: const EdgeInsets.all(12), // p-3
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title - matches React: font-bold text-sm mb-1 line-clamp-1
                  Text(
                    title,
                    style: AppTextStyles.bodySmall(
                      color: AppColors.foreground,
                    ).copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4), // mb-1
                  // Instructor - matches React: text-xs mb-2
                  Text(
                    instructor,
                    style: AppTextStyles.labelSmall(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 8), // mb-2
                  // Rating and price - matches React: gap-1 text-xs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 12, // w-3 h-3
                            color: AppColors.orange,
                          ),
                          const SizedBox(width: 4), // gap-1
                          Text(
                            rating.toString(),
                            style: AppTextStyles.labelSmall(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isFree == true
                            ? 'مجاني'
                            : '${price.toStringAsFixed(0)} جنيه',
                        style: AppTextStyles.bodySmall(
                          color: isFree == true
                              ? AppColors.orange
                              : AppColors.purple,
                        ).copyWith(fontWeight: FontWeight.bold),
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

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.purple.withOpacity(0.1),
      child: const Icon(
        Icons.image,
        color: AppColors.purple,
        size: 40,
      ),
    );
  }
}
