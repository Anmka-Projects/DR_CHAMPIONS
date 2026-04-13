import 'dart:developer';
import 'package:educational_app/core/notification_service/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:screen_protector/screen_protector.dart';
import 'core/design/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'core/config/app_config_provider.dart';
import 'core/config/theme_provider.dart';
import 'l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }
  await FirebaseNotification.initializeNotifications();
  log('FCM Token: ${FirebaseNotification.fcmToken}');

  // Initialize screen protection (prevent screenshots and screen recording)
  try {
    await ScreenProtector.protectDataLeakageOn();
    await ScreenProtector.preventScreenshotOn();
  } catch (e) {
    // Log error but don't prevent app from running
    debugPrint('Screen protection initialization error: $e');
  }

  // Initialize app config provider
  final configProvider = AppConfigProvider();
  await configProvider.initialize();

  // Initialize theme provider (singleton) and load preferences
  final themeProvider = ThemeProvider.instance;
  await themeProvider.ensureInitialized();

  runApp(EducationalApp(
    configProvider: configProvider,
    themeProvider: themeProvider,
  ));
}

class EducationalApp extends StatelessWidget {
  final AppConfigProvider configProvider;
  final ThemeProvider themeProvider;

  const EducationalApp({
    super.key,
    required this.configProvider,
    required this.themeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: configProvider,
      builder: (context, _) {
        return ListenableBuilder(
          listenable: themeProvider,
          builder: (context, _) {
            return MaterialApp.router(
              title: configProvider.config?.appName ?? 'Dr Champions Academy',
              debugShowCheckedModeBanner: false,

              // RTL & Localization
              locale: themeProvider.locale,
              supportedLocales: const [
                Locale('ar'),
                Locale('en'),
              ],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],

              // Theme - use API config if available
              theme: AppTheme.lightTheme(configProvider.config?.theme),
              darkTheme: AppTheme.darkTheme(configProvider.config?.theme),
              themeMode: themeProvider.themeMode,

              // Router
              routerConfig: AppRouter.router,
            );
          },
        );
      },
    );
  }
}
