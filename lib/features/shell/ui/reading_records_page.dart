import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../engine/localization_engine.dart';
import '../controller/bookshelf_controller.dart';
import '../model/book_model.dart';
import '../service/reading_session_service.dart';
import 'book_viewer_page.dart';
import 'comic_viewer_page.dart';
import 'epub_viewer_page.dart';
import 'txt_viewer_page.dart';

/// ReadingRecordsPage —— 全部阅读记录页（阅读统计详情页「查看全部」入口的目标页）。
/// 展示全部阅读会话（每次打开阅读器即一条：书名 + 开始时间 + 本次阅读时长），
/// 以及读完了哪些书、累计读完耗时。所有颜色走主题系统、文本全部走 LocalizationEngine。
class ReadingRecordsPage extends StatefulWidget {
  const ReadingRecordsPage({super.key});

  @override
  State<ReadingRecordsPage> createState() => _ReadingRecordsPageState();
}

class _ReadingRecordsPageState extends State<ReadingRecordsPage> {
  final BookshelfController _controller = BookshelfController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return ValueListenableBuilder<List<BookModel>>(
      valueListenable: _controller.books,
      builder: (context, books, child) {
        // bookId -> BookModel 反查表
        final bookMap = <String, BookModel>{for (final b in books) b.id: b};

        return ValueListenableBuilder<List<ReadingSession>>(
          valueListenable: ReadingSessionService.sessionsNotifier,
          builder: (context, sessions, _) {
            // 读完了的书籍（按累计进度判定）及其累计阅读总时长
            final finished = books
                .where((b) => b.progress >= 1.0)
                .toList()
              ..sort((a, b) =>
                  (b.lastReadAt ?? DateTime(2000))
                      .compareTo(a.lastReadAt ?? DateTime(2000)));
            final finishedSeconds =
                finished.fold<int>(0, (sum, b) => sum + b.readingDurationSeconds);

            final hasData = sessions.isNotEmpty || finished.isNotEmpty;

            return CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(
                leading: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.maybePop(context),
                  child: Icon(
                    CupertinoIcons.back,
                    size: 22,
                    color: theme.textTheme.textStyle.color,
                  ),
                ),
                middle: Text(
                  LocalizationEngine.text('all_reading_records'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.textStyle.color,
                  ),
                ),
              ),
              child: SafeArea(
                child: !hasData
                    // 空状态
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            LocalizationEngine.text('records_empty'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                            ),
                          ),
                        ),
                      )
                    // 记录列表
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        children: [
                          // 概览：阅读次数 / 读完本数 / 读完耗时
                          _buildSummary(
                            theme,
                            sessions.length,
                            finished.length,
                            finishedSeconds,
                          ),
                          const SizedBox(height: 18),
                          // 阅读明细（会话列表）
                          _sectionHeader(
                            LocalizationEngine.text('records_detail'),
                          ),
                          const SizedBox(height: 8),
                          ...sessions.map((s) => _SessionListRow(
                                theme: theme,
                                book: bookMap[s.bookId],
                                session: s,
                                onTap: () => _openBook(bookMap[s.bookId]),
                              )),
                          // 读完了
                          if (finished.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            _sectionHeader(
                              '${LocalizationEngine.text('records_finished')} (${finished.length})',
                            ),
                            const SizedBox(height: 8),
                            ...finished.map((b) => ReadingRecordRow(
                                  theme: theme,
                                  book: b,
                                  onTap: () => _openBook(b),
                                )),
                          ],
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }

  /// 概览统计：阅读次数 / 读完本数 / 读完耗时。
  Widget _buildSummary(
    CupertinoThemeData theme,
    int sessionCount,
    int finishedCount,
    int finishedSeconds,
  ) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: '$sessionCount',
            label: LocalizationEngine.text('records_session_count'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            value: '$finishedCount',
            label: LocalizationEngine.text('records_finished_count'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            value: formatSessionDuration(finishedSeconds),
            label: LocalizationEngine.text('records_finished_time'),
          ),
        ),
      ],
    );
  }

  /// 概览单块统计（数值 + 标签）。
  Widget _StatTile({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  /// 分组小标题。
  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: CupertinoColors.label.resolveFrom(context),
        ),
      ),
    );
  }

  /// 根据书籍格式跳转到对应阅读器（PDF/EPUB/TXT/漫画）。
  void _openBook(BookModel? book) {
    if (book == null) return;
    final path = book.path.toLowerCase();
    if (path.endsWith('.pdf')) {
      Navigator.of(context).push(CupertinoPageRoute(
        builder: (_) => BookViewerPage(
          title: book.title,
          filePath: book.path,
          bookId: book.id,
          controller: _controller,
        ),
      ));
    } else if (path.endsWith('.epub')) {
      Navigator.of(context).push(CupertinoPageRoute(
        builder: (_) => EpubViewerPage(
          title: book.title,
          filePath: book.path,
          bookId: book.id,
          controller: _controller,
        ),
      ));
    } else if (path.endsWith('.txt')) {
      Navigator.of(context).push(CupertinoPageRoute(
        builder: (_) => TxtViewerPage(
          title: book.title,
          filePath: book.path,
          bookId: book.id,
          controller: _controller,
        ),
      ));
    } else if (path.endsWith('.cbz') ||
        path.endsWith('.cbr') ||
        path.endsWith('.cb7') ||
        path.endsWith('.cbt') ||
        path.endsWith('.zip')) {
      Navigator.of(context).push(CupertinoPageRoute(
        builder: (_) => ComicViewerPage(
          title: book.title,
          filePath: book.path,
          bookId: book.id,
          controller: _controller,
        ),
      ));
    }
  }
}

/// 单次阅读会话行（全部记录页用）：封面 + 书名 + 「HH:MM 开始 · 读了 Y 分钟」。
class _SessionListRow extends StatelessWidget {
  final CupertinoThemeData theme;
  final BookModel? book;
  final ReadingSession session;
  final VoidCallback onTap;

  const _SessionListRow({
    required this.theme,
    required this.book,
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cover = book?.coverBytes;
    final title = book?.title ?? LocalizationEngine.text('unknown_book');
    final timeText =
        '${formatSessionTime(session.startedAt)}${LocalizationEngine.text('session_start_suffix')} · ${LocalizationEngine.text('session_read_prefix')}${formatSessionDuration(session.durationSeconds)}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: CupertinoColors.systemGrey5,
              ),
              child: cover != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(cover, fit: BoxFit.cover),
                    )
                  : const Icon(
                      CupertinoIcons.book,
                      size: 20,
                      color: CupertinoColors.systemGrey,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_right,
              size: 15,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// 阅读记录单行卡片（封面 + 书名 + 阅读时长 + 阅读日期）。
/// 纯展示组件：数据通过构造函数传入，交互通过 onTap 回调抛出，便于跨页复用。
class ReadingRecordRow extends StatelessWidget {
  final CupertinoThemeData theme;
  final BookModel book;
  final VoidCallback onTap;

  const ReadingRecordRow({
    super.key,
    required this.theme,
    required this.book,
    required this.onTap,
  });

  /// 将阅读时长（秒）格式化为「X小时Y分钟」/「Y分钟」，单位走本地化。
  String _durationText() {
    final durMin = book.readingDurationSeconds ~/ 60;
    if (durMin <= 0) return '';
    final h = durMin ~/ 60;
    final m = durMin % 60;
    final hourUnit = LocalizationEngine.text('hours_short');
    final minUnit = LocalizationEngine.text('minutes_short');
    if (h > 0) return '$h$hourUnit$m$minUnit';
    return '$m$minUnit';
  }

  /// 将最后阅读时间格式化为「YYYY/MM/DD」的中性数字格式（不含硬编码文本）。
  String _dateText() {
    final d = book.lastReadAt;
    if (d == null) return '';
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}/$mm/$dd';
  }

  @override
  Widget build(BuildContext context) {
    final cover = book.coverBytes;
    final durText = _durationText();
    final dateStr = _dateText();

    // 副标题：阅读时长 + 阅读日期，按有无数据动态拼接
    final parts = <String>[];
    if (durText.isNotEmpty) {
      parts.add('${LocalizationEngine.text('record_duration_label')} $durText');
    }
    if (dateStr.isNotEmpty) {
      parts.add('${LocalizationEngine.text('record_read_on')} $dateStr');
    }
    final subtitle = parts.join('  ·  ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 封面缩略图
            Container(
              width: 44,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: CupertinoColors.systemGrey5,
              ),
              child: cover != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(cover, fit: BoxFit.cover),
                    )
                  : const Icon(
                      CupertinoIcons.book,
                      size: 20,
                      color: CupertinoColors.systemGrey,
                    ),
            ),
            const SizedBox(width: 12),
            // 书名 + 时长 + 日期
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 阅读进度条
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: book.progress.clamp(0.0, 1.0),
                      minHeight: 4,
                      color: theme.primaryColor,
                      backgroundColor: CupertinoColors.systemGrey5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_right,
              size: 15,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }
}
