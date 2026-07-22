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
  // 视口尺寸（由外层 LayoutBuilder 写入），供「相邻页预渲染」推导每页渲染宽度。
  double _pageW = 0.0;
  double _pageH = 0.0;
  // 已预渲染的对开页索引（去重，避免每次 onPageChanged 重复预热）。
  int _lastPrefetchedSpread = -1;
  // 预取代际号：可见页位置每次变化即自增，旧代际的后台预取在锁内二次校验时
  // 判定失效并立即丢弃，避免为已滚走的页空转渲染（配合 PdfRenderService 的取消机制）。
  int _prefetchGeneration = 0;
  /// 静默增强代际号：滚动停止时自增并随 setState 重建可见页瓦片，驱动其重跑
  /// Stage 2 智能清晰度增强（无转圈）。与 [_prefetchGeneration] 相互独立。
  int _enhanceTick = 0;
  // 后台预渲染窗口：向前（下一页方向）预渲染 10 页、向后（上一页方向）2 页，
  // 使连续翻页/小幅跳转直接命中终缓存、无感切换（详见 [_prefetchAround]）。
  static const int _kPrefetchAhead = 10;
  static const int _kPrefetchBehind = 2;
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
    // 复位全局滚动标记，避免上一视图残留的 isScrolling=true 导致本视图增强被永久降级。
    PdfRenderService.isScrolling = false;
    _zoomController.addListener(_onZoomChanged);
    _buildSpreads();
    _initControllers();
    // 首帧后视口尺寸已知，预热起始页相邻页，避免「第一次翻页才渲染」的卡顿。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prefetchAround(0);
    });
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
      // 监听翻页进度：过渡中（page 非整数）置 isScrolling=true 暂停 Stage2 增强，
      // 落定（page 回到整数）恢复并触发当前可见页静默增强，避免每页增强抢光栅线程
      // 导致下一页原生渲染被推迟、翻页出现转圈（连续滚动模式已有等价逻辑，此处补齐
      // PageView 点击/滑动翻页模式，使其同样享受 120Hz 即时翻页）。
      _pageController!.addListener(_onPageScroll);
    } else {
      _scrollController = ScrollController();
    }
  }

  /// PageView 翻页进度回调：派生「是否处于翻页过渡中」，驱动 [PdfRenderService.isScrolling]
  /// 与 [_enhanceTick]（与连续滚动的 ScrollEnd 逻辑对齐）。仅在状态发生翻转时 setState，
  /// 不会因高频回调反复重建。
  void _onPageScroll() {
    if (!_usePageView || _pageController == null) return;
    final p = _pageController!.page;
    if (p == null) return;
    final transitioning = (p - p.round()).abs() > 0.01;
    if (transitioning) {
      if (!PdfRenderService.isScrolling) PdfRenderService.isScrolling = true;
    } else if (PdfRenderService.isScrolling) {
      // 落定：恢复增强，并触发当前可见页静默升级为智能清晰度（无转圈）。
      PdfRenderService.isScrolling = false;
      _enhanceTick++;
      if (mounted) setState(() {});
    }
  }

  void _disposeControllers() {
    if (_pageController != null) {
      _pageController!.removeListener(_onPageScroll);
      _pageController!.dispose();
      _pageController = null;
    }
    _scrollController?.dispose();
    _scrollController = null;
  }

  /// 由对开页索引推导当前页码（取该对开页首页，1-based）并上报。
  void _reportPage(int spreadIndex) {
    if (spreadIndex < 0 || spreadIndex >= _spreads.length) return;
    final firstPage = _spreads[spreadIndex].first + 1;
    widget.onPageChanged?.call(firstPage);
    // 可见页位置变化：推进预取代际，令旧代际后台预取在锁内失效丢弃。
    _prefetchGeneration++;
    _prefetchAround(spreadIndex);
  }

  /// 相邻页预渲染（后台、低优先级）：预热以 [spreadIndex] 为中心、向前
  /// [_kPrefetchAhead] 页、向后 [_kPrefetchBehind] 页窗口内的「已裁切原生渲染」缓存，
  /// 使连续翻页/小幅跳转直接命中 [PdfRenderService] 的基础缓存、翻开即见原生图（0 等待、
  /// 不转圈）；智能清晰度增强由 [_PdfPageWidget._load] 的「阶段二」在可见页上后台完成、
  /// 算完无感替换。此分工确保后台预取绝不批量触发主线程增强（toByteData + 解码），
  /// 从根上杜绝「开智能清晰度后卡死」。
  ///
  /// 与 [_PdfPageWidget._load] 使用完全一致的渲染参数与缓存键（经
  /// [PdfRenderService.estimateRenderWidth]），预热出的基础缓存即正式渲染要命中的同一份。
  ///
  /// 关键设计：
  /// 1. 预取只暖「原生层」（`skipPostProcess: true`，含 autoCrop 裁切）——增强留给可见页，
  ///    避免 10 页后台增强同时压满主线程（这是上一版「直接卡死」的回归根因）。
  /// 2. 低优先级（`background: true`）——可见页渲染可抢占后台预取，翻页永远即时。
  /// 3. 就近优先 + 代际取消——窗口内先算最近的页；可见页位置变化即令旧预取失效丢弃。
  void _prefetchAround(int spreadIndex) {
    if (!mounted || _pageW <= 0) return;
    if (spreadIndex == _lastPrefetchedSpread) return;
    _lastPrefetchedSpread = spreadIndex;
    // 捕获本代际号：期间若用户翻页推进代际，旧预取在锁内二次校验判定失效即丢弃。
    final myGen = _prefetchGeneration;

    final settings = widget.settings;
    final isTwoPage = settings.layoutMode == 1 || settings.layoutMode == 3;
    final perPageWidth = isTwoPage ? ((_pageW - _pageGap) / 2) : _pageW;

    // 收集窗口内所有页码（按对开页展开），再按距当前页「就近优先」排序，
    // 保证离视线最近的页最先被渲染好，连续翻页瞬时命中。
    final sStart = (spreadIndex - _kPrefetchBehind).clamp(0, _spreads.length - 1);
    final sEnd = (spreadIndex + _kPrefetchAhead).clamp(0, _spreads.length - 1);
    final curFirstPage = _spreads[spreadIndex].first;
    final pageNums = <int>[];
    for (var s = sStart; s <= sEnd; s++) {
      for (final pageIndex in _spreads[s]) {
        pageNums.add(pageIndex + 1);
      }
    }
    pageNums.sort((a, b) {
      final da = (a - curFirstPage).abs();
      final db = (b - curFirstPage).abs();
      // 距离相同时优先「向前」（下一页方向），更符合顺读习惯。
      if (da == db) return b.compareTo(a);
      return da.compareTo(db);
    });

    for (final pageNum in pageNums) {
      final isOddPage = pageNum % 2 != 0;
      final effectiveAutoCrop = switch (settings.cropOddEvenMode) {
        0 => settings.autoCrop,
        1 => settings.autoCrop && isOddPage,
        2 => settings.autoCrop && !isOddPage,
        _ => settings.autoCrop,
      };
      final useManual = settings.cropMode == 2 &&
          (settings.manualCropLeft > 0 ||
              settings.manualCropRight > 0 ||
              settings.manualCropTop > 0 ||
              settings.manualCropBottom > 0);
      // 后台预热（命中缓存即瞬时返回，几乎零成本）：只暖「已裁切原生渲染」层，
      // 绝不做事后增强——增强（toByteData + 主线程解码）一律留给可见页阶段二，
      // 绝不让 10 页后台预取同时压满主线程导致「开智能清晰度后卡死」。
      PdfRenderService.renderPageImage(
        widget.document,
        pageNum,
        renderWidth: PdfRenderService.estimateRenderWidth(perPageWidth),
        autoCrop: useManual ? false : effectiveAutoCrop,
        denoise: settings.denoise,
        sharpness: settings.sharpness,
        skipPostProcess: true, // ★ 关键：后台只暖原生层（含裁切），不碰主线程增强
        background: true, // ★ 低优先级，让位可见页
        manualCropLeft: settings.manualCropLeft,
        manualCropRight: settings.manualCropRight,
        manualCropTop: settings.manualCropTop,
        manualCropBottom: settings.manualCropBottom,
        // ★ 代际 + 卸载双重取消：视图卸载或已翻到别的页（代际变化）即丢弃。
        isStillNeeded: () => mounted && _prefetchGeneration == myGen,
      );
    }
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
    // 复位全局滚动标记：若本视图在翻页过渡中被销毁，避免 isScrolling 残留为 true
    // 而让其它视图/文档的增强被永久降级（连续滚动与 PageView 两种情况都要清）。
    PdfRenderService.isScrolling = false;
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
        // 记录视口尺寸供相邻页预渲染推导渲染宽度（仅在尺寸变化时更新）。
        if ((_pageW - pageW).abs() > 0.5 || (_pageH - pageH).abs() > 0.5) {
          _pageW = pageW;
          _pageH = pageH;
        }

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
              if (n is ScrollStartNotification || n is ScrollUpdateNotification) {
                // 标记当前处于滚动中，暂停 Stage 2 深度增强计算，保障 120Hz 帧率。
                if (!PdfRenderService.isScrolling) PdfRenderService.isScrolling = true;
              } else if (n is ScrollEndNotification) {
                // 滚动静止：恢复增强，并触发当前可见页静默升级为智能清晰度。
                PdfRenderService.isScrolling = false;
                _reportVisiblePage();
                _enhanceTick++;
                setState(() {});
              }
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
                    enhanceTick: _enhanceTick,
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
                  enhanceTick: _enhanceTick,
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
        enhanceTick: _enhanceTick,
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
  /// 静默增强代际号：滚动停止时父视图自增并随 setState 重建本瓦片，[didUpdateWidget]
  /// 据此触发 Stage 2 增强（无转圈），把原生图升级为智能清晰度。
  final int enhanceTick;

  const _PdfPageWidget({
    required this.document,
    required this.pageIndex,
    required this.settings,
    required this.targetWidth,
    this.fillScreen = false,
    this.enhanceTick = 0,
  });

  @override
  State<_PdfPageWidget> createState() => _PdfPageWidgetState();
}

class _PdfPageWidgetState extends State<_PdfPageWidget> {
  ui.Image? _image;
  bool _loading = true;
  int _loadToken = 0; // 每次 _load 自增，防止快速翻页时旧阶段二覆盖新页
  int _enhanceToken = 0; // 滚动停止触发的静默增强专用令牌，与 _loadToken 互不干扰

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 安全替换当前显示的 [ui.Image]：登记/释放「正在显示」引用，使
  /// [PdfRenderService] 在缓存淘汰/回收时不会 dispose 一个正被 [RawImage] 绘制的纹理
  /// （否则会触发原生层崩溃）。相同实例不重复登记。
  void _setImage(ui.Image? img) {
    if (_image == img) return;
    if (_image != null) PdfRenderService.markUnused(_image!);
    _image = img;
    if (img != null) PdfRenderService.markInUse(img);
  }

  @override
  void dispose() {
    if (_image != null) PdfRenderService.markUnused(_image!);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PdfPageWidget old) {
    super.didUpdateWidget(old);
    // ★ 关键修复（生命周期）：连续滚动模式下 ListView 会回收 Element，使同一个
    // [_PdfPageWidgetState] 被复用去显示不同 pageIndex 的页。若不在此检测 pageIndex
    // 变化并重新加载，State 会沿用旧页的 _image / 令牌 / 增强状态，导致旧页在途的异步
    // 增强结果覆盖新页、或旧 _image 在新页被 dispose 时遭误伤——这是翻页崩溃的高发温床。
    // 检测到 pageIndex 变化立即重新 [_load]，旧页在途请求由令牌机制统一丢弃。
    if (old.pageIndex != widget.pageIndex) {
      _load();
      return;
    }
    // 滚动停止信号（enhanceTick 变化）：静默重跑 Stage 2，把原生图升级为智能清晰度，
    // 不重置 loading（无转圈）、不重渲阶段一（命中缓存即瞬时）。
    if (old.enhanceTick != widget.enhanceTick) {
      final needEnhance = widget.settings.denoise || widget.settings.sharpness != 1.0;
      if (needEnhance && mounted) {
        // ★ 使用独立 _enhanceToken 而非 _loadToken：避免因滚动停止信号的 token
        // 自增杀掉 _load() 阶段二的令牌（导致阶段二完成后增强图被 evict、从零重算）。
        // 两路 token 独立，互不取消：
        //   · _load() 阶段二先完成 → 已写缓存、已显示，此处 enhance 命中缓存瞬间返回；
        //   · _load() 阶段二仍在途 → 此处 enhance 并发跑（双份 _enhanceImage，但远优于
        //     旧逻辑「杀旧启新」导致的总长等待+掉帧）。
        final myToken = ++_enhanceToken;
        final tokenValid = () => mounted && _enhanceToken == myToken;
        _enhance(tokenValid, _image);
      }
      return;
    }
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
    // 捕获本次加载令牌：快速翻页导致本 Widget 复用/重建时，旧阶段的异步结果若已过期
    // （令牌不符或已卸载）直接丢弃，绝不把旧页/旧增强覆盖到当前页。
    final myToken = ++_loadToken;
    final bool Function() tokenValid =
        () => mounted && _loadToken == myToken;
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
    final bool needEnhance = settings.denoise || settings.sharpness != 1.0;

    final dpr = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    final double renderWidth = (widget.targetWidth * dpr)
        .clamp(200, PdfRenderService.maxRenderWidth.toDouble())
        .toDouble();

    // —— 阶段一：仅原生渲染（命中预取缓存即瞬时），立即显示，翻页 0 等待、不转圈 ——
    final base = await PdfRenderService.renderPageImage(
      widget.document,
      pageNum,
      renderWidth: renderWidth,
      autoCrop: useManual ? false : effectiveAutoCrop,
      denoise: false,
      sharpness: 1.0, // 阶段一不做增强，原生图最快呈现
      manualCropLeft: settings.manualCropLeft,
      manualCropRight: settings.manualCropRight,
      manualCropTop: settings.manualCropTop,
      manualCropBottom: settings.manualCropBottom,
      // ★ 渲染中断关键钩子：本页 Widget 已卸载（快速翻页滑出视口）即丢弃，
      // 进入文档锁后二次校验失败 → 立即释放锁，根治「队列雪崩」。
      isStillNeeded: tokenValid,
    );
    // ★ 关键修复：令牌失效表示本页已滑出视口/被复用。base 由 PdfRenderService 内部
    // 缓存持有（生命周期由 LRU 管理），此处不可直接 dispose（会破坏缓存、致它页黑屏），
    // 直接返回即可——缓存会在容量超限时自行释放，不会泄漏。
    if (!tokenValid()) return;
    if (base == null) return;
    setState(() {
      _setImage(base);
      _loading = false; // 立即消除转圈
    });

    // 无需增强（关闭智能清晰度/去杂色且清晰度=1）：阶段一即终态，结束。
    if (!needEnhance) return;

    // —— 阶段二：后台把智能清晰度/去杂色算完，无感替换上来（见 [_enhance]）——
    await _enhance(tokenValid, base);
  }

  /// Stage 2 智能清晰度增强（去杂色 + 锐化），无转圈、可在滚动停止后静默调用。
  ///
  /// [base] 为当前已显示的原始裁切图（用于「增强未改变即等同 base」的判定）。
  /// 增强仅在「当前可见页」进行，每次至多 1~2 页，不会批量压满主线程/显存；
  /// 算完前用户已看到原生图，无等待感。令牌失效（快速翻走）时安全回收过期增强图，
  /// 防止显存堆积导致 OOM。
  Future<void> _enhance(bool Function() tokenValid, ui.Image? base) async {
    final settings = widget.settings;
    final int pageNum = widget.pageIndex + 1; // 1-based
    final bool isOddPage = pageNum % 2 != 0;
    final effectiveAutoCrop = switch (settings.cropOddEvenMode) {
      0 => settings.autoCrop,
      1 => settings.autoCrop && isOddPage,
      2 => settings.autoCrop && !isOddPage,
      _ => settings.autoCrop,
    };
    final bool useManual = settings.cropMode == 2 &&
        (settings.manualCropLeft > 0 ||
            settings.manualCropRight > 0 ||
            settings.manualCropTop > 0 ||
            settings.manualCropBottom > 0);
    final dpr = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    final double renderWidth = (widget.targetWidth * dpr)
        .clamp(200, PdfRenderService.maxRenderWidth.toDouble())
        .toDouble();

    // 滚动中（PdfRenderService.isScrolling）renderPageImage 被强制降级为原生图，
    // 此时 enhanced==base，下方判定跳过，等价于「滚动期间不增强」。
    final enhanced = await PdfRenderService.renderPageImage(
      widget.document,
      pageNum,
      renderWidth: renderWidth,
      autoCrop: useManual ? false : effectiveAutoCrop,
      denoise: settings.denoise,
      sharpness: settings.sharpness,
      manualCropLeft: settings.manualCropLeft,
      manualCropRight: settings.manualCropRight,
      manualCropTop: settings.manualCropTop,
      manualCropBottom: settings.manualCropBottom,
      // 与阶段一同一令牌：翻走/复用导致令牌失效或卸载即丢弃，避免增强结果覆盖到别的页。
      isStillNeeded: tokenValid,
    );
    if (enhanced == null || !tokenValid()) {
      // ★ 关键修复（OOM）：令牌失效 → 本页已滑出视口，必须把过期的增强结果回收。
      // 注意：enhanced 是 PdfRenderService 缓存持有的实例，直接 dispose 会破坏仍在
      // 缓存中、可能被其它页复用的同一份（黑屏/崩溃）。故走 evictImage 安全移除并释放；
      // 同时排除当前正显示的 _image，避免误释放正在呈现的图。
      if (enhanced != null && enhanced != base && enhanced != _image) {
        PdfRenderService.evictImage(enhanced);
      }
      return;
    }
    setState(() => _setImage(enhanced));
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
  /// 静默增强代际号：滚动停止时自增并随 setState 重建可见页瓦片，驱动其重跑
  /// Stage 2 智能清晰度增强（无转圈）。与主视图 [_enhanceTick] 同源逻辑。
  int _enhanceTick = 0;

  @override
  void initState() {
    super.initState();
    // 复位全局滚动标记（与 PdfCustomViewState 同步），避免上一视图残留导致增强被降级。
    PdfRenderService.isScrolling = false;
    _scrollController = ScrollController();
    _zoomController.addListener(_onZoomChanged);
    _flatPages = [for (final s in widget.spreads) ...s];
    _paneKeys = List.generate(_flatPages.length, (_) => GlobalKey());
  }

  @override
  void dispose() {
    // 复位全局滚动标记，避免本面板在滚动中途销毁后 isScrolling 残留为 true。
    PdfRenderService.isScrolling = false;
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
          if (n is ScrollStartNotification || n is ScrollUpdateNotification) {
            // 标记当前处于滚动中，暂停 Stage 2 深度增强计算，保障 120Hz 帧率。
            if (!PdfRenderService.isScrolling) PdfRenderService.isScrolling = true;
          } else if (n is ScrollEndNotification) {
            // 滚动静止：恢复增强，并触发当前可见页静默升级为智能清晰度。
            PdfRenderService.isScrolling = false;
            _reportVisiblePage();
            _enhanceTick++;
            setState(() {});
          }
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
        enhanceTick: _enhanceTick,
      ),
    );
  }
}
