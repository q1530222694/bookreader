import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../engine/localization_engine.dart';
import '../controller/bookshelf_controller.dart';
import '../model/book_model.dart';
import '../service/reader_data_service.dart';
import 'book_viewer_page.dart';
import 'comic_viewer_page.dart';
import 'epub_viewer_page.dart';
import 'txt_viewer_page.dart';

/// 全部书签页：汇总所有书籍的书签（按添加时间倒序），点击可直达对应书籍的对应页。
class AllBookmarksPage extends StatefulWidget {
  const AllBookmarksPage({super.key});

  @override
  State<AllBookmarksPage> createState() => _AllBookmarksPageState();
}

class _AllBookmarksPageState extends State<AllBookmarksPage> {
  final BookshelfController _controller = BookshelfController();
  List<BookmarkWithBook> _bookmarks = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 读取所有书籍的书签：书名通过 controller 中的书籍列表解析（找不到则回退未知书籍）。
  Future<void> _load() async {
    final books = _controller.books.value;
    final titleMap = <String, String>{
      for (final b in books) b.id: b.title,
    };
    final list = await ReaderDataStore.loadAllBookmarks(
      books.map((b) => b.id).toList(),
      (id) => titleMap[id] ?? LocalizationEngine.text('unknown_book'),
    );
    if (!mounted) return;
    setState(() {
      _bookmarks = list;
      _loading = false;
    });
  }

  /// 根据书籍格式跳转到对应阅读器，并定位到书签所在页。
  void _openBook(BookModel? book, int page) {
    if (book == null) {
      _showMissingDialog();
      return;
    }
    final path = book.path.toLowerCase();
    if (path.endsWith('.pdf')) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => BookViewerPage(
            title: book.title,
            filePath: book.path,
            bookId: book.id,
            controller: _controller,
            initialPage: page,
          ),
        ),
      );
      return;
    }
    if (path.endsWith('.epub')) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => EpubViewerPage(
            title: book.title,
            filePath: book.path,
            bookId: book.id,
            controller: _controller,
          ),
        ),
      );
      return;
    }
    if (path.endsWith('.txt')) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => TxtViewerPage(
            title: book.title,
            filePath: book.path,
            bookId: book.id,
            controller: _controller,
          ),
        ),
      );
      return;
    }
    if (path.endsWith('.cbz') ||
        path.endsWith('.cbr') ||
        path.endsWith('.cb7') ||
        path.endsWith('.cbt') ||
        path.endsWith('.zip')) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => ComicViewerPage(
            title: book.title,
            filePath: book.path,
            bookId: book.id,
            controller: _controller,
          ),
        ),
      );
      return;
    }
    _showMissingDialog();
  }

  void _showMissingDialog() {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(LocalizationEngine.text('unknown_book')),
        content: Text(LocalizationEngine.text('conv_open_failed')),
        actions: [
          CupertinoDialogAction(
            child: Text(LocalizationEngine.text('confirm')),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// 将毫秒时间戳格式化为『YYYY-MM-DD HH:mm』（本地时区）。
  String _formatTime(int millis) {
    final t = DateTime.fromMillisecondsSinceEpoch(millis);
    final p = (int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${p(t.month)}-${p(t.day)} ${p(t.hour)}:${p(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final primary = theme.primaryColor;
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final bg = CupertinoColors.secondarySystemBackground.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(LocalizationEngine.text('reader_bookmarks_all')),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _bookmarks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        LocalizationEngine.text('reader_bookmarks_empty'),
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryColor,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                    itemCount: _bookmarks.length,
                    separatorBuilder: (_, __) => Container(height: 1, color: CupertinoColors.systemGrey4.resolveFrom(context)),
                    itemBuilder: (context, i) {
                      final item = _bookmarks[i];
                      final b = item.bookmark;
                      final name = b.label.isNotEmpty
                          ? b.label
                          : '${LocalizationEngine.text('reader_nav_progress')} ${b.pageNumber}';
                      final timeStr = b.createdAt > 0 ? _formatTime(b.createdAt) : '';
                      return GestureDetector(
                        onTap: () => _openBook(
                          _controller.getBook(item.bookId),
                          b.pageNumber,
                        ),
                        child: Container(
                          color: bg,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.bookmark, size: 18, color: primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        color: labelColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${LocalizationEngine.text('reader_bookmark_add_time')} $timeStr',
                                      style: TextStyle(
                                        color: secondaryColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        color: secondaryColor,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                CupertinoIcons.chevron_right,
                                size: 16,
                                color: secondaryColor,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
