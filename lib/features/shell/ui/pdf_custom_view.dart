import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../model/pdf_reader_settings.dart';
import '../service/pdf_render_service.dart';

/// PDF 自定义阅读视图（Dumb UI：仅消费 [PdfDocument] 与 [PdfReaderSettings]）。
///
/// 基于 pdfrx 低层渲染 API 自建，真正支持：
/// - 版面：单页(0) / 双页(1) / 单页连续(2) / 双页连续(3)；
/// - 翻页方式：左右翻页(0) / 上下滚动(1) / 仿真(2) / 无(3)；
///   左右翻页与仿真走 [PageView]（逐页吸附），上下滚动与无走 [ListView]（自由滚动）；
/// - 自动裁切：经 [PdfRenderService] 用 pdfrx 原生子区域渲染实现精确去白边；
/// - 颜色调整（亮度/对比度/饱和度/去色）与智能去杂色：纯 Flutter GPU 合成叠加。
///
/// 与旧方案（pdfx 的 [PdfView]）的区别：旧控件不支持自定义版面与裁切，双页被降级为
/// 单页、裁切只是缩放去白边近似；本视图完全掌控页面布局与渲染，满足真实需求。
class PdfCustomView extends StatefulWidget {
  final PdfDocument document;
  final PdfReaderSettings settings;
  /// 翻页方式：0 左右翻页 / 1 上下滚动 / 2 仿真 / 3 无。
  final int pageMode;
  /// 翻页/滚动时回调当前页码（1-based），用于同步阅读进度。
  final ValueChanged<int>? onPageChanged;

  const PdfCustomView({
    super.key,
    required this.document,
    required this.settings,
    required this.pageMode,
    this.onPageChanged,
  });

  @override
  State<PdfCustomView> createState() => _PdfCustomViewState();
}

class _PdfCustomViewState extends State<PdfCustomView> {
  /// 每个元素是一“对开页”的 0-based 页码列表（单页为长度1，双页为长度2）。
  late List<List<int>> _spreads;
  PageController? _pageController;
  ScrollController? _scrollController;
  final List<GlobalKey> _spreadKeys = [];
  final GlobalKey _listKey = GlobalKey();

  bool get _isHorizontal => widget.pageMode == 0 || widget.pageMode == 2;
  bool get _isContinuous =>
      widget.settings.layoutMode == 2 || widget.settings.layoutMode == 3;
  /// 是否使用 PageView（逐页吸附）：仅在「非连续 + 横向（左右翻页/仿真）」时。
  bool get _usePageView => !_isContinuous && _isHorizontal;

  @override
  void initState() {
    super.initState();
    _buildSpreads();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant PdfCustomView old) {
    super.didUpdateWidget(old);
    // 版面或翻页方式变化：重建对开页划分与滚动控制器。
    if (old.settings.layoutMode != widget.settings.layoutMode ||
        old.pageMode != widget.pageMode) {
      _disposeControllers();
      _buildSpreads();
      _initControllers();
    }
  }

  void _buildSpreads() {
    final layout = widget.settings.layoutMode;
    final isTwoPage = layout == 1 || layout == 3;
    final pageCount = widget.document.pages.length;
    _spreads = [];
    if (isTwoPage) {
      // 封面单独成页，其后两两成对（常见书籍对开排版）。
      _spreads.add([0]);
      for (int i = 1; i < pageCount; i += 2) {
        _spreads.add([i, if (i + 1 < pageCount) i + 1]);
      }
    } else {
      for (int i = 0; i < pageCount; i++) {
        _spreads.add([i]);
      }
    }
    _spreadKeys.clear();
    for (int i = 0; i < _spreads.length; i++) {
      _spreadKeys.add(GlobalKey());
    }
  }

  void _initControllers() {
    if (_usePageView) {
      _pageController = PageController();
    } else {
      _scrollController = ScrollController();
    }
  }

  void _disposeControllers() {
    _pageController?.dispose();
    _pageController = null;
    _scrollController?.dispose();
    _scrollController = null;
  }

  /// 由对开页索引推导当前页码（取该对开页首页，1-based）并上报。
  void _reportPage(int spreadIndex) {
    if (spreadIndex < 0 || spreadIndex >= _spreads.length) return;
    final firstPage = _spreads[spreadIndex].first + 1;
    widget.onPageChanged?.call(firstPage);
  }

  /// 连续滚动模式下，滚动结束后找到视口顶部最近的对开页并上报。
  void _reportVisiblePage() {
    // 通过 ListView 的 GlobalKey 取得视口渲染盒，计算其全局顶部作为基准。
    final viewportBox =
        _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null) return;
    final top = viewportBox.localToGlobal(Offset.zero).dy;
    int best = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < _spreadKeys.length; i++) {
      final box =
          _spreadKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final dy = box.localToGlobal(Offset.zero).dy - top;
      // 偏好已进入视口（dy>=0）且更贴近顶部的项。
      final dist = dy >= 0 ? dy : -dy * 2;
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    _reportPage(best);
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scrollDir = _isHorizontal ? Axis.horizontal : Axis.vertical;

    if (_usePageView) {
      return PageView.builder(
        controller: _pageController,
        scrollDirection: scrollDir,
        itemCount: _spreads.length,
        itemBuilder: (context, i) => _buildSpread(i, scrollDir),
        onPageChanged: (i) => _reportPage(i),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification) _reportVisiblePage();
        return false;
      },
      child: ListView.builder(
        key: _listKey,
        controller: _scrollController,
        scrollDirection: scrollDir,
        itemCount: _spreads.length,
        itemBuilder: (context, i) => KeyedSubtree(
          key: _spreadKeys[i],
          child: _buildSpread(i, scrollDir),
        ),
      ),
    );
  }

  /// 构建单个对开页（1 或 2 个页面）。
  Widget _buildSpread(int index, Axis scrollDir) {
    final pages = _spreads[index];
    final isTwo = pages.length == 2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final perPageWidth = isTwo
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        final children = pages.map((p) {
          return Expanded(
            child: _PdfPageWidget(
              document: widget.document,
              pageIndex: p,
              settings: widget.settings,
              targetWidth: perPageWidth,
            ),
          );
        }).toList();

        if (isTwo) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                children[0],
                const SizedBox(width: 12),
                if (children.length > 1) children[1],
              ],
            ),
          );
        }
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Center(child: children.first),
        );
      },
    );
  }
}

/// 单页渲染瓦片：按需调用 [PdfRenderService] 渲染，并叠加颜色滤镜与缩放。
class _PdfPageWidget extends StatefulWidget {
  final PdfDocument document;
  final int pageIndex; // 0-based
  final PdfReaderSettings settings;
  final double targetWidth; // 目标显示宽度（逻辑像素），用于推导渲染分辨率

  const _PdfPageWidget({
    required this.document,
    required this.pageIndex,
    required this.settings,
    required this.targetWidth,
  });

  @override
  State<_PdfPageWidget> createState() => _PdfPageWidgetState();
}

class _PdfPageWidgetState extends State<_PdfPageWidget> {
  ui.Image? _image;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _PdfPageWidget old) {
    super.didUpdateWidget(old);
    // 仅当自动裁切或目标宽度变化时需要重新渲染；亮度/去色/去杂色等仅由 build 重包滤镜。
    if (old.settings.autoCrop != widget.settings.autoCrop ||
        old.targetWidth.round() != widget.targetWidth.round()) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final dpr = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    final double renderWidth = (widget.targetWidth * dpr)
        .clamp(200, PdfRenderService.maxRenderWidth.toDouble())
        .toDouble();
    final img = await PdfRenderService.renderPageImage(
      widget.document,
      widget.pageIndex + 1,
      renderWidth: renderWidth,
      autoCrop: widget.settings.autoCrop,
    );
    if (!mounted) return;
    setState(() {
      _image = img;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _image == null
        ? Center(
            child: _loading
                ? const CupertinoActivityIndicator()
                : const SizedBox.shrink(),
          )
        : RawImage(
            image: _image,
            fit: BoxFit.contain,
          );

    // 颜色调整：仅在确有调整时包裹 ColorFiltered（纯 GPU 合成，无原生调用）。
    final matrix = PdfRenderService.buildColorMatrix(widget.settings);
    if (matrix != null) {
      child = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: child,
      );
    }
    // 智能去杂色：轻度高斯模糊平滑扫描件的细碎杂点（GPU 合成，无原生调用）。
    if (widget.settings.denoise) {
      child = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 1.4, sigmaY: 1.4),
        child: child,
      );
    }
    // 缩放：pinch 放大，缩放比为 1 时不平移以保证父级滚动可用。
    child = InteractiveViewer(
      panEnabled: false,
      minScale: 1.0,
      maxScale: 4.0,
      child: child,
    );

    return child;
  }
}
