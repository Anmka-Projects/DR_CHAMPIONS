// Import necessary libraries
import 'dart:developer'; // For logging and debugging
import 'dart:math'
    show Random; // For generating random numbers (show only Random class)
import 'package:firebase_core/firebase_core.dart'; // Firebase core functionality
import 'package:firebase_messaging/firebase_messaging.dart'; // Firebase Cloud Messaging
import 'package:educational_app/firebase_options.dart'; // Firebase options
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Local notifications plugin

// Main class for handling Firebase notifications
/// Top-level background handler required by firebase_messaging
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
  log('Background message received: ${message.messageId}');
  await FirebaseNotification.showBasicNotification(message);
}

class FirebaseNotification {
  // Firebase Messaging instance for handling FCM
  static final FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Local notifications plugin for showing notifications
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Variable to store the FCM token (device registration token)
  static String? fcmToken;

  // Android notification channel configuration (required for Android 8.0+)
  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // Channel ID (must be unique)
    'High Importance Notifications', // Channel name visible to user
    description:
        'This channel is used for important notifications.', // Channel description
    importance: Importance.high, // High importance for sound and alert
  );

  // Main initialization method for notifications
  static Future<void> initializeNotifications() async {
    // Ensure Firebase is initialized (defensive for any direct calls)
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
    }

    await requestNotificationPermission(); // Request user permission
    await getFcmToken(); // Get device FCM token
    await initializeLocalNotifications(); // Initialize local notifications
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Set up background message handler (when app is closed or in background)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Set up foreground message listener (when app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Received foreground message: ${message.messageId}'); // Log message receipt
      showBasicNotification(message); // Show local notification
    });
  }

  // Initialize local notifications plugin
  static Future<void> initializeLocalNotifications() async {
    // Configuration for initializing local notifications
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android:
          AndroidInitializationSettings('@mipmap/ic_launcher'), // Android icon
      iOS: DarwinInitializationSettings(), // iOS settings
    );

    // Initialize the local notifications plugin
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Create notification channel for Android (required for Android 8.0+)
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Request notification permissions from user
  static Future<void> requestNotificationPermission() async {
    final NotificationSettings settings = await messaging.requestPermission();
    log('Notification permission status: ${settings.authorizationStatus}'); // Log permission status
  }

  // Get and store the FCM token for this device
  static Future<void> getFcmToken() async {
    try {
      fcmToken = await messaging.getToken(); // Retrieve FCM token
      log('FCM Token: $fcmToken'); // Log the token for debugging

      // Listen for token refresh events (tokens can change)
      messaging.onTokenRefresh.listen((String newToken) {
        fcmToken = newToken; // Update stored token
        log('FCM Token refreshed: $newToken'); // Log token refresh
      });
    } catch (e) {
      log('Error getting FCM token: $e'); // Log any errors
    }
  }

  // Handle background messages (when app is closed or in background)
  // Random number generator for unique notification IDs
  static final Random random = Random();

  // Generate a random ID for notifications (prevents duplicate IDs)
  static int generateRandomId() {
    return random.nextInt(10000); // Generate random number between 0-9999
  }

  // Display a basic local notification
  static Future<void> showBasicNotification(RemoteMessage message) async {
    try {
      // Notification details configuration for both platforms
      final NotificationDetails details = NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id, // Use predefined channel ID
          channel.name, // Use predefined channel name
          channelDescription: channel.description, // Channel description
          importance: Importance.high, // High importance level
          priority: Priority.high, // High priority for notification
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, // Show alert on iOS
          presentBadge: true, // Update app badge on iOS
          presentSound: true, // Play sound on iOS
        ),
      );

      // Display the notification using local notifications plugin
      await flutterLocalNotificationsPlugin.show(
        generateRandomId(), // Unique ID for notification
        message.notification?.title ?? 'No Title', // Title (with fallback)
        message.notification?.body ?? 'No Body', // Body (with fallback)
        details, // Platform-specific details
      );

      log('Local notification shown successfully'); // Log success
    } catch (e) {
      log('Error showing local notification: $e'); // Log any errors
    }
  }
}
