import 'package:flutter/cupertino.dart';
import 'package:pdfx/pdfx.dart';
import 'package:photo_view/photo_view.dart';

import '../controller/bookshelf_controller.dart';

/// BookViewerPage displays the first page of a PDF book.
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

class _BookViewerPageState extends State<BookViewerPage> with WidgetsBindingObserver {
  String? _errorText;
  PdfController? _pdfController;
  DateTime? _sessionStart;
  double? _lastSyncedProgress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializePdf();
    });
  }

  Future<void> _initializePdf() async {
    final documentFuture = PdfDocument.openFile(widget.filePath);
    try {
      if (!mounted) {
        await (await documentFuture).close();
        return;
      }
      setState(() {
        _pdfController = PdfController(document: documentFuture);
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
    _pauseSessionAndPersist();
    WidgetsBinding.instance.removeObserver(this);
    _pdfController?.dispose();
    super.dispose();
  }

  void _handleError(Object error) {
    if (!mounted) return;
    setState(() {
      _errorText = '打开 PDF 失败：$error';
    });
  }

  void _syncProgress(int page) {
    if (widget.controller == null || _pdfController == null) {
      return;
    }

    final totalPages = _pdfController!.pagesCount;
    if (totalPages == null || totalPages <= 0) {
      return;
    }

    final progress = (page / totalPages).clamp(0.0, 1.0);
    if (_lastSyncedProgress != null && (progress - _lastSyncedProgress!).abs() < 0.0001) {
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
    if (_sessionStart == null || widget.controller == null) {
      _sessionStart = null;
      return;
    }

    final elapsedSeconds = DateTime.now().difference(_sessionStart!).inSeconds;
    _sessionStart = null;
    if (elapsedSeconds <= 0) {
      return;
    }

    widget.controller!.updateBookReadingDuration(widget.bookId, elapsedSeconds);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _startSession();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      _pauseSessionAndPersist();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(widget.title, style: TextStyle(color: CupertinoTheme.of(context).primaryColor))),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _pdfController == null
                  ? const Center(child: CupertinoActivityIndicator())
                  : PdfView(
                      controller: _pdfController!,
                      onDocumentError: (error) => _handleError(error),
                onDocumentLoaded: (_) {
                  if (!mounted || _pdfController == null) return;
                  _syncProgress(_pdfController!.page);
                  setState(() {
                    _errorText = null;
                  });
                },
                onPageChanged: (page) {
                  _syncProgress(page);
                },
                builders: PdfViewBuilders<DefaultBuilderOptions>(
                  options: const DefaultBuilderOptions(),
                  documentLoaderBuilder: (_) => const Center(
                    child: CupertinoActivityIndicator(),
                  ),
                  pageLoaderBuilder: (_) => const Center(
                    child: CupertinoActivityIndicator(),
                  ),
                  pageBuilder: _pageBuilder,
                ),
                scrollDirection: Axis.vertical,
                pageSnapping: true,
                physics: const BouncingScrollPhysics(),
              ),
            ),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground.resolveFrom(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CupertinoColors.systemGrey4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_triangle,
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
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                border: Border(top: BorderSide(color: CupertinoColors.systemGrey4)),
              ),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _pdfController == null ? null : () {
                      _pdfController!.previousPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.ease,
                      );
                    },
                    child: const Icon(CupertinoIcons.back),
                  ),
                  Expanded(
                    child: Center(
                      child: _pdfController == null
                          ? const Text(
                              '--/--',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : PdfPageNumber(
                              controller: _pdfController!,
                              builder: (_, __, page, pagesCount) {
                                return Text(
                                  '$page/${pagesCount ?? 0}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _pdfController == null ? null : () {
                      _pdfController!.nextPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.ease,
                      );
                    },
                    child: const Icon(CupertinoIcons.forward),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PhotoViewGalleryPageOptions _pageBuilder(
    BuildContext context,
    Future<PdfPageImage> pageImage,
    int index,
    PdfDocument document,
  ) {
    return PhotoViewGalleryPageOptions(
      imageProvider: PdfPageImageProvider(
        pageImage,
        index,
        document.id,
      ),
      minScale: PhotoViewComputedScale.contained * 1,
      maxScale: PhotoViewComputedScale.contained * 3.0,
      initialScale: PhotoViewComputedScale.contained * 1.0,
      heroAttributes: PhotoViewHeroAttributes(tag: '${document.id}-$index'),
    );
  }
}
