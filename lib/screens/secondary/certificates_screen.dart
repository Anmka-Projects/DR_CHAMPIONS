import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_text_styles.dart';
import '../../core/design/app_radius.dart';
import '../../core/localization/localization_helper.dart';
import '../../services/certificates_service.dart';
import '../../services/token_storage_service.dart';

/// Certificates Screen - Pixel-perfect match to React version
/// Matches: components/screens/certificates-screen.tsx
class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _certificates = [];

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  Future<void> _loadCertificates() async {
    if (kDebugMode) {
      print('🔄 CertificatesScreen: _loadCertificates() called');
    }
    setState(() => _isLoading = true);
    try {
      final response = await CertificatesService.instance.getCertificates();
      final parsedCertificates = _extractCertificates(response);

      if (kDebugMode) {
        print('✅ Certificates loaded: ${parsedCertificates.length}');
      }

      setState(() {
        _certificates = parsedCertificates;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading certificates: $e');
      }
      setState(() {
        _certificates = [];
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _extractCertificates(Map<String, dynamic> response) {
    final dynamic data = response['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map<String, dynamic>) {
      final dynamic nested = data['certificates'] ?? data['items'] ?? data['data'];
      if (nested is List) {
        return nested.whereType<Map<String, dynamic>>().toList();
      }
    }
    final dynamic root = response['certificates'] ?? response['items'];
    if (root is List) {
      return root.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  String _formatDate(BuildContext context, String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return context.l10n.undefinedDate;
    }
    try {
      final date = DateTime.parse(dateString);
      final months = [
        context.l10n.monthJanuary,
        context.l10n.monthFebruary,
        context.l10n.monthMarch,
        context.l10n.monthApril,
        context.l10n.monthMay,
        context.l10n.monthJune,
        context.l10n.monthJuly,
        context.l10n.monthAugust,
        context.l10n.monthSeptember,
        context.l10n.monthOctober,
        context.l10n.monthNovember,
        context.l10n.monthDecember,
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header - Purple gradient like Home
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0C52B3), Color(0xFF093F8A)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadius.largeCard),
                  bottomRight: Radius.circular(AppRadius.largeCard),
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16, // pt-4
                bottom: 32, // pb-8
                left: 16, // px-4
                right: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button and title - matches React: gap-4 mb-4
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 40, // w-10
                          height: 40, // h-10
                          decoration: const BoxDecoration(
                            color: AppColors.whiteOverlay20, // bg-white/20
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 20, // w-5 h-5
                          ),
                        ),
                      ),
                      const SizedBox(width: 16), // gap-4
                      Text(
                        context.l10n.certificates,
                        style: AppTextStyles.h3(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16), // mb-4
                  // Certificate count - matches React: gap-2
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 20, // w-5 h-5
                        color: Colors.white.withOpacity(0.7), // white/70
                      ),
                      const SizedBox(width: 8), // gap-2
                      Text(
                        context.l10n.achievedCertificates(_certificates.length),
                        style: AppTextStyles.bodyMedium(
                          color: Colors.white.withOpacity(0.7), // white/70
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content - matches React: px-4 -mt-4 space-y-4
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -16), // -mt-4
                child: _isLoading
                    ? _buildLoadingState()
                    : _certificates.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadCertificates,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _certificates.length,
                              itemBuilder: (context, index) {
                                final cert = _certificates[index];
                                return TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: Duration(
                                      milliseconds: 500 + (index * 100)),
                                  curve: Curves.easeOut,
                                  builder: (context, value, child) {
                                    return Transform.translate(
                                      offset: Offset(0, 20 * (1 - value)),
                                      child: Opacity(
                                        opacity: value,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _buildCertificateCard(context, cert),
                                );
                              },
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadCertificate(Map<String, dynamic> cert) async {
    final downloadUrl = _resolveCertificateUrl(cert['download_url']?.toString());
    if (downloadUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.downloadLinkNotAvailable,
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  context.l10n.downloading,
                  style: GoogleFonts.cairo(),
                ),
              ],
            ),
            backgroundColor: AppColors.purple,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      // Get download directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        // For Android 10+, use Downloads directory
        if (directory != null) {
          final downloadsPath = Directory('${directory.path}/../Download');
          if (await downloadsPath.exists()) {
            directory = downloadsPath;
          } else {
            try {
              await downloadsPath.create(recursive: true);
              directory = downloadsPath;
            } catch (e) {
              // Keep using the original directory if creation fails
            }
          }
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception(context.l10n.cannotAccessDownloads);
      }

      // Get file name from URL or use certificate number
      final certificateNumber =
          cert['certificate_number']?.toString() ?? 'certificate';
      final fileName = downloadUrl.split('/').last;
      final fileExtension =
          fileName.contains('.') ? fileName.split('.').last : 'pdf';
      final file = File('${directory.path}/$certificateNumber.$fileExtension');

      // Download file
      final token = await TokenStorageService.instance.getAccessToken();
      final authToken = (token ?? '').trim().toLowerCase().startsWith('bearer ')
          ? (token ?? '').trim().substring(7).trim()
          : (token ?? '').trim();
      final response = await http.get(
        Uri.parse(downloadUrl),
        headers: authToken.isNotEmpty
            ? {'Authorization': 'Bearer $authToken'}
            : {},
      );
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.downloadSuccessful(file.path),
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        throw Exception(context.l10n.downloadFailed(response.statusCode));
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error downloading certificate: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.errorDownloading(
                  e.toString().replaceFirst('Exception: ', '')),
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Widget _buildCertificateCard(
      BuildContext context, Map<String, dynamic> cert) {
    // Extract data from API
    final course = cert['course'] as Map<String, dynamic>?;
    final courseTitle = course?['title']?.toString() ??
        cert['course_title']?.toString() ??
        context.l10n.course;
    final studentName =
        cert['student_name']?.toString() ?? context.l10n.student;
    final issueDate = cert['issue_date']?.toString();
    final certificateNumber = cert['certificate_number']?.toString() ?? '';
    final grade = cert['grade']?.toString() ?? context.l10n.excellent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16), // space-y-4
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24), // rounded-3xl
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Certificate Preview - matches React: bg-gradient-to-bl p-6 border-b-2 border-dashed
          Container(
            padding: const EdgeInsets.all(24), // p-6
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  AppColors.purple.withOpacity(0.1),
                  AppColors.orange.withOpacity(0.1),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.purple.withOpacity(0.2),
                  width: 2,
                  style: BorderStyle
                      .solid, // Flutter doesn't have dashed, using solid
                ),
              ),
            ),
            child: Column(
              children: [
                // Award icon - matches React: w-16 h-16 rounded-full
                Container(
                  width: 64, // w-16
                  height: 64, // h-16
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [AppColors.orange, AppColors.purple],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    size: 32, // w-8 h-8
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16), // mb-4

                // Certificate title - matches React
                Text(
                  context.l10n.certificateOfCompletion,
                  style: AppTextStyles.h4(
                    color: AppColors.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4), // mb-1

                // Course name - matches React
                Text(
                  courseTitle,
                  style: AppTextStyles.bodyMedium(
                    color: AppColors.purple,
                  ).copyWith(fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12), // mb-3

                // "Certifies that" text
                Text(
                  context.l10n.certifiesThat,
                  style: AppTextStyles.bodySmall(
                    color: AppColors.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8), // my-2

                // Student name - matches React: text-xl font-bold
                Text(
                  studentName,
                  style: AppTextStyles.h3(
                    color: AppColors.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8), // my-2

                // "Has completed with grade" text
                Text(
                  context.l10n.hasCompletedWithGrade,
                  style: AppTextStyles.bodySmall(
                    color: AppColors.mutedForeground,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Grade - matches React: font-bold text-[var(--orange)] text-lg
                Text(
                  grade,
                  style: AppTextStyles.h4(
                    color: AppColors.orange,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Certificate Info - matches React: p-4
          Padding(
            padding: const EdgeInsets.all(16), // p-4
            child: Column(
              children: [
                // Date and ID row - matches React: mb-4
                Padding(
                  padding: const EdgeInsets.only(bottom: 16), // mb-4
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16, // w-4 h-4
                            color: AppColors.mutedForeground,
                          ),
                          const SizedBox(width: 8), // gap-2
                          Text(
                            _formatDate(context, issueDate),
                            style: AppTextStyles.bodySmall(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        certificateNumber.isNotEmpty
                            ? '#$certificateNumber'
                            : '',
                        style: AppTextStyles.labelSmall(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action buttons - matches React: flex gap-3
                Row(
                  children: [
                    // Preview button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openPreview(cert),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12), // py-3
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(12), // rounded-xl
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.remove_red_eye_rounded,
                                size: 20, // w-5 h-5
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8), // gap-2
                              Text(
                                Localizations.localeOf(context).languageCode == 'ar'
                                    ? 'Preview'
                                    : 'Preview',
                                style: AppTextStyles.bodyMedium(
                                  color: AppColors.primary,
                                ).copyWith(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12), // gap-3
                    // Download button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _downloadCertificate(cert),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12), // py-3
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius:
                                BorderRadius.circular(12), // rounded-xl
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.download,
                                size: 20, // w-5 h-5
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8), // gap-2
                              Text(
                                context.l10n.download,
                                style: AppTextStyles.bodyMedium(
                                  color: Colors.white,
                                ).copyWith(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
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
              width: 96, // w-24
              height: 96, // h-24
              decoration: const BoxDecoration(
                color: AppColors.lavenderLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events,
                size: 48, // w-12 h-12
                color: AppColors.purple,
              ),
            ),
            const SizedBox(height: 16), // mb-4
            Text(
              context.l10n.noCertificatesYet,
              style: AppTextStyles.h4(
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 8), // mb-2
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                context.l10n.completeCoursesForCertificates,
                style: AppTextStyles.bodyMedium(
                  color: AppColors.mutedForeground,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 400,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
          );
        },
      ),
    );
  }

  String _resolveCertificateUrl(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) {
      return '${ApiEndpoints.imageBaseUrl}$value';
    }
    return '${ApiEndpoints.imageBaseUrl}/$value';
  }

  Future<void> _openPreview(Map<String, dynamic> cert) async {
    final previewUrl = _resolveCertificateUrl(cert['preview_url']?.toString());
    if (previewUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'ar'
                ? 'Preview link not available'
                : 'Preview link not available',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    final uri = Uri.tryParse(previewUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
