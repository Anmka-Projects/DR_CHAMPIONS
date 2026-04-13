import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/design/app_colors.dart';
import '../../core/navigation/route_names.dart';
import '../../services/auth_service.dart';
import '../../l10n/app_localizations.dart';

/// Placeholder screen for instructor flow until API is ready.
/// Shows centered text notifying the user they are an instructor.
class InstructorPlaceholderScreen extends StatelessWidget {
  const InstructorPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.school_rounded,
                  size: 80,
                  color: AppColors.purple.withOpacity(0.8),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.instructor,
                  style: GoogleFonts.cairo(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.purple,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You are signed in as an instructor. Instructor features will be available when the API is ready.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                OutlinedButton.icon(
                  onPressed: () async {
                    await AuthService.instance.logout();
                    if (context.mounted) {
                      context.go(RouteNames.splash);
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: Text(l10n.logout, style: GoogleFonts.cairo()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
