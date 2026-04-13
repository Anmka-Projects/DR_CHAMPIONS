import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/app_config.dart';

/// Service for fetching and managing app configuration
class AppConfigService {
  AppConfigService._();
  
  static final AppConfigService instance = AppConfigService._();
  
  AppConfig? _cachedConfig;

  /// Fetch app configuration from API
  Future<AppConfig> fetchAppConfig() async {
    try {
      final response = await ApiClient.instance.get(ApiEndpoints.appConfig);
      
      if (response['success'] == true && response['data'] != null) {
        final config = AppConfig.fromJson(response['data'] as Map<String, dynamic>);
        _cachedConfig = config;
        return config;
      } else {
        throw Exception('Failed to fetch app config: Invalid response format');
      }
    } catch (e) {
      // Return default config if API fails
      return _getDefaultConfig();
    }
  }

  /// Get cached config or fetch if not available
  Future<AppConfig> getAppConfig() async {
    if (_cachedConfig != null) {
      return _cachedConfig!;
    }
    return await fetchAppConfig();
  }

  /// Clear cached config
  void clearCache() {
    _cachedConfig = null;
  }

  /// Get default configuration (fallback)
  AppConfig _getDefaultConfig() {
    return AppConfig(
      appName: 'Dr Champions Academy',
      appNameAr: 'Dr Champions Academy',
      tagline: 'منصة التعليم الذكية',
      version: '1.0.0',
      forceUpdate: false,
      minVersion: '1.0.0',
      theme: ThemeConfig.fromJson({}),
      features: FeaturesConfig.fromJson({}),
      socialLinks: SocialLinksConfig.fromJson({}),
      support: SupportConfig.fromJson({}),
      legal: LegalConfig.fromJson({}),
    );
  }
}

