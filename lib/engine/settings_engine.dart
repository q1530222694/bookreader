import 'package:flutter/widgets.dart';

import '../core/cloud_drive_store.dart';
import '../core/scan_roots_store.dart';
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

  // PDF 阅读器专属视觉设置（翻页方式 / 翻页动画 / 布局 / 自动裁切 / 背景调节 / 重排排版）
  // 翻页方式（同一行）：0=左右滑动 1=上下滑动 2=左右单击 3=上下单击 4=单击滚动
  static const String readerPageModeKey = 'app.reader.pdf.pageMode';
  static const int readerPageModeDefault = 0;
  // 翻页动画（独立栏目「翻页动画」）：
  // 0=无动画（瞬时跳转） 1=仿真动画（平滑吸附）
  // 2=淡入淡出 3=叠加 4=跃动 5=旋转 6=旋转木马 7=模仿圆筒 8=反转
  static const String readerPageAnimationKey = 'app.reader.pdf.pageAnimation';
  static const int readerPageAnimationDefault = 1;
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
  // 色温（0.5 偏冷蓝 ~ 2.0 偏暖黄，1.0 为原始色温）
  static const String pdfBgColorTempKey = 'app.reader.pdf.bg.colorTemp';
  static const double pdfBgColorTempDefault = 1.0;
  // 清晰度（0.5~2.0，1.0 为原始；>1 锐化、<1 轻微柔化），像素级卷积，需重渲染。
  static const String pdfBgSharpnessKey = 'app.reader.pdf.bg.sharpness';
  static const double pdfBgSharpnessDefault = 1.0;
  static const String pdfBgOverlayKey = 'app.reader.pdf.bg.overlay';
  static const bool pdfBgOverlayDefault = false;
  // 页面裁切模式：0=不裁切 / 1=智能自动裁边 / 2=手动裁边 / 3=框选裁边
  static const String pdfCropModeKey = 'app.reader.pdf.cropMode';
  static const int pdfCropModeDefault = 0;
  // 手动裁切边距（归一化 0~1，表示页面宽高的裁切比例）
  static const String pdfManualCropLeftKey = 'app.reader.pdf.crop.left';
  static const double pdfManualCropLeftDefault = 0.0;
  static const String pdfManualCropRightKey = 'app.reader.pdf.crop.right';
  static const double pdfManualCropRightDefault = 0.0;
  static const String pdfManualCropTopKey = 'app.reader.pdf.crop.top';
  static const double pdfManualCropTopDefault = 0.0;
  static const String pdfManualCropBottomKey = 'app.reader.pdf.crop.bottom';
  static const double pdfManualCropBottomDefault = 0.0;
  // 双屏模式：左右分屏独立滑动，用于对比阅读
  static const String pdfDualScreenKey = 'app.reader.pdf.dualScreen';
  static const bool pdfDualScreenDefault = false;
  // 双击放大：开启后双击页面循环放大（1×→2×→3×）并支持双指缩放
  static const String pdfDoubleTapZoomKey = 'app.reader.pdf.doubleTapZoom';
  static const bool pdfDoubleTapZoomDefault = false;
  // 撑满全屏（仅连续滚动模式生效）：开启后上下滚动（单页连续 / 双页连续）时，
  // 每页按裁切后的真实宽高比自定尺寸，宽度铺满、消除逐页跳动与未对齐；
  // 左右翻页（PageView）不生效，始终显示完整一页。
  static const String pdfFillScreenInScrollKey = 'app.reader.pdf.fillScreenInScroll';
  static const bool pdfFillScreenInScrollDefault = true;
  // 奇偶页分开裁边：0=统一 / 1=仅奇数页 / 2=仅偶数页
  static const String pdfCropOddEvenModeKey = 'app.reader.pdf.crop.oddEvenMode';
  static const int pdfCropOddEvenModeDefault = 0;
  // 重排排版（重排后可读写的字体排版参数，本地方案、全平台通用）
  static const String pdfReflowFontSizeKey = 'app.reader.pdf.reflow.fontSize';
  static const double pdfReflowFontSizeDefault = 18.0;
  static const String pdfReflowLineSpacingKey = 'app.reader.pdf.reflow.lineSpacing';
  static const double pdfReflowLineSpacingDefault = 1.6;
  static const String pdfReflowLetterSpacingKey = 'app.reader.pdf.reflow.letterSpacing';
  static const double pdfReflowLetterSpacingDefault = 0.0;
  static const String pdfReflowParaSpacingKey = 'app.reader.pdf.reflow.paraSpacing';
  static const double pdfReflowParaSpacingDefault = 8.0;
  // OCR 扫描件重排总开关（默认开启；关闭后扫描件走「无可重排文本」提示）
  static const String pdfOcrEnabledKey = 'app.reader.pdf.ocrEnabled';
  static const bool pdfOcrEnabledDefault = true;
  // OCR 扫描件重排「预扫页数」：重排时先同步识别前 N 页并立即显示，
  // 其余页在后台异步续扫（默认 3 页）。
  static const String pdfOcrEagerPagesKey = 'app.reader.pdf.ocrEagerPages';
  static const int pdfOcrEagerPagesDefault = 3;

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
  static int get readerPageMode {
    return Config.get(readerPageModeKey) as int? ?? readerPageModeDefault;
  }

  static void setReaderPageMode(int value) {
    Config.set(readerPageModeKey, value);
  }

  static int get readerPageAnimation {
    return Config.get(readerPageAnimationKey) as int? ??
        readerPageAnimationDefault;
  }

  static void setReaderPageAnimation(int value) {
    Config.set(readerPageAnimationKey, value);
  }

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

  static double get pdfBgColorTemp {
    return Config.get(pdfBgColorTempKey) as double? ?? pdfBgColorTempDefault;
  }

  static void setPdfBgColorTemp(double value) {
    Config.set(pdfBgColorTempKey, value);
  }

  static double get pdfBgSharpness {
    return Config.get(pdfBgSharpnessKey) as double? ?? pdfBgSharpnessDefault;
  }

  static void setPdfBgSharpness(double value) {
    Config.set(pdfBgSharpnessKey, value);
  }

  static bool get pdfBgOverlay {
    return Config.get(pdfBgOverlayKey) as bool? ?? pdfBgOverlayDefault;
  }

  static void setPdfBgOverlay(bool value) {
    Config.set(pdfBgOverlayKey, value);
  }

  static int get pdfCropMode {
    return Config.get(pdfCropModeKey) as int? ?? pdfCropModeDefault;
  }

  static void setPdfCropMode(int value) {
    Config.set(pdfCropModeKey, value);
  }

  static double get pdfManualCropLeft {
    return Config.get(pdfManualCropLeftKey) as double? ?? pdfManualCropLeftDefault;
  }

  static void setPdfManualCropLeft(double value) {
    Config.set(pdfManualCropLeftKey, value);
  }

  static double get pdfManualCropRight {
    return Config.get(pdfManualCropRightKey) as double? ?? pdfManualCropRightDefault;
  }

  static void setPdfManualCropRight(double value) {
    Config.set(pdfManualCropRightKey, value);
  }

  static double get pdfManualCropTop {
    return Config.get(pdfManualCropTopKey) as double? ?? pdfManualCropTopDefault;
  }

  static void setPdfManualCropTop(double value) {
    Config.set(pdfManualCropTopKey, value);
  }

  static double get pdfManualCropBottom {
    return Config.get(pdfManualCropBottomKey) as double? ??
        pdfManualCropBottomDefault;
  }

  static void setPdfManualCropBottom(double value) {
    Config.set(pdfManualCropBottomKey, value);
  }

  static bool get pdfDualScreen {
    return Config.get(pdfDualScreenKey) as bool? ?? pdfDualScreenDefault;
  }

  static void setPdfDualScreen(bool value) {
    Config.set(pdfDualScreenKey, value);
  }

  static bool get pdfDoubleTapZoom {
    return Config.get(pdfDoubleTapZoomKey) as bool? ??
        pdfDoubleTapZoomDefault;
  }

  static void setPdfDoubleTapZoom(bool value) {
    Config.set(pdfDoubleTapZoomKey, value);
  }

  static bool get pdfFillScreenInScroll {
    return Config.get(pdfFillScreenInScrollKey) as bool? ??
        pdfFillScreenInScrollDefault;
  }

  static void setPdfFillScreenInScroll(bool value) {
    Config.set(pdfFillScreenInScrollKey, value);
  }

  static int get pdfCropOddEvenMode {
    return Config.get(pdfCropOddEvenModeKey) as int? ?? pdfCropOddEvenModeDefault;
  }

  static void setPdfCropOddEvenMode(int value) {
    Config.set(pdfCropOddEvenModeKey, value);
  }

  // 重排排版参数存取
  static double get pdfReflowFontSize {
    return Config.get(pdfReflowFontSizeKey) as double? ??
        pdfReflowFontSizeDefault;
  }

  static void setPdfReflowFontSize(double value) {
    Config.set(pdfReflowFontSizeKey, value);
  }

  static double get pdfReflowLineSpacing {
    return Config.get(pdfReflowLineSpacingKey) as double? ??
        pdfReflowLineSpacingDefault;
  }

  static void setPdfReflowLineSpacing(double value) {
    Config.set(pdfReflowLineSpacingKey, value);
  }

  static double get pdfReflowLetterSpacing {
    return Config.get(pdfReflowLetterSpacingKey) as double? ??
        pdfReflowLetterSpacingDefault;
  }

  static void setPdfReflowLetterSpacing(double value) {
    Config.set(pdfReflowLetterSpacingKey, value);
  }

  static double get pdfReflowParaSpacing {
    return Config.get(pdfReflowParaSpacingKey) as double? ??
        pdfReflowParaSpacingDefault;
  }

  static void setPdfReflowParaSpacing(double value) {
    Config.set(pdfReflowParaSpacingKey, value);
  }

  static bool get pdfOcrEnabled {
    return Config.get(pdfOcrEnabledKey) as bool? ?? pdfOcrEnabledDefault;
  }

  static void setPdfOcrEnabled(bool value) {
    Config.set(pdfOcrEnabledKey, value);
  }

  /// 设置 OCR 重排「预扫页数」（先同步识别前 N 页，其余后台续扫）。
  static int get pdfOcrEagerPages {
    return Config.get(pdfOcrEagerPagesKey) as int? ?? pdfOcrEagerPagesDefault;
  }

  static void setPdfOcrEagerPages(int value) {
    Config.set(pdfOcrEagerPagesKey, value);
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

  // 扫描导入：用户通过 UI 追加的扫描根目录（跨启动持久化于磁盘，见 ScanRootsStore）。
  static const String scanRootsKey = 'app.bookshelf.scanRoots';

  /// 用户追加的扫描根目录列表。
  ///
  /// 读取来自 [ScanRootsStore] 的磁盘持久化（App 启动时已 [ScanRootsStore.load]，
  /// 重启后不丢失）；内存镜像保证高频读取免盘。
  static List<String> get scanRoots => ScanRootsStore.roots;

  /// 写入用户追加的扫描根目录并落盘持久化（异步写盘，失败忽略、内存仍有效）。
  static set scanRoots(List<String> roots) {
    Config.set(scanRootsKey, List<String>.from(roots)); // 保留内存态便于即时响应。
    ScanRootsStore.persist(roots);
  }

  // 数据管理：个人云盘/NAS 配置列表（跨启动持久化于磁盘，见 CloudDriveStore）。
  static const String cloudDrivesKey = 'app.dataManager.cloudDrives';

  /// 已配置的个人云盘/NAS 列表（字典形式，由 feature 层转为 [CloudDriveConfig]）。
  ///
  /// 读取来自 [CloudDriveStore] 的磁盘持久化（App 启动时已 [CloudDriveStore.load]，
  /// 重启后不丢失）；内存镜像保证高频读取免盘。
  static List<Map<String, dynamic>> get cloudDrives => CloudDriveStore.drives;

  /// 写入云盘配置列表并落盘持久化（异步写盘，失败忽略、内存仍有效）。
  static set cloudDrives(List<Map<String, dynamic>> drives) {
    Config.set(cloudDrivesKey, List<Map<String, dynamic>>.from(drives));
    CloudDriveStore.persist(drives);
  }

  /// 可被「导出阅读数据」携带的用户偏好键白名单。
  ///
  /// 排除 [readerBackgroundColorKey]（其值为 [Color]，无法直接 JSON 序列化，
  /// 导出会抛异常）；其余均为基础类型（String/int/double/bool），可安全落盘。
  static const List<String> exportableSettingKeys = [
    languageKey,
    appearanceKey,
    themeColorKey,
    fontFamilyKey,
    readerPageModeKey,
    readerPageAnimationKey,
    readerLayoutModeKey,
    pdfAutoCropKey,
    pdfBgBrightnessKey,
    pdfBgContrastKey,
    pdfBgSaturationKey,
    pdfBgRemoveColorKey,
    pdfBgDenoiseKey,
    pdfBgColorTempKey,
    pdfBgSharpnessKey,
    pdfBgOverlayKey,
    pdfCropModeKey,
    pdfManualCropLeftKey,
    pdfManualCropRightKey,
    pdfManualCropTopKey,
    pdfManualCropBottomKey,
    pdfDualScreenKey,
    pdfDoubleTapZoomKey,
    pdfFillScreenInScrollKey,
    pdfCropOddEvenModeKey,
    pdfReflowFontSizeKey,
    pdfReflowLineSpacingKey,
    pdfReflowLetterSpacingKey,
    pdfReflowParaSpacingKey,
    pdfOcrEnabledKey,
    pdfOcrEagerPagesKey,
    startupPageKey,
    startupSplashTypeKey,
    startupSplashTextKey,
    startupSplashImagePathKey,
    startupSplashDurationKey,
    startupSplashEntryModeKey,
    dailySentenceUseBuiltinKey,
  ];

  /// 导出用户偏好为可序列化字典（仅含 [exportableSettingKeys] 白名单）。
  static Map<String, dynamic> exportSettings() {
    final map = <String, dynamic>{};
    for (final key in exportableSettingKeys) {
      final value = Config.get(key);
      if (value != null) map[key] = value;
    }
    return map;
  }

  /// 从导出字典恢复用户偏好（仅写入白名单内、且确实存在的键，避免脏数据污染）。
  static void importSettings(Map<String, dynamic> map) {
    for (final key in exportableSettingKeys) {
      if (map.containsKey(key)) {
        Config.set(key, map[key]);
      }
    }
  }
}
