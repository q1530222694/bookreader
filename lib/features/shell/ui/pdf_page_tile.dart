import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:pdfx/pdfx.dart';

import '../model/pdf_reader_settings.dart';
import '../service/pdf_render_service.dart';

/// 单页 PDF 渲染瓦片（Dumb UI：仅接收数据与回调，不持有业务状态）。
///
/// 负责：
/// - 按 [renderWidth]（逻辑像素宽）与目标 DPR 渲染页面字节；
/// - 自动裁切：经 [PdfRenderService.computeCropFractions] 求内容包围盒后精确裁切；
/// - 背景调节：经 [PdfRenderService.buildColorMatrix] 合成 [ColorFilter]，
///   并以 [ImageFiltered] 实现智能去杂色（轻微高斯模糊近似）；
/// - [zoomable] 为真时使用 [PhotoView] 支持双指缩放（用于单页/双页翻页模式），
///   否则按 [BoxFit] 铺满（用于连续滚动模式）。
class PdfPageTile extends StatefulWidget {
  final PdfDocument document;
  final int pageNumber;
  final PdfReaderSettings settings;

  /// 该页渲染的逻辑像素宽度（双页模式下单页为屏宽一半）。
  final double renderWidth;

  /// 是否可缩放（翻页模式启用 [PhotoView]）。
  final bool zoomable;

  /// 连续模式下的填充方式（通常为 [BoxFit.fitWidth]）。
  final BoxFit fit;

  const PdfPageTile({
    super.key,
    required this.document,
    required this.pageNumber,
    required this.settings,
    required this.renderWidth,
    this.zoomable = false,
    this.fit = BoxFit.fitWidth,
  });

  @override
  State<PdfPageTile> createState() => _PdfPageTileState();
}

class _PdfPageTileState extends State<PdfPageTile> {
  Uint8List? _bytes;
  double? _pageAspect; // 宽/高，用于连续模式下的高度撑开
  bool _loading = true;
  bool _error = false;

  /// 当前设备像素比（在 [didChangeDependencies] 中安全采集，供 [_load] 使用）。
  /// 不在 initState 中读取 MediaQuery：initState 阶段禁止依赖 InheritedWidget，
  /// 且此时正处于 PageView.builder 首帧挂载，任何 setState/依赖查询都会抛异常。
  double _devicePixelRatio = 1.0;

  /// 是否已触发过首次加载（避免 didChangeDependencies 多次触发重复渲染）。
  bool _didInitialLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery 依赖查询只能在 didChangeDependencies（及之后）进行。
    _devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    // 首帧挂载完成后仅触发一次首次渲染；延迟到首帧之后执行，避免在本构建阶段
    // 调用 _load 内的 setState（会触发「setState called during build」）。
    if (!_didInitialLoad) {
      _didInitialLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  @override
  void didUpdateWidget(PdfPageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 仅在需要改变像素内容（自动裁切开关、渲染宽度、页码）时才重新渲染；
    // 颜色调整（亮度/对比度/饱和度/去色/去杂色）只改滤镜，无需重渲染。
    if (oldWidget.settings.autoCrop != widget.settings.autoCrop ||
        oldWidget.renderWidth != widget.renderWidth ||
        oldWidget.pageNumber != widget.pageNumber ||
        oldWidget.document != widget.document) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    // 注意：首次 _load 由 didChangeDependencies 在挂载期间触发，此处严禁在首个
    // await 之前调用 setState（会触发「setState called during build」）。改为直接
    // 置位加载态字段（首帧构建本就展示菊花），拿到字节后再于 await 之后 setState。
    _loading = true;
    _error = false;

    // 使用在 didChangeDependencies 中缓存的 dpr，避免 initState/构建期查询 MediaQuery。
    final dpr = _devicePixelRatio;
    final renderWidthPx = (widget.renderWidth * dpr).clamp(1.0, 2000.0);

    // 自动裁切：先求内容包围盒（归一化）
    Rect? cropFrac;
    if (widget.settings.autoCrop) {
      try {
        cropFrac = await PdfRenderService.computeCropFractions(
          widget.document,
          widget.pageNumber,
        );
      } catch (_) {
        cropFrac = null;
      }
    }

    if (!mounted) return;
    // 单次取页 + 渲染 + 关闭（服务内部文档锁串行化），返回字节与宽高比。
    final result = await PdfRenderService.renderPageBytes(
      widget.document,
      widget.pageNumber,
      renderWidth: renderWidthPx,
      cropFrac: cropFrac,
    );

    if (!mounted) return;
    if (result != null) {
      setState(() {
        _bytes = result.bytes;
        _pageAspect = result.aspectRatio;
        _loading = false;
        _error = false;
      });
    } else {
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  /// 应用颜色调整与去杂色滤镜，包裹原始图片。
  Widget _buildFiltered(Widget image) {
    Widget body = image;
    if (widget.settings.denoise) {
      // 智能去杂色：以极小半径的高斯模糊柔化孤立小黑点 / 杂点。
      body = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 0.7, sigmaY: 0.7),
        child: body,
      );
    }
    final matrix = PdfRenderService.buildColorMatrix(widget.settings);
    if (matrix != null) {
      body = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: body,
      );
    }
    return body;
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
        color: CupertinoColors.white,
        child: const Center(
          child: Icon(
            CupertinoIcons.exclamationmark_triangle,
            color: CupertinoColors.systemGrey,
          ),
        ),
      );
    }

    if (_loading || _bytes == null) {
      return SizedBox(
        height: _pageAspect != null ? widget.renderWidth / _pageAspect! : 200,
        child: const Center(child: CupertinoActivityIndicator()),
      );
    }

    final image = Image.memory(
      _bytes!,
      fit: widget.fit,
      filterQuality: FilterQuality.high,
    );
    final filtered = _buildFiltered(image);

    if (widget.zoomable) {
      // 必须显式给出 childSize：zoomable 模式下子节点为无限尺寸的 Container，
      // 若不提供 childSize，PhotoView 在布局阶段会因无法测量子节点尺寸而断言崩溃。
      // 用「渲染宽度 × 页面宽高比」推导出确定尺寸作为 childSize，避免该崩溃。
      final aspect = _pageAspect;
      final childSize = aspect != null
          ? Size(widget.renderWidth, widget.renderWidth / aspect)
          : Size(widget.renderWidth, widget.renderWidth * 1.4);
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: CupertinoColors.white,
        child: PhotoView.customChild(
          childSize: childSize,
          minScale: PhotoViewComputedScale.contained * 0.5,
          maxScale: PhotoViewComputedScale.contained * 4.0,
          initialScale: PhotoViewComputedScale.contained,
          backgroundDecoration:
              const BoxDecoration(color: Color(0x00000000)),
          filterQuality: FilterQuality.high,
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: filtered,
          ),
        ),
      );
    }

    // 连续模式：以页面宽高比撑开容器，避免图片被拉伸
    if (_pageAspect != null) {
      return AspectRatio(
        aspectRatio: _pageAspect!,
        child: Container(color: CupertinoColors.white, child: filtered),
      );
    }
    return Container(color: CupertinoColors.white, child: filtered);
  }
}
