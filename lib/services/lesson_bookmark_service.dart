import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LessonBookmarkService {
  LessonBookmarkService._();
  static final LessonBookmarkService instance = LessonBookmarkService._();

  static const String _storageKey = 'bookmarked_lessons_v1';

  Future<List<Map<String, dynamic>>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => e.map(
                (key, value) => MapEntry(key.toString(), value),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> isBookmarked(String lessonId) async {
    if (lessonId.trim().isEmpty) return false;
    final bookmarks = await getBookmarks();
    return bookmarks.any((b) => b['lessonId']?.toString() == lessonId);
  }

  Future<bool> toggleBookmark(Map<String, dynamic> bookmark) async {
    final lessonId = bookmark['lessonId']?.toString() ?? '';
    if (lessonId.trim().isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final bookmarks = await getBookmarks();
    final idx = bookmarks.indexWhere((b) => b['lessonId']?.toString() == lessonId);

    bool isNowBookmarked;
    if (idx >= 0) {
      bookmarks.removeAt(idx);
      isNowBookmarked = false;
    } else {
      final payload = <String, dynamic>{
        ...bookmark,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      bookmarks.insert(0, payload);
      isNowBookmarked = true;
    }

    await prefs.setString(_storageKey, jsonEncode(bookmarks));
    return isNowBookmarked;
  }
}
