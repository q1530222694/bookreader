import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Rect;

import 'package:flutter/material.dart' show Colors;
import 'package:pdfrx/pdfrx.dart';
import 'package:synchronized/synchronized.dart';

import '../model/pdf_reader_settings.dart';

/// PDF 渲染服务（纯逻辑层，无 UI 依赖）。
///
/// 底层引擎：pdfrx（基于 PDFium，全平台）。本服务负责：
/// 1. 按需将某一页渲染为 [ui.Image]（可带原生裁切区域）；
/// 2. 自动裁切：对低分辨率探针图做像素扫描，求出内容包围盒（归一化 0~1），
///    再交由 pdfrx 原生渲染在目标分辨率下只渲染该子区域（x/y/width/height），
///    性能最优（扫描只在小图上发生，且裁切由 PDFium 原生完成，无 Dart 兜底）；
/// 3. 智能去杂色：对渲染出的位图做真正的「去噪点」处理（3x3 邻域判定，仅移除孤立
///    黑点/杂点，保留文字笔画），替代原先「整体高斯模糊」导致清晰度下降的方案；
/// 4. 将 [PdfReaderSettings] 的颜色调整（亮度/对比度/饱和度/去色）合成为
///    Flutter [ColorFilter.matrix] 所需的 20 长度矩阵。
///
/// 被 [lib/features/shell/ui/pdf_custom_view.dart] 调用，
/// 不直接触碰任何持久化或 UI 状态（符合「SDK/服务层不反向依赖 UI」铁律）。
class PdfRenderService {
  PdfRenderService._();

  /// 自动裁切内容包围盒缓存（按 文档sourceName:页码 维度，跨页面复用，避免重复像素扫描）。
  static final Map<String, Rect> _cropCache = {};

  /// 单页渲染结果缓存（按 文档sourceName:页码:渲染宽:裁切:去杂色 维度）。命中即直接返回，
  /// 避免对同页反复调用 PDFium 原生渲染（多次原生渲染是 Windows 下崩溃的高危来源）。
  /// 缓存持有 [ui.Image]，文档关闭时统一 dispose，避免重复解码与内存泄漏。
  static final Map<String, ui.Image> _renderCache = {};

  /// 文档级串行锁：同一 PdfDocument 的所有原生渲染（render）严格互斥。
  ///
  /// 关键修复：原先多个页面构建时会并发对同一文档发起 render，而 PDFium 在 Windows 下
  /// 对并发渲染同一文档的句柄竞争容易崩溃。按文档维度加锁，保证一个文档任意时刻
  /// 只有一处原生渲染在进行。（注意：本服务的公有方法之间不互相嵌套加锁，避免死锁。）
  static final Map<String, Lock> _docLocks = {};

  /// 取得（或创建）某文档的串行锁。
  static Lock _lockFor(PdfDocument document) {
    final id = document.sourceName;
    return _docLocks.putIfAbsent(id, Lock.new);
  }

  /// 单页最大渲染像素宽度，兼顾清晰度与内存（移动端足够，桌面端也不会爆内存）。
  static const int maxRenderWidth = 2000;

  /// 自动裁切扫描用的探针图宽度（越大边界越准、越慢；480 在精度与速度间平衡）。
  static const int cropScanWidth = 480;

  /// 渲染单页为 [ui.Image]，支持原生精确裁切与智能去杂色。
  ///
  /// [renderWidth] 为目标像素宽（调用方应已乘 devicePixelRatio），高度按页面真实
  /// 宽高比推导；[autoCrop] 为 true 时先求内容包围盒，再用 pdfrx 的
  /// `render(x,y,width,height,fullWidth,fullHeight)` 仅渲染该子区域，得到去白边的
  /// 精确裁剪图（区别于旧方案“整体缩放去白边”的近似做法）。[denoise] 为 true 时在
  /// 渲染出的位图上执行真正的去噪点处理（仅移除孤立杂点，保留文字清晰度）。
  ///
  /// 返回 null 表示渲染失败（已安全兜底，不会导致阅读器崩溃）。
  static Future<ui.Image?> renderPageImage(
    PdfDocument document,
    int pageNumber, {
    required double renderWidth,
    bool autoCrop = false,
    bool denoise = false,
  }) async {
    final fullW =
        math.min(renderWidth, maxRenderWidth.toDouble()).clamp(1.0, double.infinity);
    final cacheKey =
        '${document.sourceName}:$pageNumber:${fullW.round()}:$autoCrop:$denoise';
    final cached = _renderCache[cacheKey];
    if (cached != null) return cached;

    try {
      // 自动裁切的包围盒计算会内部加锁，此处不再嵌套加锁（避免 synchronized 死锁）。
      final crop = autoCrop
          ? await computeCropFractions(document, pageNumber)
          : null;

      final ui.Image? result = await _lockFor(document).synchronized(() async {
        final page = document.pages[pageNumber - 1];
        final pageW = page.width;
        final pageH = page.height;
        if (pageW <= 0 || pageH <= 0) return null;
        final fullH = (fullW * pageH / pageW).clamp(1.0, double.infinity);

      PdfImage? image;
      if (crop == null ||
          (crop.left <= 0.001 &&
              crop.top <= 0.001 &&
              crop.right >= 0.999 &&
              crop.bottom >= 0.999)) {
        // 无裁切：整体渲染。
        // 使用 fullWidth/fullHeight（与 pdfrx 自身 PdfViewer 一致），确保 PDFium 按完整页面渲染，
        // 避免使用 width/height 时可能的子区域语义差异或 CropBox 裁切。
        image = await page.render(
          fullWidth: fullW,
          fullHeight: fullH,
          backgroundColor: Colors.white,
        );
        } else {
          // 有裁切：在目标分辨率下只渲染内容子区域（x/y/width/height 为像素子区域，
          // fullWidth/fullHeight 为整页虚拟尺寸，二者配合即可“抠”出内容包围盒）。
          final x = (crop.left * fullW).round();
          final y = (crop.top * fullH).round();
          final w = ((crop.right - crop.left) * fullW).round();
          final h = ((crop.bottom - crop.top) * fullH).round();
          if (w <= 2 || h <= 2) {
            image = await page.render(
              fullWidth: fullW,
              fullHeight: fullH,
              backgroundColor: Colors.white,
            );
          } else {
            image = await page.render(
              x: x,
              y: y,
              width: w,
              height: h,
              fullWidth: fullW,
              fullHeight: fullH,
              backgroundColor: Colors.white,
            );
          }
        }
        if (image == null) return null;
        final uiImg = await image.createImage();
        image.dispose();
        return uiImg;
      });

      if (result == null) return null;

      // 智能去杂色：在原生渲染结果上做真正的去噪点（保留文字笔画），而非模糊。
      final out = denoise ? await _denoiseImage(result) : result;
      if (out != result) {
        result.dispose(); // 去杂色产生了新图，释放旧图（缓存持有新图）。
      }
      _renderCache[cacheKey] = out;
      return out;
    } catch (_) {
      // 渲染异常不应导致阅读器崩溃，交由上层回退处理。
      return null;
    }
  }

  /// 在文档锁内安全关闭文档，释放缓存的 [ui.Image] 与包围盒，并移除串行锁。
  ///
  /// 该方法返回 Future 但不强制 await（dispose 中调用即可）。
  static Future<void> disposeDocument(PdfDocument document) async {
    final id = document.sourceName;
    final lock = _docLocks[id];
    if (lock == null) {
      await document.dispose();
      return;
    }
    await lock.synchronized(() async {
      // 释放本服务持有的所有已渲染 [ui.Image]，避免 GPU 内存泄漏。
      _renderCache.removeWhere((key, img) {
        if (key.startsWith('$id:')) {
          img.dispose();
          return true;
        }
        return false;
      });
      _cropCache.removeWhere((key, _) => key.startsWith('$id:'));
      await document.dispose();
    });
    _docLocks.remove(id);
  }

  /// 计算自动裁切的内容包围盒（归一化 0~1 的 [Rect]）。
  ///
  /// 先以低分辨率渲染白底探针图（单次 render，内部加锁），再读取其原始像素
  /// [PdfImage.pixels]（RGBA/BGRA），扫描非近白像素，取其最小/最大坐标并留约 2%
  /// 间隙，避免裁掉内容。结果按 文档:页码 缓存，重复调用直接命中。
  static Future<Rect> computeCropFractions(
    PdfDocument document,
    int pageNumber,
  ) async {
    final cacheKey = '${document.sourceName}:$pageNumber';
    final cached = _cropCache[cacheKey];
    if (cached != null) return cached;

    PdfImage? probe;
    try {
      probe = await _lockFor(document).synchronized(() async {
        final page = document.pages[pageNumber - 1];
        final pageW = page.width;
        final pageH = page.height;
        if (pageW <= 0 || pageH <= 0) return null;
        final probeH =
            (cropScanWidth * pageH / pageW).clamp(1.0, double.infinity);
        // 关键：必须传 fullWidth/fullHeight，使 width??=fullWidth、height??=fullHeight，
        // 否则 fullWidth 会回退为页面“原生 pt 尺寸”，导致整页被渲染到更小的位图里、
        // 右/下边缘被静默裁切（与主渲染无裁切分支是同一类缺陷）。传 fullWidth/fullHeight
        // 后位图尺寸 == 整页渲染尺寸，探针才是真正的“全页”探针。
        return await page.render(
          fullWidth: cropScanWidth.toDouble(),
          fullHeight: probeH,
          backgroundColor: Colors.white,
        );
      });
    } catch (_) {
      probe = null;
    }

    final rect = probe == null
        ? const Rect.fromLTRB(0, 0, 1, 1)
        : _scanContent(probe.pixels, probe.width, probe.height, probe.format);
    probe?.dispose();
    _cropCache[cacheKey] = rect;
    return rect;
  }

  /// 扫描原始像素（RGBA 或 BGRA）求内容包围盒，返回归一化 [Rect]。
  ///
  /// 改进点：
  /// - 提高探针分辨率（调用方已用 [cropScanWidth]=480）以更准确定位边界；
  /// - 近白阈值放宽到 238，避免把浅灰文字误判为内容、也避免把轻微灰底误判为背景；
  /// - 若内容像素占比过低（<0.3%，仅有极少量噪点），视为空页不裁切；
  /// - 四周保留约 2% 间隙（至少为 1px），既去掉白边又不会切到文字笔画；
  /// - 裁切结果严格 clamp 到 [0,1]，绝不越界。
  static Rect _scanContent(
    Uint8List pixels,
    int w,
    int h,
    ui.PixelFormat format,
  ) {
    // pdfrx 的像素格式平台相关：rgba8888 或 bgra8888，需分别取 R/B 通道。
    final isBgra = format == ui.PixelFormat.bgra8888;

    var minX = w;
    var minY = h;
    var maxX = -1;
    var maxY = -1;
    var contentCount = 0;
    final total = w * h;

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        if (i + 2 >= pixels.lengthInBytes) break;
        final r = isBgra ? pixels[i + 2] : pixels[i];
        final g = pixels[i + 1];
        final b = isBgra ? pixels[i] : pixels[i + 2];
        // 近白像素视为背景，跳过；内容像素（文字/插图）通常偏暗。
        if (r > 238 && g > 238 && b > 238) continue;
        contentCount++;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }

    // 内容占比过低：仅有零星噪点，不裁切（避免把噪点当内容、反而保留大片白边）。
    if (maxX < 0 || total <= 0 || contentCount * 100 < total * 0.3) {
      return const Rect.fromLTRB(0, 0, 1, 1);
    }

    // 四周保留约 2% 的少量间隙（至少 1px），避免误伤内容笔画；严格 clamp 不越界。
    final marginX = math.max(1, (w * 0.02).round());
    final marginY = math.max(1, (h * 0.02).round());
    final left = (minX - marginX).clamp(0, w - 1);
    final top = (minY - marginY).clamp(0, h - 1);
    final right = (maxX + marginX).clamp(1, w);
    final bottom = (maxY + marginY).clamp(1, h);

    // 内容几乎铺满整页时直接返回整页，避免边缘处的无意义微裁切。
    if (left <= 1 && top <= 1 && right >= w - 1 && bottom >= h - 1) {
      return const Rect.fromLTRB(0, 0, 1, 1);
    }

    return Rect.fromLTRB(
      left / w,
      top / h,
      right / w,
      bottom / h,
    );
  }

  /// 真正的智能去杂色：对渲染出的位图做 3x3 邻域判定，仅移除「孤立」的黑点/杂色，
  /// 保留文字笔画（笔画像素拥有较多相邻墨点，不会被误删），从而既不降低清晰度、
  /// 又能去除扫描件上的小黑点/杂点。返回处理后的新 [ui.Image]。
  static Future<ui.Image> _denoiseImage(ui.Image src) async {
    try {
      final bytes = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) return src;
      final rgba = bytes.buffer.asUint8List();
      final w = src.width;
      final h = src.height;
      final out = Uint8List.fromList(rgba); // 先整体拷贝，仅修改被判定为杂点的像素。

      // 亮度阈值：低于该值视为“墨点/内容”，高于视为背景。
      const int inkThreshold = 140;
      bool isInk(int i) =>
          (0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2]) <
          inkThreshold;

      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          if (!isInk(i)) continue;
          // 统计 8 邻域内的墨点数量。
          int inkNeighbors = 0;
          int sr = 0, sg = 0, sb = 0, sn = 0;
          for (var ny = y - 1; ny <= y + 1; ny++) {
            for (var nx = x - 1; nx <= x + 1; nx++) {
              if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
              if (nx == x && ny == y) continue;
              final j = (ny * w + nx) * 4;
              if (isInk(j)) {
                inkNeighbors++;
              } else {
                sr += rgba[j];
                sg += rgba[j + 1];
                sb += rgba[j + 2];
                sn++;
              }
            }
          }
          // 孤立墨点（邻域墨点 < 2）：判定为杂点，用邻域背景平均色温替换，无缝消除。
          if (inkNeighbors < 2 && sn > 0) {
            out[i] = (sr ~/ sn).clamp(0, 255);
            out[i + 1] = (sg ~/ sn).clamp(0, 255);
            out[i + 2] = (sb ~/ sn).clamp(0, 255);
            out[i + 3] = rgba[i + 3];
          }
        }
      }

      // decodeImageFromPixels 为回调式（void，结果经 ImageDecoderCallback 返回）。
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        out,
        w,
        h,
        ui.PixelFormat.rgba8888,
        (image) => completer.complete(image),
      );
      final newImage = await completer.future;
      return newImage;
    } catch (_) {
      // 去杂色失败不应影响阅读，退回原图。
      return src;
    }
  }

  /// 将 [PdfReaderSettings] 的颜色调整合成为 [ColorFilter.matrix] 所需的 20 长度矩阵。
  ///
  /// 合成顺序（输入 → 输出）：亮度 → 色温 → 饱和度 → 对比度 → 去色（灰度）。
  /// 返回 null 表示无任何颜色调整（无需 [ColorFiltered]）。
  static List<double>? buildColorMatrix(PdfReaderSettings settings) {
    if (!settings.removeColor &&
        settings.brightness == 1.0 &&
        settings.contrast == 1.0 &&
        settings.saturation == 1.0 &&
        settings.colorTemperature == 1.0) {
      return null;
    }

    _Matrix4x4 m = _Matrix4x4.identity();
    m = _Matrix4x4.compose(_brightness(settings.brightness), m);
    m = _Matrix4x4.compose(_colorTemperature(settings.colorTemperature), m);
    m = _Matrix4x4.compose(_saturation(settings.saturation), m);
    m = _Matrix4x4.compose(_contrast(settings.contrast), m);
    if (settings.removeColor) {
      m = _Matrix4x4.compose(_grayscale(), m);
    }
    return m.flatten();
  }

  /// 亮度矩阵：对角缩放。
  static _Matrix4x4 _brightness(double b) {
    return _Matrix4x4.fromRows(
      [b, 0, 0, 0, 0, b, 0, 0, 0, 0, b, 0, 0, 0, 0, 1],
      const [0, 0, 0, 0],
    );
  }

  /// 对比度矩阵：out = in * c + (1 - c) * 0.5。
  static _Matrix4x4 _contrast(double c) {
    final o = (1 - c) * 0.5;
    return _Matrix4x4.fromRows(
      [c, 0, 0, 0, 0, c, 0, 0, 0, 0, c, 0, 0, 0, 0, 1],
      [o, o, o, 0],
    );
  }

  /// 饱和度矩阵：s=1 原色，s=0 灰度。
  static _Matrix4x4 _saturation(double s) {
    const lr = 0.2126;
    const lg = 0.7152;
    const lb = 0.0722;
    final r = lr * (1 - s) + s;
    final g = lg * (1 - s);
    final b = lb * (1 - s);
    return _Matrix4x4.fromRows(
      [r, g, b, 0, r, g, b, 0, r, g, b, 0, 0, 0, 0, 1],
      const [0, 0, 0, 0],
    );
  }

  /// 灰度矩阵（去除颜色，仅黑白灰）。
  static _Matrix4x4 _grayscale() {
    const lr = 0.2126;
    const lg = 0.7152;
    const lb = 0.0722;
    return _Matrix4x4.fromRows(
      [lr, lg, lb, 0, lr, lg, lb, 0, lr, lg, lb, 0, 0, 0, 0, 1],
      const [0, 0, 0, 0],
    );
  }

  /// 色温矩阵：t=1 原色，t<1 偏冷（蓝调），t>1 偏暖（黄/橙调）。
  ///
  /// 实现方式：通过偏移 R/G/B 通道的输出值模拟色温偏移。
  /// 暖色调增强红绿通道、抑制蓝色；冷色调增强蓝色、轻微抑制红色。
  static _Matrix4x4 _colorTemperature(double t) {
    if (t >= 0.99 && t <= 1.01) return _Matrix4x4.identity();
    // 偏移量：与 |t-1| 成正比，暖为正（R+G+, B-），冷为负（R-, B+）
    final d = (t - 1.0).clamp(-0.5, 0.5);
    // 暖：红 +0.15d, 绿 +0.05d, 蓝 -0.20d
    // 冷：红 -0.10d, 绿 -0.02d, 蓝 +0.18d
    final ro = d > 0 ? d * 0.15 : d * 0.10;
    final go = d > 0 ? d * 0.05 : d * 0.02;
    final bo = d > 0 ? -d * 0.20 : -d * 0.18;
    return _Matrix4x4.fromRows(
      [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],
      [ro, go, bo, 0],
    );
  }
}

/// 4x4 颜色矩阵 + 4 维平移向量的轻量实现，用于合成 [ColorFilter] 参数。
class _Matrix4x4 {
  /// 行主序 16 个元素（颜色矩阵部分）。
  final List<double> m;

  /// 4 维平移（R,G,B,A 各自的偏移量）。
  final List<double> t;

  _Matrix4x4.fromRows(List<num> m, List<num> t)
      : m = m.map((e) => e.toDouble()).toList(),
        t = t.map((e) => e.toDouble()).toList();

  factory _Matrix4x4.identity() {
    return _Matrix4x4.fromRows(
      [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],
      const [0, 0, 0, 0],
    );
  }

  /// 合成 a ∘ b：输入先经 b 再经 a。
  static _Matrix4x4 compose(_Matrix4x4 a, _Matrix4x4 b) {
    final m = List<double>.filled(16, 0.0);
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        var s = 0.0;
        for (var k = 0; k < 4; k++) {
          s += a.m[r * 4 + k] * b.m[k * 4 + c];
        }
        m[r * 4 + c] = s;
      }
    }
    final t = List<double>.filled(4, 0.0);
    for (var r = 0; r < 4; r++) {
      var s = a.t[r];
      for (var k = 0; k < 4; k++) {
        s += a.m[r * 4 + k] * b.t[k];
      }
      t[r] = s;
    }
    return _Matrix4x4.fromRows(m, t);
  }

  /// 展开为 [ColorFilter.matrix] 所需的 20 长度列表（RGBA 行 + 平移）。
  List<double> flatten() {
    return [
      m[0], m[1], m[2], m[3], t[0],
      m[4], m[5], m[6], m[7], t[1],
      m[8], m[9], m[10], m[11], t[2],
      m[12], m[13], m[14], m[15], t[3],
    ];
  }
}
