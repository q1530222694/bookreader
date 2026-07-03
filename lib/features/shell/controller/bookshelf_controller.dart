import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

import '../model/book_model.dart';
import '../service/bookshelf_service.dart';

/// BookshelfController manages imported books and coordinates file import logic.
class BookshelfController {
  final BookshelfService _service = BookshelfService();

  final ValueNotifier<List<BookModel>> books = ValueNotifier<List<BookModel>>(
    [],
  );
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> errorText = ValueNotifier<String?>(null);

  Future<void> importPdf() async {
    isLoading.value = true;
    errorText.value = null;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
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
      errorText.value = '导入 PDF 失败：$e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> importMultiplePdfs() async {
    isLoading.value = true;
    errorText.value = null;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
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

  void removeBook(String bookId) {
    _service.removeBook(bookId);
    books.value = _service.listBooks();
  }

  void dispose() {
    books.dispose();
    isLoading.dispose();
    errorText.dispose();
  }
}
