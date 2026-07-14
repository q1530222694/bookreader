import 'package:flutter/cupertino.dart';

import '../../../engine/settings_engine.dart';
import '../model/custom_theme_color_model.dart';
import '../service/custom_theme_color_service.dart';

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
    static final ValueNotifier<String> startupSplashEntryMode =
      ValueNotifier<String>(SettingsEngine.startupSplashEntryMode);
    static final ValueNotifier<bool> dailySentenceUseBuiltin =
      ValueNotifier<bool>(SettingsEngine.dailySentenceUseBuiltin);

  /// 当前生效的主色（预设色或用户自定义色），[ShellPage] 据此重建全局主题。
  /// 这是颜色变更对外的唯一上浮入口，UI 不直接控制颜色。
  static final ValueNotifier<Color> activePrimaryColor =
      ValueNotifier<Color>(_resolveThemeColor(SettingsEngine.themeColor));

  /// 当前选中的自定义配色 id；为 null 表示当前主色来自预设。
  static final ValueNotifier<String?> activeCustomColorId =
      ValueNotifier<String?>(null);

  /// 自定义配色列表（桥接 [CustomThemeColorService] 的 notifier，UI 直接监听）。
  static final ValueNotifier<List<CustomThemeColor>> customColors =
      CustomThemeColorService.colorsNotifier;

  /// 将主题配色字符串统一解析为 [Color]（集中消除三处重复的 if-else 逻辑）。
  /// 使用 [CupertinoColors] 动态色以支持暗色模式。
  static Color _resolveThemeColor(String key) {
    switch (key) {
      case SettingsEngine.themeColorGreen:
        return CupertinoColors.activeGreen;
      case SettingsEngine.themeColorPink:
        return CupertinoColors.systemPink;
      case SettingsEngine.themeColorOrange:
        return CupertinoColors.systemOrange;
      case SettingsEngine.themeColorPurple:
        return CupertinoColors.systemIndigo;
      case SettingsEngine.themeColorRed:
        return CupertinoColors.systemRed;
      case SettingsEngine.themeColorBlue:
      default:
        return CupertinoColors.activeBlue;
    }
  }

  /// 对外暴露同一解析逻辑，供 appearance/profile 等页面复用。
  static Color resolveThemeColor(String key) => _resolveThemeColor(key);

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

  /// 选择预设配色：同步更新字符串状态与全局生效主色，并清空自定义选中态。
  static void setPresetColor(String value) {
    SettingsEngine.setThemeColor(value);
    themeColor.value = value;
    activeCustomColorId.value = null;
    activePrimaryColor.value = _resolveThemeColor(value);
  }

  /// 应用某个已存在的自定义配色（按 id），并标记为当前选中。
  static void applyCustomColorById(String id) {
    final target = CustomThemeColorService.findById(id);
    if (target == null) return;
    themeColor.value = SettingsEngine.themeColorCustom;
    activeCustomColorId.value = id;
    activePrimaryColor.value = target.color;
  }

  /// 新增自定义配色并立即应用。
  static Future<void> addCustomColor(Color color, {String? name}) async {
    final item = CustomThemeColor(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      colorValue: color.toARGB32(),
      name: name,
    );
    await CustomThemeColorService.addColor(item);
    applyCustomColorById(item.id);
  }

  /// 更新某个自定义配色的颜色与名称，若其当前被选中则同步刷新主色。
  static Future<void> updateCustomColor(
    String id,
    Color color, {
    String? name,
  }) async {
    final existing = CustomThemeColorService.findById(id);
    if (existing == null) return;
    final updated = existing.copyWith(colorValue: color.toARGB32(), name: name);
    await CustomThemeColorService.updateColor(updated);
    if (activeCustomColorId.value == id) {
      themeColor.value = SettingsEngine.themeColorCustom;
      activePrimaryColor.value = updated.color;
    }
  }

  /// 删除某个自定义配色；若其正被选中，则回退到默认蓝色主色。
  static Future<void> deleteCustomColor(String id) async {
    final wasActive = activeCustomColorId.value == id;
    await CustomThemeColorService.deleteColor(id);
    if (wasActive) {
      themeColor.value = SettingsEngine.themeColorBlue;
      activeCustomColorId.value = null;
      activePrimaryColor.value = _resolveThemeColor(SettingsEngine.themeColorBlue);
    }
  }

  /// Update the application theme color (保留旧接口，内部走 setPresetColor)。
  static void setThemeColor(String value) {
    setPresetColor(value);
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

  /// 设置启动屏进入方式（自动 / 点击）。
  static void setStartupSplashEntryMode(String value) {
    SettingsEngine.setStartupSplashEntryMode(value);
    startupSplashEntryMode.value = value;
  }

  /// 设置「每日一句」是否启用内置句子池。
  static void setDailySentenceUseBuiltin(bool value) {
    SettingsEngine.setDailySentenceUseBuiltin(value);
    dailySentenceUseBuiltin.value = value;
  }
}
