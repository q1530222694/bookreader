import 'package:flutter/cupertino.dart';

import '../controller/bookshelf_controller.dart';
import '../model/book_model.dart';
import 'book_viewer_page.dart';

/// BookshelfPage provides the bookshelf UI and import actions.
class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key});

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  final BookshelfController _controller = BookshelfController();
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _showMoreOptions(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: CupertinoColors.transparent,
            child: Stack(
              children: [
                Positioned(
                  top: MediaQuery.of(context).padding.top + 58,
                  right: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CupertinoPopupSurface(
                      child: SizedBox(
                        width: 180,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _controller.importPdf();
                              },
                              child: const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('单本导入'),
                              ),
                            ),
                            Container(
                              height: 1,
                              color: CupertinoColors.systemGrey4,
                            ),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _controller.importMultiplePdfs();
                              },
                              child: const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('多选导入'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openBook(BookModel book) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) =>
            BookViewerPage(title: book.title, filePath: book.path),
      ),
    );
  }

  List<BookModel> _filterBooks(List<BookModel> books) {
    final keyword = _searchText.trim().toLowerCase();
    if (keyword.isEmpty) {
      return books;
    }
    return books.where((book) {
      final title = book.title.toLowerCase();
      final path = book.path.toLowerCase();
      return title.contains(keyword) || path.contains(keyword);
    }).toList();
  }

  Widget _buildBookItem(BookModel book) {
    const fallbackCover = Icon(
      CupertinoIcons.book,
      size: 64,
      color: CupertinoColors.systemGrey,
    );
    final cover = book.coverBytes != null
        ? Image.memory(
            book.coverBytes!,
            width: 64,
            height: 96,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallbackCover,
          )
        : fallbackCover;

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onPressed: () => _openBook(book),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 96,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(8),
            ),
            child: cover,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '类型：${book.type.toUpperCase()}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  book.path,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: Text(
          '书架',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: CupertinoTheme.of(context).primaryColor),
        ),
        middle: const SizedBox.shrink(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  _searchText = '';
                  _searchController.clear();
                });
              },
              child: const Icon(CupertinoIcons.clear_circled),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                showCupertinoModalPopup<void>(
                  context: context,
                  builder: (context) {
                    return CupertinoPopupSurface(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: CupertinoTextField(
                                    controller: _searchController,
                                    placeholder: '搜索已导入的书籍',
                                    prefix: const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Icon(CupertinoIcons.search),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _searchText = value;
                                      });
                                    },
                                    clearButtonMode: OverlayVisibilityMode.editing,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('完成'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              child: const Icon(CupertinoIcons.search),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showMoreOptions(context),
              child: const Icon(CupertinoIcons.ellipsis),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            ValueListenableBuilder<List<BookModel>>(
              valueListenable: _controller.books,
              builder: (context, books, child) {
                final filteredBooks = _filterBooks(books);
                return Expanded(
                  child: books.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                CupertinoIcons.book,
                                size: 72,
                                color: CupertinoColors.inactiveGray,
                              ),
                              SizedBox(height: 16),
                              Text(
                                '当前书架中暂无书籍',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: CupertinoColors.inactiveGray,
                                ),
                              ),
                            ],
                          ),
                        )
                      : filteredBooks.isEmpty
                          ? Center(
                              child: Text(
                                '没有找到匹配的书籍',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: CupertinoColors.inactiveGray,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredBooks.length,
                              itemBuilder: (context, index) {
                                return _buildBookItem(filteredBooks[index]);
                              },
                            ),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _controller.isLoading,
              builder: (context, loading, child) {
                if (loading) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: CupertinoActivityIndicator(),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            ValueListenableBuilder<String?>(
              valueListenable: _controller.errorText,
              builder: (context, errorText, child) {
                if (errorText == null) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    errorText,
                    style: const TextStyle(
                      color: Color.fromARGB(255, 163, 65, 60),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
