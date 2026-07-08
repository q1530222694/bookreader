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

  static const String fontFamilyKey = 'app.fontFamily';
  static const String fontFamilySystem = 'system';
  static const String fontFamilySansSerif = 'sans_serif';
  static const String fontFamilySerif = 'serif';
  static const String fontFamilyMonospace = 'monospace';

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
}
