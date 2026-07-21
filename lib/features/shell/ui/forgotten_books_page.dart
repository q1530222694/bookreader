import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../engine/localization_engine.dart';
import '../controller/bookshelf_controller.dart';
import '../model/book_model.dart';
import 'book_viewer_page.dart';
import 'comic_viewer_page.dart';
import 'epub_viewer_page.dart';
import 'txt_viewer_page.dart';
import 'widgets/book_cover_image.dart';

/// ForgottenBooksPage 展示全部"未读完"的书籍，按未打开天数倒序排列。
/// 已看完（progress >= 1.0）的书籍不计入。
class ForgottenBooksPage extends StatefulWidget {
  const ForgottenBooksPage({super.key});

  @override
  State<ForgottenBooksPage> createState() => _ForgottenBooksPageState();
}

class _ForgottenBooksPageState extends State<ForgottenBooksPage> {
  final BookshelfController _controller = BookshelfController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 计算自上次打开以来的天数（从未打开则返回极大值，排在列表最前）。
  int _daysSinceOpened(BookModel book) {
    if (book.lastReadAt == null) return 99999;
    return DateTime.now().difference(book.lastReadAt!).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final primary = theme.primaryColor;

    return ValueListenableBuilder<List<BookModel>>(
      valueListenable: _controller.books,
      builder: (context, books, child) {
        // 筛选「遗忘」书籍：未读完 + 曾经打开过 + 距上次打开已超过 7 天。
        // 刚导入（从未打开）不计入遗忘，避免新导入即被标记为遗忘。
        final forgotten = books
            .where((b) =>
                b.progress < 1.0 &&
                b.lastReadAt != null &&
                _daysSinceOpened(b) >= 7)
            .toList()
          ..sort(
            (a, b) => _daysSinceOpened(b).compareTo(_daysSinceOpened(a)),
          );

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.maybePop(context),
              child: const Icon(CupertinoIcons.back, size: 22),
            ),
            middle: Text(
              LocalizationEngine.text('forgotten_books_title'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.textStyle.color,
              ),
            ),
          ),
          child: SafeArea(
            child: forgotten.isEmpty
                // 空状态
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        LocalizationEngine.text('forgotten_empty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                        ),
                      ),
                    ),
                  )
                // 响应式网格：一个框展示一本书，向后（右→下）排列
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // 根据可用宽度自适应列数（每列约 104~140）
                      final crossCount =
                          (constraints.maxWidth / 120).floor().clamp(2, 6);
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossCount,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: forgotten.length,
                        itemBuilder: (context, index) {
                          final book = forgotten[index];
                          final days = _daysSinceOpened(book);
                          final daysText = days >= 99999
                              ? LocalizationEngine.text(
                                  'forgotten_never_opened',
                                )
                              : LocalizationEngine.text('forgotten_days_label')
                                  .replaceAll('{days}', '$days');
                          return GestureDetector(
                            onTap: () => _openBook(context, book),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: CupertinoColors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withOpacity(0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 书籍封面
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: CupertinoColors.systemGrey5,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: BookCoverImage(
                                          book: book,
                                          fallback: (_) => const Icon(
                                            CupertinoIcons.book,
                                            size: 36,
                                            color: CupertinoColors.systemGrey,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    book.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: CupertinoColors.label
                                          .resolveFrom(context),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    daysText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: CupertinoColors.secondaryLabel
                                          .resolveFrom(context),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: book.progress,
                                    minHeight: 4,
                                    color: primary,
                                    backgroundColor: CupertinoColors.systemGrey4,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  /// 根据书籍格式跳转到对应阅读器（PDF/EPUB/TXT/漫画），不支持则提示。
  void _openBook(BuildContext context, BookModel? book) {
    if (book == null) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('书籍已被删除'),
          content: const Text('该书籍不存在，请返回书架重新选择。'),
          actions: [
            CupertinoDialogAction(
              child: const Text('确定'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
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
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('无法打开书籍'),
        content: const Text('该书籍格式不受支持或已被删除。'),
        actions: [
          CupertinoDialogAction(
            child: const Text('确定'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
