import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../controller/bookshelf_controller.dart';
import '../model/book_model.dart';
import '../service/daily_sentence_service.dart';
import '../model/daily_sentence_model.dart';
import 'book_viewer_page.dart';
import 'daily_sentence_page.dart';

/// HomePage displays the main dashboard content for the shell module.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.controller});

  final BookshelfController? controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final BookshelfController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? BookshelfController();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _openBook(BookModel book) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => BookViewerPage(title: book.title, filePath: book.path),
      ),
    );
  }

  Widget _buildRecentBookThumb(BookModel book) {
    final cover = book.coverBytes != null
        ? Image.memory(
            book.coverBytes!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildGeneratedCover(book),
          )
        : _buildGeneratedCover(book);

    return Stack(
      fit: StackFit.expand,
      children: [
        cover,
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
              '${(book.progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 10,
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
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
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
          size: 30,
          color: CupertinoColors.white,
        ),
      ),
    );
  }

  Widget _buildRecentReadingSection(BuildContext context, List<BookModel> books) {
    final recentBooks = books.length > 3 ? books.sublist(books.length - 3) : books;
    if (recentBooks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CupertinoColors.separator.resolveFrom(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocalizationEngine.text('recently_reading'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 146,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recentBooks.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final book = recentBooks[index];
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openBook(book),
                      child: SizedBox(
                        width: 96,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                height: 104,
                                width: 96,
                                child: _buildRecentBookThumb(book),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 36,
                              child: FittedBox(
                                alignment: Alignment.topLeft,
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  book.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.1,
                                    color: CupertinoColors.label.resolveFrom(context),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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
          LocalizationEngine.text('home'),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: CupertinoColors.label.resolveFrom(context)),
        ),
      ),
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ValueListenableBuilder<List<BookModel>>(
              valueListenable: _controller.books,
              builder: (context, books, child) => _buildRecentReadingSection(context, books),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    final sentences = DailySentenceService.sentencesNotifier.value;
                    final latest = sentences.isNotEmpty
                        ? sentences.last.content
                        : LocalizationEngine.text('no_sentences');
                    showCupertinoDialog<void>(
                      context: context,
                      builder: (context) {
                        return CupertinoAlertDialog(
                          title: Text(LocalizationEngine.text('view_full')),
                          content: Text(latest),
                          actions: [
                            CupertinoDialogAction(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(LocalizationEngine.text('cancel')),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: CupertinoColors.separator.resolveFrom(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                LocalizationEngine.text('daily_sentence'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: CupertinoColors.label.resolveFrom(context),
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 32,
                              onPressed: () {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (context) => const DailySentencePage(),
                                  ),
                                );
                              },
                              child: const Icon(CupertinoIcons.add),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<List<DailySentenceModel>>(
                          valueListenable: DailySentenceService.sentencesNotifier,
                          builder: (context, sentences, child) {
                            final latestSentence = sentences.isNotEmpty
                                ? sentences.last.content
                                : LocalizationEngine.text('no_sentences');
                            return Text(
                              latestSentence,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                            );
                          },
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
  }
}
