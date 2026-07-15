import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:pdfrx/pdfrx.dart';

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../controller/bookshelf_controller.dart';
import '../controller/settings_controller.dart';
import '../model/pdf_reader_settings.dart';
import '../service/pdf_render_service.dart';
import '../service/reading_session_service.dart';
import 'pdf_custom_view.dart';
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
  // 翻页方式：0 左右翻页 / 1 上下滚动 / 2 仿真 / 3 无（初始化自持久化，回调中落库）。
  int _selectedPageMode = SettingsEngine.readerPageMode;

  // PDF 专属视觉设置（初始化自全局持久化，回调中上浮并落库）。
  // 渲染效果由 PdfCustomView 真实实现（2-up / 连续 / 原生裁切 / GPU 滤镜）。
  int _layoutMode = SettingsEngine.readerLayoutMode;
  bool _autoCrop = SettingsEngine.pdfAutoCrop;
  double _contrast = SettingsEngine.pdfBgContrast;
  double _saturation = SettingsEngine.pdfBgSaturation;
  bool _removeColor = SettingsEngine.pdfBgRemoveColor;
  bool _denoise = SettingsEngine.pdfBgDenoise;

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
        autoCrop: _autoCrop,
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
        removeColor: _removeColor,
        denoise: _denoise,
      );

  /// 重排：一键切换为「上下滚动 + 单栏连续 + 去白边」的紧凑阅读模式，适合手机阅读。
  ///
  /// 组合三项已实现的能力：翻页方式=上下滚动(1)、布局=单页连续(2)、自动裁切=开，
  /// 全部由 pdfrx 低层自建的 [PdfCustomView] 真实实现（连续滚动 + 原生精确裁切去白边）。
  ///
  /// 说明：对「图片扫描件」而言这是版式层面的重排（连续滚动 + 去白边 + 撑满宽度），
  /// 并非文字级重排（后者需 OCR 识别文字后重新排版，属阶段3 PaddleOCR 集成范畴）。
  void _reflow() {
    if (!mounted) return;
    setState(() {
      _selectedPageMode = 1; // 上下滚动
      _layoutMode = 2; // 单页连续
      _autoCrop = true; // 去白边
      SettingsController.setReaderPageMode(1);
      SettingsController.setReaderLayoutMode(2);
      SettingsController.setPdfAutoCrop(true);
    });
  }

  /// 构建 PDF 阅读视图。
  ///
  /// 直接委托给自建的 [PdfCustomView]：双栏 2-up / 连续滚动 / 翻页吸附、原生精确裁切、
  /// 颜色调整与智能去杂色等均由该视图内部按 [PdfReaderSettings] 真实实现。
  Widget _buildPdfView() {
    return PdfCustomView(
      document: _pdfDocument!,
      settings: _readerSettings,
      pageMode: _selectedPageMode,
      onPageChanged: _syncProgress,
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
                            color: Colors.black.withOpacity(
                              _overlayAnimation.value,
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
                                  minSize: 0,
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
                                    color: themeColor.withOpacity(0.12),
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
