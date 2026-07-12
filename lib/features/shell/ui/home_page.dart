import 'package:flutter/cupertino.dart';

import '../controller/daily_sentence_controller.dart';

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../controller/bookshelf_controller.dart';
import '../controller/settings_controller.dart';
import '../model/book_model.dart';
import '../model/reading_stats_model.dart';
import '../model/daily_sentence_model.dart';
import '../service/app_stats_service.dart';
import '../service/daily_sentence_service.dart';
import 'book_viewer_page.dart';
import 'epub_viewer_page.dart';
import 'txt_viewer_page.dart';
import 'comic_viewer_page.dart';
import 'package:open_filex/open_filex.dart';

/// HomePage displays the redesigned dashboard matching the provided mock.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.controller, this.currentTimeProvider});

  final BookshelfController? controller;
  final DateTime Function()? currentTimeProvider;

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

  Future<void> _openBook(BookModel book) async {
    _controller.updateBookLastRead(book.id, DateTime.now());
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
        CupertinoPageRoute(builder: (_) => EpubViewerPage(title: book.title, filePath: book.path)),
      );
      return;
    }

    if (path.endsWith('.txt')) {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => TxtViewerPage(title: book.title, filePath: book.path)),
      );
      return;
    }

    if (path.endsWith('.cbz') || path.endsWith('.cbr') || path.endsWith('.cb7') || path.endsWith('.cbt') || path.endsWith('.zip')) {
      Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => ComicViewerPage(title: book.title, filePath: book.path)),
      );
      return;
    }

    try {
      final result = await OpenFilex.open(book.path);
      if (result.type != ResultType.done) {
        _controller.setError('无法打开文件：${result.message}');
      }
    } catch (e) {
      _controller.setError('打开文件失败：$e');
    }
  }

  DateTime _resolveNow() => widget.currentTimeProvider?.call() ?? DateTime.now();

  String _greetingTitle() {
    final hour = _resolveNow().hour;
    if (hour < 6) {
      return LocalizationEngine.text('greeting_title_late_night');
    }
    if (hour < 12) {
      return LocalizationEngine.text('greeting_title_morning');
    }
    if (hour < 18) {
      return LocalizationEngine.text('greeting_title_afternoon');
    }
    return LocalizationEngine.text('greeting_title_evening');
  }

  String _greetingSubtitle() {
    final hour = _resolveNow().hour;
    if (hour < 6) {
      return LocalizationEngine.text('greeting_subtitle_late_night');
    }
    if (hour < 12) {
      return LocalizationEngine.text('greeting_subtitle_morning');
    }
    if (hour < 18) {
      return LocalizationEngine.text('greeting_subtitle_afternoon');
    }
    return LocalizationEngine.text('greeting_subtitle_evening');
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
              _greetingTitle(),
              style: theme.textTheme.textStyle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _greetingSubtitle(),
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
                              ? Container(
                                  color: theme.primaryColor.withOpacity(0.08),
                                  child: Center(
                                    child: Icon(
                                      CupertinoIcons.book,
                                      color: theme.primaryColor,
                                      size: 36,
                                    ),
                                  ),
                                )
                              : (book.coverBytes != null
                                  ? Image.memory(book.coverBytes!, fit: BoxFit.cover)
                                  : Container(color: CupertinoColors.systemGrey)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 84,
                          child: book == null
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      LocalizationEngine.text('bookshelf_empty_title'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.textStyle.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: CupertinoColors.label.resolveFrom(context),
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      LocalizationEngine.text('bookshelf_empty_subtitle'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.textStyle.copyWith(
                                        fontSize: 12,
                                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                                      ),
                                    ),
                                    const Spacer(),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: SizedBox(
                                        width: 120,
                                        child: CupertinoButton.filled(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          minSize: 32,
                                          onPressed: () => _controller.importPdf(),
                                          child: Text(
                                            LocalizationEngine.text('bookshelf_import_button'),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      book.title,
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
                                          onPressed: () => _openBook(book),
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

  String _formatReadingDuration(int minutes, String language) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final hourLabel = language == SettingsEngine.languageEnglish ? LocalizationEngine.text('hours_short') : LocalizationEngine.text('hours_short');
    final minuteLabel = language == SettingsEngine.languageEnglish ? 'm' : LocalizationEngine.text('minutes_short');
    return '$hours $hourLabel $mins $minuteLabel';
  }

  String _formatReadingDays(int days, String language) {
    final dayLabel = language == SettingsEngine.languageEnglish ? LocalizationEngine.text('days_short') : LocalizationEngine.text('days_short');
    return '$days $dayLabel';
  }

  // 中间阅读数据展示区域（包括大号时长卡片 + 三个统计卡片）
  Widget _readingDataSection(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: SettingsController.language,
      builder: (context, language, child) {
        final launchCountLabel = LocalizationEngine.text('app_launch_count');
        final launchUnit = LocalizationEngine.text('launch_unit');

        return ValueListenableBuilder<List<BookModel>>(
          valueListenable: _controller.books,
          builder: (context, books, child) {
            final stats = ReadingStats.fromBooks(books);
            final streakDays = stats.streakDays;

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
                                _formatReadingDuration(stats.todayMinutes, language),
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
                                _formatReadingDays(streakDays, language),
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
                  // 四个统计卡片固定并排显示，确保宽高一致且不随屏幕变化换行
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _buildStatCard(
                            context,
                            _formatReadingDuration(stats.monthMinutes, language),
                            LocalizationEngine.text('monthly_reading'),
                            accentColor: const Color(0xFF2F80ED),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildStatCard(
                            context,
                            _formatReadingDuration(stats.yearMinutes, language),
                            LocalizationEngine.text('yearly_reading'),
                            accentColor: const Color(0xFF27AE60),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildStatCard(
                            context,
                            _formatReadingDays(stats.activeDays, language),
                            LocalizationEngine.text('cumulative_reading'),
                            accentColor: const Color(0xFFE67E22),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: ValueListenableBuilder<int>(
                            valueListenable: AppStatsService.appLaunchCountNotifier,
                            builder: (context, launchCount, child) {
                              final displayValue = '$launchCount $launchUnit';
                              return _buildStatCard(
                                context,
                                displayValue,
                                launchCountLabel,
                                accentColor: const Color(0xFF9B51E0),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 辅助方法：构建单个统计卡片
  Widget _buildStatCard(BuildContext context, String value, String label, {required Color accentColor}) {
    final theme = CupertinoTheme.of(context);
    final parts = value.split(' ');
    final primaryText = parts.isNotEmpty ? parts.first : value;
    final secondaryText = parts.length > 1 ? value.substring(value.indexOf(' ')).trim() : '';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 68),
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.separator.resolveFrom(context).withOpacity(0.7)),
        boxShadow: [
          BoxShadow(color: CupertinoColors.systemGrey.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.textStyle.copyWith(
                    fontSize: 9,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      primaryText,
                      style: theme.textTheme.textStyle.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (secondaryText.isNotEmpty) ...[
                      const SizedBox(width: 2),
                      Text(
                        secondaryText,
                        style: theme.textTheme.textStyle.copyWith(
                          fontSize: 10,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ],
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

  Future<void> _quickAddDailySentence(BuildContext context) async {
    final textController = TextEditingController();
    final sentenceController = DailySentenceController();
    final theme = CupertinoTheme.of(context);

    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text(
            LocalizationEngine.text('daily_sentence'),
            style: TextStyle(color: CupertinoColors.label.resolveFrom(context)),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: CupertinoTextField(
              controller: textController,
              autofocus: true,
              maxLines: 6,
              placeholder: LocalizationEngine.text('enter_content'),
              style: TextStyle(color: CupertinoColors.label.resolveFrom(context)),
              placeholderStyle: TextStyle(color: CupertinoColors.placeholderText.resolveFrom(context)),
              decoration: BoxDecoration(
                color: theme.barBackgroundColor,
                border: Border.all(color: CupertinoColors.separator.resolveFrom(context)),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                LocalizationEngine.text('cancel'),
                style: TextStyle(color: CupertinoColors.label.resolveFrom(context)),
              ),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                final content = textController.text.trim();
                if (content.isNotEmpty) {
                  await sentenceController.addSentence(content);
                }
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: Text(
                LocalizationEngine.text('save'),
                style: TextStyle(color: theme.primaryColor),
              ),
            ),
          ],
        );
      },
    );

    sentenceController.dispose();
  }

  Widget _dailySentence(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocalizationEngine.text('daily_sentence'),
            style: theme.textTheme.textStyle.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            constraints: const BoxConstraints(minHeight: 70, maxHeight: 88),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CupertinoColors.separator.resolveFrom(context)),
              boxShadow: [
                BoxShadow(color: CupertinoColors.systemGrey.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 3)),
              ],
            ),
            child: ValueListenableBuilder<List<DailySentenceModel>>(
              valueListenable: DailySentenceService.sentencesNotifier,
              builder: (context, sentences, child) {
                final latest = sentences.isNotEmpty ? sentences.last.content : '知识改变命运，阅读点亮人生。';
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        latest,
                        style: theme.textTheme.textStyle.copyWith(
                          fontSize: 13,
                          height: 1.5,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: const EdgeInsets.all(6),
                      minSize: 36,
                      onPressed: () => _quickAddDailySentence(context),
                      child: Icon(
                        CupertinoIcons.add_circled_solid,
                        size: 20,
                        color: CupertinoTheme.of(context).primaryColor,
                      ),
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
