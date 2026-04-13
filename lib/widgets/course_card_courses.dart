import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../core/design/app_colors.dart';
import '../core/design/app_text_styles.dart';
import '../core/design/app_radius.dart';

/// Course Card for Courses Screen - Pixel-perfect match to React version
/// Matches: components/ui/course-card.tsx
class CourseCardCourses extends StatelessWidget {
  final String category;
  final String title;
  final int participants;
  final String? icon;
  final String variant; // "dark" or "light"
  final VoidCallback? onTap;

  const CourseCardCourses({
    super.key,
    required this.category,
    required this.title,
    required this.participants,
    this.icon,
    this.variant = 'dark',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = variant == 'dark';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20), // p-5
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lavenderLight,
          borderRadius: BorderRadius.circular(24), // rounded-3xl
        ),
        child: Stack(
          children: [
            // Decorative curves - matches React (only for dark variant)
            if (isDark)
              Positioned.fill(
                child: CustomPaint(
                  painter: _CurvesPainter(),
                ),
              ),

            // Content
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon - matches React: text-2xl mb-2
                      if (icon != null) ...[
                        Text(
                          icon!,
                          style: const TextStyle(fontSize: 24), // text-2xl
                        ),
                        const SizedBox(height: 8), // mb-2
                      ],

                      // Category - matches React: text-xs font-medium mb-1
                      Text(
                        category,
                        style: AppTextStyles.labelSmall(
                          color: isDark ? AppColors.orange : AppColors.purple,
                        ),
                      ),
                      const SizedBox(height: 4), // mb-1

                      // Title - matches React: font-bold text-lg mb-4
                      Text(
                        title,
                        style: AppTextStyles.h4(
                          color: isDark ? Colors.white : AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 16), // mb-4

                      // Participants - matches React: gap-2
                      Row(
                        children: [
                          // Avatars - matches React: -space-x-2
                          Stack(
                            clipBehavior: Clip.none,
                            children: List.generate(3, (index) {
                              return Positioned(
                                right: index *
                                    24.0, // -space-x-2 = negative spacing
                                child: Container(
                                  width: 32, // w-8
                                  height: 32, // h-8
                                  decoration: BoxDecoration(
                                    color: AppColors.orangeLight,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/avatar-person.png',
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                        color: AppColors.orangeLight,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(width: 8), // gap-2
                          Text(
                            '+$participants',
                            style: AppTextStyles.bodySmall(
                              color: isDark
                                  ? Colors.white.withOpacity(0.7)
                                  : AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Button - matches React: w-12 h-12 rounded-full
                Container(
                  width: 48, // w-12
                  height: 48, // h-12
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.orange : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chevron_left,
                    size: 20, // w-5 h-5
                    color: isDark ? Colors.white : AppColors.foreground,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for decorative curves
class _CurvesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final paint2 = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.5);
    path1.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.25,
      size.width * 0.5,
      size.height * 0.5,
    );
    path1.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.75,
      size.width,
      size.height * 0.5,
    );

    final path2 = Path();
    path2.moveTo(0, size.height * 0.65);
    path2.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.4,
      size.width * 0.5,
      size.height * 0.65,
    );
    path2.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.9,
      size.width,
      size.height * 0.65,
    );

    canvas.drawPath(path1, paint);
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
