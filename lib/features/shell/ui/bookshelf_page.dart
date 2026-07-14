import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../engine/localization_engine.dart';
import '../controller/bookshelf_controller.dart';
import '../model/book_model.dart';
import 'book_viewer_page.dart';
import 'epub_viewer_page.dart';
import 'txt_viewer_page.dart';
import 'comic_viewer_page.dart';
import 'package:open_filex/open_filex.dart';

class _BookDownloadItemData {
  const _BookDownloadItemData({
    required this.title,
    required this.fileMeta,
    required this.progress,
    required this.timestamp,
    required this.type,
    this.book,
  });

  final String title;
  final String fileMeta;
  final double progress;
  final String timestamp;
  final String type;
  final BookModel? book;
}

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
  bool _showDownloadListMode = false;
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
          LocalizationEngine.text('bookshelf_scan_import'),
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
                          _showScanImportPicker(context);
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(LocalizationEngine.text('bookshelf_scan_import')),
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

  Future<void> _showScanImportPicker(BuildContext context) async {
    final candidates = await _controller.scanForSupportedBooks();
    if (!mounted) return;

    if (candidates.isEmpty) {
      _controller.setError(LocalizationEngine.text('bookshelf_scan_import_empty'));
      return;
    }

    final selectedPaths = <String>{};

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '导入书籍',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim1, anim2) {
        return SafeArea(
          child: GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            behavior: HitTestBehavior.opaque,
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  // blurred, dimmed background
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                    child: Container(color: Colors.transparent),
                  ),

                  // bottom card
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      onTap: () {},
                      child: StatefulBuilder(
                        builder: (modalCtx, setModalState) {
                          return Container(
                            height: MediaQuery.of(context).size.height * 0.75,
                            margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemBackground.resolveFrom(context),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6)),
                              ],
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 12, left: 12, right: 12, bottom: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '导入书籍',
                                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                                            ),
                                            const SizedBox(height: 10),
                                          ],
                                        ),
                                      ),
                                      // close button
                                      GestureDetector(
                                        onTap: () => Navigator.of(ctx).pop(),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 18, color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 8),

                                const Divider(height: 1),

                                // list
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    child: ListView.separated(
                                      itemCount: candidates.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                                      itemBuilder: (ctx2, index) {
                                        final candidate = candidates[index];
                                        final isSelected = selectedPaths.contains(candidate.path);

                                        // leading icon color by type
                                        Color iconBg;
                                        IconData iconData = Icons.book;
                                        final type = candidate.type.toLowerCase();
                                        if (type.contains('pdf')) {
                                          iconBg = Colors.red[400]!;
                                          iconData = Icons.picture_as_pdf;
                                        } else if (type.contains('epub')) {
                                          iconBg = Colors.blue[400]!;
                                          iconData = Icons.book;
                                        } else if (type.contains('mobi')) {
                                          iconBg = Colors.green[400]!;
                                          iconData = Icons.menu_book;
                                        } else if (type.contains('txt')) {
                                          iconBg = Colors.grey[400]!;
                                          iconData = Icons.description;
                                        } else {
                                          iconBg = Colors.purple[400]!;
                                          iconData = Icons.book;
                                        }

                                        return Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(10),
                                            onTap: () {
                                              setModalState(() {
                                                if (isSelected) {
                                                  selectedPaths.remove(candidate.path);
                                                } else {
                                                  selectedPaths.add(candidate.path);
                                                }
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 32,
                                                    height: 38,
                                                    decoration: BoxDecoration(
                                                      color: iconBg,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Icon(iconData, color: Colors.white, size: 18),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(candidate.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                                        const SizedBox(height: 1),
                                                        Text('${_localizedFileType(candidate.type)} · ${_formatFileSize(candidate.fileSizeBytes)}', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // custom selector
                                                  Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? Colors.blue[600] : Colors.transparent,
                                                      border: Border.all(color: isSelected ? Colors.blue[600]! : Colors.grey[400]!),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: isSelected
                                                        ? const Icon(Icons.check, color: Colors.white, size: 12)
                                                        : const SizedBox.shrink(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                const Divider(height: 1),

                                // bottom actions
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      Text('已选择 ${selectedPaths.length} 本', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                                      const Spacer(),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue[800],
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: selectedPaths.isEmpty
                                            ? null
                                            : () async {
                                                Navigator.of(ctx).pop();
                                                final selectedCandidates = candidates.where((c) => selectedPaths.contains(c.path)).toList();
                                                if (selectedCandidates.isEmpty) {
                                                  _controller.setError(LocalizationEngine.text('bookshelf_scan_import_empty'));
                                                  return;
                                                }
                                                await _controller.importScanCandidates(selectedCandidates);
                                              },
                                        child: Text('确认导入 (${selectedPaths.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, a1, a2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: a1, child: child),
        );
      },
    );
  }

  Future<void> _openBook(BookModel book) async {
    _controller.updateBookLastRead(book.id, DateTime.now());
    final path = book.path.toLowerCase();
    if (path.endsWith('.pdf')) {
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
      return;
    }

    // EPUB
    if (path.endsWith('.epub')) {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (context) => EpubViewerPage(title: book.title, filePath: book.path, bookId: book.id, controller: _controller)),
      );
      return;
    }

    // TXT
    if (path.endsWith('.txt')) {
      Navigator.push(
        context,
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

    // Comic archive formats (CBZ/CBR/CB7/CBT)
    if (path.endsWith('.cbz') || path.endsWith('.cbr') || path.endsWith('.cb7') || path.endsWith('.cbt') || path.endsWith('.zip')) {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (context) => ComicViewerPage(title: book.title, filePath: book.path, bookId: book.id, controller: _controller)),
      );
      return;
    }

    // Fallback: try system open
    try {
      final result = await OpenFilex.open(book.path);
      if (result.type != ResultType.done) {
        _controller.setError('无法打开文件：${result.message}');
      }
    } catch (e) {
      _controller.setError('打开文件失败：$e');
    }
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
        final actions = <Map<String, dynamic>>[
          {
            'label': book.isFavorite
                ? LocalizationEngine.text('bookshelf_remove_favorite')
                : LocalizationEngine.text('bookshelf_add_favorite'),
            'isDestructive': false,
            'onTap': () => _controller.updateBookFavorite(book.id, !book.isFavorite),
          },
          {
            'label': LocalizationEngine.text('bookshelf_mark_reading'),
            'isDestructive': false,
            'onTap': () => _controller.updateBookReadingState(book.id, 0.5),
          },
          {
            'label': LocalizationEngine.text('bookshelf_mark_finished'),
            'isDestructive': false,
            'onTap': () => _controller.updateBookReadingState(book.id, 1.0),
          },
          {
            'label': LocalizationEngine.text('bookshelf_mark_unread'),
            'isDestructive': false,
            'onTap': () => _controller.updateBookReadingState(book.id, 0.0),
          },
          {
            'label': LocalizationEngine.text('bookshelf_delete'),
            'isDestructive': true,
            'onTap': () => _deleteBook(book),
          },
        ];
        final labels = actions.map((action) => action['label'] as String).toList();
        final menuWidth = _calculateMenuWidth(
          overlayContext,
          labels,
          minWidth: 128.0,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(actions.length, (index) {
                      final action = actions[index];
                      final isDestructive = action['isDestructive'] as bool;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            onPressed: () {
                              overlayEntry.remove();
                              (action['onTap'] as VoidCallback).call();
                            },
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                action['label'] as String,
                                style: isDestructive
                                    ? const TextStyle(color: CupertinoColors.destructiveRed)
                                    : null,
                              ),
                            ),
                          ),
                          if (index < actions.length - 1)
                            Container(height: 1, color: CupertinoColors.systemGrey4.resolveFrom(overlayContext)),
                        ],
                      );
                    }),
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
          final t = b.normalizedType.toLowerCase();
          return t != 'pdf' && t != 'epub' && t != 'txt';
        }).toList();
      } else {
        filtered = filtered.where((b) => b.normalizedType.toLowerCase() == category).toList();
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

  static const List<_BookDownloadItemData> _mockDownloadItems = [
    _BookDownloadItemData(
      title: 'Flutter 开发实战',
      fileMeta: 'PDF · 12.4 MB',
      progress: 0.48,
      timestamp: '刚刚',
      type: 'pdf',
    ),
    _BookDownloadItemData(
      title: '产品设计手册',
      fileMeta: 'EPUB · 8.1 MB',
      progress: 0.72,
      timestamp: '2小时前',
      type: 'epub',
    ),
    _BookDownloadItemData(
      title: '高效阅读笔记',
      fileMeta: 'TXT · 1.2 MB',
      progress: 0.34,
      timestamp: '昨天',
      type: 'txt',
    ),
    _BookDownloadItemData(
      title: '架构设计精要',
      fileMeta: 'PDF · 6.8 MB',
      progress: 0.91,
      timestamp: '3天前',
      type: 'pdf',
    ),
  ];

  Widget _buildDownloadListView(List<BookModel> books) {
    final displayItems = books.isEmpty
        ? _mockDownloadItems
        : books.take(4).map((book) {
            final title = _bookTitle(book);
            return _BookDownloadItemData(
              title: title,
              fileMeta: '${_localizedFileType(book.normalizedType)} · ${_formatFileSize(book.fileSizeBytes)}',
              progress: book.progress.clamp(0.0, 1.0),
              timestamp: book.lastReadAt != null ? '最近阅读' : LocalizationEngine.text('just_now'),
              type: book.type,
              book: book,
            );
          }).toList();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      itemCount: displayItems.length,
      separatorBuilder: (context, index) => Container(
        height: 1,
        color: CupertinoColors.systemGrey5.resolveFrom(context),
      ),
      itemBuilder: (context, index) {
        return _buildDownloadListItem(context, displayItems[index]);
      },
    );
  }

  Widget _buildDownloadListItem(BuildContext context, _BookDownloadItemData item) {
    final theme = CupertinoTheme.of(context);
    final progressColor = theme.primaryColor;
    final book = item.book;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: book != null
                  ? _buildBookThumbnail(book)
                  : Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6.resolveFrom(context),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.systemGrey.withOpacity(0.16),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          CupertinoIcons.book_fill,
                          color: progressColor,
                          size: 28,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: book != null ? () => _openBook(book) : null,
              onLongPressStart: book != null
                  ? (details) => _showBookActions(
                        context,
                        book,
                        anchorPosition: details.globalPosition,
                      )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.textStyle.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.fileMeta,
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey5.resolveFrom(context),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: item.progress.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: progressColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(item.progress * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.textStyle.copyWith(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.timestamp,
                        style: theme.textTheme.textStyle.copyWith(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (book != null)
            Builder(
              builder: (buttonContext) {
                return CupertinoButton(
                  key: ValueKey('bookshelf_list_more_button_${book.id}'),
                  padding: const EdgeInsets.all(6),
                  minSize: 0,
                  borderRadius: BorderRadius.circular(999),
                  color: CupertinoColors.systemGrey6.withOpacity(0.95),
                  onPressed: () => _showBookActions(buttonContext, book),
                  child: const Icon(CupertinoIcons.ellipsis, size: 16),
                );
              },
            )
          else
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.withOpacity(0.95),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(CupertinoIcons.ellipsis, size: 16),
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
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openBook(book),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 88,
                    height: 120,
                    child: _buildBookThumbnail(book),
                  ),
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
                      '${(book.progress * 100).toStringAsFixed(0)}% · ${book.normalizedType.toUpperCase()}',
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
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openBook(book),
                    child: SizedBox(
                      width: 70,
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildBookThumbnail(book),
                        ),
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
    return '${_localizedFileType(book.normalizedType)} · ${_formatFileSize(book.fileSizeBytes)}';
  }

  String _localizedFileType(String type) {
    final normalizedType = type.toLowerCase();
    final key = 'file_type_$normalizedType';
    final val = LocalizationEngine.text(key);
    if (val == key) {
      return normalizedType.toUpperCase();
    }
    return val;
  }

  Widget _buildStatsCards(BuildContext context, List<BookModel> books) {
    final theme = CupertinoTheme.of(context);
    final allCount = books.length;
    final favCount = books.where((book) => book.isFavorite).length;
    final readingCount = books.where((book) => book.progress > 0 && book.progress < 1).length;
    final finishedCount = books.where((book) => book.progress >= 1.0).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          // 背景改用次要系统背景，与回忆页阅读统计卡片一致，无需硬边框即可与页面底色形成柔和对比
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            // 阴影调淡，仅留极轻的主题主色投影，整体线框更柔和
            BoxShadow(
              color: CupertinoTheme.of(context).primaryColor.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildStatCell(
                context,
                CupertinoIcons.book,
                const Color(0xFF5DA5FF),
                allCount.toString(),
                LocalizationEngine.text('bookshelf_all_label'),
              ),
            ),
            Expanded(
              child: _buildStatCell(
                context,
                CupertinoIcons.star_fill,
                const Color(0xFFFFC857),
                favCount.toString(),
                LocalizationEngine.text('bookshelf_favorites_label'),
              ),
            ),
            Expanded(
              child: _buildStatCell(
                context,
                CupertinoIcons.clock,
                const Color(0xFF43C17C),
                readingCount.toString(),
                LocalizationEngine.text('bookshelf_reading_label'),
              ),
            ),
            Expanded(
              child: _buildStatCell(
                context,
                CupertinoIcons.check_mark,
                const Color(0xFF9B7BFF),
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
    final labelFontSize = 12.5;
    final iconSize = labelFontSize * 0.9;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: textStyle.copyWith(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontWeight: FontWeight.w600,
                  fontSize: labelFontSize,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 4),
              Container(
                width: labelFontSize + 8,
                height: labelFontSize + 8,
                decoration: BoxDecoration(
                  color: bgColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular((labelFontSize + 8) / 2),
                  boxShadow: [
                    BoxShadow(
                      color: bgColor.withOpacity(0.24),
                      blurRadius: 6,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(icon, color: bgColor, size: iconSize),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: textStyle.copyWith(
              color: CupertinoColors.label.resolveFrom(context),
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
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
              padding: const EdgeInsets.only(left: 6, right: 12),
              child: Row(
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
                  const Spacer(),
                  Text(
                    LocalizationEngine.text('view_all'),
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CupertinoTheme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: cardHeight,
              child: displayBooks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _buildEmptyRecentPlaceholder(context, width - 24, cardHeight),
                    )
                  : ListView.builder(
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

  Widget _buildEmptyRecentPlaceholder(BuildContext context, double width, double height) {
    final theme = CupertinoTheme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.primaryColor.withOpacity(0.08), theme.scaffoldBackgroundColor],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: CupertinoColors.systemGrey.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocalizationEngine.text('bookshelf_empty_title'),
                  style: theme.textTheme.textStyle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  LocalizationEngine.text('bookshelf_empty_subtitle'),
                  style: theme.textTheme.textStyle.copyWith(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                SizedBox(
                  width: 120,
                  child: CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    onPressed: _controller.importPdf,
                    child: Text(
                      LocalizationEngine.text('bookshelf_import_button'),
                      style: theme.textTheme.textStyle.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: height * 0.6,
            height: height,
            child: Center(
              child: Icon(
                CupertinoIcons.book,
                color: theme.primaryColor,
                size: height * 0.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, double progress, {double height = 6}) {
    final bg = CupertinoColors.systemGrey5.resolveFrom(context);
    final fg = CupertinoTheme.of(context).primaryColor;
    return SizedBox(
      width: 140,
      child: Container(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final headerColor = CupertinoColors.label.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: Text(
          LocalizationEngine.text('bookshelf'),
          style: theme.textTheme.textStyle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: headerColor,
          ),
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
              child: Icon(CupertinoIcons.search, size: 20, color: headerColor),
            ),
            const SizedBox(width: 16),
            Builder(
              builder: (buttonContext) {
                return GestureDetector(
                  onTap: () => _showMoreOptions(buttonContext),
                  child: Icon(CupertinoIcons.ellipsis, size: 20, color: headerColor),
                );
              },
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
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
                                    setState(() {
                                      _showDownloadListMode = !_showDownloadListMode;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    child: Icon(
                                      CupertinoIcons.slider_horizontal_3,
                                      color: _showDownloadListMode
                                          ? CupertinoTheme.of(context).primaryColor
                                          : CupertinoColors.inactiveGray.resolveFrom(context),
                                    ),
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
                                    : _showDownloadListMode
                                        ? _buildDownloadListView(filteredBooks)
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
              ],
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
            ValueListenableBuilder<String?>(
              valueListenable: _controller.toastMessage,
              builder: (context, toast, child) {
                if (toast == null) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  bottom: 20,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.78),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        toast,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
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
