import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../controller/bookshelf_controller.dart';
import '../model/book_model.dart';
import '../service/daily_sentence_service.dart';
import '../model/daily_sentence_model.dart';
import 'book_viewer_page.dart';
import 'daily_sentence_page.dart';

/// HomePage displays the redesigned dashboard matching the provided mock.
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

  Widget _greetingSection(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final textStyle = theme.textTheme.textStyle;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocalizationEngine.text('greeting_with_name'),
                  style: textStyle.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  LocalizationEngine.text('greeting_subtitle'),
                  style: theme.textTheme.textStyle.copyWith(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 36,
            onPressed: () {},
            child: const Icon(CupertinoIcons.bell),
          ),
        ],
      ),
    );
  }

  Widget _recentReadingCard(BuildContext context, BookModel? book) {
    final theme = CupertinoTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: CupertinoColors.systemGrey.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 84,
                  height: 112,
                  child: book == null
                      ? Container(color: CupertinoColors.systemGrey)
                      : (book.coverBytes != null
                          ? Image.memory(book.coverBytes!, fit: BoxFit.cover)
                          : Container(color: CupertinoColors.systemGrey)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book?.title ?? LocalizationEngine.text('no_recently_reading'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.textStyle.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      LocalizationEngine.text('reading_progress_label',),
                      style: theme.textTheme.textStyle.copyWith(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                    ),
                    const SizedBox(height: 8),
                    // progress bar (custom, avoid Material dependency)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 8,
                        color: CupertinoColors.systemGrey.resolveFrom(context).withOpacity(0.18),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: (book?.progress ?? 0).clamp(0.0, 1.0),
                            child: Container(color: theme.primaryColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          onPressed: book == null ? null : () => _openBook(book!),
                          child: Text(LocalizationEngine.text('continue_reading')),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Container()),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statsGrid(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return ValueListenableBuilder<List<BookModel>>(
      valueListenable: _controller.books,
      builder: (context, books, child) {
        final totalBooks = books.length;
        final completed = books.where((b) => b.progress >= 0.999).length;
        final avgProgress = totalBooks > 0 ? (books.map((b) => b.progress).reduce((a, b) => a + b) / totalBooks) : 0.0;

        final items = [
          {'label': LocalizationEngine.text('today_reading'), 'value': '0h 0m'},
          {'label': LocalizationEngine.text('today_books'), 'value': '$totalBooks'},
          {'label': LocalizationEngine.text('total_pages'), 'value': '${(avgProgress * 100).toStringAsFixed(0)}%'},
          {'label': LocalizationEngine.text('streak_days'), 'value': '$completed'},
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: items.map((it) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it['value'] as String, style: theme.textTheme.textStyle.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(it['label'] as String, style: theme.textTheme.textStyle.copyWith(color: CupertinoColors.secondaryLabel.resolveFrom(context))),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _quickFunctions(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final tiles = [
      {'icon': CupertinoIcons.folder, 'label': LocalizationEngine.text('import_pdf')},
      {'icon': CupertinoIcons.clock, 'label': LocalizationEngine.text('recent_files')},
      {'icon': CupertinoIcons.chart_bar, 'label': LocalizationEngine.text('reading_stats')},
      {'icon': CupertinoIcons.star, 'label': LocalizationEngine.text('favorites')},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: tiles.map((t) {
          return Expanded(
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(t['icon'] as IconData, color: theme.primaryColor),
                ),
                const SizedBox(height: 8),
                Text(t['label'] as String, style: theme.textTheme.textStyle.copyWith(fontSize: 12, color: CupertinoColors.secondaryLabel.resolveFrom(context)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _dailySentence(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocalizationEngine.text('daily_sentence'),
            style: CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ValueListenableBuilder<List<DailySentenceModel>>(
              valueListenable: DailySentenceService.sentencesNotifier,
              builder: (context, sentences, child) {
                final latest = sentences.isNotEmpty ? sentences.last.content : LocalizationEngine.text('no_sentences');
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        '"$latest"',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: CupertinoColors.label.resolveFrom(context),
                              height: 1.6,
                            ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 36,
                      onPressed: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (context) => const DailySentencePage(),
                          ),
                        );
                      },
                      child: Icon(CupertinoIcons.chevron_right, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(LocalizationEngine.text('home'))),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 18),
          children: [
            _greetingSection(context),
            const SizedBox(height: 6),
            ValueListenableBuilder<List<BookModel>>(
              valueListenable: _controller.books,
              builder: (context, books, child) {
                final latest = books.isNotEmpty ? books.last : null;
                return _recentReadingCard(context, latest);
              },
            ),
            _statsGrid(context),
            _quickFunctions(context),
            _dailySentence(context),
          ],
        ),
      ),
    );
  }
}
