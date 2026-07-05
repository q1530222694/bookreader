import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';

import '../model/book_model.dart';

/// BookshelfService handles local book import and simple book metadata extraction.
class BookshelfService {
  static final List<BookModel> _books = [];
  static final ValueNotifier<List<BookModel>> booksNotifier =
      ValueNotifier<List<BookModel>>(List<BookModel>.unmodifiable(_books));

  /// Returns true when the bookshelf contains at least one book.
  static bool get hasBooks => _books.isNotEmpty;

  /// Import a PDF file and return a book model for the local bookshelf.
  Future<BookModel> importPdf(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('文件不存在', file.path);
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final rawTitle = file.uri.pathSegments.last;
    final title = rawTitle.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
    final normalizedTitle = title.isEmpty ? '未命名 PDF' : title;

    final coverBytes = await _generatePdfCover(file.path);

    final book = BookModel(
      id: id,
      title: normalizedTitle,
      path: file.path,
      type: 'pdf',
      coverBytes: coverBytes,
      progress: 0.0,
    );

    _books.add(book);
    booksNotifier.value = List<BookModel>.unmodifiable(_books);
    return book;
  }

  /// Get all imported books.
  List<BookModel> listBooks() {
    return List<BookModel>.unmodifiable(_books);
  }

  /// Generate cover bytes from the first page of the imported PDF.
  Future<Uint8List?> _generatePdfCover(String filePath) async {
    try {
      final document = await PdfDocument.openFile(filePath);
      final page = await document.getPage(1);
      final pageImage = await page.render(
        width: page.width.toInt() * 2,
        height: page.height.toInt() * 2,
        format: PdfPageImageFormat.png,
      );
      await page.close();
      await document.close();
      return pageImage?.bytes;
    } catch (e) {
      return null;
    }
  }

  BookModel? pickRandomBook() {
    if (_books.isEmpty) {
      return null;
    }

    final randomIndex = Random().nextInt(_books.length);
    return _books[randomIndex];
  }

  void removeBook(String bookId) {
    _books.removeWhere((book) => book.id == bookId);
    booksNotifier.value = List<BookModel>.unmodifiable(_books);
  }
}
