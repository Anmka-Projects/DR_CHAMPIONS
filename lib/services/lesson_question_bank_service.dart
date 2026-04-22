import 'dart:io';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/lesson_question.dart';
import '../models/lesson_question_attempt_result.dart';
import '../models/lesson_question_bank_student_payload.dart';

class LessonQuestionBankService {
  LessonQuestionBankService._();

  static final LessonQuestionBankService instance = LessonQuestionBankService._();

  Future<LessonQuestionBankStudentPayload> getLessonQuestions(
      String lessonId) async {
    final response = await ApiClient.instance.get(
      ApiEndpoints.lessonQuestions(lessonId),
      requireAuth: true,
      logTag: 'LQ',
    );
    if (response['success'] != true || response['data'] == null) {
      throw Exception(response['message'] ?? 'Failed to fetch lesson questions');
    }
    final data = Map<String, dynamic>.from(response['data'] as Map);
    return LessonQuestionBankStudentPayload.fromJson(data);
  }

  Future<LessonQuestionAttemptResult> submitLessonAnswers(
    String lessonId,
    Map<String, dynamic> answersByQuestionId,
  ) async {
    final answers = answersByQuestionId.entries
        .map((e) => {
              'questionId': e.key,
              'answer': e.value,
            })
        .toList();

    final response = await ApiClient.instance.post(
      ApiEndpoints.submitLessonQuestions(lessonId),
      body: {
        'answers': answers,
      },
      requireAuth: true,
      logTag: 'LQ',
    );
    if (response['success'] != true || response['data'] == null) {
      throw Exception(response['message'] ?? 'Failed to submit answers');
    }
    return LessonQuestionAttemptResult.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  Future<List<LessonQuestion>> getAdminLessonQuestions(String lessonId) async {
    final response = await ApiClient.instance.get(
      ApiEndpoints.adminLessonQuestions(lessonId),
      requireAuth: true,
      logTag: 'LQ-ADMIN',
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to fetch admin questions');
    }

    dynamic raw = response['data'];
    if (raw is Map) {
      raw = raw['questions'] ?? raw['items'] ?? raw['data'];
    }
    if (raw is! List) return const <LessonQuestion>[];
    return raw
        .whereType<Map>()
        .map((e) => LessonQuestion.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> createAdminLessonQuestion(
    String lessonId, {
    required String text,
    required String type,
    required dynamic correctAnswer,
    List<String> options = const [],
    String? explanation,
    int points = 1,
    bool isActive = true,
  }) async {
    final response = await ApiClient.instance.post(
      ApiEndpoints.adminLessonQuestions(lessonId),
      requireAuth: true,
      logTag: 'LQ-ADMIN',
      body: {
        'text': text,
        'type': type,
        'options': options,
        'correctAnswer': correctAnswer,
        'explanation': explanation ?? '',
        'points': points,
        'isActive': isActive,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to create question');
    }
    return response;
  }

  Future<Map<String, dynamic>> updateAdminLessonQuestion(
    String questionId, {
    String? text,
    String? type,
    List<String>? options,
    dynamic correctAnswer,
    String? explanation,
    int? points,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{
      if (text != null) 'text': text,
      if (type != null) 'type': type,
      if (options != null) 'options': options,
      if (correctAnswer != null) 'correctAnswer': correctAnswer,
      if (explanation != null) 'explanation': explanation,
      if (points != null) 'points': points,
      if (isActive != null) 'isActive': isActive,
    };
    final response = await ApiClient.instance.put(
      ApiEndpoints.adminLessonQuestion(questionId),
      requireAuth: true,
      logTag: 'LQ-ADMIN',
      body: body,
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to update question');
    }
    return response;
  }

  Future<void> deleteAdminLessonQuestion(String questionId) async {
    final response = await ApiClient.instance.delete(
      ApiEndpoints.adminLessonQuestion(questionId),
      requireAuth: true,
      logTag: 'LQ-ADMIN',
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to delete question');
    }
  }

  Future<void> reorderAdminLessonQuestions(
    String lessonId,
    List<String> questionIds,
  ) async {
    final response = await ApiClient.instance.put(
      ApiEndpoints.reorderAdminLessonQuestions(lessonId),
      requireAuth: true,
      logTag: 'LQ-ADMIN',
      body: {'questionIds': questionIds},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to reorder questions');
    }
  }

  Future<Map<String, int>> getAdminCourseLessonQuestionCounts(
      String courseId) async {
    final response = await ApiClient.instance.get(
      ApiEndpoints.adminLessonQuestionCountsForCourse(courseId),
      requireAuth: true,
      logTag: 'LQ-ADMIN',
    );
    if (response['success'] != true || response['data'] == null) {
      throw Exception(response['message'] ?? 'Failed to fetch lesson counts');
    }
    final data = Map<String, dynamic>.from(response['data'] as Map);
    final out = <String, int>{};
    data.forEach((key, value) {
      final n = value is int ? value : int.tryParse(value.toString());
      if (n != null) out[key.toString()] = n;
    });
    return out;
  }

  Future<Map<String, dynamic>> importAdminLessonQuestionsXlsx(
    String lessonId,
    File file,
  ) async {
    final response = await ApiClient.instance.postMultipart(
      ApiEndpoints.importAdminLessonQuestionsXlsx(lessonId),
      fields: const <String, String>{},
      files: {'file': file},
      requireAuth: true,
      logTag: 'LQ-ADMIN',
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to import XLSX');
    }
    return response;
  }
}
