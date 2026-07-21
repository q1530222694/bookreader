import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../../engine/settings_engine.dart';
import '../../shell/model/book_model.dart';
import '../../shell/service/bookshelf_service.dart';
import '../../shell/service/cover_store.dart';
import '../../shell/service/reader_data_service.dart';
import '../../shell/service/reading_session_service.dart';
import '../model/reading_backup_model.dart';

/// 阅读数据备份服务：聚合导出（选目录写 JSON）与导入（选文件恢复）。
///
/// 不依赖任何新第三方包——目录/文件选择复用既有 [file_picker]（全平台通用），
/// 落盘用 [File]/[dart:io]。导出为「合并恢复」语义：导入不会清空现有数据。
class BackupService {
  /// 构建当前全部阅读数据为 [ReadingBackup]（不落盘，供预览/同步复用）。
  static Future<ReadingBackup> buildBackup() async {
    final books = BookshelfService().listBooks();
    final sessions = ReadingSessionService.sessionsNotifier.value;
    final notes = <String, List<NoteItem>>{};
    final bookmarks = <String, List<BookmarkItem>>{};
    for (final book in books) {
      notes[book.id] = await ReaderDataStore.loadNotes(book.id);
      bookmarks[book.id] = await ReaderDataStore.loadBookmarks(book.id);
    }
    final settings = SettingsEngine.exportSettings();
    return ReadingBackup(
      books: books,
      sessions: sessions,
      notes: notes,
      bookmarks: bookmarks,
      settings: settings,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 序列化为 JSON 字节（供文件写出或云盘同步上传）。
  static Uint8List encode(ReadingBackup backup) =>
      utf8.encode(jsonEncode(backup.toJson()));

  /// 导出到用户选择的目录（[file_picker] 选目录，全平台通用）。
  /// 返回写出文件的路径；用户取消返回 null。
  static Future<String?> exportToFile() async {
    final backup = await buildBackup();
    final bytes = encode(backup);
    final dir = await FilePicker.getDirectoryPath();
    if (dir == null) return null;
    final fileName = 'reading_backup_${_timestamp()}.json';
    final file = File('$dir${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// 从用户选择的备份文件导入（合并到现有数据）。
  /// 用户取消选择抛出 [BackupUserCancelException]，由调用方静默忽略。
  static Future<ReadingBackup> importFromFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) throw BackupUserCancelException();
    final content = await File(path).readAsString();
    // 大备份文件（上千本书）的 JSON 解析是 CPU 密集操作，放到独立 isolate 执行，
    // 避免阻塞导入对话框与主线程。合并恢复涉及 ReaderDataStore 文件 IO，需在主线程
    // 调用（隔离内不便访问应用服务），故仅离线解析、对象构造仍回主线程。
    final map = await compute(_parseBackupJson, content);
    final backup = ReadingBackup.fromJson(map);
    await _applyBackup(backup);
    return backup;
  }

  /// 将备份合并恢复进当前 App（书籍/会话/笔记/书签/设置）。
  static Future<void> _applyBackup(ReadingBackup backup) async {
    BookshelfService().importBooks(backup.books);
    await ReadingSessionService.importSessions(backup.sessions);
    for (final entry in backup.notes.entries) {
      final merged = await _mergeNotes(entry.key, entry.value);
      await ReaderDataStore.saveNotes(entry.key, merged);
    }
    for (final entry in backup.bookmarks.entries) {
      await ReaderDataStore.saveBookmarks(entry.key, entry.value);
    }
    if (backup.settings.isNotEmpty) {
      SettingsEngine.importSettings(backup.settings);
    }
    // 按需回填封面：导入的书若标记有封面、但本地缺封面文件（如跨设备导入），
    // 后台重新生成封面，使书架即时显示导入书的封面（不阻塞导入返回）。
    _warmImportedCovers(backup.books);
  }

  /// 导入后按需回填封面：对标记有封面、本地却缺封面文件的书，后台重新生成封面。
  static void _warmImportedCovers(List<BookModel> books) {
    for (final book in books) {
      if (!book.hasCover || book.path.isEmpty) continue;
      _warmOneCover(book);
    }
  }

  /// 单本书封面回填：本地无封面文件时调用封面预热（失败忽略，不影响导入结果）。
  static Future<void> _warmOneCover(BookModel book) async {
    try {
      if (await CoverStore.exists(book.id)) return;
      // 复用书架服务的封面工作者池（见 [BookshelfService.warmUpCover]）。
      BookshelfService().warmUpCover(book, book.path);
    } catch (_) {
      // 封面重新生成失败不影响导入结果。
    }
  }

  /// 笔记按 id 去重合并（导入覆盖同 id 现有笔记），其余追加。
  static Future<List<NoteItem>> _mergeNotes(
    String bookId,
    List<NoteItem> incoming,
  ) async {
    final existing = await ReaderDataStore.loadNotes(bookId);
    final byId = <String, NoteItem>{};
    for (final n in existing) byId[n.id] = n;
    for (final n in incoming) byId[n.id] = n;
    final merged = byId.values.toList();
    merged.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
    return merged;
  }

  static String _timestamp() {
    final d = DateTime.now();
    final pad = (int n) => n.toString().padLeft(2, '0');
    return '${d.year}${pad(d.month)}${pad(d.day)}_'
        '${pad(d.hour)}${pad(d.minute)}${pad(d.second)}';
  }
}

/// 用户取消文件选择时抛出，调用方应静默忽略（不弹错误）。
class BackupUserCancelException implements Exception {
  @override
  String toString() => '用户取消了导入';
}

/// 在独立 isolate 解析备份 JSON 文本（避免大文件阻塞主线程）。
/// [compute] 仅接受顶层函数，故置于文件顶层。
Map<String, dynamic> _parseBackupJson(String content) =>
    jsonDecode(content) as Map<String, dynamic>;
