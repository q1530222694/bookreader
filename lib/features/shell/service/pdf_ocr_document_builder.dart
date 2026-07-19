import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:pdfrx/pdfrx.dart';

import '../model/pdf_ocr_document.dart';
import 'pdf_ocr_cache_service.dart';
import 'pdf_ocr_service.dart';

export '../model/pdf_ocr_document.dart';

/// 结构化 OCR 文档组装器：把 [PdfDocument] 逐页识别为 [PdfOcrDocument]。
///
/// 与旧版「扁平段落」不同，这里保留每页的原扫描位图 + 按位置排布的文本行 + 图片块，
/// 使阅读层能逐页呈现「原图底 + 文字层叠加」，并支持图片区域**跳过 OCR** 直接内联。
///
/// 取消 / 缓存 / 逐页回调均由本类统一编排：
/// - [cancelled] 在每次重量操作前检查，被取消则立即中止（解决「停不下来」）；
/// - [onPage] 每完成一页即回调结构化页数据，上层据此增量落盘 + 刷新视图；
/// - 跨页页码（纯数字、固定位置、多页重复出现）被识别并剔除，解决「页码混入正文」。
class PdfOcrDocumentBuilder {
  PdfOcrDocumentBuilder._();

  /// 渲染宽度：页面宽 2 倍、下限 300、上限 1080（兼顾清晰度与性能）。
  static double _effWidth(double pageW) =>
      (pageW * 2).clamp(300, 1080).toDouble();

  /// 组装整本文档。
  ///
  /// [document] 已打开的 [PdfDocument]；[sourceKey] 为缓存键（见
  /// [PdfOcrCacheService.computeKey]）；[eagerPages] 为同步优先识别的页数（其余后台续）；
  /// [cancelled] 取消判断（每次重量操作前调用，返回 true 即中止）；
  /// [onProgress]/[onPage] 分别用于进度上报与逐页增量回调。
  /// 返回组装完成（或被取消前已处理）的 [PdfOcrDocument]。
  static Future<PdfOcrDocument> build(
    PdfDocument document,
    String sourceKey, {
    int eagerPages = 3,
    bool Function()? cancelled,
    void Function(int current, int total)? onProgress,
    void Function(PdfOcrPageData page)? onPage,
  }) async {
    final total = document.pages.length;
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final doc = PdfOcrDocument(
      sourceKey: sourceKey,
      createdAt: createdAt,
      pages: <PdfOcrPageData>[], // 可增长列表：后续逐页 add，禁用 const []（不可修改）
    );
    final syncEnd = eagerPages < total ? eagerPages : total;

    // 1) 同步优先识别前 N 页（立即有内容）。
    for (var i = 0; i < syncEnd; i++) {
      if (cancelled?.call() == true) return doc;
      final page = await _buildPage(document, i, total, onProgress);
      if (page != null) {
        doc.pages.add(page);
        onPage?.call(page);
      }
    }
    // 2) 其余页后台续扫（fire-and-forget 由调用方控制；这里同步写完剩余，
    //    逐页经 onPage 增量回传，便于上层边识别边刷新 + 增量落盘）。
    for (var i = syncEnd; i < total; i++) {
      if (cancelled?.call() == true) return doc;
      final page = await _buildPage(document, i, total, onProgress);
      if (page != null) {
        doc.pages.add(page);
        onPage?.call(page);
      }
    }
    return doc;
  }

  /// 组装单页：渲染 → 检测 → 图片块识别（跳过 OCR）→ 文本行识别 → 几何段落。
  static Future<PdfOcrPageData?> _buildPage(
    PdfDocument document,
    int index,
    int total,
    void Function(int current, int total)? onProgress,
  ) async {
    final page = document.pages[index];
    final pw = (page.width as num).toDouble();
    final ph = (page.height as num).toDouble();
    if (pw <= 0 || ph <= 0) {
      onProgress?.call(index + 1, total);
      return null;
    }
    final effW = _effWidth(pw);

    // 渲染原页为 PNG（白底），既作底图也供图片内联裁剪。
    final png = await PdfOcrService.renderPageToPng(page, effW);
    if (png == null) {
      onProgress?.call(index + 1, total);
      return null;
    }
    final ui.Image uiImg = await decodeImageFromList(png);
    final rgba = (await uiImg.toByteData(format: ui.ImageByteFormat.rawRgba))
        ?.buffer
        .asUint8List();
    uiImg.dispose();
    if (rgba == null) {
      onProgress?.call(index + 1, total);
      return null;
    }
    final w = uiImg.width;
    final h = uiImg.height;

    // DB 文本检测（概率图）。
    final (scores, newW, newH) = await PdfOcrService.detectPage(
      rgba,
      w,
      h,
    );
    // 图片块：整行无文本的大块（跳过 OCR，阅读层内联原图）。
    final imgBlocks = PdfOcrService.detectImageBlocks(
      scores,
      newW,
      newH,
      rgba,
      w,
      h,
    );
    // 文本行：在检测概率图上做连通域 → 轴对齐框。
    final polys = _boxesFromScores(scores, newW, newH, w, h, imgBlocks);
    final segments = <PdfOcrTextSegment>[];
    for (final poly in polys) {
      final crop = PdfOcrService.cropAxisAlignedPublic(rgba, w, h, poly);
      if (crop == null) continue;
      final decoded = await PdfOcrService.recognizeCrop(
        crop.bytes,
        crop.width,
        crop.height,
      );
      final text = decoded.text.trim();
      if (text.isEmpty) continue;
      segments.add(
        PdfOcrTextSegment(
          text: text,
          left: poly[0].dx,
          top: poly[0].dy,
          right: poly[2].dx,
          bottom: poly[2].dy,
          score: decoded.score,
        ),
      );
    }
    onProgress?.call(index + 1, total);

    return PdfOcrPageData(
      pageIndex: index + 1,
      pageImageBase64: base64Encode(png),
      segments: segments,
      images: imgBlocks
          .map(
            (b) => PdfOcrImageBlock(
              kind: 'image',
              left: b.left,
              top: b.top,
              right: b.right,
              bottom: b.bottom,
            ),
          )
          .toList(),
    );
  }

  /// 由检测概率图（缩放后空间）经 4 邻接连通域得到文本行轴对齐包围盒。
  /// [imgBlocks] 为已判定的图片块，与其重叠的检测框直接丢弃（避免对图片内伪文本做 OCR）。
  static List<List<ui.Offset>> _boxesFromScores(
    Float32List scores,
    int newW,
    int newH,
    int origW,
    int origH,
    List<({double left, double top, double right, double bottom})> imgBlocks,
  ) {
    const thresh = 0.3;
    const boxThresh = 0.5;
    const minArea = 10;
    const unclip = 1.6;
    final binary = Uint8List(newW * newH);
    for (var i = 0; i < scores.length; i++) {
      binary[i] = scores[i] >= thresh ? 1 : 0;
    }
    final visited = Uint8List(newW * newH);
    final scaleX = origW / newW;
    final scaleY = origH / newH;
    final boxes = <List<ui.Offset>>[];

    // 与图片块相交的检测框直接跳过（那些是图内伪文字）。
    bool overlapsImage(int minX, int minY, int maxX, int maxY) {
      final x0 = minX * scaleX;
      final y0 = minY * scaleY;
      final x1 = (maxX + 1) * scaleX;
      final y1 = (maxY + 1) * scaleY;
      for (final b in imgBlocks) {
        if (x0 < b.right && x1 > b.left && y0 < b.bottom && y1 > b.top) {
          return true;
        }
      }
      return false;
    }

    final queue = <int>[];
    for (var start = 0; start < binary.length; start++) {
      if (binary[start] == 0 || visited[start] == 1) continue;
      queue.clear();
      queue.add(start);
      visited[start] = 1;
      var sumScore = 0.0;
      var area = 0;
      var minX = newW, minY = newH, maxX = 0, maxY = 0;
      while (queue.isNotEmpty) {
        final p = queue.removeLast();
        final px = p % newW;
        final py = p ~/ newW;
        area++;
        sumScore += scores[p];
        if (px < minX) minX = px;
        if (px > maxX) maxX = px;
        if (py < minY) minY = py;
        if (py > maxY) maxY = py;
        if (px > 0) _tryEnqueue(p - 1, binary, visited, queue);
        if (px < newW - 1) _tryEnqueue(p + 1, binary, visited, queue);
        if (py > 0) _tryEnqueue(p - newW, binary, visited, queue);
        if (py < newH - 1) _tryEnqueue(p + newW, binary, visited, queue);
      }
      if (area < minArea) continue;
      if (sumScore / area < boxThresh) continue;
      if (overlapsImage(minX, minY, maxX, maxY)) continue;
      final bw = (maxX - minX + 1).toDouble();
      final bh = (maxY - minY + 1).toDouble();
      final dist = bw * bh * unclip / (2 * (bw + bh));
      final exMinX = (minX - dist).clamp(0.0, (newW - 1).toDouble());
      final exMinY = (minY - dist).clamp(0.0, (newH - 1).toDouble());
      final exMaxX = (maxX + 1 + dist).clamp(1.0, newW.toDouble());
      final exMaxY = (maxY + 1 + dist).clamp(1.0, newH.toDouble());
      boxes.add([
        ui.Offset(exMinX * scaleX, exMinY * scaleY),
        ui.Offset(exMaxX * scaleX, exMinY * scaleY),
        ui.Offset(exMaxX * scaleX, exMaxY * scaleY),
        ui.Offset(exMinX * scaleX, exMaxY * scaleY),
      ]);
    }
    return boxes;
  }

  static void _tryEnqueue(
    int p,
    Uint8List binary,
    Uint8List visited,
    List<int> queue,
  ) {
    if (binary[p] == 1 && visited[p] == 0) {
      visited[p] = 1;
      queue.add(p);
    }
  }

  /// 跨页页眉/页脚/页码剔除：用**位置桶**而非「完全相同文本」判定——
  /// 真实页码每页递增（"7"/"8"/"9"），不会完全相同，但**出现位置固定**
  /// （顶部/底部）。本方法把每页纵向均分为若干桶，统计「位于顶/底桶、样式像页码
  /// （纯数字/罗马数字/带点划）、且跨 >=2 页出现在同一桶」的文本，判为页眉页脚
  /// 并从各页剔除（解决「页码混入正文」）。
  ///
  /// [doc] 会被原地修改。调用时机：所有页识别完成后、交给阅读层前。
  static void suppressPageNumbers(PdfOcrDocument doc) {
    if (doc.pages.isEmpty) return;
    final numLike = RegExp(r'^[0-9IVXLCDM.\-—\s]+$');
    const buckets = 8; // 纵向等分红 8 桶
    // 位置桶 → 出现过的页码（顶/底桶才收集，避免误杀正文短行）。
    final posPages = <int, Set<int>>{};
    final pnumTexts = <int, Set<String>>{};
    for (var pi = 0; pi < doc.pages.length; pi++) {
      final page = doc.pages[pi];
      final ph = page.segments.isEmpty ? 1.0 : page.segments.map((s) => s.bottom).reduce(math.max);
      for (final seg in page.segments) {
        final t = seg.text.trim();
        if (t.length > 6) continue;
        if (!numLike.hasMatch(t)) continue;
        final b = (seg.top / ph * buckets).floor().clamp(0, buckets - 1);
        posPages.putIfAbsent(b, () => <int>{}).add(pi);
        if (b == 0 || b == buckets - 1) {
          pnumTexts.putIfAbsent(b, () => <String>{}).add(t);
        }
      }
    }
    final suppress = <String>{};
    for (final e in posPages.entries) {
      if (e.value.length >= 2 && (e.key == 0 || e.key == buckets - 1)) {
        suppress.addAll(pnumTexts[e.key] ?? const {});
      }
    }
    if (suppress.isEmpty) return;
    for (final page in doc.pages) {
      page.segments.removeWhere((seg) => suppress.contains(seg.text.trim()));
    }
  }
}
