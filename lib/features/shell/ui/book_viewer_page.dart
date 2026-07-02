import 'package:flutter/cupertino.dart';
import 'package:pdfx/pdfx.dart';

/// BookViewerPage displays the first page of a PDF book.
class BookViewerPage extends StatefulWidget {
  final String title;
  final String filePath;

  const BookViewerPage({
    super.key,
    required this.title,
    required this.filePath,
  });

  @override
  State<BookViewerPage> createState() => _BookViewerPageState();
}

class _BookViewerPageState extends State<BookViewerPage> {
  String? _errorText;
  late final PdfController _pdfController;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfController(
      document: PdfDocument.openFile(widget.filePath),
    );
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  void _handleError(Object error) {
    if (!mounted) return;
    setState(() {
      _errorText = '打开 PDF 失败：$error';
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(widget.title)),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PdfView(
                controller: _pdfController,
                onDocumentError: (error) => _handleError(error),
                onDocumentLoaded: (_) {
                  if (!mounted) return;
                  setState(() {
                    _errorText = null;
                  });
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
                    onPressed: () {
                      _pdfController.previousPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.ease,
                      );
                    },
                    child: const Icon(CupertinoIcons.back),
                  ),
                  Expanded(
                    child: Center(
                      child: PdfPageNumber(
                        controller: _pdfController,
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
                    onPressed: () {
                      _pdfController.nextPage(
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
