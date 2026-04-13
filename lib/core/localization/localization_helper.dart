import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// Helper class to easily access localization strings
extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

