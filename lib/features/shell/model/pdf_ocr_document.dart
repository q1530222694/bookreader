/// 结构化 OCR 文档模型（扫描件重排的数据骨架）。
///
/// 与旧版「扁平 List 段落」不同，这里保留每页的原扫描位图 + 按位置排布的文本行
/// + 图片块，使阅读层能像 ePub 那样逐页呈现「原图底 + 文字层叠加」，并支持
/// 对图片区域跳过 OCR、对用户编辑结果落盘。所有字段均为可 JSON 序列化类型。

/// 单条 OCR 文本行（在页面渲染图坐标系内）。
class PdfOcrTextSegment {
  /// 识别文本（已剔除空行；含标题、正文、图注等）。
  final String text;

  /// 该文本行在渲染图中的轴对齐包围盒（left/top/right/bottom，单位=渲染图像素）。
  final double left;
  final double top;
  final double right;
  final double bottom;

  /// 识别平均置信度（0~1），供 UI 可选标灰低置信文本。
  final double score;

  /// 版面类型：由 Layout 分析模型标注（'text' 正文 / 'title' 标题 等）。
  /// 阅读层据此对标题做差异化渲染（大字号 + 加粗 + 独立段距），详见
  /// [pdf_ocr_service.dart] 的 [PdfOcrService.runLayoutAnalysis] 路由逻辑。
  final String layoutType;

  const PdfOcrTextSegment({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.score = 0.0,
    this.layoutType = 'text',
  });

  /// 是否为标题（供 UI 差异化渲染）。由 Layout 模型标注 'title' 时为真。
  bool get isTitle => layoutType == 'title';

  double get width => right - left;
  double get height => bottom - top;

  Map<String, dynamic> toJson() => {
        't': text,
        'l': left,
        'tp': top,
        'r': right,
        'b': bottom,
        's': score,
        'ly': layoutType, // 新增：版面类型（标题/正文等）
      };

  factory PdfOcrTextSegment.fromJson(Map<String, dynamic> j) => PdfOcrTextSegment(
        text: j['t'] as String,
        left: (j['l'] as num).toDouble(),
        top: (j['tp'] as num).toDouble(),
        right: (j['r'] as num).toDouble(),
        bottom: (j['b'] as num).toDouble(),
        score: (j['s'] as num? ?? 0.0).toDouble(),
        // 旧缓存（v2 及之前）缺省按正文处理，保证向后兼容、不崩溃。
        layoutType: (j['ly'] as String?) ?? 'text',
      );
}

/// 图片块：检测到的大面积非文本区域（如插图、照片），本轮**不做 OCR**，
/// 阅读层直接从原扫描图对应区域裁剪内联展示（满足「图片不识别、缩放到对应位置」）。
///
/// 后续可扩展为表格/公式等分类型（[kind]='image'/'table'/'formula'），本轮仅用 image。
class PdfOcrImageBlock {
  /// 区域类型：'image'（插图/照片）。下轮可加 'table'/'formula'。
  final String kind;

  /// 区域包围盒（渲染图坐标）。
  final double left;
  final double top;
  final double right;
  final double bottom;

  const PdfOcrImageBlock({
    required this.kind,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;

  Map<String, dynamic> toJson() => {
        'k': kind,
        'l': left,
        'tp': top,
        'r': right,
        'b': bottom,
      };

  factory PdfOcrImageBlock.fromJson(Map<String, dynamic> j) => PdfOcrImageBlock(
        kind: (j['k'] as String?) ?? 'image',
        left: (j['l'] as num).toDouble(),
        top: (j['tp'] as num).toDouble(),
        right: (j['r'] as num).toDouble(),
        bottom: (j['b'] as num).toDouble(),
      );
}

/// 单页 OCR 结果（结构化）。
class PdfOcrPageData {
  /// 页码（1-based），便于与 PdfDocument 对齐与缓存定位。
  final int pageIndex;

  /// 该页原扫描渲染图（PNG 字节），作阅读层底图；空表示未渲染（由阅读层自行渲染）。
  final String? pageImageBase64;

  /// 按阅读顺序（top 升序、单栏自左向右）排布的文本行。
  final List<PdfOcrTextSegment> segments;

  /// 图片块（跳过 OCR 的内联区域）。
  final List<PdfOcrImageBlock> images;

  const PdfOcrPageData({
    required this.pageIndex,
    this.pageImageBase64,
    this.segments = const [],
    this.images = const [],
  });

  Map<String, dynamic> toJson() => {
        'p': pageIndex,
        'img': pageImageBase64,
        'seg': segments.map((s) => s.toJson()).toList(),
        'imgb': images.map((b) => b.toJson()).toList(),
      };

  factory PdfOcrPageData.fromJson(Map<String, dynamic> j) => PdfOcrPageData(
        pageIndex: j['p'] as int,
        pageImageBase64: j['img'] as String?,
        segments: (j['seg'] as List?)
                ?.map((e) => PdfOcrTextSegment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        images: (j['imgb'] as List?)
                ?.map((e) => PdfOcrImageBlock.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// 整本文档的 OCR 结构化结果（可落盘缓存）。
class PdfOcrDocument {
  /// 数据源键（由文件路径派生的稳定标识，见 [PdfOcrCacheService]）。
  final String sourceKey;

  /// 生成时间（毫秒），用于缓存新鲜度判断。
  final int createdAt;

  final List<PdfOcrPageData> pages;

  const PdfOcrDocument({
    required this.sourceKey,
    required this.createdAt,
    required this.pages,
  });

  /// 是否来自本地缓存（由阅读层据此决定是否需要后台补识别）。
  bool get isFromCache => sourceKey.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'key': sourceKey,
        'ts': createdAt,
        'pages': pages.map((p) => p.toJson()).toList(),
      };

  factory PdfOcrDocument.fromJson(Map<String, dynamic> j) => PdfOcrDocument(
        sourceKey: j['key'] as String? ?? '',
        createdAt: (j['ts'] as num?)?.toInt() ?? 0,
        pages: (j['pages'] as List? ?? [])
            .map((e) => PdfOcrPageData.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
