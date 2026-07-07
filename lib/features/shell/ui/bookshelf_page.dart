import 'dart:io';
import 'dart:math' as math;

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
  String _selectedCategory = 'all';

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

  Offset _resolveAnchorPosition(BuildContext context) {
    final renderBox = context.findRenderObject();
    if (renderBox is RenderBox) {
      final offset = renderBox.localToGlobal(Offset.zero);
      return offset + Offset(renderBox.size.width / 2, renderBox.size.height);
    }
    return const Offset(0, 0);
  }

  double _calculateMenuWidth(BuildContext context, List<String> labels,
      {double minWidth = 120.0, double horizontalPadding = 32.0, double maxWidth = double.infinity}) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontSize: 17);
    final textDirection = Directionality.of(context);
    var maxTextWidth = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: textDirection,
        maxLines: 1,
      )..layout();
      maxTextWidth = math.max(maxTextWidth, painter.width);
    }
    return maxTextWidth + horizontalPadding
        .clamp(minWidth, maxWidth.isFinite ? maxWidth : double.infinity);
  }

  void _showMoreOptions(BuildContext context, {Offset? anchorPosition}) {
    final overlayState = Overlay.of(context, rootOverlay: true);

    late final OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final targetPosition = anchorPosition ?? _resolveAnchorPosition(context);
        final mediaQuery = MediaQuery.of(overlayContext);
        final screenWidth = mediaQuery.size.width;
        final screenHeight = mediaQuery.size.height;
        final labels = [
          LocalizationEngine.text('bookshelf_import_single'),
          LocalizationEngine.text('bookshelf_import_multiple'),
          LocalizationEngine.text('bookshelf_random_read'),
        ];
        final menuWidth = _calculateMenuWidth(
          overlayContext,
          labels,
          minWidth: 120.0,
          maxWidth: screenWidth - 24.0,
        );
        final menuHeight = labels.length * 46.0 + (labels.length - 1) * 1.0;
        final safeLeft = (targetPosition.dx - menuWidth / 2).clamp(12.0, screenWidth - menuWidth - 12.0);
        final safeTop = (targetPosition.dy + 8.0).clamp(12.0, screenHeight - menuHeight - 12.0);

        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => overlayEntry.remove(),
              child: Container(color: CupertinoColors.transparent),
            ),
            Positioned(
              left: safeLeft,
              top: safeTop,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: menuWidth,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground.resolveFrom(overlayContext),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: CupertinoColors.systemGrey4.resolveFrom(overlayContext)),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        onPressed: () {
                          overlayEntry.remove();
                          _controller.importPdf();
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(LocalizationEngine.text('bookshelf_import_single')),
                        ),
                      ),
                      Container(height: 1, color: CupertinoColors.systemGrey4.resolveFrom(overlayContext)),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        onPressed: () {
                          overlayEntry.remove();
                          _controller.importMultiplePdfs();
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(LocalizationEngine.text('bookshelf_import_multiple')),
                        ),
                      ),
                      Container(height: 1, color: CupertinoColors.systemGrey4.resolveFrom(overlayContext)),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        onPressed: () {
                          overlayEntry.remove();
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
          ],
        );
      },
    );

    overlayState.insert(overlayEntry);
  }

  void _openBook(BookModel book) {
    _controller.updateBookLastRead(book.id, DateTime.now());
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => BookViewerPage(
          title: book.title,
          filePath: book.path,
          bookId: book.id,
          controller: _controller,
        ),
      ),
    );
  }

  Future<void> _deleteBook(BookModel book) async {
    _controller.removeBook(book.id);
  }

  void _showBookActions(BuildContext context, BookModel book, {Offset? anchorPosition}) {
    final overlayState = Overlay.of(context, rootOverlay: true);

    late final OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final targetPosition = anchorPosition ?? _resolveAnchorPosition(context);
        final mediaQuery = MediaQuery.of(overlayContext);
        final screenWidth = mediaQuery.size.width;
        final screenHeight = mediaQuery.size.height;
        final labels = [LocalizationEngine.text('bookshelf_delete')];
        final menuWidth = _calculateMenuWidth(
          overlayContext,
          labels,
          minWidth: 110.0,
          maxWidth: screenWidth - 24.0,
        );
        final menuHeight = 46.0;
        final safeLeft = (targetPosition.dx - menuWidth / 2).clamp(12.0, screenWidth - menuWidth - 12.0);
        final safeTop = (targetPosition.dy + 8.0).clamp(12.0, screenHeight - menuHeight - 12.0);

        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => overlayEntry.remove(),
              child: Container(color: CupertinoColors.transparent),
            ),
            Positioned(
              left: safeLeft,
              top: safeTop,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: menuWidth,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground.resolveFrom(overlayContext),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: CupertinoColors.systemGrey4.resolveFrom(overlayContext)),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    onPressed: () {
                      overlayEntry.remove();
                      _deleteBook(book);
                    },
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        LocalizationEngine.text('bookshelf_delete'),
                        style: const TextStyle(color: CupertinoColors.destructiveRed),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlayState.insert(overlayEntry);
  }

  List<BookModel> _filterBooks(List<BookModel> books) {
    // First filter by selected category (all/pdf/epub/txt/other)
    var filtered = books;
    final category = _selectedCategory.trim().toLowerCase();
    if (category.isNotEmpty && category != 'all') {
      if (category == 'other') {
        filtered = filtered.where((b) {
          final t = b.type.toLowerCase();
          return t != 'pdf' && t != 'epub' && t != 'txt';
        }).toList();
      } else {
        filtered = filtered.where((b) => b.type.toLowerCase() == category).toList();
      }
    }

    // Then apply search keyword filter
    final keyword = _searchText.trim().toLowerCase();
    if (keyword.isEmpty) {
      return filtered;
    }
    return filtered.where((book) {
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

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
            Positioned(
              right: 8,
              bottom: 8,
              child: Builder(
                builder: (buttonContext) {
                  return CupertinoButton(
                    padding: const EdgeInsets.all(6),
                    minSize: 0,
                    borderRadius: BorderRadius.circular(999),
                    color: CupertinoColors.systemGrey6.withOpacity(0.95),
                    onPressed: () => _showBookActions(buttonContext, book),
                    child: const Icon(CupertinoIcons.ellipsis, size: 16),
                  );
                },
              ),
            ),
          ],
        ),
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
      child: const Center(
        child: Icon(
          CupertinoIcons.book_fill,
          size: 44,
          color: CupertinoColors.white,
        ),
      ),
    );
  }

  String _bookTitle(BookModel book) {
    final title = book.title.trim();
    if (title.isNotEmpty) {
      return title;
    }
    return book.path.split(Platform.pathSeparator).last;
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return '-';
    }
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var index = 0;
    while (size >= 1024 && index < units.length - 1) {
      size /= 1024;
      index += 1;
    }
    final precision = size >= 100 || index == 0 ? 0 : 1;
    return '${size.toStringAsFixed(precision)} ${units[index]}';
  }

  Widget _buildBookItem(BookModel book) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openBook(book),
        onLongPressStart: (details) => _showBookActions(
          context,
          book,
          anchorPosition: details.globalPosition,
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CupertinoColors.systemGrey5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBookCover(book),
              const SizedBox(height: 12),
              Text(
                _bookTitle(book),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                textAlign: TextAlign.left,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.label.resolveFrom(context),
                  height: 1.25,
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
        onLongPressStart: (details) => _showBookActions(
          context,
          book,
          anchorPosition: details.globalPosition,
        ),
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
                      _bookTitle(book),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.label.resolveFrom(context),
                        height: 1.25,
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
              Builder(
                builder: (buttonContext) {
                  return CupertinoButton(
                    padding: const EdgeInsets.all(6),
                    minSize: 0,
                    borderRadius: BorderRadius.circular(999),
                    color: CupertinoColors.systemGrey6.withOpacity(0.95),
                    onPressed: () => _showBookActions(buttonContext, book),
                    child: const Icon(CupertinoIcons.ellipsis, size: 16),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookThumbnail(BookModel book) {
    final thumbnail = book.coverBytes != null
        ? Image.memory(
            book.coverBytes!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildGeneratedCover(book),
          )
        : _buildGeneratedCover(book);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: CupertinoColors.systemGrey4.withOpacity(0.9),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: thumbnail,
    );
  }

  Widget _buildGridCard(BookModel book) {
    // calculate thumbnail and card heights so card is thumbnail height + 2px
    const double thumbWidth = 70.0;
    const double thumbAspect = 3.0 / 4.0;
    final double thumbHeight = thumbWidth / thumbAspect;
    final double cardHeight = thumbHeight + 2.0;

    final theme = CupertinoTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openBook(book),
      onLongPressStart: (details) => _showBookActions(
        context,
        book,
        anchorPosition: details.globalPosition,
      ),
      child: Container(
        height: cardHeight,
        padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: Builder(
                builder: (buttonContext) {
                  return GestureDetector(
                    onTap: () => _showBookActions(buttonContext, book),
                    child: const Padding(
                      padding: EdgeInsets.only(top: 0, right: 0),
                      child: Icon(CupertinoIcons.ellipsis, size: 16, color: CupertinoColors.inactiveGray),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 70,
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildBookThumbnail(book),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _bookTitle(book),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: CupertinoColors.label.resolveFrom(context),
                                height: 1.25,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatMeta(book),
                          style: const TextStyle(
                            color: CupertinoColors.inactiveGray,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '已读 ${(book.progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: CupertinoColors.systemBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMeta(BookModel book) {
    return '${_localizedFileType(book.type)} · ${_formatFileSize(book.fileSizeBytes)}';
  }

  String _localizedFileType(String type) {
    final key = 'file_type_${type.toLowerCase()}';
    final val = LocalizationEngine.text(key);
    if (val == key) {
      return type.toUpperCase();
    }
    return val;
  }

  Widget _buildStatsCards(BuildContext context, List<BookModel> books) {
    final theme = CupertinoTheme.of(context);
    final textStyle = theme.textTheme.textStyle.copyWith(fontSize: 13);
    final allCount = books.length;
    final favCount = books.where((book) => book.isFavorite).length;
    final readingCount = books.where((book) => book.progress > 0 && book.progress < 1).length;
    final finishedCount = books.where((book) => book.progress >= 1.0).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: _buildStatCell(
                context,
                CupertinoIcons.book,
                CupertinoColors.systemBlue,
                allCount.toString(),
                LocalizationEngine.text('bookshelf_all_label'),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              fit: FlexFit.loose,
              child: _buildStatCell(
                context,
                CupertinoIcons.star_fill,
                CupertinoColors.systemYellow,
                favCount.toString(),
                LocalizationEngine.text('bookshelf_favorites_label'),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              fit: FlexFit.loose,
              child: _buildStatCell(
                context,
                CupertinoIcons.clock,
                CupertinoColors.systemGreen,
                readingCount.toString(),
                LocalizationEngine.text('bookshelf_reading_label'),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              fit: FlexFit.loose,
              child: _buildStatCell(
                context,
                CupertinoIcons.check_mark,
                CupertinoColors.systemPurple,
                finishedCount.toString(),
                LocalizationEngine.text('bookshelf_finished_label'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCell(BuildContext context, IconData icon, Color bgColor, String value, String label) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: CupertinoColors.white, size: 16),
                ),
                const SizedBox(width: 6),
                Text(value, style: textStyle.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: textStyle.copyWith(color: CupertinoColors.inactiveGray, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRecentReading(BuildContext context, List<BookModel> books) {
    final sortedBooks = List<BookModel>.from(books)
      ..sort((a, b) {
        final aTime = a.lastReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastReadAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    final displayBooks = sortedBooks.isEmpty ? <BookModel>[] : sortedBooks.take(6).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isDesktop = width >= 900;
        final isTablet = width >= 600 && width < 900;
        final cardWidth = isDesktop
            ? width * 0.12
            : isTablet
                ? width * 0.2
                : width * 0.24;
        final normalizedWidth = cardWidth.clamp(90.0, isDesktop ? 130.0 : isTablet ? 120.0 : 110.0);
        final cardHeight = normalizedWidth * 1.45;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6, right: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    LocalizationEngine.text('recently_reading'),
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      '${LocalizationEngine.text('view_all')} >',
                      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: CupertinoColors.inactiveGray.resolveFrom(context),
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: cardHeight,
              child: ListView.builder(
                itemCount: displayBooks.length,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final book = displayBooks[index];
                  return Padding(
                    padding: EdgeInsets.only(right: index == displayBooks.length - 1 ? 0 : 12),
                    child: _buildRecentReadingCard(context, book, normalizedWidth, cardHeight),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentReadingCard(BuildContext context, BookModel book, double width, double height) {
    final coverHeight = height * 0.78;
    final progressHeight = 4.0;
    return GestureDetector(
      onTap: () => _openBook(book),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: CupertinoTheme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              height: coverHeight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AspectRatio(
                  aspectRatio: 0.75,
                  child: _buildBookThumbnail(book),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildProgressBar(context, book.progress, height: progressHeight),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${(book.progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: CupertinoColors.inactiveGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, double progress, {double height = 6}) {
    final bg = CupertinoColors.systemGrey5.resolveFrom(context);
    final fg = CupertinoTheme.of(context).primaryColor;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: fg,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: Text(
          LocalizationEngine.text('bookshelf'),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: CupertinoColors.black),
        ),
        middle: const SizedBox.shrink(),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
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
              child: const Icon(CupertinoIcons.search, color: CupertinoColors.black),
            ),
            const SizedBox(width: 16),
            Builder(
              builder: (buttonContext) {
                return GestureDetector(
                  onTap: () => _showMoreOptions(buttonContext),
                  child: const Icon(CupertinoIcons.ellipsis, color: CupertinoColors.black),
                );
              },
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatsCards(context, books),
                      const SizedBox(height: 12),
                      _buildRecentReading(context, books),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    ...<Map<String, String>>[
                                      {'k': 'all', 't': LocalizationEngine.text('bookshelf_tab_all')},
                                      {'k': 'pdf', 't': LocalizationEngine.text('file_type_pdf')},
                                      {'k': 'epub', 't': LocalizationEngine.text('file_type_epub')},
                                      {'k': 'txt', 't': LocalizationEngine.text('file_type_txt')},
                                      {'k': 'other', 't': LocalizationEngine.text('bookshelf_tab_other')},
                                    ].map((item) {
                                      final key = item['k']!;
                                      final label = item['t']!;
                                      final selected = _selectedCategory == key;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: GestureDetector(
                                          onTap: () => setState(() => _selectedCategory = key),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: selected ? CupertinoTheme.of(context).primaryColor.withOpacity(0.12) : CupertinoColors.transparent,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              label,
                                              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                                                fontSize: 14,
                                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                                color: selected ? CupertinoTheme.of(context).primaryColor : CupertinoColors.inactiveGray,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                showCupertinoModalPopup<void>(
                                  context: context,
                                  builder: (c) => CupertinoActionSheet(
                                    title: Text(LocalizationEngine.text('bookshelf_filter')),
                                    actions: [
                                      CupertinoActionSheetAction(
                                        onPressed: () => Navigator.of(c).pop(),
                                        child: Text(LocalizationEngine.text('done')),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                child: Icon(CupertinoIcons.slider_horizontal_3, color: CupertinoTheme.of(context).primaryColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
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
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          childAspectRatio: 1.72,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                        ),
                                        itemCount: filteredBooks.length,
                                        itemBuilder: (context, index) {
                                          return _buildGridCard(filteredBooks[index]);
                                        },
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        itemCount: filteredBooks.length,
                                        itemBuilder: (context, index) {
                                          return _buildBookListItem(filteredBooks[index]);
                                        },
                                      ),
                      ),
                    ],
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
