import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:pdf_render/pdf_render_widgets.dart';

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

  Future<PdfDocument> _openDocument() =>
      PdfDocument.openFile(widget.filePath).timeout(const Duration(seconds: 8));

  void _handleError(dynamic error) {
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
        child: Stack(
          children: [
            PdfViewer(
              doc: _openDocument(),
              onError: _handleError,
              params: PdfViewerParams(
                padding: 12,
                minScale: 0.5,
                maxScale: 4,
                pageDecoration: BoxDecoration(
                  color: CupertinoColors.white,
                  border: Border.all(color: CupertinoColors.systemGrey4),
                ),
                buildPagePlaceholder: (context, pageNumber, pageRect) {
                  return Container(
                    color: CupertinoColors.systemGrey6,
                    alignment: Alignment.center,
                    child: const CupertinoActivityIndicator(),
                  );
                },
              ),
            ),
            if (_errorText != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground.resolveFrom(
                        context,
                      ),
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
              ),
          ],
        ),
      ),
    );
  }
}
