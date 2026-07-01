import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:pdf_render/pdf_render.dart';

/// BookViewerPage displays the first page of a PDF book.
class BookViewerPage extends StatefulWidget {
  final String title;
  final String filePath;

  const BookViewerPage({super.key, required this.title, required this.filePath});

  @override
  State<BookViewerPage> createState() => _BookViewerPageState();
}

class _BookViewerPageState extends State<BookViewerPage> {
  late final Future<ui.Image> _pageFuture;

  @override
  void initState() {
    super.initState();
    _pageFuture = _renderFirstPage();
  }

  Future<ui.Image> _renderFirstPage() async {
    try {
      final document = await PdfDocument.openFile(widget.filePath);
      final page = await document.getPage(1);
      final maxRenderDimension = 1000;
      final pageWidth = page.width.toInt();
      final pageHeight = page.height.toInt();
      final safePageWidth = pageWidth > 0 ? pageWidth : 800;
      final safePageHeight = pageHeight > 0 ? pageHeight : 1200;
      final scale = min(maxRenderDimension / safePageWidth, maxRenderDimension / safePageHeight);
      final renderWidth = max(1, (safePageWidth * scale).round());
      final renderHeight = max(1, (safePageHeight * scale).round());
      final pageImage = await page.render(
        width: renderWidth,
        height: renderHeight,
      );
      final ui.Image image = await pageImage.createImageIfNotAvailable();
      pageImage.dispose();
      await document.dispose();
      return image;
    } catch (e, stack) {
      throw Exception('打开 PDF 失败：$e\n$stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.title),
      ),
      child: SafeArea(
        child: FutureBuilder<ui.Image>(
          future: _pageFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CupertinoActivityIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_triangle, size: 48, color: CupertinoColors.systemRed),
                      const SizedBox(height: 16),
                      const Text('无法打开 PDF 文件', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(
                        snapshot.error?.toString() ?? '未知错误',
                        style: const TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            return InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: RawImage(
                  image: snapshot.data,
                  fit: BoxFit.contain,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
