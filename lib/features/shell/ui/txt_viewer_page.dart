import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../engine/localization_engine.dart';
import '../controller/bookshelf_controller.dart';
import '../controller/settings_controller.dart';
import '../service/reading_session_service.dart';
import 'reader_settings_sheet.dart';

class TxtViewerPage extends StatefulWidget {
  final String title;
  final String filePath;
  final String bookId;
  final BookshelfController? controller;

  const TxtViewerPage({
    super.key,
    required this.title,
    required this.filePath,
    required this.bookId,
    this.controller,
  });

  @override
  State<TxtViewerPage> createState() => _TxtViewerPageState();
}

class _TxtViewerPageState extends State<TxtViewerPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  String? _content;
  bool _isFullscreen = true;
  bool _showSettings = false;
  Timer? _tapDetectionTimer;
  final ReadingSessionTracker _session = ReadingSessionTracker();
  late final AnimationController _settingsController;
  late final Animation<double> _settingsAnimation;
  late final Animation<Offset> _headerOffsetAnimation;
  late final Animation<Offset> _sheetOffsetAnimation;
  late final Animation<double> _overlayAnimation;
  late final Animation<double> _contentScaleAnimation;
  int _selectedThemeIndex = 1;
  double _brightness = 0.8;
  int _selectedFontIndex = 0;
  int _selectedPageMode = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session.start();
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
    _load();
  }

  @override
  void dispose() {
    _pauseSession();
    _tapDetectionTimer?.cancel();
    _settingsController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _pauseSession();
    }
  }

  /// 结束本次阅读会话并记录（开始时间 / 时长 / 是否读完）。
  void _pauseSession() {
    _session.stop(
      bookId: widget.bookId,
      isFinished: () =>
          (widget.controller?.getBook(widget.bookId)?.progress ?? 0) >= 1.0,
      onDuration: (s) => widget.controller?.updateBookReadingDuration(
        widget.bookId,
        s,
      ),
    );
  }

  Future<void> _load() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      String text;
      try {
        text = utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        text = latin1.decode(bytes);
      }
      if (!mounted) return;
      setState(() {
        _content = text;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _content = '无法读取文本文件：$e';
      });
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      _showSettings = false;
    });
    _settingsController.reverse();
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

  Future<void> _showAddTagDialog() async {
    if (widget.controller == null || widget.bookId.isEmpty) {
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

  @override
  Widget build(BuildContext context) {
    final textColor = CupertinoColors.label.resolveFrom(context);
    final backgroundColor = CupertinoColors.systemBackground.resolveFrom(
      context,
    );
    final themeColor = CupertinoTheme.of(context).primaryColor;

    return ValueListenableBuilder<Color>(
      valueListenable: SettingsController.readerBackgroundColor,
      builder: (context, readerBackgroundColor, child) {
        final effectiveTextColor = readerBackgroundColor.computeLuminance() > 0.6
            ? CupertinoColors.label.resolveFrom(context)
            : CupertinoColors.white;

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
                        if (_isFullscreen)
                          SizedBox(
                            height: 48,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: _toggleFullscreen,
                                child: Icon(
                                  CupertinoIcons.fullscreen_exit,
                                  color: themeColor,
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: _content == null
                              ? const Center(child: CupertinoActivityIndicator())
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                                  child: SelectableText(
                                    _content!,
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.5,
                                      color: effectiveTextColor,
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
                        key: const ValueKey('txt_reader_center_tap_target'),
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
                    ignoring: !_showSettings && !_settingsController.isAnimating,
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
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                        child: Row(
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              onPressed: () => Navigator.of(context).maybePop(),
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
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.label.resolveFrom(
                                    context,
                                  ),
                                ),
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
                              child: const Text('TXT'),
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
                      color: CupertinoColors.systemBackground.resolveFrom(context),
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
                        isPdfReader: false,
                        onThemeChanged: (index) =>
                            setState(() => _selectedThemeIndex = index),
                        onBrightnessChanged: (value) =>
                            setState(() => _brightness = value),
                        onFontChanged: (index) =>
                            setState(() => _selectedFontIndex = index),
                        onPageModeChanged: (index) =>
                            setState(() => _selectedPageMode = index),
                        onBackgroundColorChanged: (color) =>
                            SettingsController.setReaderBackgroundColor(color),
                        onAddTag: _showAddTagDialog,
                        onClose: _toggleSettings,
                        bookId: 'txt_reader',
                        totalPages: 0,
                        currentPage: 1,
                        onJumpToPage: (_) {},
                        onToggleLandscape: (_) {},
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
