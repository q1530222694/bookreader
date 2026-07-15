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

  @override
  void initState() {
    super.initState();
    _load();
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
    setState(() {
      _loading = true;
      _error = false;
    });

    final dpr = MediaQuery.of(context).devicePixelRatio;
    final renderWidthPx = (widget.renderWidth * dpr).clamp(1.0, 2000.0);

    // 页面尺寸（用于连续模式高度撑开，缓存复用）
    Size? size;
    try {
      size = await PdfRenderService.pageSize(widget.document, widget.pageNumber);
    } catch (_) {
      size = null;
    }
    if (!mounted) return;
    if (size != null && size.width > 0) {
      setState(() => _pageAspect = size!.width / size.height);
    }

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
    final bytes = await PdfRenderService.renderPageBytes(
      widget.document,
      widget.pageNumber,
      renderWidth: renderWidthPx,
      cropFrac: cropFrac,
    );

    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
      _error = bytes == null;
    });
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
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: CupertinoColors.white,
        child: PhotoView.customChild(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: filtered,
          ),
          minScale: PhotoViewComputedScale.contained * 0.5,
          maxScale: PhotoViewComputedScale.contained * 4.0,
          initialScale: PhotoViewComputedScale.contained,
          backgroundDecoration:
              const BoxDecoration(color: Color(0x00000000)),
          filterQuality: FilterQuality.high,
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
