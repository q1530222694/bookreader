import 'package:flutter/cupertino.dart';
import 'package:pdfx/pdfx.dart';

import '../model/pdf_reader_settings.dart';
import 'pdf_page_tile.dart';

/// PDF 多布局阅读视图（Dumb UI：仅消费 [PdfReaderSettings] 与 [PdfDocument]）。
///
/// 支持 4 种布局（[PdfReaderSettings.layoutMode]）：
/// - 0 单页：每屏一页，可双指缩放（[PageView]）；
/// - 1 双页：每屏一个对开（左右两页），可缩放；
/// - 2 单页连续：纵向连续滚动，整页铺满宽度；
/// - 3 双页连续：纵向连续滚动的对开列表。
///
/// 性能优化：所有页面按需懒渲染（[PageView.builder]/[ListView.builder]），
/// 瓦片内部仅对自动裁切开关变化重渲染，颜色调整只改 GPU 滤镜；双页模式单页
/// 渲染宽度减半，显著降低内存与解码开销。跨端（Android/iOS/Win/Mac）均走
/// pdfx 原生渲染 + Flutter 合成滤镜，无平台分支。
class PdfReaderView extends StatefulWidget {
  final PdfDocument document;
  final PdfReaderSettings settings;
  final int pageMode; // 0=左右翻页 1=上下滚动 2/3=其它
  final int initialPage; // 1 基页码
  final ValueChanged<int>? onCurrentPageChanged; // 1 基当前页码

  const PdfReaderView({
    super.key,
    required this.document,
    required this.settings,
    this.pageMode = 1,
    this.initialPage = 1,
    this.onCurrentPageChanged,
  });

  @override
  State<PdfReaderView> createState() => _PdfReaderViewState();
}

class _PdfReaderViewState extends State<PdfReaderView> {
  late final int _pagesCount;
  late final int _spreadCount;
  PageController? _pageController;
  ScrollController? _scrollController;
  bool _isContinuous = false;

  @override
  void initState() {
    super.initState();
    _pagesCount = widget.document.pagesCount ?? 0;
    final layout = widget.settings.layoutMode;
    _isContinuous = layout == 2 || layout == 3;
    _spreadCount = layout == 0 || layout == 2
        ? _pagesCount
        : (_pagesCount + 1) ~/ 2;

    if (_isContinuous) {
      _scrollController = ScrollController();
      // 连续模式：尽量定位到初始阅读进度（近似，按滚动比例跳转）
      if (widget.initialPage > 1 && _pagesCount > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final max = _scrollController!.position.maxScrollExtent;
          final offset = (widget.initialPage - 1) /
              (_pagesCount - 1) *
              max;
          _scrollController!.jumpTo(offset.clamp(0.0, max));
        });
      }
    } else {
      final initialSpread = layout == 1
          ? (widget.initialPage - 1) ~/ 2
          : widget.initialPage - 1;
      _pageController = PageController(
        initialPage: initialSpread.clamp(0, _spreadCount - 1),
      );
      _pageController!.addListener(_notifyPagedPage);
    }
  }

  @override
  void didUpdateWidget(PdfReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 布局切换时重建控制器，避免 PageView/ListView 混用导致异常
    if (oldWidget.settings.layoutMode != widget.settings.layoutMode) {
      _rebuildControllers();
    }
  }

  void _rebuildControllers() {
    _pageController?.removeListener(_notifyPagedPage);
    _pageController?.dispose();
    _pageController = null;
    _scrollController?.dispose();
    _scrollController = null;

    final layout = widget.settings.layoutMode;
    _isContinuous = layout == 2 || layout == 3;
    _spreadCount = layout == 0 || layout == 2
        ? _pagesCount
        : (_pagesCount + 1) ~/ 2;

    if (_isContinuous) {
      _scrollController = ScrollController();
    } else {
      _pageController = PageController();
      _pageController!.addListener(_notifyPagedPage);
    }
    if (mounted) setState(() {});
  }

  /// 翻页模式下，计算当前页码并上报（用于进度同步）。
  void _notifyPagedPage() {
    if (_pageController == null) return;
    final index = _pageController!.page?.round() ?? 0;
    final pages = _pagesForSpread(index);
    if (pages.isNotEmpty) {
      widget.onCurrentPageChanged?.call(pages.first);
    }
  }

  /// 给定对开索引，返回该对开包含的 1 基页码列表。
  List<int> _pagesForSpread(int spreadIndex) {
    if (spreadIndex < 0) return [];
    if (widget.settings.layoutMode == 0 || widget.settings.layoutMode == 2) {
      final p = spreadIndex + 1;
      return p <= _pagesCount ? [p] : [];
    }
    final start = spreadIndex * 2 + 1;
    if (start > _pagesCount) return [];
    final end = start + 1;
    return end <= _pagesCount ? [start, end] : [start];
  }

  @override
  void dispose() {
    _pageController?.removeListener(_notifyPagedPage);
    _pageController?.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (_pagesCount <= 0) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_isContinuous) {
      return _buildContinuous(context, width);
    }
    return _buildPaged(context, width);
  }

  /// 单页 / 双页：翻页视图（可缩放）。
  Widget _buildPaged(BuildContext context, double width) {
    final isDouble = widget.settings.layoutMode == 1;
    return PageView.builder(
      controller: _pageController,
      scrollDirection: widget.pageMode == 0 ? Axis.horizontal : Axis.vertical,
      itemCount: _spreadCount,
      itemBuilder: (context, index) {
        final pages = _pagesForSpread(index);
        if (pages.isEmpty) {
          return const SizedBox.shrink();
        }
        if (isDouble) {
          return Row(
            children: pages.map((p) {
              return Expanded(
                child: PdfPageTile(
                  document: widget.document,
                  pageNumber: p,
                  settings: widget.settings,
                  renderWidth: width / 2,
                  zoomable: true,
                ),
              );
            }).toList(),
          );
        }
        return PdfPageTile(
          document: widget.document,
          pageNumber: pages.first,
          settings: widget.settings,
          renderWidth: width,
          zoomable: true,
        );
      },
    );
  }

  /// 单页连续 / 双页连续：纵向连续滚动。
  Widget _buildContinuous(BuildContext context, double width) {
    final isDouble = widget.settings.layoutMode == 3;
    return NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        if (_scrollController == null ||
            _scrollController!.position.maxScrollExtent <= 0 ||
            _pagesCount <= 1) {
          return false;
        }
        final fraction = _scrollController!.offset /
            _scrollController!.position.maxScrollExtent;
        final page = (1 + fraction * (_pagesCount - 1)).round();
        widget.onCurrentPageChanged?.call(page.clamp(1, _pagesCount));
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _spreadCount,
        itemBuilder: (context, index) {
          final pages = _pagesForSpread(index);
          if (pages.isEmpty) {
            return const SizedBox.shrink();
          }
          if (isDouble) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: pages.map((p) {
                  return Expanded(
                    child: PdfPageTile(
                      document: widget.document,
                      pageNumber: p,
                      settings: widget.settings,
                      renderWidth: width / 2,
                      zoomable: false,
                    ),
                  );
                }).toList(),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: PdfPageTile(
              document: widget.document,
              pageNumber: pages.first,
              settings: widget.settings,
              renderWidth: width,
              zoomable: false,
            ),
          );
        },
      ),
    );
  }
}
