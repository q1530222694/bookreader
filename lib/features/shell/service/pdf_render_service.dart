import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:pdfx/pdfx.dart';

import '../model/pdf_reader_settings.dart';

/// PDF 渲染服务（纯逻辑层，无 UI 依赖）。
///
/// 职责：
/// 1. 按需将某一页渲染为 PNG 字节（可带裁切区域）；
/// 2. 自动裁切：对低分辨率缩略图做像素扫描，求出内容包围盒（归一化 0~1），
///    再交由原生渲染层在目标分辨率下精确裁切，性能最优（扫描只在小图上发生）；
/// 3. 将 [PdfReaderSettings] 的颜色调整（亮度/对比度/饱和度/去色）合成为
///    Flutter [ColorFilter.matrix] 所需的 20 长度矩阵。
///
/// 该服务被 [lib/features/shell/ui/pdf_page_tile.dart] 调用，
/// 不直接触碰任何持久化或 UI 状态（符合「SDK/服务层不反向依赖 UI」铁律）。
class PdfRenderService {
  PdfRenderService._();

  /// 自动裁切内容包围盒缓存（按 文档id:页码 维度，跨 Tillde 复用，避免重复像素扫描）。
  static final Map<String, Rect> _cropCache = {};

  /// 页面原始尺寸缓存（避免重复 getPage 取尺寸）。
  static final Map<String, Size> _sizeCache = {};

  /// 单页最大渲染像素宽度，兼顾清晰度与内存（移动端足够，桌面端也不会爆内存）。
  static const int maxRenderWidth = 2000;

  /// 自动裁切扫描用的缩略图宽度（越小越快，足够定位内容边界）。
  static const int cropScanWidth = 240;

  /// 取得页面原始尺寸（点，72dpi）。
  static Future<Size> pageSize(PdfDocument document, int pageNumber) async {
    final key = '${document.id}:$pageNumber';
    final cached = _sizeCache[key];
    if (cached != null) return cached;
    final page = await document.getPage(pageNumber);
    final size = Size(page.width, page.height);
    await page.close();
    _sizeCache[key] = size;
    return size;
  }

  /// 渲染单页为 PNG 字节。
  ///
  /// [renderWidth] 为目标像素宽，高度按页面比例推导；[cropFrac] 为归一化裁切区域
  /// （0~1，相对页面），为空表示整页渲染。返回 null 表示渲染失败。
  static Future<Uint8List?> renderPageBytes(
    PdfDocument document,
    int pageNumber, {
    required double renderWidth,
    Rect? cropFrac,
  }) async {
    try {
      final width = math.min(renderWidth, maxRenderWidth.toDouble())
          .clamp(1.0, double.infinity);
      final size = await pageSize(document, pageNumber);
      final aspect = size.height / size.width;
      final renderHeight = (width * aspect).clamp(1.0, double.infinity);

      final page = await document.getPage(pageNumber);
      Rect? cropRect;
      if (cropFrac != null) {
        cropRect = Rect.fromLTRB(
          cropFrac.left * width,
          cropFrac.top * renderHeight,
          cropFrac.right * width,
          cropFrac.bottom * renderHeight,
        );
      }
      final image = await page.render(
        width: width,
        height: renderHeight,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
        cropRect: cropRect,
      );
      await page.close();
      return image?.bytes;
    } catch (error) {
      // 渲染异常不应导致阅读器崩溃，交由上层回退处理。
      return null;
    }
  }

  /// 计算自动裁切的内容包围盒（归一化 0~1 的 [Rect]）。
  ///
  /// 先以低分辨率渲染白底 PNG，再解码 RGBA 扫描非近白像素，
  /// 取其最小/最大坐标并留约 1.5% 间隙，避免裁掉内容。
  static Future<Rect> computeCropFractions(
    PdfDocument document,
    int pageNumber,
  ) async {
    final cacheKey = '${document.id}:$pageNumber';
    final cached = _cropCache[cacheKey];
    if (cached != null) return cached;

    final size = await pageSize(document, pageNumber);
    final scanHeight = (cropScanWidth * (size.height / size.width))
        .clamp(1.0, double.infinity);

    Uint8List? bytes;
    try {
      final page = await document.getPage(pageNumber);
      final image = await page.render(
        width: cropScanWidth.toDouble(),
        height: scanHeight,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      await page.close();
      bytes = image?.bytes;
    } catch (_) {
      bytes = null;
    }

    final rect = bytes == null
        ? const Rect.fromLTRB(0, 0, 1, 1)
        : await _scanContent(bytes);
    _cropCache[cacheKey] = rect;
    return rect;
  }

  /// 解码 PNG 字节为 RGBA 并扫描内容包围盒。
  static Future<Rect> _scanContent(Uint8List bytes) async {
    // 当前 Flutter 的 decodeImageFromList 为回调式（void，带 ImageDecoderCallback）
    final completer = Completer<Image>();
    decodeImageFromList(bytes, (image) => completer.complete(image));
    final codec = await completer.future;
    final data = await codec.toByteData(format: ImageByteFormat.rawRgba);
    final w = codec.width;
    final h = codec.height;
    if (data == null) return const Rect.fromLTRB(0, 0, 1, 1);

    var minX = w;
    var minY = h;
    var maxX = -1;
    var maxY = -1;
    final length = data.lengthInBytes;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        if (i + 2 >= length) break;
        final r = data.getUint8(i);
        final g = data.getUint8(i + 1);
        final b = data.getUint8(i + 2);
        // 近白像素视为背景，跳过；内容像素（文字/插图）通常偏暗
        if (r > 235 && g > 235 && b > 235) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }

    if (maxX < 0) {
      // 整页空白，不裁切
      return const Rect.fromLTRB(0, 0, 1, 1);
    }

    // 四周保留约 1.5% 的少量间隙，避免误伤内容
    final marginX = (w * 0.015).round();
    final marginY = (h * 0.015).round();
    final left = (minX - marginX).clamp(0, w);
    final top = (minY - marginY).clamp(0, h);
    final right = (maxX + marginX).clamp(0, w);
    final bottom = (maxY + marginY).clamp(0, h);

    return Rect.fromLTRB(
      left / w,
      top / h,
      right / w,
      bottom / h,
    );
  }

  /// 将 [PdfReaderSettings] 的颜色调整合成为 [ColorFilter.matrix] 所需的 20 长度矩阵。
  ///
  /// 合成顺序（输入 → 输出）：亮度 → 饱和度 → 对比度 → 去色（灰度）。
  /// 返回 null 表示无任何颜色调整（无需 [ColorFiltered]）。
  static List<double>? buildColorMatrix(PdfReaderSettings settings) {
    if (!settings.removeColor &&
        settings.brightness == 1.0 &&
        settings.contrast == 1.0 &&
        settings.saturation == 1.0) {
      return null;
    }

    _Matrix4x4 m = _Matrix4x4.identity();
    m = _Matrix4x4.compose(_brightness(settings.brightness), m);
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
