import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';

import '../model/book_model.dart';
import '../model/scan_candidate_model.dart';

/// BookshelfService handles local book import and simple book metadata extraction.
class BookshelfService {
  BookshelfService({List<Directory>? scanRoots}) : _scanRoots = scanRoots;

  static final List<BookModel> _books = [];
  static final ValueNotifier<List<BookModel>> booksNotifier =
      ValueNotifier<List<BookModel>>(List<BookModel>.unmodifiable(_books));
  static bool _isUpdateScheduled = false;
  final List<Directory>? _scanRoots;

  /// Returns true when the bookshelf contains at least one book.
  static bool get hasBooks => _books.isNotEmpty;

  /// Import a PDF file and return a book model for the local bookshelf.
  /// If the file path has already been imported, returns the existing book.
  Future<BookModel> importPdf(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('文件不存在', file.path);
    }

    final normalizedPath = _normalizePath(file.path);
    final existingBook = _findBookByNormalizedPath(normalizedPath);
    if (existingBook != null) {
      return existingBook;
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final rawName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : file.path.split(Platform.pathSeparator).last;
    final title = rawName.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
    final type = _detectBookType(file.path.toLowerCase());
    final normalizedTitle = title.isEmpty ? '未命名 ${type.toUpperCase()}' : title;
    final fileSizeBytes = await file.length();

    Uint8List? coverBytes;
    if (type == 'pdf') {
      coverBytes = await _generatePdfCover(file.path);
    }

    final book = BookModel(
      id: id,
      title: normalizedTitle,
      path: file.path,
      type: BookModel.normalizeBookType(path: file.path, rawType: type),
      coverBytes: coverBytes,
      progress: 0.0,
      isFavorite: false,
      fileSizeBytes: fileSizeBytes,
      tags: const [],
    );

    _books.add(book);
    _notifyBooksChanged();
    return book;
  }

  Future<List<ScanCandidateModel>> scanForSupportedBooks() async {
    final directories = _resolveScanDirectories();
    if (directories.isEmpty) {
      return const <ScanCandidateModel>[];
    }

    final candidates = <ScanCandidateModel>[];
    final seenPaths = <String>{};
    final supportedExtensions = <String>{'.pdf', '.epub', '.txt', '.mobi', '.cbz', '.cbr', '.cb7', '.cbt', '.zip'};

    for (final directory in directories) {
      if (!await directory.exists()) {
        continue;
      }

      try {
        await for (final entity in directory.list(recursive: true, followLinks: false)) {
          if (entity is! File) {
            continue;
          }

          final lowerPath = entity.path.toLowerCase();
          final extension = lowerPath.substring(lowerPath.lastIndexOf('.')).trim();
          if (!supportedExtensions.contains(extension)) {
            continue;
          }

          final candidatePath = entity.path;
          if (seenPaths.contains(candidatePath)) {
            continue; // already added this file from another directory listing
          }

          final title = entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments.last.replaceAll(RegExp(r'\.[^.]+$'), '').trim()
              : entity.path.split(Platform.pathSeparator).last.replaceAll(RegExp(r'\.[^.]+$'), '').trim();

          candidates.add(
            ScanCandidateModel(
              path: candidatePath,
              title: title.isEmpty ? '未命名文件' : title,
              type: _detectBookType(lowerPath),
              fileSizeBytes: await entity.length(),
            ),
          );

          seenPaths.add(candidatePath);
        }
      } catch (e) {
        // Ignore directories we cannot access due to sandbox or permission restrictions.
        continue;
      }
    }

    candidates.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return candidates;
  }

  Future<void> importScanCandidates(List<ScanCandidateModel> candidates) async {
    for (final candidate in candidates) {
      final file = File(candidate.path);
      if (!await file.exists()) {
        continue;
      }
      await importPdf(file);
    }
  }

  List<Directory> _resolveScanDirectories() {
    if (_scanRoots != null && _scanRoots.isNotEmpty) {
      return _scanRoots;
    }

    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final directories = <Directory>[];

    String? actualHome = home;
    if (Platform.isMacOS && actualHome != null && actualHome.contains('/Library/Containers/')) {
      final userName = Platform.environment['USER'] ?? Platform.environment['LOGNAME'];
      if (userName != null && userName.isNotEmpty) {
        actualHome = '/Users/$userName';
      }
    }

    if (actualHome != null && actualHome.isNotEmpty) {
      final commonRoots = <String>[
        '$actualHome/Downloads',
        '$actualHome/Documents',
        '$actualHome/Desktop',
      ];
      for (final root in commonRoots) {
        directories.add(Directory(root));
      }
    }

    if (Platform.isMacOS) {
      final fallbackRoots = <String>[];
      final userName = Platform.environment['USER'] ?? Platform.environment['LOGNAME'];
      if (userName != null && userName.isNotEmpty) {
        fallbackRoots.addAll(<String>[
          '/Users/$userName/Downloads',
          '/Users/$userName/Documents',
          '/Users/$userName/Desktop',
        ]);
      }
      fallbackRoots.addAll(<String>[
        '/Users/wzh/Downloads',
        '/Users/wzh/Documents',
        '/Users/wzh/Desktop',
      ]);
      for (final root in fallbackRoots) {
        directories.add(Directory(root));
      }
    }

    // Ensure unique directory paths (Directory equality is not guaranteed to dedupe by path)
    final uniqueDirs = directories.map((d) => d.path).toSet().map((p) => Directory(p)).toList();
    return uniqueDirs;
  }

  String _detectBookType(String pathLower) {
    if (pathLower.endsWith('.pdf')) return 'pdf';
    if (pathLower.endsWith('.epub')) return 'epub';
    if (pathLower.endsWith('.txt')) return 'txt';
    if (pathLower.endsWith('.mobi')) return 'mobi';
    if (pathLower.endsWith('.cbz') || pathLower.endsWith('.cbr') || pathLower.endsWith('.cb7') || pathLower.endsWith('.cbt') || pathLower.endsWith('.zip')) {
      return 'comic';
    }
    return 'file';
  }

  /// Returns whether the file has already been imported into the bookshelf.
  bool isBookAlreadyImported(File file) {
    final normalizedPath = _normalizePath(file.path);
    return _findBookByNormalizedPath(normalizedPath) != null;
  }

  BookModel? _findBookByNormalizedPath(String normalizedPath) {
    for (final book in _books) {
      if (_normalizePath(book.path) == normalizedPath) {
        return book;
      }
    }
    return null;
  }

  String _normalizePath(String path) {
    try {
      return File(path).absolute.path.toLowerCase();
    } catch (_) {
      return path.toLowerCase();
    }
  }

  /// Get all imported books.
  List<BookModel> listBooks() {
    return List<BookModel>.unmodifiable(_books);
  }

  /// Get a book by its id.
  BookModel? getBookById(String bookId) {
    for (final book in _books) {
      if (book.id == bookId) {
        return book;
      }
    }
    return null;
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
    _notifyBooksChanged();
  }

  void updateBookReadingDuration(String bookId, int additionalSeconds) {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index < 0 || additionalSeconds <= 0) {
      return;
    }

    final currentSeconds = _books[index].readingDurationSeconds;
    final updatedBook = _books[index].copyWith(
      readingDurationSeconds: currentSeconds + additionalSeconds,
    );
    _books[index] = updatedBook;
    _notifyBooksChanged();
  }

  void updateBookFavorite(String bookId, bool isFavorite) {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index < 0) {
      return;
    }

    final updatedBook = _books[index].copyWith(isFavorite: isFavorite);
    _books[index] = updatedBook;
    _notifyBooksChanged();
  }

  void updateBookReadingState(String bookId, double progress) {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index < 0) {
      return;
    }

    final nextProgress = progress.clamp(0.0, 1.0);
    final updatedBook = _books[index].copyWith(progress: nextProgress);
    _books[index] = updatedBook;
    _notifyBooksChanged();
  }

  void updateBookLastRead(String bookId, DateTime lastReadAt) {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index < 0) {
      return;
    }

    final updatedBook = _books[index].copyWith(lastReadAt: lastReadAt);
    _books[index] = updatedBook;
    _notifyBooksChanged();
  }

  void updateBookTags(String bookId, List<String> tags) {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index < 0) {
      return;
    }

    final updatedBook = _books[index].copyWith(tags: List<String>.unmodifiable(tags));
    _books[index] = updatedBook;
    _notifyBooksChanged();
  }

  /// Generate cover bytes from the first page of the imported PDF.
  Future<Uint8List?> _generatePdfCover(String filePath) async {
    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(filePath);
      // pdfrx：通过 document.pages 取页（0-based），无需 getPage/close。
      final page = document.pages[0];
      final pageImage = await page.render(
        width: (page.width * 2).round(),
        height: (page.height * 2).round(),
        backgroundColor: Colors.white,
      );
      Uint8List? bytes;
      if (pageImage != null) {
        // pdfrx 的 PdfImage 不含原始字节字段，需经 createImage → ui.Image → PNG 字节。
        final uiImage = await pageImage.createImage();
        final data = await uiImage.toByteData(format: ui.ImageByteFormat.png);
        bytes = data?.buffer.asUint8List();
        uiImage.dispose();
        pageImage.dispose();
      }
      await document.dispose();
      return bytes;
    } catch (e) {
      if (document != null) {
        try {
          await document.dispose();
        } catch (_) {}
      }
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
    _notifyBooksChanged();
  }

  void _notifyBooksChanged() {
    if (_isUpdateScheduled) {
      return;
    }
    _isUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      booksNotifier.value = List<BookModel>.unmodifiable(_books);
      _isUpdateScheduled = false;
    });
  }
}
