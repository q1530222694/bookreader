import 'dart:io';

import '../model/book_model.dart';

/// BookshelfService handles local book import and simple book metadata extraction.
class BookshelfService {
  final List<BookModel> _books = [];

  /// Import a PDF file and return a book model for the local bookshelf.
  Future<BookModel> importPdf(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('文件不存在', file.path);
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final title = file.uri.pathSegments.last;

    final book = BookModel(id: id, title: title, path: file.path, type: 'pdf');

    _books.add(book);
    return book;
  }

  /// Get all imported books.
  List<BookModel> listBooks() {
    return List<BookModel>.unmodifiable(_books);
  }
}
