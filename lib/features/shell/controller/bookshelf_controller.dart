import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:file_picker/file_picker.dart';

import '../../../engine/localization_engine.dart';
import '../model/book_model.dart';
import '../model/scan_candidate_model.dart';
import '../service/bookshelf_service.dart';

/// BookshelfController manages imported books and coordinates file import logic.
class BookshelfController {
  final BookshelfService _service = BookshelfService();

  final ValueNotifier<List<BookModel>> books = BookshelfService.booksNotifier;
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> errorText = ValueNotifier<String?>(null);
  final ValueNotifier<String?> toastMessage = ValueNotifier<String?>(null);
  Timer? _toastTimer;

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

      final file = File(filePath);
      if (_service.isBookAlreadyImported(file)) {
        _showToast(LocalizationEngine.text('bookshelf_import_duplicate'));
        return;
      }

      await _service.importPdf(file);
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

      var duplicateSkipped = false;
      for (final file in result.files) {
        final filePath = file.path;
        if (filePath == null) continue;
        final importFile = File(filePath);
        if (_service.isBookAlreadyImported(importFile)) {
          duplicateSkipped = true;
          continue;
        }
        await _service.importPdf(importFile);
      }
      if (duplicateSkipped) {
        _showToast(LocalizationEngine.text('bookshelf_import_duplicate_skipped'));
      }
    } catch (e) {
      errorText.value = '批量导入失败：$e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<ScanCandidateModel>> scanForSupportedBooks() async {
    return _service.scanForSupportedBooks();
  }

  Future<void> importScanCandidates(List<ScanCandidateModel> candidates) async {
    isLoading.value = true;
    errorText.value = null;

    try {
      var duplicateSkipped = false;
      for (final candidate in candidates) {
        final file = File(candidate.path);
        if (!await file.exists()) {
          continue;
        }
        if (_service.isBookAlreadyImported(file)) {
          duplicateSkipped = true;
          continue;
        }
        await _service.importPdf(file);
      }
      if (duplicateSkipped) {
        _showToast(LocalizationEngine.text('bookshelf_import_duplicate_skipped'));
      }
    } catch (e) {
      errorText.value = '扫描导入失败：$e';
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

  void _showToast(String message) {
    toastMessage.value = message;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      toastMessage.value = null;
    });
  }

  void updateBookProgress(String bookId, double progress) {
    _service.updateBookProgress(bookId, progress);
  }

  void updateBookReadingDuration(String bookId, int additionalSeconds) {
    _service.updateBookReadingDuration(bookId, additionalSeconds);
  }

  void updateBookFavorite(String bookId, bool isFavorite) {
    _service.updateBookFavorite(bookId, isFavorite);
  }

  void updateBookReadingState(String bookId, double progress) {
    _service.updateBookReadingState(bookId, progress);
  }

  void updateBookLastRead(String bookId, DateTime lastReadAt) {
    _service.updateBookLastRead(bookId, lastReadAt);
  }

  void removeBook(String bookId) {
    _service.removeBook(bookId);
  }

  void dispose() {
    isLoading.dispose();
    errorText.dispose();
    toastMessage.dispose();
    _toastTimer?.cancel();
  }
}
