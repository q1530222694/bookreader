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
  State<PdfCustomView> createState() => PdfCustomViewState();
}

class PdfCustomViewState extends State<PdfCustomView> {
  /// 每个元素是一“对开页”的 0-based 页码列表（单页为长度1，双页为长度2）。
  late List<List<int>> _spreads;
  PageController? _pageController;
  ScrollController? _scrollController;
  final List<GlobalKey> _spreadKeys = [];
  final GlobalKey _listKey = GlobalKey();
  // 双屏两栏各自的 State 句柄，用于把进度跳转同时作用到左右两栏。
  final GlobalKey<DualScreenPaneState> _leftPaneKey = GlobalKey();
  final GlobalKey<DualScreenPaneState> _rightPaneKey = GlobalKey();

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

  /// 由 1-based 页码推导对开页索引（双页模式每两页一对开，单页模式一一对应）。
  int _pageToSpread(int pageNumber) {
    final oneBased = pageNumber.clamp(1, widget.document.pages.length);
    final isTwoPage =
        widget.settings.layoutMode == 1 || widget.settings.layoutMode == 3;
    return isTwoPage ? (oneBased - 1) ~/ 2 : (oneBased - 1);
  }

  /// 对外暴露：跳转到指定页码（1-based）。双屏模式同时滚动左右两栏。
  void jumpToPage(int pageNumber) {
    if (widget.settings.dualScreen) {
      _leftPaneKey.currentState?.jumpToPage(pageNumber);
      _rightPaneKey.currentState?.jumpToPage(pageNumber);
      _reportPage(_pageToSpread(pageNumber));
      return;
    }
    _animateToSpread(_pageToSpread(pageNumber));
  }

  /// 对外暴露：上一页 / 下一页（与点击翻页同行为）。
  void goPrevPage() => _goPrev();
  void goNextPage() => _goNext();

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

  /// 构建双屏对比视图：左右分屏，各含独立的滚动控制器与页面列表，
  /// 用于同一文档不同位置的对比阅读（如对照译文与原文、或前后章节对比）。
  ///
  /// 布局：水平分割线分隔左/右两栏，每栏为完整的单页连续阅读视图，
  /// 各自独立滚动（ScrollController 互不干扰），页码独立上报（以左侧为准）。
  Widget _buildDualScreenView(BuildContext context) {
    // 双屏模式下强制使用垂直连续滚动（最自然的对比阅读体验）
    return LayoutBuilder(
      builder: (context, constraints) {
        final halfW = constraints.maxWidth / 2;
        final fullH = constraints.maxHeight;

        return Row(
          children: [
            // 左半屏
            Expanded(
              child: _DualScreenPane(
                key: _leftPaneKey,
                document: widget.document,
                settings: widget.settings,
                paneWidth: halfW,
                paneHeight: fullH,
                spreads: _spreads,
                onPageChanged: (page) => _reportPage(page),
              ),
            ),
            // 分隔线
            Container(
              width: 1,
              color: CupertinoColors.systemGrey4.resolveFrom(context),
            ),
            // 右半屏
            Expanded(
              child: _DualScreenPane(
                key: _rightPaneKey,
                document: widget.document,
                settings: widget.settings,
                paneWidth: halfW,
                paneHeight: fullH,
                spreads: _spreads,
                onPageChanged: (_) {}, // 右侧不主导进度上报
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scrollDir = _isHorizontal ? Axis.horizontal : Axis.vertical;

    // ── 双屏模式：左右分屏独立滑动，用于对比阅读 ──
    if (widget.settings.dualScreen) {
      return _buildDualScreenView(context);
    }

    // 外层 LayoutBuilder 拿到的是屏幕确定尺寸；而 PageView/ListView 在滚动轴上会给出
    // 无限约束，单页尺寸必须从外层获取，否则在「上下滚动」模式会出现"无限高度"断言，
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
  /// 连续模式下使用实际页面宽高比推导容器高度，确保页面紧密相连无多余间隙。
  Widget _buildSpread(int index, Axis scrollDir, double pageW, double pageH) {
    final pages = _spreads[index];
    final isTwo = pages.length == 2;

    // 连续模式：按页面实际宽高比计算容器高度，避免强制撑满视口导致的大片空白间隙
    final bool useNaturalHeight = _isContinuous;
    double? naturalSpreadH;
    if (useNaturalHeight && widget.document.pages.isNotEmpty) {
      // 以首页的宽高比为基准计算显示高度
      try {
        final firstPage = widget.document.pages[pages[0]];
        final pw = firstPage.width.toDouble();
        final ph = firstPage.height.toDouble();
        if (pw > 0 && ph > 0) {
          if (isTwo) {
            // 双页：每页半宽，高度由宽度与宽高比推导
            final perW = (pageW - _pageGap) / 2;
            naturalSpreadH = perW * (ph / pw);
          } else {
            // 单页：全宽
            naturalSpreadH = pageW * (ph / pw);
          }
        }
      } catch (_) {
        // 页面尺寸获取失败时回退到视口高度
      }
    }
    final effectiveH = naturalSpreadH ?? pageH;

    if (isTwo) {
      final perPageWidth = (pageW - _pageGap) / 2;
      return SizedBox(
        width: pageW,
        height: effectiveH,
        // clipBehavior: none 防止 Row 的溢出被硬裁剪（FittedBox/BoxFit.contain 保证内容不越界，
        // 但 PDF 原始页面可能含极微超出 CropBox/MediaBox 的像素，不应被静默切掉）。
        child: ClipRect(
          clipBehavior: Clip.none,
          // IntrinsicHeight 强制左右两页等高：以较高的一侧为准，较矮的一页垂直居中填充，
          // 解决「双页时两边页面高度不一致」的问题。
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
        ),
      );
    }
    return SizedBox(
      width: pageW,
      height: effectiveH,
      child: _PdfPageWidget(
        document: widget.document,
        pageIndex: pages[0],
        settings: widget.settings,
        targetWidth: pageW,
      ),
    );
  }

  /// 双页 / 连续模式下的页间间隙（逻辑像素）：极细分隔，页面几乎紧贴。
  static const double _pageGap = 2.0;
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
    // 仅当自动裁切、去杂色、手动裁切、目标宽度或奇偶页模式变化时需要重新渲染；
    // 亮度/去色等仅由 build 重包滤镜。
    if (old.settings.autoCrop != widget.settings.autoCrop ||
        old.settings.denoise != widget.settings.denoise ||
        old.settings.cropMode != widget.settings.cropMode ||
        old.settings.manualCropLeft != widget.settings.manualCropLeft ||
        old.settings.manualCropRight != widget.settings.manualCropRight ||
        old.settings.manualCropTop != widget.settings.manualCropTop ||
        old.settings.manualCropBottom != widget.settings.manualCropBottom ||
        old.targetWidth.round() != widget.targetWidth.round() ||
        old.settings.cropOddEvenMode != widget.settings.cropOddEvenMode) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final settings = widget.settings;
    // 根据奇偶页分开裁边模式决定是否对本页应用自动裁切：
    // cropOddEvenMode: 0=统一(所有页) / 1=仅奇数页 / 2=仅偶数页
    final int pageNum = widget.pageIndex + 1; // 1-based
    final bool isOddPage = pageNum % 2 != 0;
    final effectiveAutoCrop = switch (settings.cropOddEvenMode) {
      0 => settings.autoCrop,
      1 => settings.autoCrop && isOddPage,
      2 => settings.autoCrop && !isOddPage,
      _ => settings.autoCrop,
    };
    // 手动裁边（框选）优先：cropMode==2 且四边任一边有值即启用手动裁切，覆盖自动裁切。
    final bool useManual = settings.cropMode == 2 &&
        (settings.manualCropLeft > 0 ||
            settings.manualCropRight > 0 ||
            settings.manualCropTop > 0 ||
            settings.manualCropBottom > 0);

    final dpr = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    final double renderWidth = (widget.targetWidth * dpr)
        .clamp(200, PdfRenderService.maxRenderWidth.toDouble())
        .toDouble();
    final img = await PdfRenderService.renderPageImage(
      widget.document,
      pageNum,
      renderWidth: renderWidth,
      autoCrop: useManual ? false : effectiveAutoCrop,
      denoise: settings.denoise,
      manualCropLeft: settings.manualCropLeft,
      manualCropRight: settings.manualCropRight,
      manualCropTop: settings.manualCropTop,
      manualCropBottom: settings.manualCropBottom,
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
            // 单页模式居中显示；连续/双页模式顶部对齐（由外层 SizedBox 统一高度保证对齐）
            alignment: widget.settings.layoutMode == 0
                ? Alignment.center
                : Alignment.topCenter,
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
    // 缩放能力后续将以"不抢占翻页手势"的方式（如仅在已放大态启用）重新接入。
    // 智能去杂色已在 PdfRenderService 渲染期完成（真正的去噪点处理，不靠模糊），此处无需再叠加。
    return child;
  }
}

/// 双屏模式下的单栏面板：独立的滚动控制器 + 页面列表，供左/右半屏各持有一个实例。
///
/// 每个面板维护自己的 [ScrollController]，实现左右独立滑动对比阅读。
/// 页面渲染复用 [_PdfPageWidget] 与 [PdfRenderService]，无重复渲染逻辑。
class _DualScreenPane extends StatefulWidget {
  final PdfDocument document;
  final PdfReaderSettings settings;
  final double paneWidth;
  final double paneHeight;
  final List<List<int>> spreads;
  final ValueChanged<int>? onPageChanged;

  const _DualScreenPane({
    super.key,
    required this.document,
    required this.settings,
    required this.paneWidth,
    required this.paneHeight,
    required this.spreads,
    this.onPageChanged,
  });

  @override
  State<_DualScreenPane> createState() => DualScreenPaneState();
}

class DualScreenPaneState extends State<_DualScreenPane> {
  late ScrollController _scrollController;
  final GlobalKey _listKey = GlobalKey();
  // 每个面板独立的 GlobalKey 列表（切勿复用外层 _spreadKeys，否则双屏两栏重复 key 崩溃）。
  late final List<GlobalKey> _paneKeys;
  // 展平后的页码列表：双页布局下 [_spreads] 为成对页码，对比阅读需逐页展示，故展平。
  late final List<int> _flatPages;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _flatPages = [for (final s in widget.spreads) ...s];
    _paneKeys = List.generate(_flatPages.length, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 跳转到指定页码（1-based）：用 Scrollable.ensureVisible 把对应页滚入视口顶部。
  void jumpToPage(int pageNumber) {
    final idx = pageNumber - 1; // _flatPages 为 0-based 逐页
    if (idx < 0 || idx >= _flatPages.length) return;
    final ctx = _paneKeys[idx].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.0,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  void _reportVisiblePage() {
    final viewportBox =
        _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null) return;
    final top = viewportBox.localToGlobal(Offset.zero).dy;
    int best = 0;
    double bestDist = double.infinity;
    for (int i = 0; i < _paneKeys.length; i++) {
      final box =
          _paneKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final dy = box.localToGlobal(Offset.zero).dy - top;
      final dist = dy >= 0 ? dy : -dy * 2;
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }
    if (best < _flatPages.length) {
      widget.onPageChanged?.call(_flatPages[best] + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 关键：外层 _buildDualScreenView 用 Row+Expanded 包裹本面板，会把「垂直方向」
    // 约束放成无界（infinite）。ListView 在垂直轴上收到无界高度会直接抛
    // "Vertical viewport was given unbounded height" 崩溃。用 SizedBox 给一个
    // 有界高度（paneHeight = 半屏外的整屏高）即可消除。
    return SizedBox(
      height: widget.paneHeight,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollEndNotification) _reportVisiblePage();
          return false;
        },
        child: ListView.builder(
          key: _listKey,
          controller: _scrollController,
          scrollDirection: Axis.vertical,
          itemCount: _flatPages.length,
          itemBuilder: (context, i) => KeyedSubtree(
            key: _paneKeys[i],
            child: _buildSpreadItem(_flatPages[i]),
          ),
        ),
      ),
    );
  }

  Widget _buildSpreadItem(int pageIndex) {
    final pageW = widget.paneWidth;
    final pageH = widget.paneHeight;

    // 计算自然高度（基于页面宽高比）
    double? naturalH;
    try {
      final page = widget.document.pages[pageIndex];
      final pw = page.width.toDouble();
      final ph = page.height.toDouble();
      if (pw > 0 && ph > 0) {
        naturalH = pageW * (ph / pw);
      }
    } catch (_) {}
    final effectiveH = naturalH ?? pageH;

    return SizedBox(
      width: pageW,
      height: effectiveH,
      child: _PdfPageWidget(
        document: widget.document,
        pageIndex: pageIndex,
        settings: widget.settings,
        targetWidth: pageW,
      ),
    );
  }
}
