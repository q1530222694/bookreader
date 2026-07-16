import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart' show DeviceOrientation, SystemChrome;
import 'package:pdfrx/pdfrx.dart';

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../controller/bookshelf_controller.dart';
import '../controller/settings_controller.dart';
import '../model/pdf_reader_settings.dart';
import '../service/pdf_render_service.dart';
import '../service/pdf_text_reflow_service.dart';
import '../service/reading_session_service.dart';
import 'pdf_custom_view.dart';
import 'pdf_reflow_view.dart';
import 'reader_settings_sheet.dart';

/// BookViewerPage 展示 PDF 书籍，支持翻页 / 布局 / 自动裁切 / 背景调节等设置。
///
/// 渲染核心使用 pdfrx 低层 API 自建的 [PdfCustomView]（双栏 2-up、连续滚动、
/// 原生精确裁切、GPU 滤镜叠加均由自定义视图掌控），取代了不支持自定义版面与裁切的
/// pdfx [PdfView]。详见 [lib/features/shell/ui/pdf_custom_view.dart]。
class BookViewerPage extends StatefulWidget {
  final String title;
  final String filePath;
  final String bookId;
  final BookshelfController? controller;

  const BookViewerPage({
    super.key,
    required this.title,
    required this.filePath,
    required this.bookId,
    this.controller,
  });

  @override
  State<BookViewerPage> createState() => _BookViewerPageState();
}

class _BookViewerPageState extends State<BookViewerPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  String? _errorText;
  PdfDocument? _pdfDocument;
  DateTime? _sessionStart;
  double? _lastSyncedProgress;
  bool _showSettings = false;
  // 框选裁边状态
  bool _showCropSelector = false;
  Offset? _cropStartPos;
  Offset? _cropEndPos;
  int _cropTargetPage = 1; // 框选目标页码（1-based）
  late final AnimationController _settingsController;
  late final Animation<double> _settingsAnimation;
  late final Animation<Offset> _headerOffsetAnimation;
  late final Animation<Offset> _sheetOffsetAnimation;
  late final Animation<double> _overlayAnimation;
  late final Animation<double> _contentScaleAnimation;
  Timer? _tapDetectionTimer;
  int _selectedThemeIndex = 1;
  double _brightness = 1.0;
  int _selectedFontIndex = 0;
  // 翻页方式：0 左右滑动 / 1 上下滑动 / 2 左右单击 / 3 上下单击 / 4 单击滚动。
  // 初始化自持久化，回调中落库。
  int _selectedPageMode = SettingsEngine.readerPageMode;

  // 重排状态：_isReflowing 表示当前处于重排阅读视图；_reflowParagraphs 为已提取段落；
  // _reflowLoading 为提取中；_reflowError 为无文本层 / 提取失败提示。
  bool _isReflowing = false;
  List<String>? _reflowParagraphs;
  bool _reflowLoading = false;
  String? _reflowError;

  // PDF 专属视觉设置（初始化自全局持久化，回调中上浮并落库）。
  // 渲染效果由 PdfCustomView 真实实现（2-up / 连续 / 原生裁切 / GPU 滤镜）。
  int _layoutMode = SettingsEngine.readerLayoutMode;
  bool _autoCrop = SettingsEngine.pdfAutoCrop;
  double _contrast = SettingsEngine.pdfBgContrast;
  double _saturation = SettingsEngine.pdfBgSaturation;
  bool _removeColor = SettingsEngine.pdfBgRemoveColor;
  bool _denoise = SettingsEngine.pdfBgDenoise;
  double _colorTemperature = SettingsEngine.pdfBgColorTemp;
  int _cropMode = SettingsEngine.pdfCropMode;
  double _manualCropLeft = SettingsEngine.pdfManualCropLeft;
  double _manualCropRight = SettingsEngine.pdfManualCropRight;
  double _manualCropTop = SettingsEngine.pdfManualCropTop;
  double _manualCropBottom = SettingsEngine.pdfManualCropBottom;
  bool _dualScreen = SettingsEngine.pdfDualScreen;
  int _cropOddEvenMode = SettingsEngine.pdfCropOddEvenMode;

  // 当前阅读页码（1-based），由翻页回调同步；用于设置面板初始化进度/笔记/书签。
  int _currentPage = 1;
  // 阅读视图句柄：设置面板（进度/目录/笔记/搜索）通过它驱动翻页跳转。
  final GlobalKey<PdfCustomViewState> _pdfViewKey = GlobalKey<PdfCustomViewState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settingsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(_handleSettingsAnimationChanged)
      ..addStatusListener(_handleSettingsAnimationStatusChanged);
    _settingsAnimation = CurvedAnimation(
      parent: _settingsController,
      curve: Curves.easeOutBack,
    );
    _headerOffsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(_settingsAnimation);
    _sheetOffsetAnimation = Tween<Offset>(
      begin: const Offset(0, 2.2),
      end: Offset.zero,
    ).animate(_settingsAnimation);
    _overlayAnimation = Tween<double>(begin: 0.0, end: 0.15).animate(
      _settingsAnimation,
    );
    _contentScaleAnimation = Tween<double>(begin: 1.0, end: 0.985).animate(
      _settingsAnimation,
    );
    _startSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializePdf();
    });
  }

  Future<void> _initializePdf() async {
    try {
    final document = await PdfDocument.openFile(widget.filePath);
    if (!mounted) {
      await document.dispose();
      return;
    }
    _pdfDocument = document;
    setState(() {
      _errorText = null;
    });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorText = '打开 PDF 失败：$error';
      });
    }
  }

  @override
  void dispose() {
    _tapDetectionTimer?.cancel();
    _pauseSessionAndPersist();
    WidgetsBinding.instance.removeObserver(this);
    _settingsController.dispose();
    if (_pdfDocument != null) {
      // 关闭文档并释放本服务持有的渲染缓存（含已渲染的 ui.Image），避免 GPU 内存泄漏。
      PdfRenderService.disposeDocument(_pdfDocument!);
    }
    super.dispose();
  }

  void _syncProgress(int page) {
    if (widget.controller == null || _pdfDocument == null) {
      return;
    }

    final totalPages = _pdfDocument!.pages.length;
    if (totalPages <= 0) {
      return;
    }

    final progress = (page / totalPages).clamp(0.0, 1.0);
    _currentPage = page;
    if (_lastSyncedProgress != null &&
        (progress - _lastSyncedProgress!).abs() < 0.0001) {
      return;
    }
    _lastSyncedProgress = progress;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller!.updateBookProgress(widget.bookId, progress);
    });
  }

  void _startSession() {
    if (_sessionStart != null) {
      return;
    }
    _sessionStart = DateTime.now();
  }

  void _pauseSessionAndPersist() {
    final begin = _sessionStart;
    _sessionStart = null;
    if (begin == null) return;

    final elapsedSeconds = DateTime.now().difference(begin).inSeconds;
    if (elapsedSeconds <= 0) return;

    // 更新书籍累计阅读时长（仅在有 controller 时）
    if (widget.controller != null) {
      widget.controller!.updateBookReadingDuration(widget.bookId, elapsedSeconds);
    }
    // 记录本次阅读会话：开始时间 / 时长 / 是否读完，供阅读记录页使用
    final finished = widget.controller == null
        ? false
        : (widget.controller!.getBook(widget.bookId)?.progress ?? 0) >= 1.0;
    ReadingSessionService.logSession(
      bookId: widget.bookId,
      startedAt: begin,
      durationSeconds: elapsedSeconds,
      finished: finished,
    );
  }

  Future<void> _showAddTagDialog() async {
    if (widget.controller == null) {
      return;
    }
    final textController = TextEditingController();

    void submitTag() {
      final newTag = textController.text.trim();
      if (newTag.isNotEmpty) {
        final book = widget.controller!.getBook(widget.bookId);
        if (book != null) {
          final tags = List<String>.from(book.tags);
          if (!tags.contains(newTag)) {
            tags.add(newTag);
            widget.controller!.updateBookTags(widget.bookId, tags);
          }
        }
      }
      Navigator.of(context).pop();
    }

    await showCupertinoDialog<void>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(LocalizationEngine.text('reader_add_tag')),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: textController,
              placeholder: LocalizationEngine.text('reader_add_tag_placeholder'),
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submitTag(),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(LocalizationEngine.text('cancel')),
            ),
            CupertinoDialogAction(
              onPressed: submitTag,
              child: Text(LocalizationEngine.text('add')),
            ),
          ],
        );
      },
    );
    textController.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _startSession();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pauseSessionAndPersist();
    }
  }

  void _handleSettingsAnimationChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleSettingsAnimationStatusChanged(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      setState(() {});
    }
  }

  void _toggleSettings() {
    if (!mounted) return;
    setState(() {
      _showSettings = !_showSettings;
    });
    if (_showSettings) {
      _settingsController.forward();
    } else {
      _settingsController.reverse();
    }
  }

  /// 横屏模式开关：开启时锁定为横屏，关闭时恢复跟随系统（竖屏优先）。
  void _toggleLandscape(bool enabled) {
    if (enabled) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _handleCenterTap() {
    if (_tapDetectionTimer != null) {
      _tapDetectionTimer!.cancel();
      _tapDetectionTimer = null;
      return;
    }

    _tapDetectionTimer = Timer(const Duration(milliseconds: 220), () {
      _tapDetectionTimer = null;
      if (!mounted) return;
      _toggleSettings();
    });
  }

  /// 由当前状态聚合的 PDF 阅读器视觉设置（供 GPU 滤镜合成与布局判断消费）。
  PdfReaderSettings get _readerSettings => PdfReaderSettings(
        layoutMode: _layoutMode,
        cropMode: _cropMode,
        autoCrop: _autoCrop,
        manualCropLeft: _manualCropLeft,
        manualCropRight: _manualCropRight,
        manualCropTop: _manualCropTop,
        manualCropBottom: _manualCropBottom,
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
        colorTemperature: _colorTemperature,
        removeColor: _removeColor,
        denoise: _denoise,
        dualScreen: _dualScreen,
        cropOddEvenMode: _cropOddEvenMode,
      );

  /// 重排：基于 PDF 文本层做「真实重排」（本地、无损、跨平台、流畅）。
  ///
  /// 切换行为：已在重排中则退出，否则进入重排。经 [PdfTextReflowService.extract] 从
  /// [PdfDocument] 取出按阅读顺序排列的真实文本段落，再交由 [PdfReflowView] 以可调
  /// 字号 / 行距 / 字距 / 段距重新流式排版。提取过程异步进行，
  /// 期间显示加载提示；纯图片扫描件（无文本层）会提示改用 OCR。
  Future<void> _reflow() async {
    // 已在重排中 → 退出重排
    if (_isReflowing) {
      _exitReflow();
      return;
    }
    // 未在重排中 → 进入重排
    if (!mounted || _pdfDocument == null) return;
    setState(() {
      _reflowLoading = true;
      _reflowError = null;
    });
    try {
      final result = await PdfTextReflowService.extract(_pdfDocument!);
      if (!mounted) return;
      if (!result.hasTextLayer) {
        setState(() {
          _reflowLoading = false;
          _reflowParagraphs = null;
          _isReflowing = false;
          _reflowError = LocalizationEngine.text('pdf_reflow_empty');
        });
        return;
      }
      setState(() {
        _reflowParagraphs = result.paragraphs;
        _isReflowing = true;
        _reflowLoading = false;
        _reflowError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reflowLoading = false;
        _reflowError = '重排失败：$e';
      });
    }
  }

  /// 退出重排：返回原 PDF 版式阅读视图。
  void _exitReflow() {
    if (!mounted) return;
    setState(() {
      _isReflowing = false;
    });
  }

  /// 开始框选裁边：进入裁边选择模式，在当前页面上手绘画框。
  void _startCropSelection() {
    if (!mounted) return;
    // 取消设置面板
    if (_showSettings) {
      _toggleSettings();
    }
    setState(() {
      _showCropSelector = true;
      _cropStartPos = null;
      _cropEndPos = null;
      // 默认对当前阅读进度页进行框选（至少为第1页）
      _cropTargetPage = (_lastSyncedProgress != null
              ? (_lastSyncedProgress! * (_pdfDocument?.pages.length ?? 1)).round()
              : 0)
          .clamp(1, _pdfDocument?.pages.length ?? 1);
    });
  }

  /// 确认框选区域：将屏幕坐标的选区归一化为 0~1 的裁切边距。
  void _confirmCropSelection() {
    if (_cropStartPos == null || _cropEndPos == null || !mounted) return;

    final start = _cropStartPos!;
    final end = _cropEndPos!;
    // 选区坐标已由 _CropSelectorPage 归一化为页面图像内的 0~1（已考虑 BoxFit.contain
    // 的偏移与缩放），直接换算为四边边距（%）：left/right 为左右留白，top/bottom 为上下留白。
    final left = math.min(start.dx, end.dx).clamp(0.0, 1.0);
    final right = (1.0 - math.max(start.dx, end.dx)).clamp(0.0, 1.0);
    final top = math.min(start.dy, end.dy).clamp(0.0, 1.0);
    final bottom = (1.0 - math.max(start.dy, end.dy)).clamp(0.0, 1.0);

    setState(() {
      _manualCropLeft = left;
      _manualCropRight = right;
      _manualCropTop = top;
      _manualCropBottom = bottom;
      _cropMode = 2; // 切换到手动裁切模式
      _autoCrop = false;
      _showCropSelector = false;
      _cropStartPos = null;
      _cropEndPos = null;
      // 持久化裁切参数
      SettingsController.setPdfManualCropLeft(left);
      SettingsController.setPdfManualCropRight(right);
      SettingsController.setPdfManualCropTop(top);
      SettingsController.setPdfManualCropBottom(bottom);
      SettingsController.setPdfCropMode(2);
      SettingsController.setPdfAutoCrop(false);
    });

    // 清除该页的缓存以触发重新渲染
    if (_pdfDocument != null) {
      PdfRenderService.invalidatePageCache(
        _pdfDocument!, _cropTargetPage);
    }
  }

  /// 取消框选裁边。
  void _cancelCropSelection() {
    if (!mounted) return;
    setState(() {
      _showCropSelector = false;
      _cropStartPos = null;
      _cropEndPos = null;
    });
  }

  /// 一键还原全部裁切设置：裁切模式=0、关闭自动裁边、四边手动边距清零、奇偶页=统一。
  ///
  /// 同时落库并广播，使 [PdfCustomView] 收到新的 [PdfReaderSettings] 后自动重渲染。
  void _resetCrop() {
    if (!mounted) return;
    setState(() {
      _cropMode = 0;
      _autoCrop = false;
      _manualCropLeft = 0.0;
      _manualCropRight = 0.0;
      _manualCropTop = 0.0;
      _manualCropBottom = 0.0;
      _cropOddEvenMode = 0;
    });
    SettingsController.setPdfCropMode(0);
    SettingsController.setPdfAutoCrop(false);
    SettingsController.setPdfManualCropLeft(0.0);
    SettingsController.setPdfManualCropRight(0.0);
    SettingsController.setPdfManualCropTop(0.0);
    SettingsController.setPdfManualCropBottom(0.0);
    SettingsController.setPdfCropOddEvenMode(0);
    // 清除所有页的裁切渲染缓存，确保立即以无裁切状态重绘。
    if (_pdfDocument != null) {
      for (var i = 1; i <= _pdfDocument!.pages.length; i++) {
        PdfRenderService.invalidatePageCache(_pdfDocument!, i);
      }
    }
  }

  /// 构建 PDF 阅读视图。
  ///
  /// 重排模式下委托给 [PdfReflowView]（真实文本重排 + 可调排版）；否则委托给自建的
  /// [PdfCustomView]：双栏 2-up / 连续滚动 / 翻页吸附、原生精确裁切、颜色调整与智能去杂色
  /// 等均由该视图内部按 [PdfReaderSettings] 与 [pageAnimation] 真实实现。
  Widget _buildPdfView() {
    if (_isReflowing && _reflowParagraphs != null) {
      return PdfReflowView(
        paragraphs: _reflowParagraphs!,
        onExit: _exitReflow,
      );
    }
    return PdfCustomView(
      key: _pdfViewKey,
      document: _pdfDocument!,
      settings: _readerSettings,
      pageMode: _selectedPageMode,
      pageAnimation: SettingsEngine.readerPageAnimation,
      onPageChanged: _syncProgress,
    );
  }

  /// 框选裁边覆盖层：显示当前页面 + 半透明遮罩 + 手绘画框区域。
  ///
  /// 用户在页面上拖拽绘制矩形选区，确认后将选区归一化为裁切边距（左/右/上/下）。
  /// 顶部显示操作提示栏（取消 / 页码选择 / 确认），底部显示操作说明。
  Widget _buildCropSelectorOverlay() {
    final themeColor = CupertinoTheme.of(context).primaryColor;
    return Stack(
      children: [
        // 背景半透明遮罩
        Container(color: Colors.black.withValues(alpha: 0.6)),
        // PDF 页面预览（居中显示目标页面）
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _pdfDocument != null
                  ? _CropSelectorPage(
                      document: _pdfDocument!,
                      pageNumber: _cropTargetPage,
                      cropStart: _cropStartPos,
                      cropEnd: _cropEndPos,
                      onStart: (pos) => setState(() => _cropStartPos = pos),
                      onUpdate: (pos) => setState(() => _cropEndPos = pos),
                    )
                  : const Center(
                      child: CupertinoActivityIndicator(),
                    ),
            ),
          ),
        ),
        // 顶部操作栏
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // 取消按钮
                GestureDetector(
                  onTap: _cancelCropSelection,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey5.resolveFrom(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.xmark, size: 14, color: CupertinoColors.label.resolveFrom(context)),
                        const SizedBox(width: 4),
                        Text(LocalizationEngine.text('cancel'), style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // 目标页码
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${LocalizationEngine.text('pdf_crop_select_page')} $_cropTargetPage',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                // 切换上一页/下一页
                GestureDetector(
                  onTap: () {
                    if (_cropTargetPage > 1) {
                      setState(() => _cropTargetPage--);
                    }
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey5.resolveFrom(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(CupertinoIcons.chevron_left, size: 16),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (_pdfDocument != null && _cropTargetPage < _pdfDocument!.pages.length) {
                      setState(() => _cropTargetPage++);
                    }
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey5.resolveFrom(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(CupertinoIcons.chevron_right, size: 16),
                  ),
                ),
                const Spacer(),
                // 确认按钮
                GestureDetector(
                  onTap: _confirmCropSelection,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: themeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.checkmark, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(LocalizationEngine.text('confirm'),
                            style: const TextStyle(fontSize: 14, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 底部提示
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 20,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                LocalizationEngine.text('pdf_crop_select_hint'),
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemBackground.resolveFrom(
      context,
    );
    final themeColor = CupertinoTheme.of(context).primaryColor;
    final titleTextStyle = CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.label.resolveFrom(context),
        );

    return ValueListenableBuilder<Color>(
      valueListenable: SettingsController.readerBackgroundColor,
      builder: (context, readerBackgroundColor, child) {
        return CupertinoPageScaffold(
          backgroundColor: backgroundColor,
          child: Stack(
            children: [
              Container(
                color: readerBackgroundColor,
                child: AnimatedBuilder(
                  animation: _settingsAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _contentScaleAnimation.value,
                      alignment: Alignment.center,
                      child: child,
                    );
                  },
                  child: SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: _pdfDocument == null
                              ? const Center(child: CupertinoActivityIndicator())
                              : _reflowLoading
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CupertinoActivityIndicator(),
                                          SizedBox(height: 12),
                                          Text(
                                            LocalizationEngine.text(
                                              'pdf_reflow_loading',
                                            ),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: CupertinoColors.systemGrey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : _isReflowing && _reflowParagraphs != null
                                      ? PdfReflowView(
                                          paragraphs: _reflowParagraphs!,
                                          onExit: _exitReflow,
                                        )
                                      : _reflowError != null
                                          ? Center(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(24),
                                                child: Text(
                                                  _reflowError!,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    color: CupertinoColors
                                                        .systemGrey,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : _buildPdfView(),
                        ),
                        if (_errorText != null)
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemBackground
                                    .resolveFrom(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: CupertinoColors.systemGrey4,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      CupertinoIcons
                                          .exclamationmark_triangle,
                                      size: 48,
                                      color: CupertinoColors.systemRed,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      '无法打开 PDF 文件',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _errorText!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    return Stack(
                      children: [
                        Positioned(
                          left: width * 0.25,
                          top: height * 0.25,
                          width: width * 0.5,
                          height: height * 0.5,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapUp: (_) => _handleCenterTap(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // ── 框选裁边覆盖层 ──
              if (_showCropSelector)
                Positioned.fill(
                  child: _buildCropSelectorOverlay(),
                ),
              if (_showSettings || _settingsController.isAnimating)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _settingsAnimation,
                    builder: (context, child) {
                      return IgnorePointer(
                        ignoring:
                            !_showSettings && !_settingsController.isAnimating,
                        child: GestureDetector(
                          onTap: _toggleSettings,
                          child: Container(
                            color: Colors.black.withValues(
                              alpha: _overlayAnimation.value,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _settingsAnimation,
                  builder: (context, child) {
                    if (_settingsController.value <= 0 && !_showSettings) {
                      return const SizedBox.shrink();
                    }
                    return SlideTransition(
                      position: _headerOffsetAnimation,
                      child: SafeArea(
                        bottom: false,
                        child: Container(
                          width: double.infinity,
                          color: CupertinoColors.white,
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(8, 6, 8, 10),
                            child: Row(
                              children: [
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                  child: Icon(
                                    CupertinoIcons.back,
                                    color: themeColor,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: titleTextStyle,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: themeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text('PDF'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: _settingsAnimation,
                  builder: (context, child) {
                    if (_settingsController.value <= 0 && !_showSettings) {
                      return const SizedBox.shrink();
                    }
                    return SlideTransition(
                      position: _sheetOffsetAnimation,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground
                              .resolveFrom(context),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: ReaderSettingsSheet(
                            selectedThemeIndex: _selectedThemeIndex,
                            brightness: _brightness,
                            selectedFontIndex: _selectedFontIndex,
                            selectedPageMode: _selectedPageMode,
                            selectedBackgroundColor: readerBackgroundColor,
                            isPdfReader: true,
                            showReflow: _isReflowing,
                            onThemeChanged: (index) =>
                                setState(() => _selectedThemeIndex = index),
                            onBrightnessChanged: (value) =>
                                setState(() => _brightness = value),
                            onFontChanged: (index) =>
                                setState(() => _selectedFontIndex = index),
                            onPageModeChanged: (index) => setState(() {
                              _selectedPageMode = index;
                              SettingsController.setReaderPageMode(index);
                            }),
                            onBackgroundColorChanged: (color) =>
                                SettingsController.setReaderBackgroundColor(color),
                            // PDF 专属：布局模式（UI 保留，效果待叠加层接入）
                            selectedLayoutMode: _layoutMode,
                            onLayoutModeChanged: (index) => setState(() {
                              _layoutMode = index;
                              SettingsController.setReaderLayoutMode(index);
                            }),
                            // PDF 专属：自动裁切（UI 保留，效果待叠加层接入）
                            autoCrop: _autoCrop,
                            onAutoCropChanged: (value) => setState(() {
                              _autoCrop = value;
                              SettingsController.setPdfAutoCrop(value);
                            }),
                            // PDF 专属：背景调节（UI 保留，效果待叠加层接入）
                            contrast: _contrast,
                            onContrastChanged: (value) => setState(() {
                              _contrast = value;
                              SettingsController.setPdfBgContrast(value);
                            }),
                            saturation: _saturation,
                            onSaturationChanged: (value) => setState(() {
                              _saturation = value;
                              SettingsController.setPdfBgSaturation(value);
                            }),
                            removeColor: _removeColor,
                            onRemoveColorChanged: (value) => setState(() {
                              _removeColor = value;
                              SettingsController.setPdfBgRemoveColor(value);
                            }),
                            denoise: _denoise,
                            onDenoiseChanged: (value) => setState(() {
                              _denoise = value;
                              SettingsController.setPdfBgDenoise(value);
                            }),
                            colorTemperature: _colorTemperature,
                            onColorTemperatureChanged: (value) =>
                                setState(() {
                              _colorTemperature = value;
                              SettingsController.setPdfBgColorTemp(value);
                            }),
                            cropMode: _cropMode,
                            onCropModeChanged: (value) => setState(() {
                              _cropMode = value;
                              if (value == 1) {
                                _autoCrop = true;
                                SettingsController.setPdfAutoCrop(true);
                              } else if (value == 0) {
                                _autoCrop = false;
                                SettingsController.setPdfAutoCrop(false);
                              }
                              SettingsController.setPdfCropMode(value);
                            }),
                            manualCropLeft: _manualCropLeft,
                            onManualCropLeftChanged: (value) => setState(() {
                              _manualCropLeft = value;
                              // 调整手动裁切任一边即切换到手动裁切模式（cropMode=2），
                              // 否则 _PdfPageWidget 的 useManual 判定（cropMode==2）不会生效。
                              if (_cropMode != 2) {
                                _cropMode = 2;
                                _autoCrop = false;
                                SettingsController.setPdfCropMode(2);
                                SettingsController.setPdfAutoCrop(false);
                              }
                              SettingsController.setPdfManualCropLeft(value);
                            }),
                            manualCropRight: _manualCropRight,
                            onManualCropRightChanged: (value) =>
                                setState(() {
                              _manualCropRight = value;
                              if (_cropMode != 2) {
                                _cropMode = 2;
                                _autoCrop = false;
                                SettingsController.setPdfCropMode(2);
                                SettingsController.setPdfAutoCrop(false);
                              }
                              SettingsController
                                  .setPdfManualCropRight(value);
                            }),
                            manualCropTop: _manualCropTop,
                            onManualCropTopChanged: (value) => setState(() {
                              _manualCropTop = value;
                              if (_cropMode != 2) {
                                _cropMode = 2;
                                _autoCrop = false;
                                SettingsController.setPdfCropMode(2);
                                SettingsController.setPdfAutoCrop(false);
                              }
                              SettingsController.setPdfManualCropTop(value);
                            }),
                            manualCropBottom: _manualCropBottom,
                            onManualCropBottomChanged: (value) =>
                                setState(() {
                              _manualCropBottom = value;
                              if (_cropMode != 2) {
                                _cropMode = 2;
                                _autoCrop = false;
                                SettingsController.setPdfCropMode(2);
                                SettingsController.setPdfAutoCrop(false);
                              }
                              SettingsController
                                  .setPdfManualCropBottom(value);
                            }),
                            onSelectCrop: _startCropSelection,
                            onResetCrop: _resetCrop,
                            dualScreen: _dualScreen,
                            onDualScreenChanged: (value) => setState(() {
                              _dualScreen = value;
                              SettingsController.setPdfDualScreen(value);
                            }),
                            cropOddEvenMode: _cropOddEvenMode,
                            onCropOddEvenModeChanged: (value) => setState(() {
                              _cropOddEvenMode = value;
                              SettingsController.setPdfCropOddEvenMode(value);
                            }),
                            // 新增：进度/目录/笔记/搜索所需上下文
                            bookId: widget.bookId,
                            document: _pdfDocument,
                            totalPages: _pdfDocument?.pages.length ?? 0,
                            currentPage: _currentPage,
                            onJumpToPage: (page) =>
                                _pdfViewKey.currentState?.jumpToPage(page),
                            onToggleLandscape: _toggleLandscape,
                            onAddTag: _showAddTagDialog,
                            onReflow: _reflow,
                            onClose: _toggleSettings,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 框选裁边的页面预览与手势交互组件。
///
/// 在指定 PDF 页面上叠加透明手势层，用户拖拽绘制矩形选区。
/// 选区以半透明色块实时反馈，支持重新绘制（再次拖拽即覆盖上一次结果）。
class _CropSelectorPage extends StatefulWidget {
  final PdfDocument document;
  final int pageNumber; // 1-based
  final Offset? cropStart;
  final Offset? cropEnd;
  final ValueChanged<Offset> onStart;
  final ValueChanged<Offset> onUpdate;

  const _CropSelectorPage({
    required this.document,
    required this.pageNumber,
    this.cropStart,
    this.cropEnd,
    required this.onStart,
    required this.onUpdate,
  });

  @override
  State<_CropSelectorPage> createState() => _CropSelectorPageState();
}

class _CropSelectorPageState extends State<_CropSelectorPage> {
  ui.Image? _pageImage;
  bool _loading = true;
  // 页面图像在控件内的实际显示区域（BoxFit.contain 后的居中矩形），
  // 用于把手势坐标换算成图像归一化坐标（0~1），避免按屏幕尺寸归一化导致裁切错位。
  Rect? _imageRect;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void didUpdateWidget(_CropSelectorPage old) {
    super.didUpdateWidget(old);
    if (old.pageNumber != widget.pageNumber) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    setState(() => _loading = true);
    final dpr = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    // 渲染目标页（不裁切，完整页面用于框选参考）
    final img = await PdfRenderService.renderPageImage(
      widget.document,
      widget.pageNumber,
      renderWidth: (600 * dpr).clamp(200, PdfRenderService.maxRenderWidth.toDouble()),
      autoCrop: false,
      denoise: false,
    );
    if (!mounted) return;
    setState(() {
      _pageImage = img;
      _loading = false;
    });
  }

  void _handlePanStart(DragStartDetails details) {
    if (_imageRect == null || _imageRect!.width <= 0 || _imageRect!.height <= 0) {
      return;
    }
    widget.onStart(_localToNorm(details.localPosition, _imageRect!));
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_imageRect == null || _imageRect!.width <= 0 || _imageRect!.height <= 0) {
      return;
    }
    widget.onUpdate(_localToNorm(details.localPosition, _imageRect!));
  }

  /// 计算图像在 box 内以 [BoxFit.contain] 显示时的居中矩形。
  static Rect _containRect(Size box, Size image) {
    if (box.width <= 0 || box.height <= 0) return Rect.zero;
    if (image.width <= 0 || image.height <= 0) return Rect.zero;
    final scale = math.min(box.width / image.width, box.height / image.height);
    final w = image.width * scale;
    final h = image.height * scale;
    return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
  }

  /// 局部像素坐标 → 图像归一化坐标（0~1）。
  static Offset _localToNorm(Offset p, Rect r) => Offset(
        ((p.dx - r.left) / r.width).clamp(0.0, 1.0),
        ((p.dy - r.top) / r.height).clamp(0.0, 1.0),
      );

  /// 图像归一化坐标（0~1）→ 局部像素坐标。
  static Offset _normToLocal(Offset p, Rect r) =>
      Offset(r.left + p.dx * r.width, r.top + p.dy * r.height);

  @override
  Widget build(BuildContext context) {
    if (_loading || _pageImage == null) {
      return const SizedBox(
        width: 400,
        height: 560,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    // 用 LayoutBuilder 拿到真实的布局约束（而非 context.size，后者在未首次布局时可能为零/过期），
    // 避免因 imageRect 尺寸为零导致手势坐标换算出现 Infinity/NaN 进而触发布局断言崩溃。
    return LayoutBuilder(
      builder: (ctx, constraints) {
        _imageRect = _containRect(
          constraints.biggest,
          Size(_pageImage!.width.toDouble(), _pageImage!.height.toDouble()),
        );
        return GestureDetector(
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 页面图像
              RawImage(image: _pageImage, fit: BoxFit.contain),
              // 选区高亮（半透明蓝色覆盖）：将归一化选区坐标还原为局部像素坐标绘制
              if (widget.cropStart != null &&
                  widget.cropEnd != null &&
                  _imageRect != null &&
                  _imageRect!.width > 0 &&
                  _imageRect!.height > 0)
                Positioned.fromRect(
                  rect: Rect.fromPoints(
                    _normToLocal(widget.cropStart!, _imageRect!),
                    _normToLocal(widget.cropEnd!, _imageRect!),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeBlue.withValues(alpha: 0.25),
                      border: Border.all(
                        color: CupertinoColors.activeBlue,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
