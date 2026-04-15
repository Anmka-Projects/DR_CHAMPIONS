import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists last lesson per course, playback position, watched time, and
/// locally tracked completed lesson ids for offline-friendly course progress.
class LessonResumeService {
  LessonResumeService._();
  static final LessonResumeService instance = LessonResumeService._();

  static const String _storageKeyV2 = 'last_opened_lessons_by_course_v2';
  static const String _storageKeyV1 = 'last_opened_lessons_by_course_v1';

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  /// Saves resume state. Omit [positionMs] / indices / [watchedSeconds] when
  /// opening from the course screen: a new [lessonId] resets them; the same
  /// lesson keeps the previous stored values.
  Future<void> saveLastOpenedLesson({
    required String courseId,
    required String lessonId,
    String? lessonTitle,
    int? positionMs,
    int? videoIndex,
    int? audioIndex,
    int? watchedSeconds,
    String? markLessonCompletedId,
  }) async {
    if (courseId.trim().isEmpty || lessonId.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final map = _decodeMap(prefs.getString(_storageKeyV2));
    final prevRaw = map[courseId];
    Map<String, dynamic> prev = {};
    if (prevRaw is Map) {
      prev = Map<String, dynamic>.from(prevRaw);
    }

    final prevLessonId = prev['lessonId']?.toString();
    final sameLesson = prevLessonId == lessonId;

    final completed = <String>{};
    final cl = prev['completedLessonIds'];
    if (cl is List) {
      for (final x in cl) {
        final s = x?.toString();
        if (s != null && s.isNotEmpty) completed.add(s);
      }
    }
    if (markLessonCompletedId != null && markLessonCompletedId.isNotEmpty) {
      completed.add(markLessonCompletedId);
    }

    final resolvedPosition = positionMs ??
        (sameLesson ? (_asInt(prev['positionMs']) ?? 0) : 0);

    final resolvedVideo = videoIndex ??
        (sameLesson ? (_asInt(prev['videoIndex']) ?? 0) : 0);

    final resolvedAudio = audioIndex ??
        (sameLesson ? (_asInt(prev['audioIndex']) ?? 0) : 0);

    final resolvedWatched = watchedSeconds ??
        (sameLesson ? (_asInt(prev['watchedSeconds']) ?? 0) : 0);

    final title = (lessonTitle != null && lessonTitle.trim().isNotEmpty)
        ? lessonTitle.trim()
        : (prev['lessonTitle']?.toString() ?? '');

    map[courseId] = {
      'lessonId': lessonId,
      'lessonTitle': title,
      'updatedAt': DateTime.now().toIso8601String(),
      'positionMs': resolvedPosition < 0 ? 0 : resolvedPosition,
      'videoIndex': resolvedVideo < 0 ? 0 : resolvedVideo,
      'audioIndex': resolvedAudio < 0 ? 0 : resolvedAudio,
      'watchedSeconds': resolvedWatched < 0 ? 0 : resolvedWatched,
      'completedLessonIds': completed.toList(),
    };
    await prefs.setString(_storageKeyV2, jsonEncode(map));
  }

  Future<Map<String, dynamic>?> getLastOpenedLesson(String courseId) async {
    if (courseId.trim().isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final v2 = _decodeMap(prefs.getString(_storageKeyV2));
    final fromV2 = _normalizeEntry(v2[courseId]);
    if (fromV2 != null) return fromV2;

    final v1 = _decodeMap(prefs.getString(_storageKeyV1));
    return _normalizeEntry(v1[courseId]);
  }

  Map<String, dynamic>? _normalizeEntry(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  Map<String, dynamic> _decodeMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
