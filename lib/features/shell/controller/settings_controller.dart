import 'package:flutter/cupertino.dart';

import '../../../engine/settings_engine.dart';

/// SettingsController exposes app setting state to Shell UI.
class SettingsController {
  static final ValueNotifier<String> language =
      ValueNotifier<String>(SettingsEngine.language);
  static final ValueNotifier<String> appearance =
      ValueNotifier<String>(SettingsEngine.appearance);
  static final ValueNotifier<String> themeColor =
      ValueNotifier<String>(SettingsEngine.themeColor);
  static final ValueNotifier<String> fontFamily =
      ValueNotifier<String>(SettingsEngine.fontFamily);
  static final ValueNotifier<Color> readerBackgroundColor =
      ValueNotifier<Color>(SettingsEngine.readerBackgroundColor);
  static final ValueNotifier<String> startupPage =
      ValueNotifier<String>(SettingsEngine.startupPage);
    static final ValueNotifier<String> startupSplashType =
      ValueNotifier<String>(SettingsEngine.startupSplashType);
    static final ValueNotifier<String> startupSplashText =
      ValueNotifier<String>(SettingsEngine.startupSplashText);
    static final ValueNotifier<String> startupSplashImagePath =
      ValueNotifier<String>(SettingsEngine.startupSplashImagePath);
    static final ValueNotifier<int> startupSplashDuration =
      ValueNotifier<int>(SettingsEngine.startupSplashDuration);

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

  /// Update the application theme color.
  static void setThemeColor(String value) {
    SettingsEngine.setThemeColor(value);
    themeColor.value = value;
  }

  /// Update the application font family.
  static void setFontFamily(String value) {
    SettingsEngine.setFontFamily(value);
    fontFamily.value = value;
  }

  /// Update the reading background color used by the reader views.
  static void setReaderBackgroundColor(Color value) {
    SettingsEngine.setReaderBackgroundColor(value);
    readerBackgroundColor.value = value;
  }

  static void setStartupPage(String value) {
    SettingsEngine.setStartupPage(value);
    startupPage.value = value;
  }

  static void setStartupSplashType(String value) {
    SettingsEngine.setStartupSplashType(value);
    startupSplashType.value = value;
  }

  static void setStartupSplashText(String value) {
    SettingsEngine.setStartupSplashText(value);
    startupSplashText.value = value;
  }

  static void setStartupSplashImagePath(String value) {
    SettingsEngine.setStartupSplashImagePath(value);
    startupSplashImagePath.value = value;
  }

  static void setStartupSplashDuration(int value) {
    SettingsEngine.setStartupSplashDuration(value);
    startupSplashDuration.value = value;
  }
}
