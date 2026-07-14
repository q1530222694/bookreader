import 'package:flutter/widgets.dart';

import 'config.dart';

/// SettingsEngine provides app-level setting keys and helpers.
class SettingsEngine {
  SettingsEngine._();

  static const String languageKey = 'app.language';
  static const String appearanceKey = 'app.appearance';

  static const String languageChinese = 'zh';
  static const String languageEnglish = 'en';
  static const String languageTraditionalChinese = 'zh_Hant';

  static const String appearanceLight = 'light';
  static const String appearanceDark = 'dark';
  static const String appearanceSystem = 'system';

  static const String themeColorKey = 'app.themeColor';
  static const String themeColorBlue = 'blue';
  static const String themeColorGreen = 'green';
  static const String themeColorPink = 'pink';
  static const String themeColorOrange = 'orange';
  static const String themeColorPurple = 'purple';
  static const String themeColorRed = 'red';
  // 选中自定义配色时的哨兵值：themeColor 置为该值表示当前主色来自自定义色，
  // 预设高亮将让位给自定义色选中态（避免预设与自定义同时高亮）。
  static const String themeColorCustom = 'custom';

  static const String fontFamilyKey = 'app.fontFamily';
  static const String fontFamilySystem = 'system';
  static const String fontFamilySansSerif = 'sans_serif';
  static const String fontFamilySerif = 'serif';
  static const String fontFamilyMonospace = 'monospace';

  static const String readerBackgroundColorKey = 'app.readerBackgroundColor';
  static const Color readerBackgroundColorDefault = Color(0xFFF7F3EC);

  // Startup page settings
  static const String startupPageKey = 'app.startupPage';
  static const String startupPageNone = 'none';
  static const String startupPageHome = 'home';
  static const String startupPageBookshelf = 'bookshelf';
  static const String startupPageMemory = 'memory';
  static const String startupPageTools = 'tools';
  static const String startupPageProfile = 'profile';

  // Startup splash settings
  static const String startupSplashTypeKey = 'app.startupSplash.type';
  static const String startupSplashTypeNone = 'none';
  static const String startupSplashTypeText = 'text';
  static const String startupSplashTypeImage = 'image';
  static const String startupSplashTextKey = 'app.startupSplash.text';
  static const String startupSplashImagePathKey = 'app.startupSplash.imagePath';
  static const String startupSplashDurationKey = 'app.startupSplash.duration';
  // 启动屏进入方式：自动（倒计时后自动进入）/ 点击（点击屏幕或按钮进入）
  static const String startupSplashEntryModeKey = 'app.startupSplash.entryMode';
  static const String startupSplashEntryModeAuto = 'auto';
  static const String startupSplashEntryModeTap = 'tap';
  static const String startupSplashEntryModeDefault = startupSplashEntryModeAuto;

  // 每日一句设置
  static const String dailySentenceUseBuiltinKey = 'app.dailySentence.useBuiltin';
  static const bool dailySentenceUseBuiltinDefault = true;

  static String get language {
    return Config.get(languageKey) as String? ?? languageChinese;
  }

  static void setLanguage(String language) {
    Config.set(languageKey, language);
  }

  static String get appearance {
    return Config.get(appearanceKey) as String? ?? appearanceSystem;
  }

  static void setAppearance(String appearance) {
    Config.set(appearanceKey, appearance);
  }

  static String get themeColor {
    return Config.get(themeColorKey) as String? ?? themeColorBlue;
  }

  static void setThemeColor(String themeColor) {
    Config.set(themeColorKey, themeColor);
  }

  static String get fontFamily {
    return Config.get(fontFamilyKey) as String? ?? fontFamilySystem;
  }

  static void setFontFamily(String fontFamily) {
    Config.set(fontFamilyKey, fontFamily);
  }

  static Color get readerBackgroundColor {
    final value = Config.get(readerBackgroundColorKey);
    return value is Color ? value : readerBackgroundColorDefault;
  }

  static void setReaderBackgroundColor(Color color) {
    Config.set(readerBackgroundColorKey, color);
  }

  // Startup page
  static String get startupPage {
    return Config.get(startupPageKey) as String? ?? startupPageNone;
  }

  static void setStartupPage(String page) {
    Config.set(startupPageKey, page);
  }

  // Startup splash
  static String get startupSplashType {
    return Config.get(startupSplashTypeKey) as String? ?? startupSplashTypeNone;
  }

  static void setStartupSplashType(String type) {
    Config.set(startupSplashTypeKey, type);
  }

  static String get startupSplashText {
    return Config.get(startupSplashTextKey) as String? ?? '';
  }

  static void setStartupSplashText(String text) {
    Config.set(startupSplashTextKey, text);
  }

  static String get startupSplashImagePath {
    return Config.get(startupSplashImagePathKey) as String? ?? '';
  }

  static void setStartupSplashImagePath(String path) {
    Config.set(startupSplashImagePathKey, path);
  }

  static int get startupSplashDuration {
    return Config.get(startupSplashDurationKey) as int? ?? 3;
  }

  static void setStartupSplashDuration(int seconds) {
    Config.set(startupSplashDurationKey, seconds);
  }

  // 启动屏进入方式（自动 / 点击）
  static String get startupSplashEntryMode {
    return Config.get(startupSplashEntryModeKey) as String? ??
        startupSplashEntryModeDefault;
  }

  static void setStartupSplashEntryMode(String mode) {
    Config.set(startupSplashEntryModeKey, mode);
  }

  // 每日一句：是否启用内置句子池
  static bool get dailySentenceUseBuiltin {
    return Config.get(dailySentenceUseBuiltinKey) as bool? ??
        dailySentenceUseBuiltinDefault;
  }

  static void setDailySentenceUseBuiltin(bool value) {
    Config.set(dailySentenceUseBuiltinKey, value);
  }
}
