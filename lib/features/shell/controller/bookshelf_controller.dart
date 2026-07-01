import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

import '../model/book_model.dart';
import '../service/bookshelf_service.dart';

/// BookshelfController manages imported books and coordinates file import logic.
class BookshelfController {
  final BookshelfService _service = BookshelfService();

  final ValueNotifier<List<BookModel>> books = ValueNotifier<List<BookModel>>([]);
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

      final book = await _service.importPdf(File(filePath));
      books.value = List<BookModel>.from(books.value)..add(book);
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

      final imported = <BookModel>[];
      for (final file in result.files) {
        final filePath = file.path;
        if (filePath == null) continue;
        final book = await _service.importPdf(File(filePath));
        imported.add(book);
      }
      books.value = List<BookModel>.from(books.value)..addAll(imported);
    } catch (e) {
      errorText.value = '批量导入失败：$e';
    } finally {
      isLoading.value = false;
    }
  }

  void dispose() {
    books.dispose();
    isLoading.dispose();
    errorText.dispose();
  }
}
