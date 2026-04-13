import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_radius.dart';

/// Exams Screen - Modern Interactive Exam Interface
class ExamsScreen extends StatefulWidget {
  final Map<String, dynamic>? examData;

  const ExamsScreen({super.key, this.examData});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen>
    with TickerProviderStateMixin {
  bool _examStarted = false;
  int _currentQuestion = 0;
  List<int?> _selectedAnswers = [];
  bool _submitted = false;
  late AnimationController _pulseController;

  final _examQuestions = [
    {
      'id': 1,
      'question': 'ما هو العنصر الأساسي في تصميم واجهات المستخدم؟',
      'options': ['الألوان فقط', 'تجربة المستخدم', 'الصور فقط', 'النصوص فقط'],
      'correctAnswer': 1,
    },
    {
      'id': 2,
      'question': 'ما هي أفضل طريقة لتحسين تجربة المستخدم؟',
      'options': [
        'إضافة المزيد من الألوان',
        'تبسيط التصميم',
        'استخدام خطوط صغيرة',
        'إخفاء القوائم'
      ],
      'correctAnswer': 1,
    },
    {
      'id': 3,
      'question': 'ما هو مبدأ التباين في التصميم؟',
      'options': [
        'استخدام لون واحد',
        'الفرق بين العناصر',
        'تصغير النصوص',
        'إزالة الصور'
      ],
      'correctAnswer': 1,
    },
    {
      'id': 4,
      'question': 'ما هي أفضل ممارسة للتصميم المتجاوب؟',
      'options': [
        'تصميم واحد لكل الأجهزة',
        'استخدام تصميم مرن',
        'تجاهل الهواتف',
        'تصميم للحاسوب فقط'
      ],
      'correctAnswer': 1,
    },
    {
      'id': 5,
      'question': 'ما هو الهدف من اختبار المستخدم؟',
      'options': [
        'إرضاء المصمم',
        'تحسين المنتج',
        'زيادة التكلفة',
        'إطالة الوقت'
      ],
      'correctAnswer': 1,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedAnswers = List.filled(_examQuestions.length, null);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  double get _progress =>
      ((_currentQuestion + 1) / _examQuestions.length) * 100;

  int get _correctCount {
    int count = 0;
    for (int i = 0; i < _examQuestions.length; i++) {
      if (_selectedAnswers[i] == _examQuestions[i]['correctAnswer']) {
        count++;
      }
    }
    return count;
  }

  double get _scorePercentage => (_correctCount / _examQuestions.length) * 100;

  void _handleSelectAnswer(int answerIndex) {
    if (_submitted) return;
    setState(() {
      _selectedAnswers[_currentQuestion] = answerIndex;
    });
  }

  void _handleNext() {
    if (_currentQuestion < _examQuestions.length - 1) {
      setState(() => _currentQuestion++);
    }
  }

  void _handlePrev() {
    if (_currentQuestion > 0) {
      setState(() => _currentQuestion--);
    }
  }

  void _handleSubmit() {
    if (_selectedAnswers.every((a) => a != null)) {
      setState(() => _submitted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_examStarted) {
      return _buildStartScreen();
    }

    if (_submitted) {
      return _buildResultScreen();
    }

    return _buildExamScreen();
  }

  Widget _buildStartScreen() {
    return Scaffold(
      backgroundColor: AppColors.beige,
      body: Stack(
        children: [
          // Background Gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0C52B3), Color(0xFF093F8A)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'الاختبار',
                        style: GoogleFonts.cairo(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Exam Card
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Animated Icon
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1 + (_pulseController.value * 0.1),
                              child: child,
                            );
                          },
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0C52B3), Color(0xFF093F8A)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.purple.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.quiz_rounded,
                                color: Colors.white, size: 48),
                          ),
                        ),
                        const SizedBox(height: 28),

                        Text(
                          'اختبار الكورس',
                          style: GoogleFonts.cairo(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'اختبر معلوماتك في هذا الكورس وتأكد من استيعابك للمفاهيم الأساسية',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: AppColors.mutedForeground,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),

                        // Stats
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FC),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(Icons.help_outline_rounded,
                                  '${_examQuestions.length}', 'سؤال'),
                              Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.grey[200]),
                              _buildStatItem(
                                  Icons.timer_outlined, '15', 'دقيقة'),
                              Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.grey[200]),
                              _buildStatItem(Icons.check_circle_outline_rounded,
                                  '60%', 'للنجاح'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Start Button
                        GestureDetector(
                          onTap: () => setState(() => _examStarted = true),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0C52B3), Color(0xFF093F8A)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.purple.withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 26),
                                const SizedBox(width: 10),
                                Text(
                                  'ابدأ الاختبار',
                                  style: GoogleFonts.cairo(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.purple, size: 24),
        const SizedBox(height: 8),
        Text(value,
            style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.foreground)),
        Text(label,
            style: GoogleFonts.cairo(
                fontSize: 12, color: AppColors.mutedForeground)),
      ],
    );
  }

  Widget _buildExamScreen() {
    final question = _examQuestions[_currentQuestion];
    final selectedAnswer = _selectedAnswers[_currentQuestion];

    return Scaffold(
      backgroundColor: AppColors.beige,
      body: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
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
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 28,
              left: 20,
              right: 20,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'السؤال ${_currentQuestion + 1} من ${_examQuestions.length}',
                        style: GoogleFonts.cairo(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text('14:30',
                              style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Progress
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerRight,
                    widthFactor: _progress / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

                // Question Dots
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_examQuestions.length, (index) {
                    final isAnswered = _selectedAnswers[index] != null;
                    final isCurrent = index == _currentQuestion;
                    return Container(
                      width: isCurrent ? 28 : 10,
                      height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? Colors.white
                            : isAnswered
                                ? Colors.white.withOpacity(0.8)
                                : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // Question & Options
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Question Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      question['question'] as String,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.foreground,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Options
                  ...(question['options'] as List).asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value as String;
                    final isSelected = selectedAnswer == index;

                    return GestureDetector(
                      onTap: () => _handleSelectAnswer(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.purple.withOpacity(0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.purple
                                : Colors.grey[200]!,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.purple.withOpacity(0.1),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.purple
                                    : Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 18)
                                  : Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: GoogleFonts.cairo(
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                option,
                                style: GoogleFonts.cairo(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.purple
                                      : AppColors.foreground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Navigation
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              top: 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentQuestion > 0)
                  Expanded(
                    child: GestureDetector(
                      onTap: _handlePrev,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            'السابق',
                            style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.foreground),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_currentQuestion > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _currentQuestion == _examQuestions.length - 1
                        ? _handleSubmit
                        : _handleNext,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _currentQuestion == _examQuestions.length - 1
                              ? [
                                  const Color(0xFF10B981),
                                  const Color(0xFF059669)
                                ]
                              : [
                                  const Color(0xFF0C52B3),
                                  const Color(0xFF093F8A)
                                ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_currentQuestion == _examQuestions.length - 1
                                        ? Colors.green
                                        : AppColors.purple)
                                    .withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _currentQuestion == _examQuestions.length - 1
                              ? 'إنهاء الاختبار'
                              : 'التالي',
                          style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    final passed = _scorePercentage >= 60;

    return Scaffold(
      backgroundColor: AppColors.beige,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Result Icon
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: passed
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (passed ? Colors.green : Colors.red).withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  passed
                      ? Icons.celebration_rounded
                      : Icons.sentiment_dissatisfied_rounded,
                  color: Colors.white,
                  size: 70,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                passed ? 'تهانينا! 🎉' : 'حاول مرة أخرى',
                style: GoogleFonts.cairo(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                passed
                    ? 'لقد اجتزت الاختبار بنجاح'
                    : 'لم تحقق الحد الأدنى للنجاح',
                style: GoogleFonts.cairo(
                    fontSize: 16, color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 40),

              // Score Card
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '${_scorePercentage.round()}%',
                      style: GoogleFonts.cairo(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: passed ? Colors.green : Colors.red,
                      ),
                    ),
                    Text(
                      'النتيجة النهائية',
                      style: GoogleFonts.cairo(
                          fontSize: 16, color: AppColors.mutedForeground),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildResultStat(
                            'الإجابات الصحيحة', '$_correctCount', Colors.green),
                        Container(
                            width: 1, height: 50, color: Colors.grey[200]),
                        _buildResultStat(
                            'الإجابات الخاطئة',
                            '${_examQuestions.length - _correctCount}',
                            Colors.red),
                        Container(
                            width: 1, height: 50, color: Colors.grey[200]),
                        _buildResultStat('إجمالي الأسئلة',
                            '${_examQuestions.length}', AppColors.purple),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Actions
              GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0C52B3), Color(0xFF093F8A)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.purple.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'العودة للدورة',
                      style: GoogleFonts.cairo(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (!passed) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _examStarted = true;
                      _submitted = false;
                      _currentQuestion = 0;
                      _selectedAnswers =
                          List.filled(_examQuestions.length, null);
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Center(
                      child: Text(
                        'إعادة الاختبار',
                        style: GoogleFonts.cairo(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.foreground),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.cairo(
              fontSize: 28, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style:
              GoogleFonts.cairo(fontSize: 11, color: AppColors.mutedForeground),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
