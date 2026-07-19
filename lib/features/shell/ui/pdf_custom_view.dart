import 'dart:math' as math;
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
/// - 翻页动画（[pageAnimation]）：0 无动画（瞬时跳转）、1 仿真（平滑吸附）、
///   2 淡入淡出、3 叠加、4 跃动、5 旋转、6 旋转木马、7 模仿圆筒、8 反转；
///   2~8 在非连续逐页模式（PageView）下由 [AnimatedBuilder] 跟随 [PageController.page]
///   实时计算相对位移并施加变换，连续滚动模式仍走平滑滚动手势。
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
  /// 翻页动画：0 无动画 / 1 仿真 / 2 淡入淡出 / 3 叠加 / 4 跃动 / 5 旋转 / 6 旋转木马 / 7 模仿圆筒 / 8 反转。
  final int pageAnimation;
  /// 翻页/滚动时回调当前页码（1-based），用于同步阅读进度。
  final ValueChanged<int>? onPageChanged;

  /// 双击放大：开启后双击页面在「1× → 2× → 3×」间循环放大（首次放大铺满屏幕，
  /// 第二次进一步放大几倍），并支持双指捏合缩放；关闭则与原有手势一致。
  final bool doubleTapZoom;

  const PdfCustomView({
    super.key,
    required this.document,
    required this.settings,
    required this.pageMode,
    this.pageAnimation = 1,
    this.onPageChanged,
    this.doubleTapZoom = false,
  });

  @override
  State<PdfCustomView> createState() => PdfCustomViewState();
}

class PdfCustomViewState extends State<PdfCustomView> {
  /// 每个元素是一“对开页”的 0-based 页码列表（单页为长度1，双页为长度2）。
  late List<List<int>> _spreads;
  PageController? _pageController;
  ScrollController? _scrollController;
  // 连续模式缩放控制器：用单个 InteractiveViewer 包裹整条连续列，
  // 整列统一缩放，页面天然紧密相连；仅在放大态（_zoomScale>1）启用平移，
  // 未放大时单指滑动仍交给 ListView 滚动/翻页，避免手势被缩放层拦截。
  final TransformationController _zoomController = TransformationController();
  double _zoomScale = 1.0;
  // 双击放大档位索引：0=原尺寸、1=2×、2=3×（循环）。
  int _dtZoomIndex = 0;
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
    _zoomController.addListener(_onZoomChanged);
    _buildSpreads();
    _initControllers();
  }

  /// 监听缩放矩阵的缩放比，驱动 [_zoomScale] 状态，用于决定是否启用平移手势。
  void _onZoomChanged() {
    final scale = _zoomController.value.getMaxScaleOnAxis();
    if ((scale - _zoomScale).abs() > 0.001) {
      setState(() => _zoomScale = scale);
    }
  }

  /// 双击放大（连续模式）：在 [_dtZoomLevels] 档位间循环，以视图中心为锚点缩放。
  void _cycleContinuousZoom() {
    _dtZoomIndex =
        (_dtZoomIndex + 1) % PdfCustomViewState._dtZoomLevels.length;
    final target = PdfCustomViewState._dtZoomLevels[_dtZoomIndex];
    final size = context.size;
    final center = size == null
        ? Offset.zero
        : Offset(size.width / 2, size.height / 2);
    final m = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(target)
      ..translate(-center.dx, -center.dy);
    // 触发 _onZoomChanged 更新 _zoomScale（决定 panEnabled 是否启用）。
    _zoomController.value = m;
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
    // 仅「无动画(0)」瞬时跳转；其余动画类型（含仿真 1 与自定义 2~8）均走过渡，
    // 自定义变换由 [_buildAnimatedSpread] 的 AnimatedBuilder 实时跟随播放。
    final animate = widget.pageAnimation != 0;
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
      // 连续模式：直接定位到目标对开页在视口顶部对应的绝对滚动偏移。
      // 关键修复：旧实现用 `clamped - _currentSpreadIndex()` 的相对位移，而
      // [_currentSpreadIndex] 在连续模式下恒为 0，导致从末尾往回拖进度条时
      // 偏移被 clamp 到最大而页面不跳转。现改为按真实渲染位置计算绝对偏移，
      // 前向/后向拖拽都能正确落点。
      final offset = _offsetForSpread(clamped);
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

  /// 计算指定对开页对齐到视口顶部时，[ScrollController] 应处的绝对偏移量。
  ///
  /// 通过对比目标对开页与列表视口的全局坐标差，叠加当前滚动偏移得到，
  /// 因而不依赖「每页固定高度」假设，可正确处理不同页面宽高比混排的连续模式。
  double _offsetForSpread(int index) {
    if (_scrollController == null ||
        !_scrollController!.hasClients ||
        index < 0 ||
        index >= _spreadKeys.length) {
      return 0.0;
    }
    final listBox =
        _listKey.currentContext?.findRenderObject() as RenderBox?;
    final targetBox =
        _spreadKeys[index].currentContext?.findRenderObject() as RenderBox?;
    if (listBox != null && targetBox != null) {
      final listTop = listBox.localToGlobal(Offset.zero).dy;
      final targetTop = targetBox.localToGlobal(Offset.zero).dy;
      final delta = targetTop - listTop; // 目标页相对视口顶部的屏幕位移
      return (_scrollController!.offset + delta)
          .clamp(0.0, _scrollController!.position.maxScrollExtent);
    }
    // 目标页尚未构建（懒加载列表）：以最近的已构建页为锚点，按平均高度估算绝对偏移，
    // 避免连续模式下跳转到远处页面时偏移为 0（页面不跳转）。
    final anchor = _nearestBuiltSpread(index);
    if (anchor != null && listBox != null) {
      final anchorBox =
          _spreadKeys[anchor].currentContext!.findRenderObject() as RenderBox;
      final listTop = listBox.localToGlobal(Offset.zero).dy;
      final anchorTop = anchorBox.localToGlobal(Offset.zero).dy;
      final avgH = anchorBox.size.height + _pageGap;
      final delta = (index - anchor) * avgH - (anchorTop - listTop);
      return (_scrollController!.offset + delta)
          .clamp(0.0, _scrollController!.position.maxScrollExtent);
    }
    return 0.0;
  }

  /// 从 [index] 向两侧寻找第一个已构建（有 renderObject）的对开页，作为偏移估算锚点。
  int? _nearestBuiltSpread(int index) {
    for (int d = 0; d < _spreadKeys.length; d++) {
      if (index - d >= 0 && _spreadKeys[index - d].currentContext != null) {
        return index - d;
      }
      if (index + d < _spreadKeys.length &&
          _spreadKeys[index + d].currentContext != null) {
        return index + d;
      }
    }
    return null;
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
                doubleTapZoom: widget.doubleTapZoom,
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
                doubleTapZoom: widget.doubleTapZoom,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _zoomController.removeListener(_onZoomChanged);
    _zoomController.dispose();
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
          // 逐页模式同样用 InteractiveViewer 包裹，统一支持双指捏合缩放：
          // 仅在放大态（_zoomScale>1）启用平移，未放大时单指滑动回落到 PageView 翻页；
          // clipBehavior 沿用 PageView 的 none，保证 2~8 自定义翻页动画不被硬裁剪。
          body = InteractiveViewer(
            transformationController: _zoomController,
            scaleEnabled: true,
            panEnabled: _zoomScale > 1.0001,
            minScale: 1.0,
            maxScale: 4.0,
            clipBehavior: Clip.none,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: scrollDir,
              clipBehavior: Clip.none,
              // 纯单击模式禁用滑动，仅由点击驱动翻页；其余模式允许滑动。
              physics: _swipeEnabled
                  ? null
                  : const NeverScrollableScrollPhysics(),
              itemCount: _spreads.length,
              itemBuilder: (context, i) =>
                  _buildAnimatedSpread(i, scrollDir, pageW, pageH),
              onPageChanged: (i) => _reportPage(i),
            ),
          );
        } else {
          // 连续模式：用单个 InteractiveViewer 包裹整条连续列，统一缩放。
          // - scaleEnabled 允许双指捏合缩放；
          // - panEnabled 仅在放大态（_zoomScale>1）开启，未放大时单指滑动回落到
          //   ListView 自身滚动/翻页，不被缩放层拦截（修复此前 InteractiveViewer
          //   手势冲突而整体移除的问题）；
          // - constrained 默认 true：ListView 受视口约束可正常滚动；放大后由
          //   boundaryMargin 提供无限平移余地，整列等比缩放，页面保持紧密相连。
          body = NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollEndNotification) _reportVisiblePage();
              return false;
            },
            child: InteractiveViewer(
              transformationController: _zoomController,
              scaleEnabled: true,
              panEnabled: _zoomScale > 1.0001,
              minScale: 1.0,
              maxScale: 4.0,
              boundaryMargin: const EdgeInsets.all(double.infinity),
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
            ),
          );
        }

        // 双击放大（开启且非纯单击翻页模式时）：以视图中心为锚点在 1×/2×/3× 间循环，
        // 与底层 InteractiveViewer 的捏合缩放共用同一变换控制器。在纯单击翻页模式
        // （左右/上下单击、单击滚动）下关闭，避免「双击既翻页又放大」的体感冲突。
        if (widget.doubleTapZoom && !_tapFlip) {
          body = GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTap: _cycleContinuousZoom,
            child: body,
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
  ///
  /// 撑满全屏（仅连续滚动模式、且设置开启时）：每页交给 [_PdfPageWidget] 按
  /// 「裁切后的真实宽高比」自定尺寸——宽度铺满、高度取内容自然高度，从而消除
  /// 「逐页独立裁切导致尺寸不一、上下跳动 / 未对齐」；左右翻页（PageView）一律
  /// 走下方 [BoxFit.contain] 显示完整一页，本分支不生效。
  Widget _buildSpread(int index, Axis scrollDir, double pageW, double pageH) {
    final pages = _spreads[index];
    final isTwo = pages.length == 2;
    // 撑满全屏（仅连续滚动模式生效）：开启后每页按裁切后真实宽高比自定尺寸，
    // 宽度铺满、消除逐页跳动与未对齐；逐页吸附（非连续）模式一律不生效。
    final bool fillScreen = _isContinuous && widget.settings.fillScreenInScroll;

    // 未开启撑满时的占位高度：连续模式按原始版面宽高比推导（维持原观感），
    // 逐页吸附（非连续）模式直接填满视口高度。
    double? naturalSpreadH;
    if (!fillScreen && _isContinuous) {
      try {
        final firstPage = widget.document.pages[pages[0]];
        final pw = firstPage.width.toDouble();
        final ph = firstPage.height.toDouble();
        if (pw > 0 && ph > 0) {
          naturalSpreadH = isTwo
              ? ((pageW - _pageGap) / 2) * (ph / pw)
              : pageW * (ph / pw);
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
        // 撑满时由 _PdfPageWidget 自定高度（真实宽高比），此处不强制；
        // 否则用 original/视口 高度保证双页等高。
        height: fillScreen ? null : effectiveH,
        child: ClipRect(
          clipBehavior: Clip.none,
          child: IntrinsicHeight(
            child: Row(
              // 撑满时顶部对齐（各页按自身裁切后高度自然堆叠）；
              // 未撑满时拉伸等高（原双页等观感）。
              crossAxisAlignment:
                  fillScreen ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _PdfPageWidget(
                    document: widget.document,
                    pageIndex: pages[0],
                    settings: widget.settings,
                    targetWidth: perPageWidth,
                    fillScreen: fillScreen,
                  ),
                ),
                SizedBox(width: _pageGap),
                Expanded(
                  child: _PdfPageWidget(
                    document: widget.document,
                    pageIndex: pages[1],
                    settings: widget.settings,
                    targetWidth: perPageWidth,
                    fillScreen: fillScreen,
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
      height: fillScreen ? null : effectiveH,
      child: _PdfPageWidget(
        document: widget.document,
        pageIndex: pages[0],
        settings: widget.settings,
        targetWidth: pageW,
        fillScreen: fillScreen,
      ),
    );
  }

  /// 包裹对开页，按当前翻页动画类型施加「逐帧变换」。
  ///
  /// 仅在非连续逐页模式（PageView）下生效：用 [AnimatedBuilder] 监听 [PageController.page]，
  /// 计算每个对开页相对当前页的偏移量 [position]（0=居中，±1=相邻页），再交给 [_transformSpread]
  /// 施加透明度/位移/旋转等效果，从而实现淡入淡出、叠加、跃动、旋转、旋转木马、圆筒、反转等动画。
  /// 无动画(0)/仿真(1) 直接返回原页（交给 PageView 原生吸附与滚动曲线）。
  Widget _buildAnimatedSpread(int index, Axis scrollDir, double pageW, double pageH) {
    final child = _buildSpread(index, scrollDir, pageW, pageH);
    if (widget.pageAnimation == 0 || _pageController == null) return child;
    return AnimatedBuilder(
      animation: _pageController!,
      builder: (context, c) {
        final page = _pageController!.page ?? _currentSpreadIndex().toDouble();
        // 相对偏移限制在 ±1 内：仅相邻页参与过渡，更远的页保持离屏态。
        final position = (page - index).clamp(-1.0, 1.0);
        return _transformSpread(c!, position, scrollDir, pageW, pageH);
      },
      child: child,
    );
  }

  /// 依据动画类型与相对偏移 [position] 返回变换后的页面。
  ///
  /// [axis] 为滚动方向（横向/纵向），决定位移与 3D 旋转的轴向，保证横竖翻页一致。
  Widget _transformSpread(
    Widget child,
    double position,
    Axis axis,
    double pageW,
    double pageH,
  ) {
    switch (widget.pageAnimation) {
      case 1: // 仿真翻页：像真实翻书——当前页绕书脊轻转并带「卷边」明暗，
        // 露出下方下一页；透视减弱、转角缓动，消除原 90° 整页硬翻转的突兀感。
        {
          final isH = axis == Axis.horizontal;
          final turn = position; // 0=居中；>0 翻向下一页；<0 翻回上一页
          // 前进绕左缘(书脊在左，露出右侧下一页)；后退绕右缘。
          final spineX = turn >= 0 ? 0.0 : pageW;
          final spineY = turn >= 0 ? 0.0 : pageH;
          // 转角缓动（smoothstep）：起止平缓、中段自然加速，比线性转角更像翻书。
          final t = turn.clamp(-1.0, 1.0);
          final sign = t >= 0 ? 1.0 : -1.0;
          final eased = t.abs() * t.abs() * (3 - 2 * t.abs());
          final angle = sign * eased * (math.pi / 2);
          // 透视略减弱（原 0.0022 过强，页缘会骤然消失），翻动更柔和。
          final m = Matrix4.identity()
            ..setEntry(3, 2, 0.0014)
            ..translate(spineX, spineY)
            ..rotateY(isH ? angle : 0.0)
            ..rotateX(isH ? 0.0 : angle)
            ..translate(-spineX, -spineY);
          // 卷边明暗：书脊侧（翻起根部）更深，自由边更亮，并在贴近书脊处加一道高光，
          // 模拟纸张卷曲受光——比单层线性阴影更像「翻书」而非「转门」。
          final a = t.abs().clamp(0.0, 1.0);
          final curlDark = (0.10 + 0.26 * a).clamp(0.0, 0.4);
          final curlLight = (0.05 * a).clamp(0.0, 0.08);
          final highlight = (0.16 * a).clamp(0.0, 0.16);
          final Alignment spineAlign = isH
              ? (turn >= 0 ? Alignment.centerLeft : Alignment.centerRight)
              : (turn >= 0 ? Alignment.topCenter : Alignment.bottomCenter);
          final Alignment freeAlign = isH
              ? (turn >= 0 ? Alignment.centerRight : Alignment.centerLeft)
              : (turn >= 0 ? Alignment.bottomCenter : Alignment.topCenter);
          final overlay = Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: spineAlign,
                end: freeAlign,
                stops: const [0.0, 0.16, 1.0],
                colors: [
                  CupertinoColors.black.withValues(alpha: curlDark),
                  CupertinoColors.white.withValues(alpha: highlight),
                  CupertinoColors.black.withValues(alpha: curlLight),
                ],
              ),
            ),
          );
          return Stack(
            children: [
              Transform(transform: m, child: child),
              Positioned.fill(child: IgnorePointer(child: overlay)),
            ],
          );
        }
      case 2: // 淡入淡出：随偏移增大而淡出
        return Opacity(
          opacity: (1 - position.abs()).clamp(0.0, 1.0),
          child: child,
        );
      case 3: // 叠加：下一张自一侧滑入，覆盖当前页
        final dx = axis == Axis.horizontal ? position * pageW : 0.0;
        final dy = axis == Axis.vertical ? position * pageH : 0.0;
        return Transform.translate(offset: Offset(dx, dy), child: child);
      case 4: // 跃动：过渡中途向上弹跳（正弦曲线峰值约 40px）
        final hop = math.sin(position.abs() * math.pi) * 40.0;
        return Transform.translate(offset: Offset(0, -hop), child: child);
      case 5: // 旋转：页面在自身平面内轻微旋转
        return Transform.rotate(angle: position * 0.25, child: child);
      case 6: // 旋转木马：3D 旋转 + 边缘缩放
        final m = Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateY(axis == Axis.horizontal ? position * 0.6 : 0.0)
          ..rotateX(axis == Axis.vertical ? position * 0.6 : 0.0);
        return Transform(
          transform: m,
          child: Transform.scale(
            scale: 1 - position.abs() * 0.2,
            child: child,
          ),
        );
      case 7: // 模仿圆筒：强透视旋转，模拟页面绕圆柱翻动
        final m = Matrix4.identity()
          ..setEntry(3, 2, 0.0025)
          ..rotateY(axis == Axis.horizontal ? position * (math.pi / 2) : 0.0)
          ..rotateX(axis == Axis.vertical ? position * (math.pi / 2) : 0.0);
        return Transform(transform: m, child: child);
      case 8: // 反转：整页翻转半圈（绕轴 180°）
        final m = Matrix4.identity()
          ..setEntry(3, 2, 0.0018)
          ..rotateY(axis == Axis.horizontal ? position * math.pi : 0.0)
          ..rotateX(axis == Axis.vertical ? position * math.pi : 0.0);
        return Transform(transform: m, child: child);
      default:
        return child;
    }
  }

  /// 双页 / 连续模式下的页间间隙（逻辑像素）：极细分隔，页面几乎紧贴。
  static const double _pageGap = 2.0;
  // 双击放大循环档位：原尺寸 → 2× → 3×（首次放大铺满屏幕，第二次进一步放大）。
  static const List<double> _dtZoomLevels = [1.0, 2.0, 3.0];
}

/// 单页渲染瓦片：按需调用 [PdfRenderService] 渲染，并叠加颜色滤镜与缩放。
class _PdfPageWidget extends StatefulWidget {
  final PdfDocument document;
  final int pageIndex; // 0-based
  final PdfReaderSettings settings;
  final double targetWidth; // 目标显示宽度（逻辑像素），用于推导渲染分辨率
  /// 撑满全屏：开启后本页按「裁切后真实宽高比」自定尺寸（宽度=targetWidth，
  /// 高度=宽/宽高比），容器宽高比与图片一致，故 [BoxFit.fill] 等同精确铺满、
  /// 无变形、无 letterbox，从而消除逐页裁切导致的上下跳动 / 未对齐。仅在连续
  /// 滚动模式由 [_buildSpread] 传入 true；其余模式（含左右翻页）为 false，走
  /// [BoxFit.contain] 显示完整一页。
  final bool fillScreen;

  const _PdfPageWidget({
    required this.document,
    required this.pageIndex,
    required this.settings,
    required this.targetWidth,
    this.fillScreen = false,
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
        old.settings.cropBandVersion != widget.settings.cropBandVersion ||
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
    // 撑满全屏（仅连续滚动模式）：按图片真实宽高比自定尺寸。
    // 容器宽=targetWidth、高=宽×图高/图宽，与图片宽高比一致，故用
    // [BoxFit.fill] 即可精确铺满、无变形、无 letterbox；裁切后各页尺寸不一的
    // 问题因此自然消除（每页按其自身内容高度堆叠，不再被强制套用统一高度）。
    if (widget.fillScreen) {
      if (_image == null) {
        // 未加载时按「页面原始宽高比」给出占位高度，避免 ListView 项高度为 0。
        double placeholderH = widget.targetWidth;
        try {
          final p = widget.document.pages[widget.pageIndex];
          final pw = p.width.toDouble();
          final ph = p.height.toDouble();
          if (pw > 0 && ph > 0) {
            placeholderH = widget.targetWidth * (ph / pw);
          }
        } catch (_) {}
        return SizedBox(
          width: widget.targetWidth,
          height: placeholderH,
          child: Center(
            child: _loading
                ? const CupertinoActivityIndicator()
                : const SizedBox.shrink(),
          ),
        );
      }
      final h = widget.targetWidth * _image!.height / _image!.width;
      return SizedBox(
        width: widget.targetWidth,
        height: h,
        child: RawImage(image: _image, fit: BoxFit.fill),
      );
    }

    // 默认（逐页吸附 / 未开撑满）：使用 FittedBox 包裹 RawImage（而非直接用
    // RawImage.fit）：
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
    // 阅读背景覆盖：开启时用半透明背景色覆盖扫描件，制造「更换背景」观感。
    if (widget.settings.bgOverlay) {
      child = Stack(
        fit: StackFit.expand,
        children: [
          child,
          IgnorePointer(
            child: Container(
              color: widget.settings.bgOverlayColor.withValues(alpha: 0.4),
            ),
          ),
        ],
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
  /// 双击放大：开启后本面板支持双指捏合缩放与双击循环放大（1×/2×/3×）。
  final bool doubleTapZoom;

  const _DualScreenPane({
    super.key,
    required this.document,
    required this.settings,
    required this.paneWidth,
    required this.paneHeight,
    required this.spreads,
    this.onPageChanged,
    this.doubleTapZoom = false,
  });

  @override
  State<_DualScreenPane> createState() => DualScreenPaneState();
}

class DualScreenPaneState extends State<_DualScreenPane> {
  late ScrollController _scrollController;
  // 本面板独立的缩放控制器：双指捏合与双击放大共用，左/右两栏互不干扰。
  final TransformationController _zoomController = TransformationController();
  double _zoomScale = 1.0;
  // 双击放大档位索引：0=原尺寸、1=2×、2=3×（循环）。
  int _dtZoomIndex = 0;
  final GlobalKey _listKey = GlobalKey();
  // 每个面板独立的 GlobalKey 列表（切勿复用外层 _spreadKeys，否则双屏两栏重复 key 崩溃）。
  late final List<GlobalKey> _paneKeys;
  // 展平后的页码列表：双页布局下 [_spreads] 为成对页码，对比阅读需逐页展示，故展平。
  late final List<int> _flatPages;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _zoomController.addListener(_onZoomChanged);
    _flatPages = [for (final s in widget.spreads) ...s];
    _paneKeys = List.generate(_flatPages.length, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _zoomController.removeListener(_onZoomChanged);
    _zoomController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 监听缩放矩阵的缩放比，驱动 [_zoomScale]（决定捏合平移是否启用）。
  void _onZoomChanged() {
    final scale = _zoomController.value.getMaxScaleOnAxis();
    if ((scale - _zoomScale).abs() > 0.001) {
      setState(() => _zoomScale = scale);
    }
  }

  /// 双击放大（双屏面板）：以面板中心为锚点在 [_dtZoomLevels] 档位间循环切换。
  void _cycleZoom() {
    _dtZoomIndex = (_dtZoomIndex + 1) % PdfCustomViewState._dtZoomLevels.length;
    final target = PdfCustomViewState._dtZoomLevels[_dtZoomIndex];
    final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
    final center = box == null ? Offset.zero : box.size.center(Offset.zero);
    final m = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(target)
      ..translate(-center.dx, -center.dy);
    // 触发 _onZoomChanged 更新 _zoomScale（决定 panEnabled 是否启用）。
    _zoomController.value = m;
  }

  /// 跳转到指定页码（1-based）：先复位缩放，再用绝对偏移把对应页滚入视口顶部。
  ///
  /// 关键修复：旧实现用 [Scrollable.ensureVisible]，目标页尚未构建（context 为 null）
  /// 时静默跳过，导致「双屏下拉动进度条不生效」。现改为：复位缩放→等待布局稳定后，
  /// 通过对比目标页与列表视口的全局坐标差计算绝对偏移并 jumpTo；目标未构建时以最近
  /// 已构建页为锚点估算，确保进度跳转在任何位置都生效。
  void jumpToPage(int pageNumber) {
    final idx = pageNumber - 1; // _flatPages 为 0-based 逐页
    if (idx < 0 || idx >= _flatPages.length) return;
    // 跳转即复位缩放，避免缩放态下的坐标变换影响偏移计算与阅读体验。
    _zoomController.value = Matrix4.identity();
    // 复位后需等一帧让布局回到未变换状态，再读取干净坐标计算偏移。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final offset = _offsetForIndex(idx);
      if (offset != null) {
        _scrollController.jumpTo(
          offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        );
      }
    });
  }

  /// 计算指定页码对齐到面板视口顶部时，[ScrollController] 应处的绝对偏移量。
  ///
  /// 通过对比目标页与列表视口的全局坐标差，叠加当前滚动偏移得到，
  /// 不依赖「每页固定高度」假设，可正确处理不同页面宽高比混排。
  double? _offsetForIndex(int idx) {
    final listBox =
        _listKey.currentContext?.findRenderObject() as RenderBox?;
    final targetBox =
        _paneKeys[idx].currentContext?.findRenderObject() as RenderBox?;
    if (listBox != null && targetBox != null) {
      final listTop = listBox.localToGlobal(Offset.zero).dy;
      final targetTop = targetBox.localToGlobal(Offset.zero).dy;
      final delta = targetTop - listTop; // 目标页相对视口顶部的屏幕位移
      return _scrollController.offset + delta;
    }
    // 目标页尚未构建（懒加载列表）：以最近的已构建页为锚点，按平均高度估算绝对偏移，
    // 避免双屏模式下跳转到远处页面时偏移为 0（页面不跳转）。
    final anchor = _nearestBuilt(idx);
    if (anchor != null && listBox != null) {
      final anchorBox =
          _paneKeys[anchor].currentContext!.findRenderObject() as RenderBox;
      final listTop = listBox.localToGlobal(Offset.zero).dy;
      final anchorTop = anchorBox.localToGlobal(Offset.zero).dy;
      final avgH = anchorBox.size.height + PdfCustomViewState._pageGap;
      final delta = (idx - anchor) * avgH - (anchorTop - listTop);
      return _scrollController.offset + delta;
    }
    return null;
  }

  /// 从 [idx] 向两侧寻找第一个已构建（有 renderObject）的页码，作为偏移估算锚点。
  int? _nearestBuilt(int idx) {
    for (int d = 0; d < _paneKeys.length; d++) {
      if (idx - d >= 0 && _paneKeys[idx - d].currentContext != null) {
        return idx - d;
      }
      if (idx + d < _paneKeys.length &&
          _paneKeys[idx + d].currentContext != null) {
        return idx + d;
      }
    }
    return null;
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
    // 双击放大：开启时用透明手势层捕获双击，以面板中心为锚点循环 1×/2×/3×
    // （与底层 InteractiveViewer 的捏合缩放共用同一变换控制器）；未开启则不拦截。
    // 整列用单个 InteractiveViewer 包裹统一缩放：仅在放大态（_zoomScale>1）启用平移，
    // 未放大时单指滑动仍交给 ListView 滚动，避免手势被缩放层拦截。
    return SizedBox(
      height: widget.paneHeight,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollEndNotification) _reportVisiblePage();
          return false;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onDoubleTap: widget.doubleTapZoom ? _cycleZoom : null,
          child: InteractiveViewer(
            transformationController: _zoomController,
            scaleEnabled: true,
            panEnabled: _zoomScale > 1.0001,
            minScale: 1.0,
            maxScale: 4.0,
            boundaryMargin: const EdgeInsets.all(double.infinity),
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
        ),
      ),
    );
  }

  Widget _buildSpreadItem(int pageIndex) {
    final pageW = widget.paneWidth;
    final pageH = widget.paneHeight;
    // 撑满全屏（连续滚动）：与主视图一致，按裁切后真实宽高比自定尺寸。
    final bool fillScreen = widget.settings.fillScreenInScroll;

    // 未开启撑满时的占位高度（基于页面宽高比）
    double? naturalH;
    if (!fillScreen) {
      try {
        final page = widget.document.pages[pageIndex];
        final pw = page.width.toDouble();
        final ph = page.height.toDouble();
        if (pw > 0 && ph > 0) {
          naturalH = pageW * (ph / pw);
        }
      } catch (_) {}
    }
    final effectiveH = naturalH ?? pageH;

    return SizedBox(
      width: pageW,
      height: fillScreen ? null : effectiveH,
      child: _PdfPageWidget(
        document: widget.document,
        pageIndex: pageIndex,
        settings: widget.settings,
        targetWidth: pageW,
        fillScreen: fillScreen,
      ),
    );
  }
}
