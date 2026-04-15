import 'dart:developer';

import 'package:educational_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../services/push_inbox_service.dart';

/// Top-level: required by [FirebaseMessaging.onBackgroundMessage].
/// Runs in a separate isolate when the app is backgrounded or terminated
/// (for data messages / combined payloads per platform rules).
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
  log('Background FCM: ${message.messageId}');
  await FirebaseNotification.ensureLocalNotificationsForIsolate();
  await PushInboxService.instance.addFromRemoteMessage(message);
  await FirebaseNotification.showBasicNotification(message);
}

class FirebaseNotification {
  static final FirebaseMessaging messaging = FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static String? fcmToken;

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Course updates, exams, and system messages.',
    importance: Importance.high,
  );

  /// Call from background isolate only — initializes the local notifications plugin.
  static Future<void> ensureLocalNotificationsForIsolate() async {
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await flutterLocalNotificationsPlugin.initialize(init);
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> initializeNotifications() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
    }

    await requestNotificationPermission();
    await getFcmToken();
    await initializeLocalNotifications();

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      log('Foreground FCM: ${message.messageId}');
      await PushInboxService.instance.addFromRemoteMessage(message);
      await showBasicNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      log('Opened from notification: ${message.messageId}');
      await PushInboxService.instance.addFromRemoteMessage(message);
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      log('Cold start from notification: ${initial.messageId}');
      await PushInboxService.instance.addFromRemoteMessage(initial);
    }
  }

  static Future<void> initializeLocalNotifications() async {
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await flutterLocalNotificationsPlugin.initialize(init);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> requestNotificationPermission() async {
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    log('FCM permission: ${settings.authorizationStatus}');
  }

  static Future<void> getFcmToken() async {
    try {
      fcmToken = await messaging.getToken();
      log('FCM token: $fcmToken');
      messaging.onTokenRefresh.listen((String newToken) {
        fcmToken = newToken;
        log('FCM token refreshed');
      });
    } catch (e) {
      log('FCM token error: $e');
    }
  }

  static int _notificationId(RemoteMessage message) {
    final mid = message.messageId;
    if (mid != null && mid.isNotEmpty) {
      return mid.hashCode & 0x7fffffff;
    }
    final t = message.sentTime?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;
    return t & 0x7fffffff;
  }

  static (String title, String body) _titleBody(RemoteMessage message) {
    final n = message.notification;
    var title = (n?.title ??
            message.data['title'] ??
            message.data['subject'] ??
            '')
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

  static Future<void> showBasicNotification(RemoteMessage message) async {
    try {
      final (title, body) = _titleBody(message);
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await flutterLocalNotificationsPlugin.show(
        _notificationId(message),
        title,
        body.isEmpty ? ' ' : body,
        details,
      );
      log('Local notification shown');
    } catch (e) {
      log('Local notification error: $e');
    }
  }
}
