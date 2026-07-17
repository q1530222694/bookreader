/// 扫描件质检（OQC）单页结果。
///
/// 由 [PdfOqcService] 对逐页渲染图做像素统计得出。所有判定均为启发式（纯 Dart、
/// 无模型），适用于扫描件 PDF 的整本快速体检。
class PdfOqcPageResult {
  /// 页码（1-based）。
  final int pageNumber;

  /// 是否空白页（暗点占比过低，整页几乎无内容）。
  final bool isBlank;

  /// 清晰度评分（0~100，越高越清晰；由边缘能量归一化得出）。
  final int blurScore;

  /// 是否模糊页（清晰度评分低于阈值）。
  final bool isBlurry;

  /// 是否存在明显黑边（四周暗带占比显著高于页面内部）。
  final bool hasBlackMargin;

  /// 估计倾斜角度（度，带符号，绝对值越大越倾斜；0 表示基本不倾斜）。
  final double skewAngle;

  /// 是否疑似重影 / 双影（内容在水平方向存在周期性重复残差）。
  final bool hasGhost;

  const PdfOqcPageResult({
    required this.pageNumber,
    this.isBlank = false,
    this.blurScore = 100,
    this.isBlurry = false,
    this.hasBlackMargin = false,
    this.skewAngle = 0.0,
    this.hasGhost = false,
  });

  /// 该页是否存在需要关注的问题（用于列表高亮与概览计数）。
  bool get hasIssue =>
      isBlank ||
      isBlurry ||
      hasBlackMargin ||
      hasGhost ||
      skewAngle.abs() > 2.0;
}

/// 扫描件质检（OQC）整本报告。
class PdfOqcReport {
  final List<PdfOqcPageResult> pages;

  const PdfOqcReport({required this.pages});

  int get totalPages => pages.length;
  int get blankCount => pages.where((p) => p.isBlank).length;
  int get blurryCount => pages.where((p) => p.isBlurry).length;
  int get marginCount => pages.where((p) => p.hasBlackMargin).length;
  int get ghostCount => pages.where((p) => p.hasGhost).length;
  int get issueCount => pages.where((p) => p.hasIssue).length;

  /// 全本最大倾斜绝对值（度）。
  double get maxSkew =>
      pages.fold(0.0, (m, p) => p.skewAngle.abs() > m ? p.skewAngle.abs() : m);
}
