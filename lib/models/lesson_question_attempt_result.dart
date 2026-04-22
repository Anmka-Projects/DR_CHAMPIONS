class LessonQuestionAttemptResult {
  final String attemptId;
  final double score;
  final bool isPassed;
  final int totalQuestions;
  final int correctAnswers;
  final String? submittedAt;

  const LessonQuestionAttemptResult({
    required this.attemptId,
    required this.score,
    required this.isPassed,
    required this.totalQuestions,
    required this.correctAnswers,
    this.submittedAt,
  });

  factory LessonQuestionAttemptResult.fromJson(Map<String, dynamic> json) {
    return LessonQuestionAttemptResult(
      attemptId: (json['attemptId'] ?? json['id'] ?? '').toString(),
      score: _asDouble(json['score']) ?? 0,
      isPassed: _asBool(json['isPassed'] ?? json['is_passed']) ?? false,
      totalQuestions: _asInt(json['totalQuestions'] ?? json['total_questions']) ?? 0,
      correctAnswers:
          _asInt(json['correctAnswers'] ?? json['correct_answers']) ?? 0,
      submittedAt: json['submittedAt']?.toString() ??
          json['submitted_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attemptId': attemptId,
      'score': score,
      'isPassed': isPassed,
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      if (submittedAt != null) 'submittedAt': submittedAt,
    };
  }
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

bool? _asBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  final s = v.toString().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return null;
}
