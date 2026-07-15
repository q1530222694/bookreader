/// PDF 阅读器的视觉设置集合。
///
/// 聚合「布局模式 / 自动裁切 / 背景调节（亮度·对比度·饱和度·去色·去杂色）」，
/// 设计为不可变数据，通过 [copyWith] 派生新实例，便于状态上浮与持久化。
/// 该对象在 [lib/features/shell/ui/book_viewer_page.dart] 中作为渲染依据，
/// 并经 [lib/features/shell/service/pdf_render_service.dart] 解析为实际渲染参数。
class PdfReaderSettings {
  /// 布局模式：
  /// 0 = 单页，1 = 双页，2 = 单页连续，3 = 双页连续
  final int layoutMode;

  /// 自动裁切：去除页面四周空白边距（仅保留少量间隙）
  final bool autoCrop;

  /// 亮度（0.3~1.5，1.0 为原始亮度）
  final double brightness;

  /// 对比度（0.5~2.0，1.0 为原始对比度）
  final double contrast;

  /// 色彩饱和度（0~2.0，1.0 为原始饱和度）
  final double saturation;

  /// 去除颜色：仅显示黑白灰（灰度化）
  final bool removeColor;

  /// 智能去杂色：去除影响阅读的小黑点 / 杂点（轻微高斯模糊近似）
  final bool denoise;

  const PdfReaderSettings({
    this.layoutMode = 0,
    this.autoCrop = false,
    this.brightness = 1.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.removeColor = false,
    this.denoise = false,
  });

  /// 派生新实例（不可变更新）。
  PdfReaderSettings copyWith({
    int? layoutMode,
    bool? autoCrop,
    double? brightness,
    double? contrast,
    double? saturation,
    bool? removeColor,
    bool? denoise,
  }) {
    return PdfReaderSettings(
      layoutMode: layoutMode ?? this.layoutMode,
      autoCrop: autoCrop ?? this.autoCrop,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      removeColor: removeColor ?? this.removeColor,
      denoise: denoise ?? this.denoise,
    );
  }

  /// 是否存在需要重新渲染（裁切）或施加滤镜（颜色矩阵）的视觉调整。
  bool get isAdjusted =>
      autoCrop ||
      brightness != 1.0 ||
      contrast != 1.0 ||
      saturation != 1.0 ||
      removeColor ||
      denoise;

  /// 是否需要重新渲染页面（仅自动裁切会改变像素内容，颜色调整只改滤镜）。
  bool get needsRerender => autoCrop;

  @override
  String toString() {
    return 'PdfReaderSettings(layoutMode:$layoutMode, autoCrop:$autoCrop, '
        'brightness:$brightness, contrast:$contrast, saturation:$saturation, '
        'removeColor:$removeColor, denoise:$denoise)';
  }
}
