import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:pdfx/pdfx.dart';
import 'package:synchronized/synchronized.dart';

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

  /// 单页渲染结果缓存（按 文档id:页码:裁切 维度）。命中即直接返回，避免对同页
  /// 反复 getPage/render/close（多次原生取页是 Windows 下崩溃的高危来源）。
  static final Map<String, PdfRenderedResult> _renderCache = {};

  /// 文档级串行锁：同一 PdfDocument 的所有原生操作（getPage/render/close）严格互斥。
  ///
  /// 关键修复：原先多个 [PdfPageTile] 构建时会并发对同一文档发起 getPage/render，
  /// 而某个瓦片的 page.close() 可能与另一瓦片的 getPage/render 在原生层交错，
  /// 导致 Windows 下 PDFium 句柄竞争直接崩溃。pdfx 全局锁只序列化「单次」通道调用，
  /// 无法阻止 close 与 render 跨调用交错，因此这里按文档维度再加一把锁，
  /// 保证一个文档在任意时刻只有一处原生操作在进行。
  static final Map<String, Lock> _docLocks = {};

  /// 取得（或创建）某文档的串行锁。
  static Lock _lockFor(PdfDocument document) {
    final id = document.id.toString();
    return _docLocks.putIfAbsent(id, Lock.new);
  }

  /// 单页最大渲染像素宽度，兼顾清晰度与内存（移动端足够，桌面端也不会爆内存）。
  static const int maxRenderWidth = 2000;

  /// 自动裁切扫描用的缩略图宽度（越小越快，足够定位内容边界）。
  static const int cropScanWidth = 240;

  /// 渲染单页为 PNG 字节。
  ///
  /// 严格遵循 pdfx 官方 [PdfView] 的安全渲染范式：**单次 getPage + 单次 render +
  /// close**，全程在文档锁内，且按「文档:页码:裁切」维度缓存结果。这样彻底消除了
  /// 原先 [PdfPageTile] 中「先 getPage 取尺寸再 close、随后又 getPage 渲染」对同一页
  /// 的两次原生取页——在 Windows 下这会让 PDFium 复用已关闭的页面句柄，引发
  /// use-after-free 原生崩溃（即「打开 PDF 即崩溃」）。
  ///
  /// [renderWidth] 为目标像素宽，高度按页面真实宽高比推导（不再对页面尺寸做额外
  /// getPage 探测）；[cropFrac] 为归一化裁切区域（0~1，相对页面），为空表示整页渲染。
  /// 返回 null 表示渲染失败（已安全兜底，不会导致阅读器崩溃）。
  static Future<PdfRenderedResult?> renderPageBytes(
    PdfDocument document,
    int pageNumber, {
    required double renderWidth,
    Rect? cropFrac,
  }) async {
    final cacheKey = '${document.id}:$pageNumber:${cropFrac ?? ''}';
    final cached = _renderCache[cacheKey];
    if (cached != null) return cached;

    try {
      final width = math.min(renderWidth, maxRenderWidth.toDouble())
          .clamp(1.0, double.infinity);
      // 单次取页 + 渲染 + 关闭：先读页面真实尺寸推导高度与裁切框，再渲染，最后关闭。
      final result = await _lockFor(document).synchronized(() async {
        final page = await document.getPage(pageNumber);
        try {
          final pageW = page.width;
          final pageH = page.height;
          if (pageW <= 0 || pageH <= 0) return null;
          final aspect = pageH / pageW;
          final height = (width * aspect).clamp(1.0, double.infinity);
          Rect? cropRect;
          if (cropFrac != null) {
            cropRect = Rect.fromLTRB(
              cropFrac.left * width,
              cropFrac.top * height,
              cropFrac.right * width,
              cropFrac.bottom * height,
            );
          }
          // 关键：与 pdfx 官方 PdfView 的渲染配置完全一致——使用 JPEG 格式 +
          // 白色背景。pdfx 在 Windows 上默认就是 JPEG（PNG 经 PDFium 原生通道
          // 输出在 Windows 下会崩溃，这正是「打开 PDF 即崩」的真正根因；PNG 透明
          // 背景由本处白色兜底，瓦片容器也是白色，无视觉差异）。
          final image = await page.render(
            width: width,
            height: height,
            format: PdfPageImageFormat.jpeg,
            backgroundColor: '#ffffff',
            cropRect: cropRect,
          );
          if (image == null) return null;
          final int iw = image.width ?? 0;
          final int ih = image.height ?? 0;
          if (iw == 0 || ih == 0) return null;
          return PdfRenderedResult(image.bytes, iw / ih);
        } finally {
          await page.close();
        }
      });
      if (result != null) _renderCache[cacheKey] = result;
      return result;
    } catch (_) {
      // 渲染异常不应导致阅读器崩溃，交由上层回退处理。
      return null;
    }
  }

  /// 在文档锁内安全关闭文档，避免与仍在进行的渲染/取页交错导致原生崩溃。
  ///
  /// 关闭后会清理该文档相关的尺寸与裁切缓存，并移除对应的串行锁。
  /// 该方法返回 Future 但不强制 await（dispose 中调用即可），所有后续的
  /// 取页/渲染会在锁内排到 close 之前完成，close 必然在最后执行。
  static Future<void> closeDocument(PdfDocument document) async {
    final id = document.id.toString();
    final lock = _docLocks[id];
    if (lock == null) {
      // 没有任何瓦片使用过，直接关闭。
      await document.close();
      return;
    }
    await lock.synchronized(() async {
      await document.close();
    });
    _renderCache.removeWhere((key, _) => key.startsWith('$id:'));
    _cropCache.removeWhere((key, _) => key.startsWith('$id:'));
    _docLocks.remove(id);
  }

  /// 计算自动裁切的内容包围盒（归一化 0~1 的 [Rect]）。
  ///
  /// 先以低分辨率渲染白底 PNG（单次 getPage + render + close），再解码 RGBA 扫描
  /// 非近白像素，取其最小/最大坐标并留约 1.5% 间隙，避免裁掉内容。
  static Future<Rect> computeCropFractions(
    PdfDocument document,
    int pageNumber,
  ) async {
    final cacheKey = '${document.id}:$pageNumber';
    final cached = _cropCache[cacheKey];
    if (cached != null) return cached;

    final scanWidth = cropScanWidth.toDouble();
    Uint8List? bytes;
    try {
      // 在文档锁内完成扫描渲染（单次 getPage + render + close），避免与正常渲染
      // 交错导致原生崩溃。
      bytes = await _lockFor(document).synchronized(() async {
        final page = await document.getPage(pageNumber);
        try {
          final pageW = page.width;
          final pageH = page.height;
          if (pageW <= 0 || pageH <= 0) return null;
          final scanHeight = (scanWidth * (pageH / pageW))
              .clamp(1.0, double.infinity);
          final image = await page.render(
            width: scanWidth,
            height: scanHeight,
            format: PdfPageImageFormat.jpeg,
            backgroundColor: '#ffffff',
          );
          return image?.bytes;
        } finally {
          await page.close();
        }
      });
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

/// 单页渲染结果：PNG 字节 + 渲染后像素宽高比（width / height）。
///
/// 宽高比供连续滚动模式按页面比例撑开容器高度，避免重复原生取页探测尺寸。
class PdfRenderedResult {
  final Uint8List bytes;
  final double aspectRatio;

  PdfRenderedResult(this.bytes, this.aspectRatio);
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
