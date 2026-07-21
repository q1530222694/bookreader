import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:pdfrx/pdfrx.dart';
import 'package:synchronized/synchronized.dart';

import '../model/pdf_reader_settings.dart';

/// 智能清晰度自动评估结果：可直接回填到 [PdfReaderSettings] / [SettingsController]。
///
/// 由 [PdfRenderService.autoEnhance] 基于页面像素统计得出，涵盖「亮度 / 对比度 /
/// 清晰度 / 智能去杂色」四项。所有取值均已裁剪到各参数的合法区间。
class PdfAutoEnhanceResult {
  /// 推荐亮度（0.3~1.5，1.0 为原始）。
  final double brightness;

  /// 推荐对比度（0.5~2.0，1.0 为原始）。
  final double contrast;

  /// 推荐清晰度（0.5~2.0，1.0 为原始；>1 锐化）。
  final double sharpness;

  /// 是否启用智能去杂色（扫描件通常含孤立墨点，默认开启）。
  final bool denoise;

  const PdfAutoEnhanceResult({
    required this.brightness,
    required this.contrast,
    required this.sharpness,
    required this.denoise,
  });
}

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

/// 垂直对齐基准带：取全文档采样页内容框 top/bottom 的中位数，作为统一垂直边界。
/// 让全文档在垂直方向对齐到统一上下边界，消除逐页独立裁切导致的翻页上下跳动。
/// 独立顶层私有类（不可嵌套于 PdfRenderService，Dart 不允许 static class）。
class VerticalBand {
  final double top;
  final double bottom;
  const VerticalBand(this.top, this.bottom);
}

class PdfRenderService {
  PdfRenderService._();

  /// 自动裁切内容包围盒缓存（按 文档sourceName:页码 维度，跨页面复用，避免重复像素扫描）。
  static final Map<String, Rect> _cropCache = {};

  /// 单页渲染结果缓存（按 文档sourceName:页码:渲染宽:裁切:去杂色 维度）。命中即直接返回，
  /// 避免对同页反复调用 PDFium 原生渲染（多次原生渲染是 Windows 下崩溃的高危来源）。
  /// 缓存持有 [ui.Image]，文档关闭时统一 dispose，避免重复解码与内存泄漏。
  ///
  /// 现为 LRU：以 [_renderCacheOrder] 记录访问顺序，超出 [_maxRenderCache] 上限时
  /// 淘汰最久未用项并 dispose 其 [ui.Image]，防止长文档 + 预渲染把 GPU 内存撑爆。
  /// 另有 [_baseRenderCache] 仅缓存「原生渲染」层（不含去杂色/锐化），供预取与后处理复用，
  /// 使「开启智能清晰度」不再重复 PDFium 原生渲染、且预取不再争抢 isolate 池（详见该字段）。
  static final Map<String, ui.Image> _renderCache = {};
  /// LRU 访问顺序（队尾为最近使用）。与 [_renderCache] 同步维护。
  static final List<String> _renderCacheOrder = [];
  /// 渲染缓存上限（条）。按 ~22MB/页（2000px 宽）估算，48 条约 1GB，桌面端安全；
  /// 移动端本为按需，预渲染仅暖相邻页，实际驻留远低于此值。
  static const int _maxRenderCache = 48;

  /// 取缓存：命中则把键移到队尾标记为最近使用。
  static ui.Image? _cacheGet(String key) {
    final img = _renderCache[key];
    if (img != null) {
      _renderCacheOrder.remove(key);
      _renderCacheOrder.add(key);
    }
    return img;
  }

  /// 写缓存：放入并标记最近使用；超出上限时从队首淘汰并 dispose，释放 GPU 内存。
  static void _cachePut(String key, ui.Image img) {
    _renderCache[key] = img;
    _renderCacheOrder.remove(key);
    _renderCacheOrder.add(key);
    while (_renderCacheOrder.length > _maxRenderCache) {
      final oldest = _renderCacheOrder.removeAt(0);
      _renderCache[oldest]?.dispose();
      _renderCache.remove(oldest);
    }
  }

  /// 基础原生渲染缓存（两级缓存之「基础层」）：仅缓存「PDFium 原生渲染 + 裁切」的
  /// [ui.Image]，键为 [baseKey]（不含去杂色/锐化维度）。
  ///
  /// 设计目的：① 预取（[_prefetchAround]）只暖这一层，绝不做去杂色/锐化，因此预取
  /// 不再争抢 isolate 池与主线程 GPU 上传；② 正式翻页若开启了智能清晰度，可直接复用
  /// 预取/前次渲染好的基础图，仅在其上做一次后处理（去杂色/锐化），跳过昂贵的原生渲染。
  /// 独立 LRU，与终缓存互不共享实例，淘汰时各自 dispose，避免双释放。
  static final Map<String, ui.Image> _baseRenderCache = {};
  static final List<String> _baseRenderCacheOrder = [];
  /// 基础缓存上限（条）。基础图不含后处理、命中率高、复用价值大；按 ~22MB/页估算，
  /// 16 条约 350MB，足够覆盖「当前页 + 预取邻页 + 少量历史」，移动/桌面均安全。
  static const int _maxBaseCache = 16;

  /// 取基础缓存：命中则把键移到队尾标记为最近使用。
  static ui.Image? _cacheGetBase(String key) {
    final img = _baseRenderCache[key];
    if (img != null) {
      _baseRenderCacheOrder.remove(key);
      _baseRenderCacheOrder.add(key);
    }
    return img;
  }

  /// 写基础缓存：放入并标记最近使用；超出上限时从队首淘汰并 dispose。
  static void _cachePutBase(String key, ui.Image img) {
    _baseRenderCache[key] = img;
    _baseRenderCacheOrder.remove(key);
    _baseRenderCacheOrder.add(key);
    while (_baseRenderCacheOrder.length > _maxBaseCache) {
      final oldest = _baseRenderCacheOrder.removeAt(0);
      _baseRenderCache[oldest]?.dispose();
      _baseRenderCache.remove(oldest);
    }
  }

  /// 估算某页在给定「显示宽度（逻辑像素，targetWidth）」下的目标渲染像素宽。
  ///
  /// 与 [_PdfPageWidget._load] 的计算完全一致，供「相邻页预渲染」复用，确保预渲染
  /// 产出的缓存键与正式渲染命中的是同一份，避免重复渲染。
  static double estimateRenderWidth(double targetWidth) {
    final dpr = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    return (targetWidth * dpr)
        .clamp(200, maxRenderWidth.toDouble())
        .toDouble();
  }

  /// 垂直对齐基准带缓存（按 文档 sourceName 维度）。value 为 null 表示「校准中」，
  /// 非 null 为已标定的上下基准（top/bottom，归一化 0~1）。基准带让全文档在垂直方向
  /// 对齐到统一边界，消除逐页独立裁切导致的翻页上下跳动。
  static final Map<String, VerticalBand?> _bandCache = {};

  /// 清空某文档的全部渲染与裁切缓存（不释放文档本身），供基准带标定完成后触发重渲。
  static void _clearDocCaches(PdfDocument document) {
    final id = document.sourceName;
    _renderCache.removeWhere((key, img) {
      if (key.startsWith('$id:')) {
        img.dispose();
        return true;
      }
      return false;
    });
    _renderCacheOrder.removeWhere((key) => key.startsWith('$id:'));
    _baseRenderCache.removeWhere((key, img) {
      if (key.startsWith('$id:')) {
        img.dispose();
        return true;
      }
      return false;
    });
    _baseRenderCacheOrder.removeWhere((key) => key.startsWith('$id:'));
    _cropCache.removeWhere((key, _) => key.startsWith('$id:'));
  }

  /// 标定垂直对齐基准带：均匀采样最多 [_bandSampleCount] 页，取各页内容框 top/bottom
  /// 的中位数作为统一基准；完成后清空缓存使后续页面按新基准重渲。
  /// 返回标定后的基准带（失败/页数不足返回 null）。同一文档重复调用直接命中缓存。
  static const int _bandSampleCount = 40;
  static Future<VerticalBand?> calibrateVerticalBand(PdfDocument document) async {
    final id = document.sourceName;
    if (_bandCache.containsKey(id)) return _bandCache[id]; // 已标定或校准中
    _bandCache[id] = null; // 占位「校准中」，防并发重入
    try {
      final pageCount = document.pages.length;
      if (pageCount <= 0) {
        _bandCache.remove(id);
        return null;
      }
      final tops = <double>[];
      final bottoms = <double>[];
      final n = _bandSampleCount;
      for (var i = 0; i < n; i++) {
        final idx = pageCount == 1
            ? 1
            : ((i * (pageCount - 1) / (n - 1)).round() + 1).clamp(1, pageCount);
        final rect = await computeCropFractions(document, idx);
        tops.add(rect.top);
        bottoms.add(rect.bottom);
        await Future.delayed(Duration.zero); // 让出事件循环，避免校准阻塞翻页
      }
      if (tops.length < 2) {
        _bandCache.remove(id);
        _clearDocCaches(document);
        return null;
      }
      final band = VerticalBand(_median(tops), _median(bottoms));
      _bandCache[id] = band;
      _clearDocCaches(document);
      return band;
    } catch (_) {
      _bandCache.remove(id);
      return null;
    }
  }

  /// 对单页内容框应用垂直基准带：若本页内容框完全落在基准带内，垂直方向改用统一基准
  /// （上下对齐、不跳动）；否则保留本页垂直（保护满版插图/超出页）。无基准时回退逐页。
  static Rect _applyVerticalBand(PdfDocument document, Rect perPage) {
    final band = _bandCache[document.sourceName];
    if (band == null) return perPage;
    const tol = 0.01;
    final within =
        perPage.top >= band.top - tol && perPage.bottom <= band.bottom + tol;
    if (!within) return perPage;
    return Rect.fromLTRB(perPage.left, band.top, perPage.right, band.bottom);
  }

  /// 中位数（对副本排序，比平均值更抗异常页）。
  static double _median(List<double> xs) {
    final s = [...xs]..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
  }

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

  /// 自动裁切扫描用的探针图宽度。严格按 [docs/裁切原理和方法.md] 取 200px：
  /// 足以看清「宏观排版」（哪里有内容、哪里是空白），又把内存与 CPU 开销降到极低，
  /// 后续投影算法只在缩略图上定位内容起止，无需更高分辨率。
  static const int cropScanWidth = 200;

  /// 渲染单页为 [ui.Image]，支持原生精确裁切与智能去杂色。
  ///
  /// [renderWidth] 为目标像素宽（调用方应已乘 devicePixelRatio），高度按页面真实
  /// 宽高比推导；[autoCrop] 为 true 时先求内容包围盒，再用 pdfrx 的
  /// `render(x,y,width,height,fullWidth,fullHeight)` 仅渲染该子区域，得到去白边的
  /// 精确裁剪图（区别于旧方案“整体缩放去白边”的近似做法）。[denoise] 为 true 时在
  /// 渲染出的位图上执行真正的去噪点处理（仅移除孤立杂点，保留文字清晰度）。
  /// [skipPostProcess] 为 true 时（供相邻页预取）只做原生渲染并写入基础缓存、跳过
  /// 去杂色/锐化，避免预取批量触发 isolate 计算与主线程 GPU 上传、与正式翻页争抢。
  ///
  /// 返回 null 表示渲染失败（已安全兜底，不会导致阅读器崩溃）。
  static Future<ui.Image?> renderPageImage(
    PdfDocument document,
    int pageNumber, {
    required double renderWidth,
    bool autoCrop = false,
    bool denoise = false,
    double sharpness = 1.0,
    bool skipPostProcess = false,
    double manualCropLeft = 0,
    double manualCropRight = 0,
    double manualCropTop = 0,
    double manualCropBottom = 0,
  }) async {
    final fullW =
        math.min(renderWidth, maxRenderWidth.toDouble()).clamp(1.0, double.infinity);

    // 手动裁切：由框选归一化的四边边距（0~1）。任意一边 >0 即视为启用手动裁切，
    // 此时优先采用手动裁切矩形（覆盖自动裁切），保证「框选裁边」真正生效。
    final bool hasManual = manualCropLeft > 0 ||
        manualCropRight > 0 ||
        manualCropTop > 0 ||
        manualCropBottom > 0;
    final Rect? manualRect = hasManual
        ? Rect.fromLTRB(
            manualCropLeft.clamp(0.0, 1.0),
            manualCropTop.clamp(0.0, 1.0),
            (1.0 - manualCropRight).clamp(0.0, 1.0),
            (1.0 - manualCropBottom).clamp(0.0, 1.0),
          )
        : null;

    // 先求裁切包围盒（手动优先，其次自动）。该包围盒同时用于决定「有效渲染宽度」：
    // 裁切去除了左右边距（宽度占比 <1）时按比例放大渲染宽度，使裁切出的内容在显示时
    // 仍能铺满原显示宽度，从而与相邻未裁切页面在宽度上对齐，避免大小不一。
    final Rect? crop = manualRect ??
        (autoCrop
            // 借用裁切文档思路：对逐页内容框叠加「垂直基准带」对齐——落在基准带内的页
            // 统一用基准带上下边界，消除竖向滚动时的页面跳动；超界页回退逐页垂直。
            ? _applyVerticalBand(
                document, await computeCropFractions(document, pageNumber))
            : null);

    double effW = fullW;
    if (crop != null) {
      final frac = (crop.right - crop.left).clamp(0.01, 1.0);
      effW = (fullW / frac).clamp(1.0, maxRenderWidth.toDouble());
    }

    // 基准带签名：基准带存在时把其上下边界纳入缓存键，使校准前/后的渲染缓存互不命中；
    // 基准带为 null（未校准）时记为 'nb'。与 calibrateVerticalBand 内的 _clearDocCaches 双保险。
    final band = _bandCache[document.sourceName];
    final bandSig = band == null
        ? 'nb'
        : '${band.top.toStringAsFixed(4)}_${band.bottom.toStringAsFixed(4)}';
    // 基础键：仅含「原生渲染」维度（不含去杂色/锐化）。同一页无论是否开启智能清晰度，
    // 其原生渲染结果都可复用，避免「开了清晰度就重复 PDFium 原生渲染」。
    final baseKey =
        '${document.sourceName}:$pageNumber:${effW.round()}:$autoCrop:'
        '$bandSig:'
        '${manualCropLeft.toStringAsFixed(3)}_${manualCropRight.toStringAsFixed(3)}_'
        '${manualCropTop.toStringAsFixed(3)}_${manualCropBottom.toStringAsFixed(3)}';
    // 终键：在基础键上叠加去杂色/锐化维度，仅「带后处理的成品」需要区分。
    final cacheKeyFull = '$baseKey:$denoise:$sharpness';

    // 终键命中（已带后处理的成品）：直接返回，成本最低。
    final cached = _cacheGet(cacheKeyFull);
    if (cached != null) return cached;

    // 预取 / 无后处理：基础渲染命中即返回（基础图即最终图），避免重复原生渲染。
    if (skipPostProcess || (!denoise && sharpness == 1.0)) {
      final b = _cacheGetBase(baseKey);
      if (b != null) return b;
    }

    // 取基础原生渲染：优先复用基础缓存（预取已暖好的原生图），否则原生渲染并写入基础缓存。
    ui.Image? base = _cacheGetBase(baseKey);
    final bool baseFromCache = base != null;
    if (base == null) {
      try {
        base = await _lockFor(document).synchronized(() async {
          final page = document.pages[pageNumber - 1];
          final pageW = page.width;
          final pageH = page.height;
          if (pageW <= 0 || pageH <= 0) return null;
          final fullH = (effW * pageH / pageW).clamp(1.0, double.infinity);

          PdfImage? image;
          if (crop == null ||
              (crop.left <= 0.001 &&
                  crop.top <= 0.001 &&
                  crop.right >= 0.999 &&
                  crop.bottom >= 0.999)) {
            // 无裁切：整体渲染。
            image = await page.render(
              fullWidth: effW,
              fullHeight: fullH,
              backgroundColor: Colors.white,
            );
          } else {
            // 有裁切：在有效渲染宽度下只渲染内容子区域（x/y/width/height 为像素子区域，
            // fullWidth/fullHeight 为整页虚拟尺寸，二者配合即可“抠”出内容包围盒）。
            final x = (crop.left * effW).round();
            final y = (crop.top * fullH).round();
            final w = ((crop.right - crop.left) * effW).round();
            final h = ((crop.bottom - crop.top) * fullH).round();
            if (w <= 2 || h <= 2) {
              image = await page.render(
                fullWidth: effW,
                fullHeight: fullH,
                backgroundColor: Colors.white,
              );
            } else {
              image = await page.render(
                x: x,
                y: y,
                width: w,
                height: h,
                fullWidth: effW,
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
      } catch (_) {
        // 原生渲染异常不应导致阅读器崩溃，交由上层回退处理。
        return null;
      }
      if (base == null) return null;
      _cachePutBase(baseKey, base);
    }

    // 预取模式：仅把原生渲染暖进基础缓存即返回，绝不做事后处理——
    // 否则预取会批量触发去杂色/锐化的 compute 与主线程 GPU 上传，与正式翻页争抢
    // isolate 池与 UI 线程，造成「开了智能清晰度后翻几页就一直转圈」。
    if (skipPostProcess) return base;

    // 无后处理：基础图即最终图，直接返回（不写入终缓存，避免与基础缓存共享同一实例）。
    if (!denoise && sharpness == 1.0) return base;

    // 有后处理：在基础图上做去杂色/锐化，产出全新 ui.Image 并仅写入终缓存
    //（与基础缓存持有的实例绝不共享，淘汰时互不干扰）。
    ui.Image out = base;
    if (denoise) {
      final denoised = await _denoiseImage(base);
      if (denoised != base) out = denoised;
    }
    if (sharpness != 1.0) {
      out = await _sharpenImage(out, sharpness);
    }
    // 仅当后处理真正改变了图像时才写入终缓存（否则基础缓存已可复用，无需双份）。
    if (out != base) {
      // 自有（本次新渲染）的基础图派生成品后从基础缓存移除并释放，避免与终缓存双份驻留显存；
      // 来自基础缓存（被预取/其它调用共享）的基础图则保留，不释放。
      if (!baseFromCache) {
        _baseRenderCache.remove(baseKey);
        _baseRenderCacheOrder.remove(baseKey);
        base.dispose();
      }
      _cachePut(cacheKeyFull, out);
    }
    return out;
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
      _renderCacheOrder.removeWhere((key) => key.startsWith('$id:'));
      _baseRenderCache.removeWhere((key, img) {
        if (key.startsWith('$id:')) {
          img.dispose();
          return true;
        }
        return false;
      });
      _baseRenderCacheOrder.removeWhere((key) => key.startsWith('$id:'));
      _cropCache.removeWhere((key, _) => key.startsWith('$id:'));
      _bandCache.remove(id); // 基准带仅按文档缓存，关闭时一并释放
      await document.dispose();
    });
    _docLocks.remove(id);
  }

  /// 使指定页面的渲染缓存失效（下次渲染时重新生成）。
  ///
  /// 用于框选裁边等场景：用户确认裁切参数后需要立即看到效果，
  /// 清除旧缓存可强制下次 [renderPageImage] 重新渲染。
  static void invalidatePageCache(PdfDocument document, int pageNumber) {
    final id = document.sourceName;
    final prefix = '$id:$pageNumber:';
    // 移除所有与该页相关的渲染缓存（不论渲染宽度或裁切状态）
    _renderCache.removeWhere((key, _) => key.startsWith(prefix));
    _cropCache.removeWhere((key, _) => key.startsWith(prefix));
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
  /// 严格按 [docs/裁切原理和方法.md] 的「投影算法」实现：
  /// - 探针分辨率 cropScanWidth=200（文档指定，足以看清宏观排版且开销极低）；
  /// - 二值化判定：任一通道 R<245 或 G<245 或 B<245 即视为内容（非纯白）；
  /// - 行/列投影统计 rowCounts/colCounts（把二维版面压成一维）；
  /// - 动态噪点阈值：X 方向 = 宽*1.5%，Y 方向 = 高*1.5%，从四边向中心收缩，
  ///   跳过计数低于阈值的行/列（抗偶发灰尘 / 极细扫描黑边）；
  /// - 安全边距 2%：向外扩，避免边缘衬线笔画 / 图片边框被微微切断；
  /// - 兜底：收缩后无内容包围盒（left>=right 或 top>=bottom）返回整页 RectF(0,0,1,1)，
  ///   避免把白页裁没；内容几乎铺满整页时亦直接返回整页。
  static Rect _scanContent(
    Uint8List pixels,
    int w,
    int h,
    ui.PixelFormat format,
  ) {
    // pdfrx 的像素格式平台相关：rgba8888 或 bgra8888，需分别取 R/B 通道。
    final isBgra = format == ui.PixelFormat.bgra8888;

    // 行/列内容像素计数（投影）。
    final rowCounts = List<int>.filled(h, 0);
    final colCounts = List<int>.filled(w, 0);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        if (i + 2 >= pixels.lengthInBytes) break;
        final r = isBgra ? pixels[i + 2] : pixels[i];
        final g = pixels[i + 1];
        final b = isBgra ? pixels[i] : pixels[i + 2];
        // 文档口径：只要任一通道「不那么白」（<245）即计入内容，把二维版面压成投影。
        if (r < 245 || g < 245 || b < 245) {
          rowCounts[y]++;
          colCounts[x]++;
        }
      }
    }

    // 动态噪点阈值：忽略偶发灰尘 / 极细扫描黑边的轻微干扰。
    final noiseX = (w * 0.015).round();
    final noiseY = (h * 0.015).round();

    // 从四个方向向中心收缩，跳过计数低于阈值的行/列，得到内容包围盒。
    var left = 0, top = 0, right = w - 1, bottom = h - 1;
    while (top <= bottom && rowCounts[top] <= noiseY) top++;
    while (bottom >= top && rowCounts[bottom] <= noiseY) bottom--;
    while (left <= right && colCounts[left] <= noiseX) left++;
    while (right >= left && colCounts[right] <= noiseX) right--;

    // 兜底：完全空白（无内容行/列）返回整页，避免把白页裁没。
    if (left >= right || top >= bottom) {
      return const Rect.fromLTRB(0, 0, 1, 1);
    }

    // 安全边距 2%：向外扩，确保边缘细内容（页眉/页脚/分隔线）绝不被裁掉。
    final padX = (w * 0.02).round();
    final padY = (h * 0.02).round();
    left = (left - padX).clamp(0, w - 1);
    top = (top - padY).clamp(0, h - 1);
    right = (right + padX).clamp(1, w);
    bottom = (bottom + padY).clamp(1, h);

    // 内容几乎铺满整页时直接返回整页，避免边缘处的无意义微裁切。
    if (left <= 0 && top <= 0 && right >= w - 1 && bottom >= h - 1) {
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
  ///
  /// 像素级 9 邻域循环为 CPU 密集操作，放在独立 isolate（[compute]）执行，
  /// 避免开启「智能清晰度」时每页冻结主线程几百毫秒、造成翻页卡顿。
  static Future<ui.Image> _denoiseImage(ui.Image src) async {
    try {
      final bytes = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) return src;
      final rgba = bytes.buffer.asUint8List();
      // 像素级去杂色是 CPU 密集循环，放到独立 isolate 执行，避免阻塞阅读翻页主线程。
      final out = await compute(
        _denoisePixels,
        _PixelMsg(rgba, src.width, src.height),
      );
      return _bytesToImage(out, src.width, src.height);
    } catch (_) {
      // 去杂色失败不应影响阅读，退回原图。
      return src;
    }
  }

  /// 真正的清晰度增强：对渲染出的位图做 unsharp mask（原图 + amount ×（原图 − 模糊图）），
  /// 提升文字与线条的边缘对比，使扫描件更清晰。返回处理后的新 [ui.Image]。
  ///
  /// [amount] 为锐化强度：>1 锐化、<1 轻微柔化（1.0 调用方已跳过，不会进入本方法）。
  /// 模糊层用 3×3 均值近似（轻量），与 [PdfReaderSettings.sharpness] 配合。
  /// 像素级循环同样放在独立 isolate 执行，避免主线程卡顿。
  static Future<ui.Image> _sharpenImage(ui.Image src, double amount) async {
    try {
      final bytes = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) return src;
      final rgba = bytes.buffer.asUint8List();
      final out = await compute(
        _sharpenPixels,
        _SharpenMsg(rgba, src.width, src.height, amount),
      );
      return _bytesToImage(out, src.width, src.height);
    } catch (_) {
      // 锐化失败不应影响阅读，退回原图。
      return src;
    }
  }

  /// 智能清晰度：基于页面像素统计，自动估算推荐的「亮度 / 对比度 / 清晰度 / 智能去杂色」，
  /// 返回 [PdfAutoEnhanceResult]，可由 UI 一键回填到 [PdfReaderSettings] / [SettingsController]。
  ///
  /// 算法（启发式，计算 PDF 扫描件足够好，纯 Dart 无模型）：
  /// - 对比度：用亮度直方图 2% / 98% 分位（黑点/白点）拉伸到 [0,255]；
  /// - 亮度：把中灰点居中到 128 的乘法近似；
  /// - 清晰度：用边缘能量（与左/上邻域亮度差）估计高频丰富度，越低越模糊 → 越强锐化；
  /// - 去杂色：存在文本内容（暗点占比 >0.2%）即启用（[ _denoiseImage] 仅移除孤立墨点，安全）。
  static Future<PdfAutoEnhanceResult> autoEnhance(ui.Image src) async {
    try {
      final bytes = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes == null) {
        return const PdfAutoEnhanceResult(
          brightness: 1.0,
          contrast: 1.0,
          sharpness: 1.0,
          denoise: false,
        );
      }
      final rgba = bytes.buffer.asUint8List();
      final w = src.width;
      final h = src.height;
      final n = w * h;

      // 亮度直方图 + 暗点计数。
      final hist = List<int>.filled(256, 0);
      int inkCount = 0;
      for (var p = 0; p < n; p++) {
        final i = p * 4;
        final lum = (0.299 * rgba[i] +
                0.587 * rgba[i + 1] +
                0.114 * rgba[i + 2])
            .toInt()
            .clamp(0, 255);
        hist[lum]++;
        if (lum < 140) inkCount++;
      }

      // 黑点 / 白点（2% 与 98% 分位）。
      int blackPt = 0, whitePt = 255, cum = 0;
      final lowTh = (n * 0.02).toInt();
      final highTh = (n * 0.98).toInt();
      for (var v = 0; v < 256; v++) {
        cum += hist[v];
        if (cum >= lowTh && blackPt == 0) blackPt = v;
        if (cum >= highTh) {
          whitePt = v;
          break;
        }
      }
      final span = (whitePt - blackPt).clamp(1, 255);
      // 对比度：把 [blackPt, whitePt] 拉伸到 [0,255]。
      final contrast = (255.0 / span).clamp(0.5, 2.0);
      // 亮度：中灰点居中到 128（乘法近似）。
      final mid = (blackPt + whitePt) ~/ 2;
      final brightness = (128.0 / mid.clamp(1, 255)).clamp(0.3, 1.5);

      // 清晰度：边缘能量（与左/上邻域亮度差的绝对值之和）估计高频丰富度。
      int edgeEnergy = 0;
      for (var y = 1; y < h; y++) {
        for (var x = 1; x < w; x++) {
          final i = (y * w + x) * 4;
          final j = (y * w + (x - 1)) * 4;
          final k = ((y - 1) * w + x) * 4;
          final l1 =
              0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2];
          final l2 =
              0.299 * rgba[j] + 0.587 * rgba[j + 1] + 0.114 * rgba[j + 2];
          final l3 =
              0.299 * rgba[k] + 0.587 * rgba[k + 1] + 0.114 * rgba[k + 2];
          edgeEnergy += ((l1 - l2).abs() + (l1 - l3).abs()).toInt();
        }
      }
      final avgEdge = edgeEnergy / ((w - 1) * (h - 1));
      double sharpness = 1.0;
      if (avgEdge < 18) {
        sharpness = 1.6;
      } else if (avgEdge < 30) {
        sharpness = 1.3;
      }

      // 去杂色：存在文本内容（暗点占比 >0.2%）即启用，安全去除孤立墨点。
      final inkRatio = inkCount / n;
      final denoise = inkRatio > 0.002;

      return PdfAutoEnhanceResult(
        brightness: brightness,
        contrast: contrast,
        sharpness: sharpness,
        denoise: denoise,
      );
    } catch (_) {
      return const PdfAutoEnhanceResult(
        brightness: 1.0,
        contrast: 1.0,
        sharpness: 1.0,
        denoise: false,
      );
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

  /// 饱和度矩阵：s=1 原色（单位阵），s=0 灰度。
  ///
  /// 每行独立计算对角元，保证 s=1 时输出恒等矩阵。
  static _Matrix4x4 _saturation(double s) {
    const lr = 0.2126;
    const lg = 0.7152;
    const lb = 0.0722;
    return _Matrix4x4.fromRows(
      // R 输出行
      [lr * (1 - s) + s, lg * (1 - s), lb * (1 - s), 0,
       // G 输出行
       lr * (1 - s), lg * (1 - s) + s, lb * (1 - s), 0,
       // B 输出行
       lr * (1 - s), lg * (1 - s), lb * (1 - s) + s, 0,
       // A 行（直通）
       0, 0, 0, 1],
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

  /// 色温矩阵：t=1 原色；t>1 偏暖（红/绿增强、蓝抑制）；t<1 偏冷（蓝增强、红抑制）。
  ///
  /// 采用通道「乘子」（而非偏移）实现：保留色彩饱和度，仅平移 R/B 平衡，色温变化清晰可见；
  /// 旧实现用极小偏移量，几乎看不出效果，且偏置会削弱色彩观感（用户反馈「调了色温没作用 / 像没颜色」）。
  static _Matrix4x4 _colorTemperature(double t) {
    if (t >= 0.99 && t <= 1.01) return _Matrix4x4.identity();
    if (t > 1.0) {
      // 暖色：f ∈ [0,1]（t 由 1 → 2）
      final f = (t - 1.0).clamp(0.0, 1.0);
      return _Matrix4x4.fromRows(
        [1 + 0.2 * f, 0, 0, 0,
         0, 1 + 0.05 * f, 0, 0,
         0, 0, 1 - 0.2 * f, 0,
         0, 0, 0, 1],
        const [0, 0, 0, 0],
      );
    }
    // 冷色：f ∈ [0,0.5]（t 由 1 → 0.5）
    final f = (1.0 - t).clamp(0.0, 1.0);
    return _Matrix4x4.fromRows(
      [1 - 0.15 * f, 0, 0, 0,
       0, 1 - 0.03 * f, 0, 0,
       0, 0, 1 + 0.2 * f, 0,
       0, 0, 0, 1],
      const [0, 0, 0, 0],
    );
  }
}

/// 跨 isolate 传递的像素消息（[Uint8List] 可直接转移，int 为尺寸）。
class _PixelMsg {
  final Uint8List rgba;
  final int w;
  final int h;

  const _PixelMsg(this.rgba, this.w, this.h);
}

/// 跨 isolate 传递的锐化消息（含锐化强度 amount）。
class _SharpenMsg {
  final Uint8List rgba;
  final int w;
  final int h;
  final double amount;

  const _SharpenMsg(this.rgba, this.w, this.h, this.amount);
}

/// 把 RGBA 字节解码回 [ui.Image]（GPU 上传，主线程但开销低）。
Future<ui.Image> _bytesToImage(Uint8List rgba, int w, int h) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    w,
    h,
    ui.PixelFormat.rgba8888,
    (image) => completer.complete(image),
  );
  return completer.future;
}

/// 去杂色像素处理（在独立 isolate 执行，避免阻塞 UI 主线程）。
///
/// 仅移除「孤立」黑点/杂色，保留文字笔画（与 [PdfRenderService._denoiseImage] 同算法）。
Uint8List _denoisePixels(_PixelMsg msg) {
  final rgba = msg.rgba;
  final w = msg.w;
  final h = msg.h;
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
  return out;
}

/// 清晰度增强像素处理（在独立 isolate 执行）。unsharp mask：原图 + amount×(原图−模糊)。
Uint8List _sharpenPixels(_SharpenMsg msg) {
  final rgba = msg.rgba;
  final w = msg.w;
  final h = msg.h;
  final amount = msg.amount;
  final out = Uint8List.fromList(rgba);

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      // 3×3 邻域均值作为低频（模糊）层。
      int sr = 0, sg = 0, sb = 0, sn = 0;
      for (var ny = y - 1; ny <= y + 1; ny++) {
        for (var nx = x - 1; nx <= x + 1; nx++) {
          if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
          final j = (ny * w + nx) * 4;
          sr += rgba[j];
          sg += rgba[j + 1];
          sb += rgba[j + 2];
          sn++;
        }
      }
      final br = sr ~/ sn, bg = sg ~/ sn, bb = sb ~/ sn;
      // unsharp：out = original + amount × (original − blurred)
      out[i] = (rgba[i] + amount * (rgba[i] - br)).clamp(0, 255).toInt();
      out[i + 1] = (rgba[i + 1] + amount * (rgba[i + 1] - bg)).clamp(0, 255).toInt();
      out[i + 2] = (rgba[i + 2] + amount * (rgba[i + 2] - bb)).clamp(0, 255).toInt();
      out[i + 3] = rgba[i + 3];
    }
  }
  return out;
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
