import '../../shell/model/book_model.dart';
import '../../shell/service/reader_data_service.dart' show BookmarkItem, NoteItem;
import '../../shell/service/reading_session_service.dart' show ReadingSession;

/// 阅读数据备份聚合：导出/导入的单一载体。
///
/// 涵盖「用户自有阅读数据」的全部维度：书籍元数据、阅读会话、按书聚合的笔记与书签、
/// 以及白名单内的用户偏好。封面字节不入库（仅 [BookModel.hasCover] 标记），
/// 同步/备份保持轻量。
class ReadingBackup {
  final String schemaVersion;
  final int createdAtMs;
  final List<BookModel> books;
  final List<ReadingSession> sessions;
  final Map<String, List<NoteItem>> notes; // bookId -> 笔记列表
  final Map<String, List<BookmarkItem>> bookmarks; // bookId -> 书签列表
  final Map<String, dynamic> settings; // 用户偏好（白名单）

  const ReadingBackup({
    required this.books,
    required this.sessions,
    required this.notes,
    required this.bookmarks,
    required this.settings,
    required this.createdAtMs,
    this.schemaVersion = '1',
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'createdAtMs': createdAtMs,
        'books': books.map((b) => b.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'notes': notes.map(
          (k, v) => MapEntry(k, v.map((n) => n.toJson()).toList()),
        ),
        'bookmarks': bookmarks.map(
          (k, v) => MapEntry(k, v.map((b) => b.toJson()).toList()),
        ),
        'settings': settings,
      };

  factory ReadingBackup.fromJson(Map<String, dynamic> json) {
    List<BookModel> booksFrom(List<dynamic>? raw) => (raw ?? [])
        .map((e) => BookModel.fromJson(e as Map<String, dynamic>))
        .toList();

    List<ReadingSession> sessionsFrom(List<dynamic>? raw) => (raw ?? [])
        .map((e) => ReadingSession.fromJson(e as Map<String, dynamic>))
        .toList();

    Map<String, List<NoteItem>> notesFrom(Map<String, dynamic>? raw) {
      final map = <String, List<NoteItem>>{};
      raw?.forEach((k, v) {
        map[k] = (v as List)
            .map((e) => NoteItem.fromJson(e as Map<String, dynamic>))
            .toList();
      });
      return map;
    }

    Map<String, List<BookmarkItem>> bookmarksFrom(Map<String, dynamic>? raw) {
      final map = <String, List<BookmarkItem>>{};
      raw?.forEach((k, v) {
        map[k] = (v as List)
            .map((e) => BookmarkItem.fromJson(e as Map<String, dynamic>))
            .toList();
      });
      return map;
    }

    return ReadingBackup(
      schemaVersion: json['schemaVersion'] as String? ?? '1',
      createdAtMs: json['createdAtMs'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
      books: booksFrom(json['books'] as List?),
      sessions: sessionsFrom(json['sessions'] as List?),
      notes: notesFrom(json['notes'] as Map<String, dynamic>?),
      bookmarks: bookmarksFrom(json['bookmarks'] as Map<String, dynamic>?),
      settings: (json['settings'] as Map<String, dynamic>?) ??
          <String, dynamic>{},
    );
  }
}
