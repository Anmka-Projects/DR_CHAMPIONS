import 'package:flutter/material.dart';

/// App Configuration Model
class AppConfig {
  final String appName;
  final String appNameAr;
  final String tagline;
  final String version;
  final bool forceUpdate;
  final String minVersion;
  final ThemeConfig theme;
  final FeaturesConfig features;
  final SocialLinksConfig socialLinks;
  final SupportConfig support;
  final LegalConfig legal;

  AppConfig({
    required this.appName,
    required this.appNameAr,
    required this.tagline,
    required this.version,
    required this.forceUpdate,
    required this.minVersion,
    required this.theme,
    required this.features,
    required this.socialLinks,
    required this.support,
    required this.legal,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      appName: json['app_name'] as String? ?? '',
      appNameAr: json['app_name_ar'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      forceUpdate: json['force_update'] as bool? ?? false,
      minVersion: json['min_version'] as String? ?? '1.0.0',
      theme: ThemeConfig.fromJson(json['theme'] as Map<String, dynamic>? ?? {}),
      features: FeaturesConfig.fromJson(json['features'] as Map<String, dynamic>? ?? {}),
      socialLinks: SocialLinksConfig.fromJson(json['social_links'] as Map<String, dynamic>? ?? {}),
      support: SupportConfig.fromJson(json['support'] as Map<String, dynamic>? ?? {}),
      legal: LegalConfig.fromJson(json['legal'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'app_name': appName,
      'app_name_ar': appNameAr,
      'tagline': tagline,
      'version': version,
      'force_update': forceUpdate,
      'min_version': minVersion,
      'theme': theme.toJson(),
      'features': features.toJson(),
      'social_links': socialLinks.toJson(),
      'support': support.toJson(),
      'legal': legal.toJson(),
    };
  }
}

/// Theme Configuration
class ThemeConfig {
  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String successColor;
  final String warningColor;
  final String errorColor;
  final String backgroundColor;
  final String cardColor;
  final String textColor;
  final String mutedTextColor;

  ThemeConfig({
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.successColor,
    required this.warningColor,
    required this.errorColor,
    required this.backgroundColor,
    required this.cardColor,
    required this.textColor,
    required this.mutedTextColor,
  });

  factory ThemeConfig.fromJson(Map<String, dynamic> json) {
    return ThemeConfig(
      primaryColor: json['primary_color'] as String? ?? '#7C3AED',
      secondaryColor: json['secondary_color'] as String? ?? '#5B21B6',
      accentColor: json['accent_color'] as String? ?? '#F97316',
      successColor: json['success_color'] as String? ?? '#10B981',
      warningColor: json['warning_color'] as String? ?? '#EAB308',
      errorColor: json['error_color'] as String? ?? '#EF4444',
      backgroundColor: json['background_color'] as String? ?? '#FDF8F3',
      cardColor: json['card_color'] as String? ?? '#FFFFFF',
      textColor: json['text_color'] as String? ?? '#1A1A2E',
      mutedTextColor: json['muted_text_color'] as String? ?? '#64748B',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primary_color': primaryColor,
      'secondary_color': secondaryColor,
      'accent_color': accentColor,
      'success_color': successColor,
      'warning_color': warningColor,
      'error_color': errorColor,
      'background_color': backgroundColor,
      'card_color': cardColor,
      'text_color': textColor,
      'muted_text_color': mutedTextColor,
    };
  }

  /// Convert hex color string to Color
  Color getPrimaryColor() {
    return _hexToColor(primaryColor);
  }

  Color getSecondaryColor() {
    return _hexToColor(secondaryColor);
  }

  Color getAccentColor() {
    return _hexToColor(accentColor);
  }

  Color getSuccessColor() {
    return _hexToColor(successColor);
  }

  Color getWarningColor() {
    return _hexToColor(warningColor);
  }

  Color getErrorColor() {
    return _hexToColor(errorColor);
  }

  Color getBackgroundColor() {
    return _hexToColor(backgroundColor);
  }

  Color getCardColor() {
    return _hexToColor(cardColor);
  }

  Color getTextColor() {
    return _hexToColor(textColor);
  }

  Color getMutedTextColor() {
    return _hexToColor(mutedTextColor);
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

/// Features Configuration
class FeaturesConfig {
  final bool purchasesEnabled;
  final bool freeMode;
  final bool showPrices;
  final bool showFreeBadge;
  final bool liveCoursesEnabled;
  final bool certificatesEnabled;
  final bool examsEnabled;
  final bool downloadsEnabled;

  FeaturesConfig({
    required this.purchasesEnabled,
    required this.freeMode,
    required this.showPrices,
    required this.showFreeBadge,
    required this.liveCoursesEnabled,
    required this.certificatesEnabled,
    required this.examsEnabled,
    required this.downloadsEnabled,
  });

  factory FeaturesConfig.fromJson(Map<String, dynamic> json) {
    return FeaturesConfig(
      purchasesEnabled: json['purchases_enabled'] as bool? ?? true,
      freeMode: json['free_mode'] as bool? ?? false,
      showPrices: json['show_prices'] as bool? ?? true,
      showFreeBadge: json['show_free_badge'] as bool? ?? true,
      liveCoursesEnabled: json['live_courses_enabled'] as bool? ?? true,
      certificatesEnabled: json['certificates_enabled'] as bool? ?? true,
      examsEnabled: json['exams_enabled'] as bool? ?? true,
      downloadsEnabled: json['downloads_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'purchases_enabled': purchasesEnabled,
      'free_mode': freeMode,
      'show_prices': showPrices,
      'show_free_badge': showFreeBadge,
      'live_courses_enabled': liveCoursesEnabled,
      'certificates_enabled': certificatesEnabled,
      'exams_enabled': examsEnabled,
      'downloads_enabled': downloadsEnabled,
    };
  }
}

/// Social Links Configuration
class SocialLinksConfig {
  final String facebook;
  final String twitter;
  final String instagram;
  final String youtube;
  final String whatsapp;

  SocialLinksConfig({
    required this.facebook,
    required this.twitter,
    required this.instagram,
    required this.youtube,
    required this.whatsapp,
  });

  factory SocialLinksConfig.fromJson(Map<String, dynamic> json) {
    return SocialLinksConfig(
      facebook: json['facebook'] as String? ?? '',
      twitter: json['twitter'] as String? ?? '',
      instagram: json['instagram'] as String? ?? '',
      youtube: json['youtube'] as String? ?? '',
      whatsapp: json['whatsapp'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'facebook': facebook,
      'twitter': twitter,
      'instagram': instagram,
      'youtube': youtube,
      'whatsapp': whatsapp,
    };
  }
}

/// Support Configuration
class SupportConfig {
  final String email;
  final String phone;
  final String whatsapp;

  SupportConfig({
    required this.email,
    required this.phone,
    required this.whatsapp,
  });

  factory SupportConfig.fromJson(Map<String, dynamic> json) {
    return SupportConfig(
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      whatsapp: json['whatsapp'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'phone': phone,
      'whatsapp': whatsapp,
    };
  }
}

/// Legal Configuration
class LegalConfig {
  final String termsUrl;
  final String privacyUrl;

  LegalConfig({
    required this.termsUrl,
    required this.privacyUrl,
  });

  factory LegalConfig.fromJson(Map<String, dynamic> json) {
    return LegalConfig(
      termsUrl: json['terms_url'] as String? ?? '',
      privacyUrl: json['privacy_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'terms_url': termsUrl,
      'privacy_url': privacyUrl,
    };
  }
}

