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

  // PDF 阅读器专属视觉设置（布局 / 自动裁切 / 背景调节）
  // 布局模式：0=单页 1=双页 2=单页连续 3=双页连续
  static const String readerLayoutModeKey = 'app.reader.pdf.layoutMode';
  static const int readerLayoutModeDefault = 0;
  // 自动裁切：去除页面四周空白边距
  static const String pdfAutoCropKey = 'app.reader.pdf.autoCrop';
  static const bool pdfAutoCropDefault = false;
  // 背景调节：亮度 / 对比度 / 饱和度 / 去色 / 去杂色
  static const String pdfBgBrightnessKey = 'app.reader.pdf.bg.brightness';
  static const double pdfBgBrightnessDefault = 1.0;
  static const String pdfBgContrastKey = 'app.reader.pdf.bg.contrast';
  static const double pdfBgContrastDefault = 1.0;
  static const String pdfBgSaturationKey = 'app.reader.pdf.bg.saturation';
  static const double pdfBgSaturationDefault = 1.0;
  static const String pdfBgRemoveColorKey = 'app.reader.pdf.bg.removeColor';
  static const bool pdfBgRemoveColorDefault = false;
  static const String pdfBgDenoiseKey = 'app.reader.pdf.bg.denoise';
  static const bool pdfBgDenoiseDefault = false;

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

  // PDF 阅读器视觉设置存取
  static int get readerLayoutMode {
    return Config.get(readerLayoutModeKey) as int? ?? readerLayoutModeDefault;
  }

  static void setReaderLayoutMode(int value) {
    Config.set(readerLayoutModeKey, value);
  }

  static bool get pdfAutoCrop {
    return Config.get(pdfAutoCropKey) as bool? ?? pdfAutoCropDefault;
  }

  static void setPdfAutoCrop(bool value) {
    Config.set(pdfAutoCropKey, value);
  }

  static double get pdfBgBrightness {
    return Config.get(pdfBgBrightnessKey) as double? ?? pdfBgBrightnessDefault;
  }

  static void setPdfBgBrightness(double value) {
    Config.set(pdfBgBrightnessKey, value);
  }

  static double get pdfBgContrast {
    return Config.get(pdfBgContrastKey) as double? ?? pdfBgContrastDefault;
  }

  static void setPdfBgContrast(double value) {
    Config.set(pdfBgContrastKey, value);
  }

  static double get pdfBgSaturation {
    return Config.get(pdfBgSaturationKey) as double? ??
        pdfBgSaturationDefault;
  }

  static void setPdfBgSaturation(double value) {
    Config.set(pdfBgSaturationKey, value);
  }

  static bool get pdfBgRemoveColor {
    return Config.get(pdfBgRemoveColorKey) as bool? ??
        pdfBgRemoveColorDefault;
  }

  static void setPdfBgRemoveColor(bool value) {
    Config.set(pdfBgRemoveColorKey, value);
  }

  static bool get pdfBgDenoise {
    return Config.get(pdfBgDenoiseKey) as bool? ?? pdfBgDenoiseDefault;
  }

  static void setPdfBgDenoise(bool value) {
    Config.set(pdfBgDenoiseKey, value);
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
