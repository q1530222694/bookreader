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
    // 版面模型是否齐备：决定逐页走「模型分类 + 路由分发」还是旧版行带回退。
    final useLayout = await PdfOcrService.isLayoutModelAvailable();
    final doc = PdfOcrDocument(
      sourceKey: sourceKey,
      createdAt: createdAt,
      pages: <PdfOcrPageData>[], // 可增长列表：后续逐页 add，禁用 const []（不可修改）
    );
    final syncEnd = eagerPages < total ? eagerPages : total;

    // 1) 同步优先识别前 N 页（立即有内容）。
    for (var i = 0; i < syncEnd; i++) {
      if (cancelled?.call() == true) return doc;
      PdfOcrPageData? page;
      try {
        page = await _buildPage(document, i, total, onProgress,
            useLayout: useLayout);
      } catch (_) {
        page = null; // 单页异常不中断整本文档
      }
      if (page != null) {
        doc.pages.add(page);
        onPage?.call(page);
      }
    }
    // 2) 其余页后台续扫（fire-and-forget 由调用方控制；这里同步写完剩余，
    //    逐页经 onPage 增量回传，便于上层边识别边刷新 + 增量落盘）。
    for (var i = syncEnd; i < total; i++) {
      if (cancelled?.call() == true) return doc;
      PdfOcrPageData? page;
      try {
        page = await _buildPage(document, i, total, onProgress,
            useLayout: useLayout);
      } catch (_) {
        page = null; // 单页异常不中断整本文档
      }
      if (page != null) {
        doc.pages.add(page);
        onPage?.call(page);
      }
    }
    return doc;
  }

  /// 组装单页：渲染原图 → 版面分析路由（模型）或旧版行带回退 → 组装结构化页。
  ///
  /// [useLayout] 为 true 时走 Layout 模型分类 + 路由分发（图表整块 / 文本区域 OCR /
  /// 页眉页脚丢弃）；为 false 或 Layout 本页推理异常时回退旧版「行带整块裁剪」流程。
  static Future<PdfOcrPageData?> _buildPage(
    PdfDocument document,
    int index,
    int total,
    void Function(int current, int total)? onProgress, {
    bool useLayout = false,
  }) async {
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

    // 模型路由优先；若 Layout 不可用或本页推理异常，回退旧版行带流程。
    final result = useLayout
        ? (await _buildByLayout(rgba, w, h)) ??
            (await _buildByLegacy(rgba, w, h))
        : (await _buildByLegacy(rgba, w, h));

    onProgress?.call(index + 1, total);
    return PdfOcrPageData(
      pageIndex: index + 1,
      pageImageBase64: base64Encode(png),
      segments: result.segments,
      images: result.images,
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

  /// 混合路由（版面模型分类 + 整页文本检测）：文本覆盖率由整页 DB 检测保证，
  /// 图表以 Layout 模型输出为主，并叠加行带算法作「互补图块探测器」补回 Layout
  /// 漏检的图（整块、不切碎，IoU 去重后并入），页眉/页脚/页码（'Drop'）区文字
  /// 丢弃，Title 区文字标记标题。模型缺失或推理异常时返回 null，交由 [_buildPage]
  /// 回退旧版行带流程。
  static Future<
          ({
            List<PdfOcrTextSegment> segments,
            List<PdfOcrImageBlock> images
          })?>
      _buildByLayout(Uint8List rgba, int w, int h) async {
    List<LayoutBox> boxes;
    try {
      boxes = await PdfOcrService.runLayoutAnalysis(rgba, w, h);
    } catch (_) {
      return null; // 模型缺失或异常，回退旧版
    }

    final figureBoxes = <LayoutBox>[];
    final suppressBoxes = <LayoutBox>[];
    final titleBoxes = <LayoutBox>[];
    final textBoxes = <LayoutBox>[]; // 正文文本块（XY-Cut 阅读顺序用）

    for (final b in boxes) {
      switch (b.label) {
        case 'Figure':
        case 'Table':
          figureBoxes.add(b);
          break;
        case 'Drop':
          suppressBoxes.add(b);
          break;
        case 'Title':
          titleBoxes.add(b);
          break;
        case 'Text':
          textBoxes.add(b);
          break;
      }
    }

    // 依然跑全页检测，保证正文文字不漏检
    final (scores, newW, newH) = await PdfOcrService.detectPage(rgba, w, h);

    // 图表以 Layout 模型为主；下方再用 detectImageBlocks 互补补回漏检图（不切碎）
    final suppressAll = <({double left, double top, double right, double bottom})>[
      for (final b in figureBoxes)
        (left: b.left, top: b.top, right: b.right, bottom: b.bottom),
      for (final b in suppressBoxes)
        (left: b.left, top: b.top, right: b.right, bottom: b.bottom),
    ];

    final polys = _boxesFromScores(scores, newW, newH, w, h, suppressAll);
    final segments = <PdfOcrTextSegment>[];

    for (final poly in polys) {
      final crop = PdfOcrService.cropAxisAlignedPublic(rgba, w, h, poly);
      if (crop == null) continue;

      ({String text, double score}) decoded;
      try {
        decoded = await PdfOcrService.recognizeCrop(
          crop.bytes,
          crop.width,
          crop.height,
        );
      } catch (_) {
        continue;
      }

      final text = decoded.text.trim();
      if (text.isEmpty) continue;

      final cx = (poly[0].dx + poly[2].dx) / 2;
      final cy = (poly[0].dy + poly[2].dy) / 2;

      // 页眉/页脚区直接丢弃文本
      if (_pointInAny(cx, cy, suppressBoxes)) continue;

      final isTitle = _pointInAny(cx, cy, titleBoxes);
      segments.add(PdfOcrTextSegment(
        text: text,
        left: poly[0].dx,
        top: poly[0].dy,
        right: poly[2].dx,
        bottom: poly[2].dy,
        score: decoded.score,
        layoutType: isTitle ? 'title' : 'text',
      ));
    }

    // 互补图块探测器：Layout 模型漏检的图表由行带算法补回（整块，不切碎）。
    // Layout 图框为主，互补框仅填充漏检洞；与 Layout 图框/抑制区高重叠、或
    // 被正文大量覆盖的伪图块跳过，避免把页眉 logo 或纯文字块当图。
    final complement = PdfOcrService.detectImageBlocks(
      scores,
      newW,
      newH,
      rgba,
      w,
      h,
    );
    final extraImages = <PdfOcrImageBlock>[];
    for (final c in complement) {
      // 与 Layout 图框去重（保留 Layout 为主）
      var dup = false;
      for (final f in figureBoxes) {
        if (_iouRect(c.left, c.top, c.right, c.bottom, f.left, f.top, f.right, f.bottom) > 0.5) {
          dup = true;
          break;
        }
      }
      if (dup) continue;
      // 与页眉/页脚/页码抑制区重叠的跳过（避免把页眉 logo 当图）
      var inSuppress = false;
      for (final s in suppressBoxes) {
        if (_iouRect(c.left, c.top, c.right, c.bottom, s.left, s.top, s.right, s.bottom) > 0.5) {
          inSuppress = true;
          break;
        }
      }
      if (inSuppress) continue;
      // 被正文文本大量覆盖的视为伪图块（文字块），跳过
      if (_textCoverageInRect(c.left, c.top, c.right, c.bottom, polys) > 0.5) continue;
      extraImages.add(PdfOcrImageBlock(
        kind: 'image',
        left: c.left,
        top: c.top,
        right: c.right,
        bottom: c.bottom,
      ));
    }

    // Layout 图框为主（告别碎截图），互补框补回漏检图表。
    final images = <PdfOcrImageBlock>[
      for (final b in figureBoxes)
        PdfOcrImageBlock(
          kind: b.label.toLowerCase(),
          left: b.left,
          top: b.top,
          right: b.right,
          bottom: b.bottom,
        ),
      ...extraImages,
    ];

    // ── 块级阅读顺序（XY-Cut）────────────────────────────────────────────
    // 把标题块与正文文本块一起做 XY-Cut 排序：纵向重叠 >30% 视为同一行（分栏），
    // 按左边界排序；否则按上边界排序（上下布局）。随后把每个文本行归入最近的块，
    // 按「块顺序 → 块内由上到下、由左到右」重排，彻底解决多栏论文全局 Y 轴排序错乱。
    // 这一步产出的 segments 顺序即真实阅读顺序，下游 _paragraphsOf 不再做任何全局 Y 排序。
    final textBlocks = [...titleBoxes, ...textBoxes];
    textBlocks.sort((a, b) {
      final yOverlap = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
      final minHeight = math.min(a.height, b.height);
      if (minHeight > 0 && yOverlap / minHeight > 0.3) {
        return a.left.compareTo(b.left); // 同栏：左→右
      }
      return a.top.compareTo(b.top); // 上下：上→下
    });

    // 给定文本行，返回其所属文本块在 textBlocks 中的下标（XY-Cut 后的顺序即阅读块顺序）。
    int getBlockIndex(PdfOcrTextSegment seg) {
      final cx = (seg.left + seg.right) / 2;
      final cy = (seg.top + seg.bottom) / 2;
      for (var i = 0; i < textBlocks.length; i++) {
        final b = textBlocks[i];
        if (cx >= b.left && cx <= b.right && cy >= b.top && cy <= b.bottom) {
          return i; // 中心点落在块内
        }
      }
      // 未落在任何块内：归到中心点最近的块，避免游离行乱序。
      var best = 0;
      var bestD = double.infinity;
      for (var i = 0; i < textBlocks.length; i++) {
        final b = textBlocks[i];
        final dx = (cx - (b.left + b.right) / 2).abs();
        final dy = (cy - (b.top + b.bottom) / 2).abs();
        final d = dx + dy;
        if (d < bestD) {
          bestD = d;
          best = i;
        }
      }
      return best;
    }

    segments.sort((a, b) {
      final bi = getBlockIndex(a).compareTo(getBlockIndex(b));
      if (bi != 0) return bi; // 先按所属块（阅读块顺序）
      final dt = a.top.compareTo(b.top);
      if (dt != 0) return dt; // 块内：上→下
      return a.left.compareTo(b.left); // 同行：左→右
    });

    // --- 【新增】强制几何过滤：自动剔除页眉、页脚、孤立页码 ---
    final double pageH = h.toDouble();
    final topBand = pageH * 0.08; // 顶部 8% 区域
    final botBand = pageH * 0.92; // 底部 8% 区域
    final numLike = RegExp(r'^[\divxlcIVXLC.\-—\s]+$');

    segments.removeWhere((seg) {
      if (seg.isTitle) return false; // 标题绝对不能删
      final text = seg.text.trim();
      if (text.isEmpty) return true;

      final isNum = numLike.hasMatch(text);
      final isShort = text.length <= 6;
      final inHeader = seg.top < topBand;
      final inFooter = seg.bottom > botBand;

      // 位于顶部且纯数字/罗马字母 -> 顶端页码
      if (inHeader && isNum) return true;
      // 位于底部且过短或是纯数字 -> 底部页码或无用注脚
      if (inFooter && (isShort || isNum)) return true;

      return false;
    });

    return (segments: segments, images: images);
  }

  /// 旧版行带回退：DB 检测概率图 → 整块图片块（行带法）→ 连通域文本行 OCR。
  /// 无 Layout 模型时使用，保证功能降级可用。
  static Future<({List<PdfOcrTextSegment> segments, List<PdfOcrImageBlock> images})>
      _buildByLegacy(Uint8List rgba, int w, int h) async {
    final (scores, newW, newH) = await PdfOcrService.detectPage(rgba, w, h);
    final imgBlocks = PdfOcrService.detectImageBlocks(
      scores,
      newW,
      newH,
      rgba,
      w,
      h,
    );
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
          layoutType: 'text', // 旧版流程无 Layout 标注，统一按正文
        ),
      );
    }
    final images = imgBlocks
        .map(
          (b) => PdfOcrImageBlock(
            kind: 'image',
            left: b.left,
            top: b.top,
            right: b.right,
            bottom: b.bottom,
          ),
        )
        .toList();
    // --- 【新增】强制几何过滤：自动剔除页眉、页脚、孤立页码 ---
    final double pageH = h.toDouble();
    final topBand = pageH * 0.08; // 顶部 8% 区域
    final botBand = pageH * 0.92; // 底部 8% 区域
    final numLike = RegExp(r'^[\divxlcIVXLC.\-—\s]+$');

    segments.removeWhere((seg) {
      if (seg.isTitle) return false; // 标题绝对不能删
      final text = seg.text.trim();
      if (text.isEmpty) return true;

      final isNum = numLike.hasMatch(text);
      final isShort = text.length <= 6;
      final inHeader = seg.top < topBand;
      final inFooter = seg.bottom > botBand;

      // 位于顶部且纯数字/罗马字母 -> 顶端页码
      if (inHeader && isNum) return true;
      // 位于底部且过短或是纯数字 -> 底部页码或无用注脚
      if (inFooter && (isShort || isNum)) return true;

      return false;
    });

    return (segments: segments, images: images);
  }

  /// 判断点 (x,y) 是否落在任一 [rects] 框内（用于标题 / 页眉页脚判定）。
  static bool _pointInAny(double x, double y, List<LayoutBox> rects) {
    for (final r in rects) {
      if (x >= r.left && x <= r.right && y >= r.top && y <= r.bottom) {
        return true;
      }
    }
    return false;
  }

  /// 两个轴对齐矩形框的 IoU（互补图块与 Layout 图框 / 抑制区去重用）。
  static double _iouRect(
    double l1,
    double t1,
    double r1,
    double b1,
    double l2,
    double t2,
    double r2,
    double b2,
  ) {
    final ix0 = math.max(l1, l2);
    final iy0 = math.max(t1, t2);
    final ix1 = math.min(r1, r2);
    final iy1 = math.min(b1, b2);
    final iw = (ix1 - ix0).clamp(0.0, double.infinity);
    final ih = (iy1 - iy0).clamp(0.0, double.infinity);
    final inter = iw * ih;
    if (inter <= 0) return 0;
    final union = (r1 - l1) * (b1 - t1) + (r2 - l2) * (b2 - t2) - inter;
    return union <= 0 ? 0 : inter / union;
  }

  /// 矩形框内被正文文本行覆盖的面积占比（>0.5 视为伪图块 / 文字块，剔除）。
  static double _textCoverageInRect(
    double l,
    double t,
    double r,
    double b,
    List<List<ui.Offset>> polys,
  ) {
    final rectArea = (r - l) * (b - t);
    if (rectArea <= 0) return 0;
    var covered = 0.0;
    for (final poly in polys) {
      final pl = poly[0].dx;
      final pt = poly[0].dy;
      final pr = poly[2].dx;
      final pb = poly[2].dy;
      final ix0 = math.max(l, pl);
      final iy0 = math.max(t, pt);
      final ix1 = math.min(r, pr);
      final iy1 = math.min(b, pb);
      final iw = (ix1 - ix0).clamp(0.0, double.infinity);
      final ih = (iy1 - iy0).clamp(0.0, double.infinity);
      covered += iw * ih;
    }
    return (covered / rectArea).clamp(0.0, 1.0);
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
