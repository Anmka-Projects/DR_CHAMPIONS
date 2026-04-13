import 'package:flutter/material.dart';
import '../core/design/app_colors.dart';
import '../core/design/app_text_styles.dart';

/// Subject Chip Widget - Pixel-perfect match to React version
/// Matches: components/ui/subject-chip.tsx
class SubjectChip extends StatelessWidget {
  final String icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const SubjectChip({
    super.key,
    required this.icon,
    required this.label,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16, // px-4
          vertical: 8, // py-2
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.dark : Colors.white,
          borderRadius: BorderRadius.circular(999), // rounded-full
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 8), // gap-2
            Text(
              label,
              style: AppTextStyles.bodySmall(
                color: isActive ? Colors.white : AppColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


