import 'lesson_question.dart';
import 'lesson_question_attempt_result.dart';

class LessonQuestionBankStudentPayload {
  final String lessonId;
  final List<LessonQuestion> questions;
  final int attemptsCount;
  final double bestScore;
  final LessonQuestionAttemptResult? latestAttempt;

  const LessonQuestionBankStudentPayload({
    required this.lessonId,
    required this.questions,
    required this.attemptsCount,
    required this.bestScore,
    this.latestAttempt,
  });

  factory LessonQuestionBankStudentPayload.fromJson(Map<String, dynamic> json) {
    final questionsRaw = json['questions'];
    final questions = questionsRaw is List
        ? questionsRaw
            .whereType<Map>()
            .map((e) => LessonQuestion.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <LessonQuestion>[];

    final stats = json['stats'] is Map
        ? Map<String, dynamic>.from(json['stats'] as Map)
        : const <String, dynamic>{};
    final latestRaw = stats['latestAttempt'];

    return LessonQuestionBankStudentPayload(
      lessonId: (json['lessonId'] ?? json['lesson_id'] ?? '').toString(),
      questions: questions,
      attemptsCount: _asInt(stats['attemptsCount'] ?? stats['attempts_count']) ?? 0,
      bestScore: _asDouble(stats['bestScore'] ?? stats['best_score']) ?? 0,
      latestAttempt: latestRaw is Map
          ? LessonQuestionAttemptResult.fromJson(
              Map<String, dynamic>.from(latestRaw),
            )
          : null,
    );
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
