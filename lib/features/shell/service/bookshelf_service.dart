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
    final rawName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : file.path.split(Platform.pathSeparator).last;
    final title = rawName.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
    final normalizedTitle = title.isEmpty ? '未命名 PDF' : title;
    final fileSizeBytes = await file.length();

    final coverBytes = await _generatePdfCover(file.path);

    final book = BookModel(
      id: id,
      title: normalizedTitle,
      path: file.path,
      type: 'pdf',
      coverBytes: coverBytes,
      progress: 0.0,
      isFavorite: false,
      fileSizeBytes: fileSizeBytes,
    );

    _books.add(book);
    booksNotifier.value = List<BookModel>.unmodifiable(_books);
    return book;
  }

  /// Get all imported books.
  List<BookModel> listBooks() {
    return List<BookModel>.unmodifiable(_books);
  }

  /// Update the reading progress of a book by its id.
  void updateBookProgress(String bookId, double progress) {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index < 0) {
      return;
    }

    final nextProgress = progress.clamp(0.0, 1.0);
    final updatedBook = _books[index].copyWith(progress: nextProgress);
    _books[index] = updatedBook;
    booksNotifier.value = List<BookModel>.unmodifiable(_books);
  }

  void updateBookLastRead(String bookId, DateTime lastReadAt) {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index < 0) {
      return;
    }

    final updatedBook = _books[index].copyWith(lastReadAt: lastReadAt);
    _books[index] = updatedBook;
    booksNotifier.value = List<BookModel>.unmodifiable(_books);
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
