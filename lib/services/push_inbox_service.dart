import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists FCM messages locally so they appear on the in-app Notifications screen
/// (including when the payload never reaches the LMS API).
class PushInboxService {
  PushInboxService._();
  static final PushInboxService instance = PushInboxService._();

  static const String _storageKey = 'fcm_push_inbox_v1';
  static const int _maxItems = 150;

  static final StreamController<void> _changed =
      StreamController<void>.broadcast();

  /// Fires after the inbox is mutated (foreground / background / cold start).
  static Stream<void> get onInboxChanged => _changed.stream;

  Future<List<Map<String, dynamic>>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  String _stableId(RemoteMessage message) {
    final mid = message.messageId?.trim();
    if (mid != null && mid.isNotEmpty) return 'fcm_$mid';
    final b = StringBuffer()
      ..write(message.notification?.title ?? '')
      ..write('|')
      ..write(message.notification?.body ?? '')
      ..write('|')
      ..write(message.sentTime?.millisecondsSinceEpoch ?? 0)
      ..write('|')
      ..write(message.data.toString());
    return 'fcm_${b.toString().hashCode}';
  }

  (String title, String body) _titleBody(RemoteMessage message) {
    final n = message.notification;
    var title = (n?.title ?? message.data['title'] ?? message.data['subject'] ?? '')
        .toString()
        .trim();
    var body = (n?.body ??
            message.data['body'] ??
            message.data['message'] ??
            message.data['content'] ??
            '')
        .toString()
        .trim();
    if (title.isEmpty) title = 'Notification';
    return (title, body);
  }

  /// Idempotent per FCM message id / hash.
  Future<void> addFromRemoteMessage(RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final id = _stableId(message);
    var list = await getAll();
    if (list.any((e) => e['id']?.toString() == id)) return;

    final (title, body) = _titleBody(message);
    final createdAt = message.sentTime?.toUtc().toIso8601String() ??
        DateTime.now().toUtc().toIso8601String();

    list.insert(0, {
      'id': id,
      'title': title,
      'body': body,
      'message': body,
      'created_at': createdAt,
      'is_read': false,
      'source': 'fcm_local',
      'icon': 'campaign',
      'data': message.data.map((k, v) => MapEntry(k, v.toString())),
    });
    if (list.length > _maxItems) {
      list = list.sublist(0, _maxItems);
    }
    await prefs.setString(_storageKey, jsonEncode(list));
    _changed.add(null);
  }

  Future<void> markAsRead(String id) async {
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    var changed = false;
    for (final item in list) {
      if (item['id']?.toString() == id) {
        item['is_read'] = true;
        changed = true;
        break;
      }
    }
    if (changed) {
      await prefs.setString(_storageKey, jsonEncode(list));
      _changed.add(null);
    }
  }

  Future<void> markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getAll();
    for (final item in list) {
      item['is_read'] = true;
    }
    await prefs.setString(_storageKey, jsonEncode(list));
    _changed.add(null);
  }
}
