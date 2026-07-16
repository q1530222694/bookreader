/// PDF 阅读器的视觉设置集合。
///
/// 聚合「布局模式 / 自动裁切 / 手动裁切 / 框选裁切 / 背景调节
/// （亮度·对比度·饱和度·色温·去色·去杂色） / 双屏模式」，
/// 设计为不可变数据，通过 [copyWith] 派生新实例，便于状态上浮与持久化。
/// 该对象在 [lib/features/shell/ui/book_viewer_page.dart] 中作为渲染依据，
/// 并经 [lib/features/shell/service/pdf_render_service.dart] 解析为实际渲染参数。
class PdfReaderSettings {
  /// 布局模式：
  /// 0 = 单页，1 = 双页，2 = 单页连续，3 = 双页连续
  final int layoutMode;

  /// 页面裁切模式：0=不裁切 / 1=智能自动裁边 / 2=手动裁边 / 3=框选裁边
  final int cropMode;

  /// 自动裁切（兼容旧接口，cropMode==1 时为 true）
  final bool autoCrop;

  /// 手动裁切边距（归一化 0~1，表示页面宽高的裁切比例）
  final double manualCropLeft;
  final double manualCropRight;
  final double manualCropTop;
  final double manualCropBottom;

  /// 亮度（0.3~1.5，1.0 为原始亮度）
  final double brightness;

  /// 对比度（0.5~2.0，1.0 为原始对比度）
  final double contrast;

  /// 色彩饱和度（0~2.0，1.0 为原始饱和度）
  final double saturation;

  /// 色温（0.5 偏冷蓝 ~ 2.0 偏暖黄，1.0 为原始色温）
  final double colorTemperature;

  /// 去除颜色：仅显示黑白灰（灰度化）
  final bool removeColor;

  /// 智能去杂色：去除影响阅读的小黑点 / 杂点（轻微高斯模糊近似）
  final bool denoise;

  /// 双屏模式：左右分屏独立滑动对比阅读
  final bool dualScreen;

  const PdfReaderSettings({
    this.layoutMode = 0,
    this.cropMode = 0,
    this.autoCrop = false,
    this.manualCropLeft = 0.0,
    this.manualCropRight = 0.0,
    this.manualCropTop = 0.0,
    this.manualCropBottom = 0.0,
    this.brightness = 1.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.colorTemperature = 1.0,
    this.removeColor = false,
    this.denoise = false,
    this.dualScreen = false,
  });

  /// 派生新实例（不可变更新）。
  PdfReaderSettings copyWith({
    int? layoutMode,
    int? cropMode,
    bool? autoCrop,
    double? manualCropLeft,
    double? manualCropRight,
    double? manualCropTop,
    double? manualCropBottom,
    double? brightness,
    double? contrast,
    double? saturation,
    double? colorTemperature,
    bool? removeColor,
    bool? denoise,
    bool? dualScreen,
  }) {
    return PdfReaderSettings(
      layoutMode: layoutMode ?? this.layoutMode,
      cropMode: cropMode ?? this.cropMode,
      autoCrop: autoCrop ?? this.autoCrop,
      manualCropLeft: manualCropLeft ?? this.manualCropLeft,
      manualCropRight: manualCropRight ?? this.manualCropRight,
      manualCropTop: manualCropTop ?? this.manualCropTop,
      manualCropBottom: manualCropBottom ?? this.manualCropBottom,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      colorTemperature: colorTemperature ?? this.colorTemperature,
      removeColor: removeColor ?? this.removeColor,
      denoise: denoise ?? this.denoise,
      dualScreen: dualScreen ?? this.dualScreen,
    );
  }

  /// 是否存在需要重新渲染（裁切）或施加滤镜（颜色矩阵）的视觉调整。
  bool get isAdjusted =>
      cropMode != 0 ||
      autoCrop ||
      manualCropLeft > 0 ||
      manualCropRight > 0 ||
      manualCropTop > 0 ||
      manualCropBottom > 0 ||
      brightness != 1.0 ||
      contrast != 1.0 ||
      saturation != 1.0 ||
      colorTemperature != 1.0 ||
      removeColor ||
      denoise;

  /// 是否需要重新渲染页面（自动裁切、手动/框选裁切与智能去杂色都会改变像素内容，
  /// 颜色调整只改滤镜、不触发重渲染）。
  bool get needsRerender =>
      (cropMode == 1 && autoCrop) ||
      cropMode == 2 ||
      cropMode == 3 ||
      denoise;

  @override
  String toString() {
    return 'PdfReaderSettings(layoutMode:$layoutMode, cropMode:$cropMode, '
        'autoCrop:$autoCrop, manualCropLTRB:($manualCropLeft,$manualCropRight,$manualCropTop,$manualCropBottom), '
        'brightness:$brightness, contrast:$contrast, saturation:$saturation, '
        'colorTemp:$colorTemperature, removeColor:$removeColor, denoise:$denoise, '
        'dualScreen:$dualScreen)';
  }
}
