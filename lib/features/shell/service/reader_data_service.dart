import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 单条笔记：与「某本书的某一页」绑定。
class NoteItem {
  final String id;
  final int pageNumber; // 1-based
  final String content;
  final int createdAt; // 毫秒时间戳
  final int updatedAt;

  NoteItem({
    required this.id,
    required this.pageNumber,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 列表/卡片摘要：取内容首行，最多 40 字。
  String get summary {
    final firstLine = content.split('\n').first.trim();
    return firstLine.isEmpty ? '(空笔记)' : firstLine;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pageNumber': pageNumber,
        'content': content,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory NoteItem.fromJson(Map<String, dynamic> json) => NoteItem(
        id: json['id'] as String,
        pageNumber: json['pageNumber'] as int,
        content: json['content'] as String,
        createdAt: json['createdAt'] as int,
        updatedAt: json['updatedAt'] as int,
      );

  NoteItem copyWith({String? content, int? pageNumber, int? updatedAt}) => NoteItem(
        id: id,
        pageNumber: pageNumber ?? this.pageNumber,
        content: content ?? this.content,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// 单条书签：仅页码 + 可选备注。
class BookmarkItem {
  final int pageNumber; // 1-based
  final String label;
  final int createdAt;

  BookmarkItem({
    required this.pageNumber,
    required this.label,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'pageNumber': pageNumber,
        'label': label,
        'createdAt': createdAt,
      };

  factory BookmarkItem.fromJson(Map<String, dynamic> json) => BookmarkItem(
        pageNumber: json['pageNumber'] as int,
        label: json['label'] as String? ?? '',
        createdAt: json['createdAt'] as int? ?? 0,
      );
}

/// 阅读数据持久化（笔记 + 书签），按 bookId 分文件存于应用文档目录。
///
/// - 笔记：`<appDocs>/book_notes/<safeId>.json`
/// - 书签：`<appDocs>/book_bookmarks/<safeId>.json`
/// 内容为 JSON 数组，随读写落盘。使用静态方法，调用方自行管理 UI 状态。
class ReaderDataStore {
  static String _safeId(String bookId) {
    final cleaned = bookId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return cleaned.isEmpty ? 'unknown' : cleaned;
  }

  static Future<File> _file(String sub, String bookId) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/$sub');
    await folder.create(recursive: true);
    return File('${folder.path}/${_safeId(bookId)}.json');
  }

  // ───────── 笔记 ─────────

  static Future<List<NoteItem>> loadNotes(String bookId) async {
    try {
      final file = await _file('book_notes', bookId);
      if (!await file.exists()) return <NoteItem>[];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return <NoteItem>[];
      final list = (jsonDecode(content) as List<dynamic>)
          .map((e) => NoteItem.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
      return list;
    } catch (e) {
      debugPrint('ReaderDataStore 加载笔记失败: $e');
      return <NoteItem>[];
    }
  }

  static Future<void> saveNotes(String bookId, List<NoteItem> notes) async {
    try {
      final file = await _file('book_notes', bookId);
      final sorted = [...notes]
        ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
      await file.writeAsString(jsonEncode(sorted.map((n) => n.toJson()).toList()));
    } catch (e) {
      debugPrint('ReaderDataStore 保存笔记失败: $e');
    }
  }

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${(Random().nextDouble() * 1e6).round()}';

  /// 新增一条笔记（预填页码），返回新列表。
  static Future<List<NoteItem>> addNote(
    String bookId, {
    required int pageNumber,
    required String content,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final note = NoteItem(
      id: _newId(),
      pageNumber: pageNumber,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    final list = await loadNotes(bookId);
    list.add(note);
    await saveNotes(bookId, list);
    return list;
  }

  /// 删除一条笔记，返回新列表。
  static Future<List<NoteItem>> deleteNote(String bookId, String id) async {
    final list = await loadNotes(bookId);
    list.removeWhere((n) => n.id == id);
    await saveNotes(bookId, list);
    return list;
  }

  // ───────── 书签 ─────────

  static Future<List<BookmarkItem>> loadBookmarks(String bookId) async {
    try {
      final file = await _file('book_bookmarks', bookId);
      if (!await file.exists()) return <BookmarkItem>[];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return <BookmarkItem>[];
      final list = (jsonDecode(content) as List<dynamic>)
          .map((e) => BookmarkItem.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
      return list;
    } catch (e) {
      debugPrint('ReaderDataStore 加载书签失败: $e');
      return <BookmarkItem>[];
    }
  }

  static Future<void> saveBookmarks(
    String bookId,
    List<BookmarkItem> bookmarks,
  ) async {
    try {
      final file = await _file('book_bookmarks', bookId);
      final sorted = [...bookmarks]
        ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
      await file.writeAsString(
        jsonEncode(sorted.map((b) => b.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('ReaderDataStore 保存书签失败: $e');
    }
  }

  /// 在指定页添加书签（同页去重），返回新列表。
  static Future<List<BookmarkItem>> addBookmark(
    String bookId, {
    required int pageNumber,
    String label = '',
  }) async {
    final list = await loadBookmarks(bookId);
    if (list.any((b) => b.pageNumber == pageNumber)) return list;
    list.add(BookmarkItem(
      pageNumber: pageNumber,
      label: label,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await saveBookmarks(bookId, list);
    return list;
  }

  /// 删除指定页书签，返回新列表。
  static Future<List<BookmarkItem>> deleteBookmark(
    String bookId,
    int pageNumber,
  ) async {
    final list = await loadBookmarks(bookId);
    list.removeWhere((b) => b.pageNumber == pageNumber);
    await saveBookmarks(bookId, list);
    return list;
  }

  /// 修改指定页书签的自定义名称（label），返回新列表。
  ///
  /// 书签支持用户自定义备注名，便于快速识别；[label] 为空时回退为默认占位。
  static Future<List<BookmarkItem>> updateBookmarkLabel(
    String bookId,
    int pageNumber,
    String label,
  ) async {
    final list = await loadBookmarks(bookId);
    final idx = list.indexWhere((b) => b.pageNumber == pageNumber);
    if (idx < 0) return list;
    list[idx] = BookmarkItem(
      pageNumber: list[idx].pageNumber,
      label: label.trim(),
      createdAt: list[idx].createdAt,
    );
    await saveBookmarks(bookId, list);
    return list;
  }

  /// 跨书汇总：读取所有书籍的书签（按添加时间倒序），每条携带 bookId 与书名。
  ///
  /// [bookTitleResolver] 用于把 bookId 解析为书名；无法解析时回退为『未知书籍』。
  /// 用于「回忆页 - 书签」卡片与「查看全部书签」页。
  static Future<List<BookmarkWithBook>> loadAllBookmarks(
    List<String> bookIds,
    String Function(String bookId) bookTitleResolver,
  ) async {
    final result = <BookmarkWithBook>[];
    for (final id in bookIds) {
      final list = await loadBookmarks(id);
      for (final b in list) {
        result.add(BookmarkWithBook(
          bookId: id,
          title: bookTitleResolver(id),
          bookmark: b,
        ));
      }
    }
    result.sort((a, b) => b.bookmark.createdAt.compareTo(a.bookmark.createdAt));
    return result;
  }
}

/// 跨书书签：组合书签与其所属书籍信息（bookId / 书名）。
class BookmarkWithBook {
  final String bookId;
  final String title;
  final BookmarkItem bookmark;

  const BookmarkWithBook({
    required this.bookId,
    required this.title,
    required this.bookmark,
  });
}
