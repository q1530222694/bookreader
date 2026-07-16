import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:pdfrx/pdfrx.dart';

import '../model/pdf_reader_settings.dart';
import '../service/pdf_render_service.dart';

/// PDF 自定义阅读视图（Dumb UI：仅消费 [PdfDocument] 与 [PdfReaderSettings]）。
///
/// 基于 pdfrx 低层渲染 API 自建，真正支持：
/// - 版面：单页(0) / 双页(1) / 单页连续(2) / 双页连续(3)；
/// - 翻页方式（[pageMode]）：
///   0 左右滑动（横向滑动 / 滚动翻页）、1 上下滑动（纵向滑动 / 滚动翻页）、
///   2 左右单击（点击屏幕左 / 右区域翻页）、3 上下单击（点击屏幕上 / 下区域翻页）、
///   4 单击滚动（点击屏幕任意处翻页，同时滑动 / 滚动也可翻页）；
/// - 翻页动画（[pageAnimation]）：0 无动画（瞬时跳转）、1 仿真（带过渡动画）；
/// - 自动裁切：经 [PdfRenderService] 用 pdfrx 原生子区域渲染实现精确去白边；
/// - 颜色调整（亮度/对比度/饱和度/去色）与智能去杂色：纯 Flutter GPU/CPU 合成叠加。
///
/// 与旧方案（pdfx 的 [PdfView]）的区别：旧控件不支持自定义版面与裁切，双页被降级为
/// 单页、裁切只是缩放去白边近似；本视图完全掌控页面布局与渲染，满足真实需求。
class PdfCustomView extends StatefulWidget {
  final PdfDocument document;
  final PdfReaderSettings settings;
  /// 翻页方式：0 左右滑动 / 1 上下滑动 / 2 左右单击 / 3 上下单击 / 4 单击滚动。
  final int pageMode;
  /// 翻页动画：0 无动画 / 1 仿真动画。
  final int pageAnimation;
  /// 翻页/滚动时回调当前页码（1-based），用于同步阅读进度。
  final ValueChanged<int>? onPageChanged;

  const PdfCustomView({
    super.key,
    required this.document,
    required this.settings,
    required this.pageMode,
    this.pageAnimation = 1,
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

  /// 横向翻页方式：左右滑动(0) 与 左右单击(2) 使用横向轴。
  bool get _isHorizontal => widget.pageMode == 0 || widget.pageMode == 2;
  bool get _isContinuous =>
      widget.settings.layoutMode == 2 || widget.settings.layoutMode == 3;
  /// 是否使用 PageView（逐页吸附）：仅在「非连续」版面时（单页0 / 双页1）。
  bool get _usePageView => !_isContinuous;
  /// 是否允许滑动/滚动翻页：纯单击模式（左右单击2 / 上下单击3）禁用滑动，仅靠点击。
  bool get _swipeEnabled => widget.pageMode != 2 && widget.pageMode != 3;
  /// 是否启用点击翻页（左右单击 / 上下单击 / 单击滚动）。
  bool get _tapFlip => widget.pageMode == 2 ||
      widget.pageMode == 3 ||
      widget.pageMode == 4;

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
        old.pageMode != widget.pageMode ||
        old.pageAnimation != widget.pageAnimation) {
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
      // 双页模式：直接两两成对，不再把封面或末页强制单独成页（与大多数阅读器一致）。
      for (int i = 0; i < pageCount; i += 2) {
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
      final dist = dy >= 0 ? dy : -dy * 2;
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    _reportPage(best);
  }

  /// 翻到上一页 / 下一页（同时驱动进度上报）。
  void _goPrev() => _animateToSpread(_currentSpreadIndex() - 1);
  void _goNext() => _animateToSpread(_currentSpreadIndex() + 1);

  int _currentSpreadIndex() {
    if (_usePageView && _pageController != null) {
      return _pageController!.page?.round() ?? 0;
    }
    return 0;
  }

  void _animateToSpread(int index) {
    final clamped = index.clamp(0, _spreads.length - 1);
    final animate = widget.pageAnimation == 1;
    if (_usePageView && _pageController != null) {
      if (animate) {
        _pageController!.animateToPage(
          clamped,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController!.jumpToPage(clamped);
      }
    } else if (_scrollController != null) {
      // 连续模式：按一个视口高度滚动一“页”。
      final offset =
          (_scrollController!.offset + (clamped - _currentSpreadIndex()) * 600)
              .clamp(0.0, _scrollController!.position.maxScrollExtent);
      if (animate) {
        _scrollController!.animateTo(
          offset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _scrollController!.jumpTo(offset);
      }
    }
  }

  /// 点击翻页：根据翻页方式判定前进 / 后退方向。
  void _onTapFlip(TapUpDetails details) {
    final size = MediaQuery.of(context).size;
    switch (widget.pageMode) {
      case 2: // 左右单击：左半屏上一页，右半屏下一页
        if (details.localPosition.dx < size.width / 2) {
          _goPrev();
        } else {
          _goNext();
        }
      case 3: // 上下单击：上半屏上一页，下半屏下一页
        if (details.localPosition.dy < size.height / 2) {
          _goPrev();
        } else {
          _goNext();
        }
      case 4: // 单击滚动：点击任意处翻到下一页（中心区域由上层设置面板接管）
      default:
        _goNext();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scrollDir = _isHorizontal ? Axis.horizontal : Axis.vertical;
    // 外层 LayoutBuilder 拿到的是屏幕确定尺寸；而 PageView/ListView 在滚动轴上会给出
    // 无限约束，单页尺寸必须从外层获取，否则在「上下滚动」模式会出现“无限高度”断言，
    // 或在单页分支误用 Expanded（Center 非 Flex）导致崩溃。
    return LayoutBuilder(
      builder: (context, constraints) {
        final double pageW = constraints.maxWidth;
        final double pageH = constraints.maxHeight;

        Widget body;
        if (_usePageView) {
          body = PageView.builder(
            controller: _pageController,
            scrollDirection: scrollDir,
            // 纯单击模式禁用滑动，仅由点击驱动翻页；其余模式允许滑动。
            physics: _swipeEnabled
                ? null
                : const NeverScrollableScrollPhysics(),
            itemCount: _spreads.length,
            itemBuilder: (context, i) =>
                _buildSpread(i, scrollDir, pageW, pageH),
            onPageChanged: (i) => _reportPage(i),
          );
        } else {
          body = NotificationListener<ScrollNotification>(
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
                child: _buildSpread(i, scrollDir, pageW, pageH),
              ),
            ),
          );
        }

        // 点击翻页：用透明手势层包裹，不抢占滑动（快速滑动仍由底层滚动控件处理）。
        if (_tapFlip) {
          body = GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: _onTapFlip,
            child: body,
          );
        }
        return body;
      },
    );
  }

  /// 构建单个对开页（1 或 2 个页面）。
  ///
  /// [pageW]/[pageH] 由外层 [LayoutBuilder] 传入（屏幕确定尺寸），保证单页铺满视口；
  /// 双页用 [Row] 承载两个 [Expanded]（Row 是 Flex，Expanded 合法），单页直接铺满，
  /// 不再把 [Expanded] 误放进 [Center]（Center 非 Flex，会触发断言/崩溃）。
  /// 连续模式下的页间间隙统一收窄为 [_pageGap]，仅留极细分隔区分页面。
  Widget _buildSpread(int index, Axis scrollDir, double pageW, double pageH) {
    final pages = _spreads[index];
    final isTwo = pages.length == 2;
    if (isTwo) {
      final perPageWidth = (pageW - _pageGap) / 2;
      return SizedBox(
        width: pageW,
        height: pageH,
        // clipBehavior: none 防止 Row 的溢出被硬裁剪（FittedBox/BoxFit.contain 保证内容不越界，
        // 但 PDF 原始页面可能含极微超出 CropBox/MediaBox 的像素，不应被静默切掉）。
        child: ClipRect(
          clipBehavior: Clip.none,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PdfPageWidget(
                  document: widget.document,
                  pageIndex: pages[0],
                  settings: widget.settings,
                  targetWidth: perPageWidth,
                ),
              ),
              SizedBox(width: _pageGap),
              Expanded(
                child: _PdfPageWidget(
                  document: widget.document,
                  pageIndex: pages[1],
                  settings: widget.settings,
                  targetWidth: perPageWidth,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      width: pageW,
      height: pageH,
      child: _PdfPageWidget(
        document: widget.document,
        pageIndex: pages[0],
        settings: widget.settings,
        targetWidth: pageW,
      ),
    );
  }

  /// 双页 / 连续模式下的页间间隙（逻辑像素）：仅留极细分隔，页面彼此紧邻。
  static const double _pageGap = 6.0;
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
        old.settings.denoise != widget.settings.denoise ||
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
      denoise: widget.settings.denoise,
    );
    if (!mounted) return;
    setState(() {
      _image = img;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 使用 FittedBox 包裹 RawImage（而非直接用 RawImage.fit）：
    // - FittedBox 保证子 widget 在约束内按 fit 缩放且绝不裁切像素；
    // - RawImage 负责将 ui.Image 渲染为纹理；
    // - 这比直接 RawImage(fit:contain) 更可靠：后者在某些高 DPI / Expanded 组合下
    //   存在边缘 1-2px 被吞的边界行为（尤其双页 Row 中每页仅半屏宽时）。
    Widget child = _image == null
        ? Center(
            child: _loading
                ? const CupertinoActivityIndicator()
                : const SizedBox.shrink(),
          )
        : FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topLeft,
            child: RawImage(image: _image),
          );

    // 颜色调整：仅在确有调整时包裹 ColorFiltered（纯 GPU 合成，无原生调用）。
    final matrix = PdfRenderService.buildColorMatrix(widget.settings);
    if (matrix != null) {
      child = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: child,
      );
    }
    // 注：原先在此包裹的 InteractiveViewer（pinch 缩放）其手势识别器会拦截单指滑动，
    // 导致 PageView/ListView 无法接收翻页/滚动手势。为保证翻页与滚动正常，已移除该层；
    // 缩放能力后续将以“不抢占翻页手势”的方式（如仅在已放大态启用）重新接入。
    // 智能去杂色已在 PdfRenderService 渲染期完成（真正的去噪点处理，不靠模糊），此处无需再叠加。
    return child;
  }
}
