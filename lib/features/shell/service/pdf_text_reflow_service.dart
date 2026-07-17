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

  /// 扫描件 OCR 重排：逐页渲染为位图并经 [PdfOcrService] 识别，复用文本层聚合逻辑产出段落。
  ///
  /// 仅用于无文本层的纯图片 PDF（扫描件）。逐页 [render] → [ui.Image] → PNG 字节 →
  /// [PdfOcrService.recognizePage] 得到按阅读顺序排列的文本行，行间以换行拼接后交给
  /// [_appendPageText] 做与文本层一致的续行 / 断段聚合。全部为本地 CPU/NPU 运算，
  /// [onProgress] 回调用于向 UI 上报识别进度（已识别页数 / 总页数）。
  /// 模型缺失或识别失败时抛错，由上层捕获提示。
  static Future<PdfReflowResult> extractOcr(
    PdfDocument document, {
    void Function(int current, int total)? onProgress,
  }) async {
    final paragraphs = <String>[];
    final total = document.pages.length;
    for (var i = 0; i < total; i++) {
      final page = document.pages[i];
      final pw = page.width;
      final ph = page.height;
      if (pw <= 0 || ph <= 0) {
        onProgress?.call(i + 1, total);
        continue;
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
        continue;
      }
      final ui.Image uiImg = await img.createImage();
      img.dispose();
      final png = await uiImg.toByteData(format: ui.ImageByteFormat.png);
      uiImg.dispose();
      if (png == null) {
        onProgress?.call(i + 1, total);
        continue;
      }
      final lines = await PdfOcrService.recognizePage(
        png.buffer.asUint8List(),
      );
      final pageText = lines.map((l) => l.text).join('\n');
      if (pageText.trim().isNotEmpty) _appendPageText(paragraphs, pageText);
      onProgress?.call(i + 1, total);
    }
    return PdfReflowResult(paragraphs: paragraphs, hasTextLayer: false);
  }
}
