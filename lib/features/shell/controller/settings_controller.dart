import 'package:flutter/cupertino.dart';

import '../../../engine/settings_engine.dart';
import '../model/custom_theme_color_model.dart';
import '../service/custom_theme_color_service.dart';
import '../service/pdf_book_settings_service.dart';

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
  static final ValueNotifier<double> pdfBgSharpness =
      ValueNotifier<double>(SettingsEngine.pdfBgSharpness);
  static final ValueNotifier<bool> pdfBgOverlay =
      ValueNotifier<bool>(SettingsEngine.pdfBgOverlay);
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
  static final ValueNotifier<int> pdfCropOddEvenMode =
      ValueNotifier<int>(SettingsEngine.pdfCropOddEvenMode);
  // 双击放大开关 notifier（开启后双击页面循环放大并支持双指缩放）。
  static final ValueNotifier<bool> pdfDoubleTapZoom =
      ValueNotifier<bool>(SettingsEngine.pdfDoubleTapZoom);
  // 撑满全屏（仅连续滚动模式生效）notifier：开启后上下滚动时每页按裁切后真实宽高比
  // 自定尺寸、宽度铺满、消除逐页跳动与未对齐；左右翻页不生效。
  static final ValueNotifier<bool> pdfFillScreenInScroll =
      ValueNotifier<bool>(SettingsEngine.pdfFillScreenInScroll);
  // 重排排版参数 notifier（重排后字体大小 / 行距 / 字距 / 段距，本地方案全平台通用）。
  static final ValueNotifier<double> pdfReflowFontSize =
      ValueNotifier<double>(SettingsEngine.pdfReflowFontSize);
  static final ValueNotifier<double> pdfReflowLineSpacing =
      ValueNotifier<double>(SettingsEngine.pdfReflowLineSpacing);
  static final ValueNotifier<double> pdfReflowLetterSpacing =
      ValueNotifier<double>(SettingsEngine.pdfReflowLetterSpacing);
  static final ValueNotifier<double> pdfReflowParaSpacing =
      ValueNotifier<double>(SettingsEngine.pdfReflowParaSpacing);
  // OCR 重排「预扫页数」notifier（重排扫描件时先同步识别前 N 页，其余后台续扫）。
  static final ValueNotifier<int> pdfOcrEagerPages =
      ValueNotifier<int>(SettingsEngine.pdfOcrEagerPages);

  // —— 每本书独立设置（按 bookId 持久化到磁盘）——
  // 全局 [SettingsEngine] 仅作「默认基线」；单本书的覆盖写在 [_activeOverrides]，
  // 由 [bindBook] 加载并落到各 notifier，任何 PDF notifier 变化经监听落盘。
  static String? _activeBookId;
  static Map<String, Object?> _activeOverrides = {};
  static bool _pdfListenersBound = false;
  static bool _applyingOverrides = false;

  /// 静态初始化时捕获的全局默认基线（此时 Config 为空，取到各 Key 的默认值）。
  static final Map<String, Object?> _defaults = {
    SettingsEngine.readerPageModeKey: SettingsEngine.readerPageMode,
    SettingsEngine.readerPageAnimationKey: SettingsEngine.readerPageAnimation,
    SettingsEngine.readerLayoutModeKey: SettingsEngine.readerLayoutMode,
    SettingsEngine.pdfAutoCropKey: SettingsEngine.pdfAutoCrop,
    SettingsEngine.pdfBgBrightnessKey: SettingsEngine.pdfBgBrightness,
    SettingsEngine.pdfBgContrastKey: SettingsEngine.pdfBgContrast,
    SettingsEngine.pdfBgSaturationKey: SettingsEngine.pdfBgSaturation,
    SettingsEngine.pdfBgRemoveColorKey: SettingsEngine.pdfBgRemoveColor,
    SettingsEngine.pdfBgDenoiseKey: SettingsEngine.pdfBgDenoise,
    SettingsEngine.pdfBgColorTempKey: SettingsEngine.pdfBgColorTemp,
    SettingsEngine.pdfBgSharpnessKey: SettingsEngine.pdfBgSharpness,
    SettingsEngine.pdfBgOverlayKey: SettingsEngine.pdfBgOverlay,
    SettingsEngine.pdfCropModeKey: SettingsEngine.pdfCropMode,
    SettingsEngine.pdfManualCropLeftKey: SettingsEngine.pdfManualCropLeft,
    SettingsEngine.pdfManualCropRightKey: SettingsEngine.pdfManualCropRight,
    SettingsEngine.pdfManualCropTopKey: SettingsEngine.pdfManualCropTop,
    SettingsEngine.pdfManualCropBottomKey: SettingsEngine.pdfManualCropBottom,
    SettingsEngine.pdfDualScreenKey: SettingsEngine.pdfDualScreen,
    SettingsEngine.pdfCropOddEvenModeKey: SettingsEngine.pdfCropOddEvenMode,
    SettingsEngine.pdfDoubleTapZoomKey: SettingsEngine.pdfDoubleTapZoom,
    SettingsEngine.pdfFillScreenInScrollKey: SettingsEngine.pdfFillScreenInScroll,
    SettingsEngine.pdfReflowFontSizeKey: SettingsEngine.pdfReflowFontSize,
    SettingsEngine.pdfReflowLineSpacingKey: SettingsEngine.pdfReflowLineSpacing,
    SettingsEngine.pdfReflowLetterSpacingKey: SettingsEngine.pdfReflowLetterSpacing,
    SettingsEngine.pdfReflowParaSpacingKey: SettingsEngine.pdfReflowParaSpacing,
    SettingsEngine.pdfOcrEagerPagesKey: SettingsEngine.pdfOcrEagerPages,
  };

  static final List<ChangeNotifier> _pdfNotifiers = [
    readerPageMode,
    readerPageAnimation,
    readerLayoutMode,
    pdfAutoCrop,
    pdfBgBrightness,
    pdfBgContrast,
    pdfBgSaturation,
    pdfBgRemoveColor,
    pdfBgDenoise,
    pdfBgColorTemp,
    pdfBgSharpness,
    pdfBgOverlay,
    pdfCropMode,
    pdfManualCropLeft,
    pdfManualCropRight,
    pdfManualCropTop,
    pdfManualCropBottom,
    pdfDualScreen,
    pdfCropOddEvenMode,
    pdfDoubleTapZoom,
    pdfFillScreenInScroll,
    pdfReflowFontSize,
    pdfReflowLineSpacing,
    pdfReflowLetterSpacing,
    pdfReflowParaSpacing,
    pdfOcrEagerPages,
  ];

  /// 绑定到某本书：加载其覆盖设置并落到 notifier；无覆盖则回退到全局默认基线。
  /// 需在 PDF 阅读页 initState 调用（可 await，内部已幂等加载磁盘）。
  static Future<void> bindBook(String bookId) async {
    await PdfBookSettingsService.ensureLoaded();
    _activeBookId = bookId;
    _activeOverrides = PdfBookSettingsService.load(bookId);
    _bindPdfListeners();
    _applyingOverrides = true;
    readerPageMode.value = _int(SettingsEngine.readerPageModeKey);
    readerPageAnimation.value = _int(SettingsEngine.readerPageAnimationKey);
    readerLayoutMode.value = _int(SettingsEngine.readerLayoutModeKey);
    pdfAutoCrop.value = _bol(SettingsEngine.pdfAutoCropKey);
    pdfBgBrightness.value = _dbl(SettingsEngine.pdfBgBrightnessKey);
    pdfBgContrast.value = _dbl(SettingsEngine.pdfBgContrastKey);
    pdfBgSaturation.value = _dbl(SettingsEngine.pdfBgSaturationKey);
    pdfBgRemoveColor.value = _bol(SettingsEngine.pdfBgRemoveColorKey);
    pdfBgDenoise.value = _bol(SettingsEngine.pdfBgDenoiseKey);
    pdfBgColorTemp.value = _dbl(SettingsEngine.pdfBgColorTempKey);
    pdfBgSharpness.value = _dbl(SettingsEngine.pdfBgSharpnessKey);
    pdfBgOverlay.value = _bol(SettingsEngine.pdfBgOverlayKey);
    pdfCropMode.value = _int(SettingsEngine.pdfCropModeKey);
    pdfManualCropLeft.value = _dbl(SettingsEngine.pdfManualCropLeftKey);
    pdfManualCropRight.value = _dbl(SettingsEngine.pdfManualCropRightKey);
    pdfManualCropTop.value = _dbl(SettingsEngine.pdfManualCropTopKey);
    pdfManualCropBottom.value = _dbl(SettingsEngine.pdfManualCropBottomKey);
    pdfDualScreen.value = _bol(SettingsEngine.pdfDualScreenKey);
    pdfCropOddEvenMode.value = _int(SettingsEngine.pdfCropOddEvenModeKey);
    pdfDoubleTapZoom.value = _bol(SettingsEngine.pdfDoubleTapZoomKey);
    pdfFillScreenInScroll.value = _bol(SettingsEngine.pdfFillScreenInScrollKey);
    pdfReflowFontSize.value = _dbl(SettingsEngine.pdfReflowFontSizeKey);
    pdfReflowLineSpacing.value = _dbl(SettingsEngine.pdfReflowLineSpacingKey);
    pdfReflowLetterSpacing.value = _dbl(SettingsEngine.pdfReflowLetterSpacingKey);
    pdfReflowParaSpacing.value = _dbl(SettingsEngine.pdfReflowParaSpacingKey);
    pdfOcrEagerPages.value = _int(SettingsEngine.pdfOcrEagerPagesKey);
    _applyingOverrides = false;
  }

  /// 仅绑定一次：为所有 PDF notifier 注册同一落盘监听。
  static void _bindPdfListeners() {
    if (_pdfListenersBound) return;
    _pdfListenersBound = true;
    for (final n in _pdfNotifiers) {
      n.addListener(_persistActiveBook);
    }
  }

  /// 任一 PDF notifier 变化即把当前整组值落盘到当前书（bindBook 期间跳过）。
  static void _persistActiveBook() {
    if (_applyingOverrides || _activeBookId == null) return;
    _activeOverrides = {
      SettingsEngine.readerPageModeKey: readerPageMode.value,
      SettingsEngine.readerPageAnimationKey: readerPageAnimation.value,
      SettingsEngine.readerLayoutModeKey: readerLayoutMode.value,
      SettingsEngine.pdfAutoCropKey: pdfAutoCrop.value,
      SettingsEngine.pdfBgBrightnessKey: pdfBgBrightness.value,
      SettingsEngine.pdfBgContrastKey: pdfBgContrast.value,
      SettingsEngine.pdfBgSaturationKey: pdfBgSaturation.value,
      SettingsEngine.pdfBgRemoveColorKey: pdfBgRemoveColor.value,
      SettingsEngine.pdfBgDenoiseKey: pdfBgDenoise.value,
      SettingsEngine.pdfBgColorTempKey: pdfBgColorTemp.value,
      SettingsEngine.pdfBgSharpnessKey: pdfBgSharpness.value,
      SettingsEngine.pdfBgOverlayKey: pdfBgOverlay.value,
      SettingsEngine.pdfCropModeKey: pdfCropMode.value,
      SettingsEngine.pdfManualCropLeftKey: pdfManualCropLeft.value,
      SettingsEngine.pdfManualCropRightKey: pdfManualCropRight.value,
      SettingsEngine.pdfManualCropTopKey: pdfManualCropTop.value,
      SettingsEngine.pdfManualCropBottomKey: pdfManualCropBottom.value,
      SettingsEngine.pdfDualScreenKey: pdfDualScreen.value,
      SettingsEngine.pdfCropOddEvenModeKey: pdfCropOddEvenMode.value,
      SettingsEngine.pdfDoubleTapZoomKey: pdfDoubleTapZoom.value,
      SettingsEngine.pdfFillScreenInScrollKey: pdfFillScreenInScroll.value,
      SettingsEngine.pdfReflowFontSizeKey: pdfReflowFontSize.value,
      SettingsEngine.pdfReflowLineSpacingKey: pdfReflowLineSpacing.value,
      SettingsEngine.pdfReflowLetterSpacingKey: pdfReflowLetterSpacing.value,
      SettingsEngine.pdfReflowParaSpacingKey: pdfReflowParaSpacing.value,
      SettingsEngine.pdfOcrEagerPagesKey: pdfOcrEagerPages.value,
    };
    PdfBookSettingsService.save(_activeBookId!, _activeOverrides);
  }

  static int _int(String key) =>
      _activeOverrides.containsKey(key)
          ? _activeOverrides[key] as int
          : _defaults[key] as int;
  static double _dbl(String key) =>
      _activeOverrides.containsKey(key)
          ? _activeOverrides[key] as double
          : _defaults[key] as double;
  static bool _bol(String key) =>
      _activeOverrides.containsKey(key)
          ? _activeOverrides[key] as bool
          : _defaults[key] as bool;

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

  /// 设置 PDF 清晰度（0.5~2.0，1.0 为原始；>1 锐化、<1 柔化）。
  static void setPdfBgSharpness(double value) {
    SettingsEngine.setPdfBgSharpness(value);
    pdfBgSharpness.value = value;
  }

  /// 设置 PDF 阅读背景覆盖开关（开启后用半透明背景色覆盖扫描件）。
  static void setPdfBgOverlay(bool value) {
    SettingsEngine.setPdfBgOverlay(value);
    pdfBgOverlay.value = value;
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

  /// 设置 PDF 奇偶页分开裁边模式（0=统一 / 1=仅奇数页 / 2=仅偶数页）。
  static void setPdfCropOddEvenMode(int value) {
    SettingsEngine.setPdfCropOddEvenMode(value);
    pdfCropOddEvenMode.value = value;
  }

  /// 设置 PDF 双击放大开关。
  static void setPdfDoubleTapZoom(bool value) {
    SettingsEngine.setPdfDoubleTapZoom(value);
    pdfDoubleTapZoom.value = value;
  }

  /// 设置 PDF 撑满全屏（仅连续滚动模式生效）开关。
  static void setPdfFillScreenInScroll(bool value) {
    SettingsEngine.setPdfFillScreenInScroll(value);
    pdfFillScreenInScroll.value = value;
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

  /// 设置 OCR 重排「预扫页数」（先同步识别前 N 页，其余后台续扫）。
  static void setPdfOcrEagerPages(int value) {
    SettingsEngine.setPdfOcrEagerPages(value);
    pdfOcrEagerPages.value = value;
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
