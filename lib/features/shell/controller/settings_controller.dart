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

  // PDF 阅读器视觉设置（翻页方式 / 翻页动画 / 布局 / 自动裁切 / 背景调节 / 重排排版）的
  // 全局 notifier。UI 仅监听这些 notifier，不直接写持久化（符合禁区 3）。
  static final ValueNotifier<int> readerPageMode =
      ValueNotifier<int>(SettingsEngine.readerPageMode);
  static final ValueNotifier<int> readerPageAnimation =
      ValueNotifier<int>(SettingsEngine.readerPageAnimation);
  static final ValueNotifier<int> readerLayoutMode =
      ValueNotifier<int>(SettingsEngine.readerLayoutMode);
  static final ValueNotifier<bool> pdfAutoCrop =
      ValueNotifier<bool>(SettingsEngine.pdfAutoCrop);
  static final ValueNotifier<double> pdfBgBrightness =
      ValueNotifier<double>(SettingsEngine.pdfBgBrightness);
  static final ValueNotifier<double> pdfBgContrast =
      ValueNotifier<double>(SettingsEngine.pdfBgContrast);
  static final ValueNotifier<double> pdfBgSaturation =
      ValueNotifier<double>(SettingsEngine.pdfBgSaturation);
  static final ValueNotifier<bool> pdfBgRemoveColor =
      ValueNotifier<bool>(SettingsEngine.pdfBgRemoveColor);
  static final ValueNotifier<bool> pdfBgDenoise =
      ValueNotifier<bool>(SettingsEngine.pdfBgDenoise);
  static final ValueNotifier<double> pdfBgColorTemp =
      ValueNotifier<double>(SettingsEngine.pdfBgColorTemp);
  static final ValueNotifier<int> pdfCropMode =
      ValueNotifier<int>(SettingsEngine.pdfCropMode);
  static final ValueNotifier<double> pdfManualCropLeft =
      ValueNotifier<double>(SettingsEngine.pdfManualCropLeft);
  static final ValueNotifier<double> pdfManualCropRight =
      ValueNotifier<double>(SettingsEngine.pdfManualCropRight);
  static final ValueNotifier<double> pdfManualCropTop =
      ValueNotifier<double>(SettingsEngine.pdfManualCropTop);
  static final ValueNotifier<double> pdfManualCropBottom =
      ValueNotifier<double>(SettingsEngine.pdfManualCropBottom);
  static final ValueNotifier<bool> pdfDualScreen =
      ValueNotifier<bool>(SettingsEngine.pdfDualScreen);
  // 重排排版参数 notifier（重排后字体大小 / 行距 / 字距 / 段距，本地方案全平台通用）。
  static final ValueNotifier<double> pdfReflowFontSize =
      ValueNotifier<double>(SettingsEngine.pdfReflowFontSize);
  static final ValueNotifier<double> pdfReflowLineSpacing =
      ValueNotifier<double>(SettingsEngine.pdfReflowLineSpacing);
  static final ValueNotifier<double> pdfReflowLetterSpacing =
      ValueNotifier<double>(SettingsEngine.pdfReflowLetterSpacing);
  static final ValueNotifier<double> pdfReflowParaSpacing =
      ValueNotifier<double>(SettingsEngine.pdfReflowParaSpacing);
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

  /// 设置 PDF 翻页方式（0 左右翻页 / 1 上下滚动 / 2 仿真 / 3 无）。
  static void setReaderPageMode(int value) {
    SettingsEngine.setReaderPageMode(value);
    readerPageMode.value = value;
  }

  /// 设置 PDF 布局模式（0 单页 / 1 双页 / 2 单页连续 / 3 双页连续）。
  static void setReaderLayoutMode(int value) {
    SettingsEngine.setReaderLayoutMode(value);
    readerLayoutMode.value = value;
  }

  /// 设置 PDF 自动裁切开关。
  static void setPdfAutoCrop(bool value) {
    SettingsEngine.setPdfAutoCrop(value);
    pdfAutoCrop.value = value;
  }

  /// 设置 PDF 背景亮度（0.3~1.5，1.0 为原始）。
  static void setPdfBgBrightness(double value) {
    SettingsEngine.setPdfBgBrightness(value);
    pdfBgBrightness.value = value;
  }

  /// 设置 PDF 背景对比度（0.5~2.0，1.0 为原始）。
  static void setPdfBgContrast(double value) {
    SettingsEngine.setPdfBgContrast(value);
    pdfBgContrast.value = value;
  }

  /// 设置 PDF 背景饱和度（0~2.0，1.0 为原始）。
  static void setPdfBgSaturation(double value) {
    SettingsEngine.setPdfBgSaturation(value);
    pdfBgSaturation.value = value;
  }

  /// 设置 PDF 去除颜色（黑白灰）开关。
  static void setPdfBgRemoveColor(bool value) {
    SettingsEngine.setPdfBgRemoveColor(value);
    pdfBgRemoveColor.value = value;
  }

  /// 设置 PDF 智能去杂色开关。
  static void setPdfBgDenoise(bool value) {
    SettingsEngine.setPdfBgDenoise(value);
    pdfBgDenoise.value = value;
  }

  /// 设置 PDF 色温（0.5 偏冷蓝 ~ 2.0 偏暖黄，1.0 为原始）。
  static void setPdfBgColorTemp(double value) {
    SettingsEngine.setPdfBgColorTemp(value);
    pdfBgColorTemp.value = value;
  }

  /// 设置 PDF 页面裁切模式（0=不裁切 / 1=自动 / 2=手动 / 3=框选）。
  static void setPdfCropMode(int value) {
    SettingsEngine.setPdfCropMode(value);
    pdfCropMode.value = value;
  }

  /// 设置 PDF 手动裁切左边距（0~1）。
  static void setPdfManualCropLeft(double value) {
    SettingsEngine.setPdfManualCropLeft(value);
    pdfManualCropLeft.value = value;
  }

  /// 设置 PDF 手动裁切右边距（0~1）。
  static void setPdfManualCropRight(double value) {
    SettingsEngine.setPdfManualCropRight(value);
    pdfManualCropRight.value = value;
  }

  /// 设置 PDF 手动裁切上边距（0~1）。
  static void setPdfManualCropTop(double value) {
    SettingsEngine.setPdfManualCropTop(value);
    pdfManualCropTop.value = value;
  }

  /// 设置 PDF 手动裁切下边距（0~1）。
  static void setPdfManualCropBottom(double value) {
    SettingsEngine.setPdfManualCropBottom(value);
    pdfManualCropBottom.value = value;
  }

  /// 设置 PDF 双屏模式开关。
  static void setPdfDualScreen(bool value) {
    SettingsEngine.setPdfDualScreen(value);
    pdfDualScreen.value = value;
  }

  /// 设置 PDF 翻页动画（0 无 / 1 仿真）。
  static void setReaderPageAnimation(int value) {
    SettingsEngine.setReaderPageAnimation(value);
    readerPageAnimation.value = value;
  }

  /// 设置重排字体大小。
  static void setPdfReflowFontSize(double value) {
    SettingsEngine.setPdfReflowFontSize(value);
    pdfReflowFontSize.value = value;
  }

  /// 设置重排行距。
  static void setPdfReflowLineSpacing(double value) {
    SettingsEngine.setPdfReflowLineSpacing(value);
    pdfReflowLineSpacing.value = value;
  }

  /// 设置重排字距（字符间距）。
  static void setPdfReflowLetterSpacing(double value) {
    SettingsEngine.setPdfReflowLetterSpacing(value);
    pdfReflowLetterSpacing.value = value;
  }

  /// 设置重排段距（段落间距）。
  static void setPdfReflowParaSpacing(double value) {
    SettingsEngine.setPdfReflowParaSpacing(value);
    pdfReflowParaSpacing.value = value;
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
