import 'package:flutter/material.dart';
import '../../models/app_config.dart';
import '../../services/app_config_service.dart';

/// Provider to hold app configuration globally
class AppConfigProvider extends ChangeNotifier {
  AppConfig? _config;
  bool _isLoading = true;
  String? _error;

  AppConfig? get config => _config;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize and fetch app configuration
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _config = await AppConfigService.instance.fetchAppConfig();
      _error = null;
    } catch (e) {
      _error = e.toString();
      // Still set default config on error
      _config = await AppConfigService.instance.getAppConfig();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh configuration
  Future<void> refresh() async {
    AppConfigService.instance.clearCache();
    await initialize();
  }
}

