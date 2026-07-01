import 'dart:io';
import 'dart:typed_data';

import '../model/book_model.dart';

/// BookshelfService handles local book import and simple book metadata extraction.
class BookshelfService {
  final List<BookModel> _books = [];

  /// Import a PDF file and return a book model for the local bookshelf.
  Future<BookModel> importPdf(File file) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final title = file.uri.pathSegments.last;
    final coverBytes = await _generateDummyCover(title);

    final book = BookModel(
      id: id,
      title: title,
      path: file.path,
      type: 'pdf',
      coverBytes: coverBytes,
    );

    _books.add(book);
    return book;
  }

  /// Get all imported books.
  List<BookModel> listBooks() {
    return List<BookModel>.unmodifiable(_books);
  }

  Future<Uint8List> _generateDummyCover(String title) async {
    return Uint8List.fromList(title.codeUnits);
  }
}
