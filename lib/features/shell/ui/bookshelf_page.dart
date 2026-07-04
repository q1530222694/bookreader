import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../controller/bookshelf_controller.dart';
import '../model/book_model.dart';
import 'book_viewer_page.dart';

/// BookshelfPage provides the bookshelf UI and import actions.
class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key, this.controller});

  final BookshelfController? controller;

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  late final BookshelfController _controller;
  late final bool _ownsController;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _showCoverMode = true;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? BookshelfController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
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
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(LocalizationEngine.text('bookshelf_import_single')),
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
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(LocalizationEngine.text('bookshelf_import_multiple')),
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
                                final randomBook = _controller.pickRandomBook();
                                if (randomBook == null) {
                                  _controller.setError(LocalizationEngine.text('bookshelf_empty_error'));
                                  return;
                                }
                                _openBook(randomBook);
                              },
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(LocalizationEngine.text('bookshelf_random_read')),
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

  Future<void> _deleteBook(BookModel book) async {
    Navigator.of(context).pop();
    _controller.removeBook(book.id);
  }

  void _showBookActions(BuildContext context, BookModel book) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: Text(book.title),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                _deleteBook(book);
              },
              isDestructiveAction: true,
              child: Text(LocalizationEngine.text('bookshelf_delete')),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: Text(LocalizationEngine.text('cancel')),
          ),
        );
      },
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

  Widget _buildBookCover(BookModel book) {
    final cover = book.coverBytes != null
        ? Image.memory(
            book.coverBytes!,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildGeneratedCover(book),
          )
        : _buildGeneratedCover(book);

    return SizedBox(
      width: double.infinity,
      height: 160,
      child: Stack(
        children: [
          Positioned.fill(child: cover),
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: CupertinoColors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${(book.progress * 100).toStringAsFixed(2)}%',
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: CupertinoColors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                book.type.toUpperCase(),
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedCover(BookModel book) {
    final seed = book.title.hashCode % 7;
    final colors = <Color>[
      CupertinoColors.systemBlue,
      CupertinoColors.systemGreen,
      CupertinoColors.systemIndigo,
      CupertinoColors.systemOrange,
      CupertinoColors.systemPink,
      CupertinoColors.systemPurple,
      CupertinoColors.systemTeal,
    ];

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors[seed], colors[(seed + 2) % colors.length]],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.book_fill,
              size: 44,
              color: CupertinoColors.white,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                book.title.isEmpty ? 'BOOK' : book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookItem(BookModel book) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openBook(book),
        onLongPress: () => _showBookActions(context, book),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CupertinoColors.systemGrey5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    _buildBookCover(book),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: CupertinoButton(
                        padding: const EdgeInsets.all(6),
                        minSize: 0,
                        borderRadius: BorderRadius.circular(999),
                        color: CupertinoColors.systemGrey6.withOpacity(0.95),
                        onPressed: () => _showBookActions(context, book),
                        child: const Icon(CupertinoIcons.ellipsis, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 42,
                child: Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookListItem(BookModel book) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openBook(book),
        onLongPress: () => _showBookActions(context, book),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CupertinoColors.systemGrey5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 88,
                  height: 120,
                  child: _buildBookThumbnail(book),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${(book.progress * 100).toStringAsFixed(0)}% · ${book.type.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(6),
                minSize: 0,
                borderRadius: BorderRadius.circular(999),
                color: CupertinoColors.systemGrey6.withOpacity(0.95),
                onPressed: () => _showBookActions(context, book),
                child: const Icon(CupertinoIcons.ellipsis, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookThumbnail(BookModel book) {
    if (book.coverBytes != null) {
      return Image.memory(
        book.coverBytes!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildGeneratedCover(book),
      );
    }

    return _buildGeneratedCover(book);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              LocalizationEngine.text('bookshelf'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: CupertinoTheme.of(context).primaryColor),
            ),
            const SizedBox(width: 8),
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
                                    placeholder: LocalizationEngine.text('bookshelf_search_placeholder'),
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
                                  child: Text(LocalizationEngine.text('done')),
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
          ],
        ),
        middle: const SizedBox.shrink(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  _showCoverMode = !_showCoverMode;
                });
              },
              child: Icon(
                _showCoverMode ? CupertinoIcons.list_bullet : CupertinoIcons.square_grid_2x2,
              ),
            ),
            const SizedBox(width: 10),
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
                          child: CupertinoButton.filled(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            onPressed: _controller.importPdf,
                            child: Text(LocalizationEngine.text('bookshelf_import_button')),
                          ),
                        )
                          : filteredBooks.isEmpty
                              ? Center(
                                  child: Text(
                                    LocalizationEngine.text('bookshelf_no_match_books'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: CupertinoColors.inactiveGray,
                                    ),
                                  ),
                                )
                              : _showCoverMode
                                  ? GridView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 0.72,
                                        crossAxisSpacing: 8,
                                        mainAxisSpacing: 8,
                                      ),
                                      itemCount: filteredBooks.length,
                                      itemBuilder: (context, index) {
                                        return _buildBookItem(filteredBooks[index]);
                                      },
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      itemCount: filteredBooks.length,
                                      itemBuilder: (context, index) {
                                        return _buildBookListItem(filteredBooks[index]);
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
