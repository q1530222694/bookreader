import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'pdf_ocr_service.dart';

/// 重排结果：已聚合的可重排正文段落 + 是否含有文本层。
class PdfReflowResult {
  /// 按阅读顺序排列的段落文本（已去掉多余空白与连字符续行）。
  final List<String> paragraphs;

  /// 文档是否含有可提取的文本层。
  /// 图片扫描件通常无文本层，需走 OCR（阶段 3）路径，此处标记为 false 供上层提示。
  final bool hasTextLayer;

  const PdfReflowResult({
    required this.paragraphs,
    required this.hasTextLayer,
  });
}

/// 基于 PDF 文本层的「真实重排」提取服务（本地、无网络、Android / PDF 通用）。
///
/// 与旧版「仅改版式为重排」的本质区别：本服务从 PDF 的 [PdfPage.loadText] 文本层
/// 取出按阅读顺序排列的真实字符（[PdfPageText.fullText]），再按「连字符续行 / 句末标点
/// 断段」聚合成段落，交由 [PdfReflowView] 以可调字号 / 行距 / 字距 / 段距重新排版。
///
/// 这是无损、流畅、跨平台的重排方案，适用于绝大多数含文本层的 PDF（电子书 / 论文 / 文档）。
/// 对纯图片扫描件（无文本层），[extract] 返回 [PdfReflowResult.hasTextLayer] = false，
/// 上层据此提示用户改用 OCR（[PdfOcrService] 阶段 3 流水线）。
class PdfTextReflowService {
  PdfTextReflowService._();

  /// 提取整本文档的可重排段落。
  ///
  /// [document] 为已打开的 [PdfDocument]；逐页 [loadText] 后聚合，全部为本地 CPU 运算，
  /// 单次调用即可一次性产出全本段落，重排视图仅做文本布局，阅读滚动保持原生流畅。
  static Future<PdfReflowResult> extract(PdfDocument document) async {
    final paragraphs = <String>[];
    var hasTextLayer = false;

    for (final page in document.pages) {
      final pageText = await page.loadText();
      final full = pageText.fullText;
      if (full.trim().isEmpty) continue;
      hasTextLayer = true;
      _appendPageText(paragraphs, full);
    }

    return PdfReflowResult(
      paragraphs: paragraphs,
      hasTextLayer: hasTextLayer,
    );
  }

  /// 将单页 [fullText] 按续行 / 断段规则聚合进 [paragraphs]。
  static void _appendPageText(List<String> paragraphs, String full) {
    final lines = full
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // 连字符续行：如 "wor-\nd" 合并为 "word"。
      if (line.endsWith('-') && i + 1 < lines.length) {
        buffer.write(line.substring(0, line.length - 1));
        continue;
      }

      if (buffer.isEmpty) {
        buffer.write(line);
      } else {
        buffer.write(' $line');
      }

      final isLast = i == lines.length - 1;
      final endsSentence = _endsWithSentencePunct(line);
      // 句末标点或末行即结束当前段落（中文以 。！？ 断段，英文以 .!? 断段）。
      if (endsSentence || isLast) {
        final text = buffer.toString().trim();
        if (text.isNotEmpty) paragraphs.add(text);
        buffer.clear();
      }
    }
    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) paragraphs.add(tail);
  }

  /// 是否以句末标点结尾（中英文句号 / 叹号 / 问号）。
  static bool _endsWithSentencePunct(String s) {
    if (s.isEmpty) return false;
    final last = s.runes.last;
    return last == 0x2E || // .
        last == 0x21 || // !
        last == 0x3F || // ?
        last == 0x3002 || // 。
        last == 0xFF01 || // ！
        last == 0xFF1F; // ？
  }

  /// 扫描件 OCR 重排：先同步识别前 [eagerPages] 页并立即返回，
  /// 其余页在后台异步续扫，每完成一页经 [onPartial] 回传增量段落；
  /// 全部完成后经 [onDone] 回传是否有页失败（[anyFailed]），供上层弹一次提示。
  ///
  /// 仅用于无文本层的纯图片 PDF（扫描件）。逐页 [render] → [ui.Image] → PNG 字节 →
  /// [PdfOcrService.recognizePage] 得到按阅读顺序排列的文本行，行间以换行拼接后交给
  /// [_appendPageText] 做与文本层一致的续行 / 断段聚合。全部为本地 CPU/NPU 运算，
  /// [onProgress] 回调用于向 UI 上报识别进度（已识别页数 / 总页数）。
  /// 单页识别异常不会中断整体，仅标记该页失败并继续后续页。
  static Future<PdfReflowResult> extractOcr(
    PdfDocument document, {
    void Function(int current, int total)? onProgress,
    int eagerPages = 3,
    void Function(PdfReflowResult partial)? onPartial,
    void Function(bool anyFailed)? onDone,
  }) async {
    final paragraphs = <String>[];
    final total = document.pages.length;
    var anyFailed = false;
    // 前 eagerPages 页：同步识别，结果立即返回（页面级）。
    final syncEnd = eagerPages < total ? eagerPages : total;
    for (var i = 0; i < syncEnd; i++) {
      final ok = await _ocrOnePage(document, i, total, paragraphs, onProgress);
      if (!ok) anyFailed = true;
    }
    // 立即把前 N 页内容返回，UI 立刻可阅读。
    // 其余页用「立即调用异步闭包」丢到事件循环后台续扫（fire-and-forget）。
    () async {
      // 其余页：后台异步续扫，每完成一页回传增量快照（独立副本避免并发读改写）。
      for (var i = syncEnd; i < total; i++) {
        final ok = await _ocrOnePage(document, i, total, paragraphs, onProgress);
        if (!ok) anyFailed = true;
        onPartial?.call(
          PdfReflowResult(
            paragraphs: List.from(paragraphs),
            hasTextLayer: false,
          ),
        );
      }
      onDone?.call(anyFailed);
    }();
    return PdfReflowResult(
      paragraphs: List.from(paragraphs),
      hasTextLayer: false,
    );
  }

  /// 单页 OCR：渲染 → 识别 → 聚合段落。[paragraphs] 为累积段落（原地追加）。
  /// 返回 true 表示该页成功（含因空白 / 空图被跳过的情况），
  /// 返回 false 表示该页识别异常（已捕获，由调用方决定是否弹提示）。
  static Future<bool> _ocrOnePage(
    PdfDocument document,
    int i,
    int total,
    List<String> paragraphs,
    void Function(int current, int total)? onProgress,
  ) async {
    final page = document.pages[i];
    final pw = page.width;
    final ph = page.height;
    if (pw <= 0 || ph <= 0) {
      onProgress?.call(i + 1, total);
      return true;
    }
    // 渲染宽度取页面 2 倍但上限 1080，兼顾清晰度与性能。
    final double effW = (pw * 2).clamp(300, 1080).toDouble();
    final double fullH = effW * ph / pw;
    final PdfImage? img = await page.render(
      fullWidth: effW,
      fullHeight: fullH,
      backgroundColor: Colors.white,
    );
    if (img == null) {
      onProgress?.call(i + 1, total);
      return true;
    }
    final ui.Image uiImg = await img.createImage();
    img.dispose();
    final png = await uiImg.toByteData(format: ui.ImageByteFormat.png);
    uiImg.dispose();
    if (png == null) {
      onProgress?.call(i + 1, total);
      return true;
    }
    try {
      final lines = await PdfOcrService.recognizePage(
        png.buffer.asUint8List(),
      );
      // 用「带位置的几何段落重建」而非纯文本聚合：扫描件靠 bbox 判断段落边界、
      // 阅读顺序、页眉页脚，效果远好于对 OCR 结果套用文本层的标点断段规则。
      if (lines.isNotEmpty) {
        _appendOcrLines(paragraphs, lines, fullH);
      }
      onProgress?.call(i + 1, total);
      return true;
    } catch (e) {
      // 该页识别失败：标记失败并继续后续页（不中断整体）。
      onProgress?.call(i + 1, total);
      return false;
    }
  }

  /// OCR 专用「几何段落重建」（仅适用于单栏为主的版式）。
  ///
  /// 与文本层的 [_appendPageText] 本质不同：扫描件没有真实换行/段落语义，
  /// 只有一堆带位置的识别行（[OcrTextLine.polygon]，坐标在渲染图空间）。
  /// 本方法用每行的包围盒（left/top/right/bottom）按几何规则重建段落，解决
  /// 「段落太碎 / 中文夹空格 / 阅读顺序乱 / 页眉页脚图注混入」四类布局问题：
  /// - 阅读顺序：单栏按行顶 y 升序（同一行内识别阶段已左→右排好）；
  /// - 段落边界：行间距突变、首行缩进、上一行未排满、字号变大（标题）任一命中即断段；
  /// - 中文夹空格：合并行时中文直接拼接，仅西文单词间补空格，并处理英文连字符续行；
  /// - 页眉页脚页码：位于页面顶/底 band 内且很短或纯数字/罗马数字的孤立行直接丢弃。
  ///
  /// [pageH] 为该页渲染图高度，用于判定页眉页脚 band。
  static void _appendOcrLines(
    List<String> paragraphs,
    List<OcrTextLine> lines,
    double pageH,
  ) {
    // 1) 抽取每行几何信息（由 4 顶点求轴对齐包围盒）。
    final items = <_LineBox>[];
    for (final l in lines) {
      final text = l.text.trim();
      if (text.isEmpty) continue;
      double minX = double.infinity, minY = double.infinity;
      double maxX = -double.infinity, maxY = -double.infinity;
      for (final p in l.polygon) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
      items.add(_LineBox(text, minX, minY, maxX, maxY));
    }
    if (items.isEmpty) return;
    // 单栏：按行顶 y 升序（阅读顺序）。
    items.sort((a, b) => a.top.compareTo(b.top));

    // 2) 稳健统计：中位行高、正文左/右边界（中位数抗噪声）。
    double median(List<double> v) {
      final s = [...v]..sort();
      return s[s.length ~/ 2];
    }

    final medH = median(items.map((e) => e.height).toList());
    final bodyLeft = median(items.map((e) => e.left).toList());
    final bodyRight = median(items.map((e) => e.right).toList());

    // 3) 过滤页眉/页脚/页码：
    // - 顶部（行首在 topBand 内）：仅删纯数字/罗马数字页码，避免误删顶部短标题/书名；
    // - 底部（行尾在 botBand 内）：删很短或纯数字/罗马数字的孤立行（页码、页脚注）；
    // - 且始终排除大字号行（标题即使落在 band 内也保留）。
    final topBand = pageH * 0.08;
    final botBand = pageH * 0.92;
    final numLike = RegExp(r'^[\divxlcIVXLC.\-—\s]+$');
    final kept = <_LineBox>[];
    for (final it in items) {
      final isBig = it.height > medH * 1.25; // 大字号→标题，永不当页眉页脚删
      final isNum = numLike.hasMatch(it.text);
      final isShort = it.text.runes.length <= 6;
      final inHeader = it.top < topBand;
      final inFooter = it.bottom > botBand;
      var drop = false;
      if (!isBig) {
        if (inHeader && isNum) {
          drop = true; // 顶部页码
        } else if (inFooter && (isShort || isNum)) {
          drop = true; // 底部页码 / 页脚注
        }
      }
      if (drop) continue;
      kept.add(it);
    }
    if (kept.isEmpty) return;

    // 4) 逐行合并成段：几何规则判断段落边界。
    final buffer = StringBuffer();
    void flush() {
      final t = buffer.toString().trim();
      if (t.isNotEmpty) paragraphs.add(t);
      buffer.clear();
    }

    _LineBox? prev;
    for (final it in kept) {
      final isTitle = it.height > medH * 1.4; // 字号明显偏大→标题，独立成段
      var newPara = false;
      if (prev == null || isTitle) {
        newPara = true;
      } else {
        final gap = it.top - prev.bottom; // 行间垂直空白
        final indented = it.left > bodyLeft + medH * 0.8; // 首行缩进
        final prevShort = prev.right < bodyRight - medH * 1.5; // 上一行未排满=段末
        if (gap > medH * 0.7 || indented || prevShort) newPara = true;
      }
      if (newPara && buffer.isNotEmpty) flush();
      _joinLine(buffer, it.text);
      if (isTitle) flush(); // 标题单独成段，不与后续正文粘连
      prev = it;
    }
    flush();
  }

  /// 行合并：中文（CJK）直接拼接，仅西文单词间补空格；
  /// 处理英文连字符续行（行尾 '-' 去掉后与下一行直接相连）。
  static void _joinLine(StringBuffer buffer, String line) {
    if (buffer.isEmpty) {
      buffer.write(line);
      return;
    }
    final prevStr = buffer.toString();
    final lastCh = prevStr.runes.last;
    // 英文连字符续行：上一行以 '-' 结尾且下一行以拉丁字符开头 → 去 '-' 直接连。
    if (lastCh == 0x2D && _isLatin(line.runes.first)) {
      buffer
        ..clear()
        ..write(prevStr.substring(0, prevStr.length - 1))
        ..write(line);
      return;
    }
    final firstCh = line.runes.first;
    if (_isLatin(lastCh) && _isLatin(firstCh)) {
      buffer.write(' $line'); // 西文单词间需空格
    } else {
      buffer.write(line); // 中文/标点直接拼，避免夹空格
    }
  }

  /// 是否为拉丁字母或数字（判断两侧是否需要补空格）。
  static bool _isLatin(int r) =>
      (r >= 0x30 && r <= 0x39) || // 0-9
      (r >= 0x41 && r <= 0x5A) || // A-Z
      (r >= 0x61 && r <= 0x7A); // a-z
}

/// OCR 单行的轴对齐包围盒 + 文本（[_appendOcrLines] 内部用的几何重建单元）。
class _LineBox {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  _LineBox(this.text, this.left, this.top, this.right, this.bottom);

  /// 行高（用于中位行高统计与标题/缩进/段距阈值）。
  double get height => bottom - top;
}
