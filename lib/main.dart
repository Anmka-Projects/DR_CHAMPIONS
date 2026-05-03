import 'dart:developer';
import 'package:educational_app/core/notification_service/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:screen_protector/screen_protector.dart';
import 'core/design/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'core/config/app_config_provider.dart';
import 'core/config/theme_provider.dart';
import 'l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

/// Release builds: pass `--dart-define=ALLOW_SCREENSHOT=true` when you need
/// Play Store screenshots from a **release** APK/AAB. Otherwise release keeps
/// protection on.
const bool kAllowScreenshotsForStore =
    bool.fromEnvironment('ALLOW_SCREENSHOT', defaultValue: false);

/// Block capture only in **release** builds (not debug/profile), unless overridden.
bool get _shouldEnableScreenProtection =>
    kReleaseMode && !kAllowScreenshotsForStore;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
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

  // Screen protection: ON for release only (debug always allows screenshots).
  // Release + ALLOW_SCREENSHOT=true → off (for store listing captures).
  try {
    if (_shouldEnableScreenProtection) {
      await ScreenProtector.protectDataLeakageOn();
      await ScreenProtector.preventScreenshotOn();
    } else {
      await ScreenProtector.preventScreenshotOff();
      await ScreenProtector.protectDataLeakageOff();
      debugPrint(
        kAllowScreenshotsForStore
            ? 'Screen protection: OFF (ALLOW_SCREENSHOT release build)'
            : 'Screen protection: OFF (non-release build)',
      );
    }
  } catch (e) {
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
