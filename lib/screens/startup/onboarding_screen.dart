import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_text_styles.dart';
import '../../core/design/app_radius.dart';
import '../../core/navigation/route_names.dart';
import '../../l10n/app_localizations.dart';

/// Onboarding Screen - Pixel-perfect match to React version
/// Matches: components/screens/onboarding-screen.tsx
class OnboardingScreen extends StatelessWidget {
  final int step;

  const OnboardingScreen({
    super.key,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isStep1 = step == 1;
    final title = isStep1 ? l10n.learnEasily : l10n.continuousProgress;
    final subtitle = isStep1
        ? l10n.discoverBestCourses
        : l10n.trackProgressAndGetCertificates;
    final buttonText = isStep1 ? l10n.nextStep : l10n.startNow;

    return Scaffold(
      backgroundColor: AppColors.beige,
      body: SafeArea(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          margin: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width > 400
                ? (MediaQuery.of(context).size.width - 400) / 2
                : 0,
          ),
          child: Column(
            children: [
              // Illustration area
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Stack(
                      children: [
                        // Main illustration card
                        Container(
                          width: 256,
                          height: 256,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(48),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  color: (isStep1
                                          ? AppColors.purple
                                          : AppColors.orange)
                                      .withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isStep1 ? Icons.menu_book : Icons.emoji_events,
                                  size: 48,
                                  color: isStep1
                                      ? AppColors.purple
                                      : AppColors.orange,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: isStep1 ? 64 : 32,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: isStep1
                                          ? AppColors.orange
                                          : AppColors.purple.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: isStep1 ? 32 : 64,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: isStep1
                                          ? AppColors.purple.withOpacity(0.3)
                                          : AppColors.purple,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Floating decorations
                        Positioned(
                          top: -16,
                          right: -16,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.orange,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            transform: Matrix4.rotationZ(0.2),
                          ),
                        ),
                        Positioned(
                          bottom: -24,
                          left: -24,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.purple,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Content area
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.largeCard),
                    topRight: Radius.circular(AppRadius.largeCard),
                  ),
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    // Step indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 8,
                          decoration: BoxDecoration(
                            color: step == 1
                                ? AppColors.purple
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 32,
                          height: 8,
                          decoration: BoxDecoration(
                            color: step == 2
                                ? AppColors.purple
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Title
                    Text(
                      title,
                      style: AppTextStyles.h2(color: AppColors.foreground),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Subtitle
                    Text(
                      subtitle,
                      style: AppTextStyles.bodyMedium(
                        color: AppColors.mutedForeground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (isStep1) {
                            context.go(RouteNames.onboarding2);
                          } else {
                            // Mark onboarding as completed
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('hasLaunched', true);
                            if (kDebugMode) {
                              print('✅ Onboarding completed, hasLaunched set to true');
                            }
                            context.go(RouteNames.login);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              buttonText,
                              style: AppTextStyles.buttonLarge(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_back, size: 20),
                          ],
                        ),
                      ),
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
}


