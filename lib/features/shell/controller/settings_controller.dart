import 'package:flutter/cupertino.dart';

import '../../../engine/settings_engine.dart';

/// SettingsController exposes app setting state to Shell UI.
class SettingsController {
  static final ValueNotifier<String> language =
      ValueNotifier<String>(SettingsEngine.language);
  static final ValueNotifier<String> appearance =
      ValueNotifier<String>(SettingsEngine.appearance);

  /// Toggle the current language between Chinese and English.
  static void setLanguage(String value) {
    SettingsEngine.setLanguage(value);
    language.value = value;
  }

  /// Update the application appearance mode.
  static void setAppearance(String value) {
    SettingsEngine.setAppearance(value);
    appearance.value = value;
  }
}
