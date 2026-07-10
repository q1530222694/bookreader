import 'dart:io';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:file_picker/file_picker.dart';

import '../model/book_model.dart';
import '../service/bookshelf_service.dart';

/// BookshelfController manages imported books and coordinates file import logic.
class BookshelfController {
  final BookshelfService _service = BookshelfService();

  final ValueNotifier<List<BookModel>> books = BookshelfService.booksNotifier;
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> errorText = ValueNotifier<String?>(null);

  Future<void> importPdf() async {
    isLoading.value = true;
    errorText.value = null;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'txt', 'mobi', 'cbz', 'cbr', 'cb7', 'cbt'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        errorText.value = '未获取到文件路径';
        return;
      }

      await _service.importPdf(File(filePath));
      books.value = _service.listBooks();
    } catch (e) {
      errorText.value = '导入书籍失败：$e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> importMultiplePdfs() async {
    isLoading.value = true;
    errorText.value = null;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'txt', 'mobi', 'cbz', 'cbr', 'cb7', 'cbt'],
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      for (final file in result.files) {
        final filePath = file.path;
        if (filePath == null) continue;
        await _service.importPdf(File(filePath));
      }
      books.value = _service.listBooks();
    } catch (e) {
      errorText.value = '批量导入失败：$e';
    } finally {
      isLoading.value = false;
    }
  }

  BookModel? pickRandomBook() {
    final availableBooks = books.value;
    if (availableBooks.isEmpty) {
      return null;
    }
    final randomIndex = Random().nextInt(availableBooks.length);
    return availableBooks[randomIndex];
  }

  void setError(String? message) {
    errorText.value = message;
  }

  void _refreshBooksAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      books.value = _service.listBooks();
    });
  }

  void updateBookProgress(String bookId, double progress) {
    _service.updateBookProgress(bookId, progress);
    _refreshBooksAfterFrame();
  }

  void updateBookReadingDuration(String bookId, int additionalSeconds) {
    _service.updateBookReadingDuration(bookId, additionalSeconds);
    books.value = _service.listBooks();
  }

  void updateBookLastRead(String bookId, DateTime lastReadAt) {
    _service.updateBookLastRead(bookId, lastReadAt);
    books.value = _service.listBooks();
  }

  void removeBook(String bookId) {
    _service.removeBook(bookId);
    books.value = _service.listBooks();
  }

  void dispose() {
    isLoading.dispose();
    errorText.dispose();
  }
}
