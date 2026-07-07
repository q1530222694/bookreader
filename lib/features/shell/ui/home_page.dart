import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../controller/bookshelf_controller.dart';
import '../controller/settings_controller.dart';
import '../model/book_model.dart';
import '../model/daily_sentence_model.dart';
import '../service/daily_sentence_service.dart';
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
  static const double _sectionGap = 10.0;

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
        builder: (context) => BookViewerPage(
          title: book.title,
          filePath: book.path,
          bookId: book.id,
          controller: _controller,
        ),
      ),
    );
  }

  Widget _greetingSection(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationEngine.text('greeting_title'),
              style: theme.textTheme.textStyle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              LocalizationEngine.text('greeting_subtitle'),
              style: theme.textTheme.textStyle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentReadingCard(BuildContext context, BookModel? book) {
    final theme = CupertinoTheme.of(context);
    final progressValue = (book?.progress ?? 0.0).clamp(0.0, 1.0);
    final progressPercent = '${(progressValue * 100).toStringAsFixed(0)}%';

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
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: SizedBox(
            height: 108,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: Text(
                    LocalizationEngine.text('recently_reading'),
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 80,
                          height: 84,
                          child: book == null
                              ? Container(color: CupertinoColors.systemGrey)
                              : (book.coverBytes != null
                                  ? Image.memory(book.coverBytes!, fit: BoxFit.cover)
                                  : Container(color: CupertinoColors.systemGrey)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 84,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book?.title ?? LocalizationEngine.text('no_recently_reading'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.textStyle.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: CupertinoColors.label.resolveFrom(context),
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                LocalizationEngine.text('reading_progress_label'),
                                style: theme.textTheme.textStyle.copyWith(
                                  fontSize: 10,
                                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        height: 7,
                                        color: CupertinoColors.systemGrey.resolveFrom(context).withOpacity(0.18),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: FractionallySizedBox(
                                            widthFactor: progressValue,
                                            child: Container(color: theme.primaryColor),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    progressPercent,
                                    style: theme.textTheme.textStyle.copyWith(
                                      fontSize: 10,
                                      color: theme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: CupertinoButton.filled(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minSize: 30,
                                    onPressed: book == null ? null : () => _openBook(book),
                                    child: Text(
                                      LocalizationEngine.text('continue_reading'),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 中间阅读数据展示区域（包括大号时长卡片 + 三个统计卡片）
  Widget _readingDataSection(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return ValueListenableBuilder<List<BookModel>>(
      valueListenable: _controller.books,
      builder: (context, books, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // 大号总阅读时长卡片
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: CupertinoColors.systemGrey.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6)),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LocalizationEngine.text('reading_stats'),
                            style: theme.textTheme.textStyle.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '18 小时 45 分钟',
                            style: theme.textTheme.textStyle.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            LocalizationEngine.text('today_reading'),
                            style: theme.textTheme.textStyle.copyWith(
                              fontSize: 11,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 18,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 0),
                                  child: Icon(CupertinoIcons.sparkles, size: 12, color: theme.primaryColor),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  LocalizationEngine.text('continuous_reading'),
                                  style: theme.textTheme.textStyle.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.label.resolveFrom(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '18天',
                            textAlign: TextAlign.left,
                            style: theme.textTheme.textStyle.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 三个统计卡片（根据屏幕宽度自适应排列）
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 360;
                  final cards = [
                    _buildStatCard(context, '32 小时', LocalizationEngine.text('monthly_reading')),
                    _buildStatCard(context, '382 小时', LocalizationEngine.text('yearly_reading')),
                    _buildStatCard(context, '126 天', LocalizationEngine.text('cumulative_reading')),
                  ];

                  if (isWide) {
                    return Row(
                      children: cards
                          .map((card) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: card,
                                ),
                              ))
                          .toList(),
                    );
                  }

                  return Column(
                    children: cards
                        .map((card) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SizedBox(width: double.infinity, child: card),
                            ))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 辅助方法：构建单个统计卡片
  Widget _buildStatCard(BuildContext context, String value, String label) {
    final theme = CupertinoTheme.of(context);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: CupertinoColors.systemGrey.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.textStyle.copyWith(
              fontSize: 10,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.textStyle.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ],
      ),
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
    final theme = CupertinoTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            child: Text(
              LocalizationEngine.text('daily_sentence'),
              style: theme.textTheme.textStyle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: CupertinoColors.systemGrey.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6)),
              ],
            ),
            child: ValueListenableBuilder<List<DailySentenceModel>>(
              valueListenable: DailySentenceService.sentencesNotifier,
              builder: (context, sentences, child) {
                final latest = sentences.isNotEmpty ? sentences.last.content : '知识改变命运，阅读点亮人生。';
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        latest,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.textStyle.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.label.resolveFrom(context),
                          height: 1.5,
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

  Widget _buildLanguageButton(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: SettingsController.language,
      builder: (context, language, child) {
        final isEnglish = language == SettingsEngine.languageEnglish;
        return CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 36,
          onPressed: () {
            SettingsController.setLanguage(
              isEnglish ? SettingsEngine.languageChinese : SettingsEngine.languageEnglish,
            );
          },
          child: const Icon(CupertinoIcons.globe),
        );
      },
    );
  }

  Widget _buildThemeButton(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: SettingsController.appearance,
      builder: (context, appearance, child) {
        final isDark = appearance == SettingsEngine.appearanceDark;
        return CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 36,
          onPressed: () {
            SettingsController.setAppearance(
              isDark ? SettingsEngine.appearanceLight : SettingsEngine.appearanceDark,
            );
          },
          child: Icon(isDark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: SettingsController.language,
      builder: (context, language, child) {
        return ValueListenableBuilder<String>(
          valueListenable: SettingsController.appearance,
          builder: (context, appearance, child) {
            return CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(
                leading: Text(
                  LocalizationEngine.text('home'),
                  style: theme.textTheme.navTitleTextStyle.copyWith(fontWeight: FontWeight.w700),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLanguageButton(context),
                    _buildThemeButton(context),
                  ],
                ),
              ),
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 18),
                  children: [
                    // 顶部问候区域
                    _greetingSection(context),
                    const SizedBox(height: 8),
                    // 最近阅读标题与卡片
                    ValueListenableBuilder<List<BookModel>>(
                      valueListenable: _controller.books,
                      builder: (context, books, child) {
                        final latest = books.isNotEmpty ? books.last : null;
                        return _recentReadingCard(context, latest);
                      },
                    ),
                    SizedBox(height: _sectionGap),
                    // 中间：阅读数据展示区域（大号时长 + 三个统计卡片）
                    _readingDataSection(context),
                    SizedBox(height: _sectionGap),
                    // 下方：快捷功能
                    _quickFunctions(context),
                    SizedBox(height: _sectionGap),
                    // 底部：每日一句
                    _dailySentence(context),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
