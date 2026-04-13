import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_text_styles.dart';
import '../../core/design/app_radius.dart';
import '../../core/localization/localization_helper.dart';
import '../../services/exams_service.dart';

/// My Exams Screen - Pixel-perfect match to React version
/// Matches: components/screens/my-exams-screen.tsx
class MyExamsScreen extends StatefulWidget {
  const MyExamsScreen({super.key});

  @override
  State<MyExamsScreen> createState() => _MyExamsScreenState();
}

class _MyExamsScreenState extends State<MyExamsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _completedExams = [];

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() => _isLoading = true);
    try {
      final response = await ExamsService.instance.getMyExams();

      if (kDebugMode) {
        print('✅ Exams loaded: ${response['completed']?.length ?? 0}');
      }

      setState(() {
        if (response['completed'] is List) {
          _completedExams = List<Map<String, dynamic>>.from(
            response['completed'] as List,
          );
        } else {
          _completedExams = [];
        }
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading exams: $e');
      }
      setState(() {
        _completedExams = [];
        _isLoading = false;
      });
    }
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

  // Static fallback data

  @override
  Widget build(BuildContext context) {
    final passedCount = _completedExams
        .where((e) => e['is_passed'] == true || e['passed'] == true)
        .length;
    final failedCount = _completedExams
        .where((e) => e['is_passed'] != true && e['passed'] != true)
        .length;

    return Scaffold(
      backgroundColor: AppColors.beige,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header - matches React: bg-[var(--orange)] rounded-b-[3rem] pt-4 pb-8 px-4
            Container(
              decoration: const BoxDecoration(
                color: AppColors.orange, // Orange header!
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
                        context.l10n.myExams,
                        style: AppTextStyles.h2(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16), // mb-4
                  Text(
                    context.l10n.viewAllCompletedExams,
                    style: AppTextStyles.bodyMedium(
                      color: Colors.white.withOpacity(0.7), // white/70
                    ),
                  ),
                ],
              ),
            ),

            // Content - matches React: px-4 -mt-6 mb-6 then space-y-4
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -24), // -mt-6
                child: _isLoading
                    ? _buildLoadingState()
                    : _completedExams.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadExams,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16), // px-4
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                children: [
                                  // Stats Card - matches React: bg-white rounded-3xl p-5 shadow-lg grid grid-cols-3
                                  Container(
                                    margin: const EdgeInsets.only(
                                        bottom: 24), // mb-6
                                    padding: const EdgeInsets.all(20), // p-5
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(
                                          24), // rounded-3xl
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // Total exams
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Text(
                                                '${_completedExams.length}',
                                                style: AppTextStyles.h2(
                                                  color: AppColors.purple,
                                                ),
                                              ),
                                              Text(
                                                context.l10n.totalExams,
                                                style: AppTextStyles.labelSmall(
                                                  color:
                                                      AppColors.mutedForeground,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Passed
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Text(
                                                '$passedCount',
                                                style: AppTextStyles.h2(
                                                  color: Colors.green,
                                                ),
                                              ),
                                              Text(
                                                context.l10n.passed,
                                                style: AppTextStyles.labelSmall(
                                                  color:
                                                      AppColors.mutedForeground,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Failed
                                        Expanded(
                                          child: Column(
                                            children: [
                                              Text(
                                                '$failedCount',
                                                style: AppTextStyles.h2(
                                                  color: Colors.red,
                                                ),
                                              ),
                                              Text(
                                                context.l10n.failed,
                                                style: AppTextStyles.labelSmall(
                                                  color:
                                                      AppColors.mutedForeground,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Exams List - matches React: space-y-4
                                  ..._completedExams
                                      .map((exam) => _buildExamCard(context, exam)),

                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamCard(BuildContext context, Map<String, dynamic> exam) {
    final passed = exam['is_passed'] == true || exam['passed'] == true;
    final score = (exam['score'] as num?)?.toInt() ??
        (exam['best_score'] as num?)?.toInt() ??
        0;
    final totalQuestions = exam['total_questions'] as int? ??
        exam['questions_count'] as int? ??
        exam['totalQuestions'] as int? ??
        0;
    final correctAnswers =
        exam['correct_answers'] as int? ?? exam['correctAnswers'] as int? ?? 0;
    final examTitle = exam['title']?.toString() ?? context.l10n.exam;
    final completedAt = exam['completed_at']?.toString() ??
        exam['submitted_at']?.toString() ??
        exam['date']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16), // space-y-4
      padding: const EdgeInsets.all(20), // p-5
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24), // rounded-3xl
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row - matches React: flex items-start gap-4
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status icon - matches React: w-14 h-14 rounded-2xl
              Container(
                width: 56, // w-14
                height: 56, // h-14
                decoration: BoxDecoration(
                  color: passed ? Colors.green[100] : Colors.red[100],
                  borderRadius: BorderRadius.circular(16), // rounded-2xl
                ),
                child: Icon(
                  passed ? Icons.check_circle : Icons.cancel,
                  size: 28, // w-7 h-7
                  color: passed ? Colors.green[600] : Colors.red[600],
                ),
              ),
              const SizedBox(width: 16), // gap-4
              // Exam info - matches React: flex-1
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      examTitle,
                      style: AppTextStyles.bodyMedium(
                        color: AppColors.foreground,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4), // mb-1
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 16, // w-4 h-4
                          color: AppColors.mutedForeground,
                        ),
                        const SizedBox(width: 8), // gap-2
                        Text(
                          _formatDate(context, completedAt),
                          style: AppTextStyles.bodySmall(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Score - matches React: text-left
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$score%',
                    style: AppTextStyles.h2(
                      color: passed ? Colors.green[600] : Colors.red[600],
                    ),
                  ),
                  Text(
                    '$correctAnswers/$totalQuestions',
                    style: AppTextStyles.labelSmall(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16), // mt-4

          // Progress bar - matches React: h-2 bg-gray-100 rounded-full
          Container(
            height: 8, // h-2
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(999), // rounded-full
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerRight,
              widthFactor: score / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: passed ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12), // mt-3

          // Status badge - matches React: flex justify-end
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12, // px-3
                vertical: 4, // py-1
              ),
              decoration: BoxDecoration(
                color: passed ? Colors.green[100] : Colors.red[100],
                borderRadius: BorderRadius.circular(999), // rounded-full
              ),
              child: Text(
                passed ? context.l10n.passed : context.l10n.failed,
                style: AppTextStyles.labelSmall(
                  color: passed ? Colors.green[700] : Colors.red[700],
                ).copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Skeletonizer(
      enabled: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          height: 24,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
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
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          height: 24,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
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
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          height: 24,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
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
                  ),
                ],
              ),
            ),
            ...List.generate(3, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 16,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 12,
                                width: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 24,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 32),
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
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.quiz_rounded,
              size: 60,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.noCompletedExams,
            style: AppTextStyles.h2(
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.startCompletingExams,
            style: AppTextStyles.bodyMedium(
              color: AppColors.mutedForeground,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
