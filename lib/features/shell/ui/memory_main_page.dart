import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../engine/localization_engine.dart';
import '../controller/bookshelf_controller.dart';
import '../model/book_model.dart';
import '../model/reading_stats_model.dart';
import '../service/reader_data_service.dart';
import '../service/reading_session_service.dart';
import 'book_viewer_page.dart';
import 'comic_viewer_page.dart';
import 'epub_viewer_page.dart';
import 'memory_page.dart';
import 'forgotten_books_page.dart';
import 'reading_timeline_page.dart';
import 'all_bookmarks_page.dart';
import 'timeline_entry.dart';
import 'txt_viewer_page.dart';

/// MemoryMainPage 是新的一级“阅读回忆”长滚动页面。
class MemoryMainPage extends StatefulWidget {
  const MemoryMainPage({super.key});

  @override
  State<MemoryMainPage> createState() => _MemoryMainPageState();
}

class _MemoryMainPageState extends State<MemoryMainPage> {
  final BookshelfController _controller = BookshelfController();
  final ScrollController _scrollController = ScrollController();

  /// 当前选中的统计周期索引（0=周, 1=月, 2=年, 3=全部）
  int _selectedPeriodIndex = 0;

  /// 热力图当前展示的月份（由卡片右上「月份 ▼」按钮切换，默认当前月）
  DateTime _heatmapMonth = DateTime(DateTime.now().year, DateTime.now().month);

  /// 跨书最近书签（最多 3 条，按添加时间倒序），用于「去年的今天」下方的书签卡片。
  List<BookmarkWithBook> _recentBookmarks = const [];

  /// 收藏笔记真实总数（替代占位常量），用于阅读统计卡片。
  int _totalNotesCount = 0;

  /// 随机回忆抽取到的真实笔记（含所属书籍信息）；null 表示暂无笔记。
  NoteWithBook? _randomMemoryNote;

  /// 阅读日历当前展示的月份（默认当前月）。
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);

  /// 阅读日历格子内容：false=显示当日阅读时长最多的书封面；true=显示当日阅读时长文本。
  bool _calendarShowDuration = false;

  @override
  void initState() {
    super.initState();
    _loadRecentBookmarks();
    _loadTotalNotes();
    _loadRandomMemory();
    // 书籍列表异步就绪后，书签标题需要重新解析（避免回退为「未知书籍」）。
    _controller.books.addListener(_loadRecentBookmarks);
    _controller.books.addListener(_loadTotalNotes);
    _controller.books.addListener(_loadRandomMemory);
    // 阅读会话变化（如本次阅读结束记录）时刷新阅读日历。
    ReadingSessionService.sessionsNotifier.addListener(_onSessionsChanged);
  }

  @override
  void dispose() {
    _controller.books.removeListener(_loadRecentBookmarks);
    _controller.books.removeListener(_loadTotalNotes);
    _controller.books.removeListener(_loadRandomMemory);
    ReadingSessionService.sessionsNotifier.removeListener(_onSessionsChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 阅读会话变化 → 重绘阅读日历。
  void _onSessionsChanged() {
    if (mounted) setState(() {});
  }

  /// 加载跨书收藏笔记总数（真实数据）。
  void _loadTotalNotes() {
    final ids = _controller.books.value.map((b) => b.id).toList();
    ReaderDataStore.countAllNotes(ids).then((count) {
      if (!mounted) return;
      setState(() => _totalNotesCount = count);
    });
  }

  /// 从真实笔记中随机抽一条用于「随机回忆」；无笔记时置 null（卡片显示空态）。
  void _loadRandomMemory() {
    final books = _controller.books.value;
    final titleMap = <String, String>{
      for (final b in books) b.id: b.title,
    };
    ReaderDataStore.loadAllNotes(
      books.map((b) => b.id).toList(),
      (id) => titleMap[id] ?? LocalizationEngine.text('unknown_book'),
    ).then((notes) {
      if (!mounted) return;
      if (notes.isEmpty) {
        setState(() => _randomMemoryNote = null);
        return;
      }
      // 用微秒时间戳取模做轻量随机，避免额外 import dart:math。
      final r = DateTime.now().microsecondsSinceEpoch % notes.length;
      setState(() => _randomMemoryNote = notes[r]);
    });
  }

  /// 加载跨书最近 3 条书签（书名通过当前书籍列表解析）。
  void _loadRecentBookmarks() {
    final books = _controller.books.value;
    final titleMap = <String, String>{
      for (final b in books) b.id: b.title,
    };
    ReaderDataStore.loadAllBookmarks(
      books.map((b) => b.id).toList(),
      (id) => titleMap[id] ?? LocalizationEngine.text('unknown_book'),
    ).then((list) {
      if (!mounted) return;
      setState(() => _recentBookmarks = list.take(3).toList());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return ValueListenableBuilder<List<BookModel>>(
      valueListenable: _controller.books,
      builder: (context, books, child) {
        final stats = ReadingStats.fromBooks(books);
        final yearHours = (stats.yearMinutes / 60).round();
        // 「今年已读」统计【已读完】的书籍（进度 100% 且最后阅读时间在今年），而非点开过的书
        final now = DateTime.now();
        final yearStart = DateTime(now.year, 1, 1);
        final yearEnd = DateTime(now.year + 1, 1, 1);
        final bookCount =
            ReadingStats.completedBooksInRange(books, yearStart, yearEnd);
        final estimatedPages = (stats.yearMinutes * 1.5).round();

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '阅读回忆',
                    style: theme.textTheme.navTitleTextStyle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '今年已阅读 $yearHours 小时 · $bookCount 本书 · $estimatedPages 页',
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {},
              child: const Icon(CupertinoIcons.calendar, size: 20),
            ),
          ),
          child: SafeArea(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 去年的今天卡片
                    _buildLastYearCard(theme, books),
                    const SizedBox(height: 12),

                    // 书签卡片：最近 3 条书签（书签名 / 书籍名 / 添加时间）
                    _buildBookmarkCard(theme),
                    const SizedBox(height: 12),

                    // 随机回忆卡片
                    _buildRandomMemoryCard(theme, books),
                    const SizedBox(height: 12),

                    // 本周阅读时长卡片（点击进入详细统计页）
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(builder: (_) => const MemoryPage()),
                      ),
                      child: _buildWeeklyChartCard(theme, stats),
                    ),
                    const SizedBox(height: 12),

                    // 阅读统计卡片（周/月/年/全部 + 四项数据 + 右上「统计页」入口）
                    _buildReadingStatsCard(theme, books, stats),
                    const SizedBox(height: 12),

                    // 阅读时间轴（按月展示真实数据，查看全部进入时间轴全量页）
                    _buildTimelineCard(theme, books),
                    const SizedBox(height: 12),

                    // 阅读热力图（日历网格）
                    _buildHeatmapCard(theme, stats),
                    const SizedBox(height: 12),

                    // 阅读日历：当月网格，每格显示当日阅读时长最多的书封面（或时长）
                    _buildReadingCalendarCard(theme, books),
                    const SizedBox(height: 12),

                    // 被遗忘的书籍（简要列表）
                    _buildForgottenBooksCard(theme, books),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 根据书籍格式跳转到对应阅读器（PDF/EPUB/TXT/漫画），不支持或为空则提示。
  void _openBook(BookModel? book) {
    if (book == null) {
      showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('书籍已被删除'),
          content: const Text('随机回忆中的书籍不存在，请返回书架重新选择。'),
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

  Widget _buildLastYearCard(CupertinoThemeData theme, List<BookModel> books) {
    final book = books.isNotEmpty ? books.first : null;
    final cover = book?.coverBytes;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionIcon(theme, CupertinoIcons.calendar),
              const SizedBox(width: 10),
              Text(
                LocalizationEngine.text('last_year_today'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              const Spacer(),
              Text(
                '${DateTime.now().year - 1}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().day.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: CupertinoColors.systemGrey5,
                ),
                child: cover != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(cover, fit: BoxFit.cover),
                      )
                    : const Icon(
                        CupertinoIcons.book,
                        size: 36,
                        color: CupertinoColors.systemGrey,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book?.title ?? '《Flutter 实战》',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: book?.progress ?? 0.3,
                        minHeight: 8,
                        color: CupertinoTheme.of(context).primaryColor,
                        backgroundColor: CupertinoColors.systemGrey4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          onPressed: () {},
                          child: const Text('继续阅读'),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          onPressed: () {},
                          child: const Icon(CupertinoIcons.ellipsis_circle),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建书签卡片：展示跨书最近 3 条书签（书签名 / 书籍名 / 添加时间），
  /// 右上「查看全部」进入所有书籍书签页，风格与「去年的今天」卡片保持一致。
  Widget _buildBookmarkCard(CupertinoThemeData theme) {
    final primary = theme.primaryColor;
    final lavenderBg =
        CupertinoColors.secondarySystemBackground.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    String fmt(int millis) {
      final t = DateTime.fromMillisecondsSinceEpoch(millis);
      final p = (int v) => v.toString().padLeft(2, '0');
      return '${t.year}-${p(t.month)}-${p(t.day)} ${p(t.hour)}:${p(t.minute)}';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: lavenderBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionIcon(theme, CupertinoIcons.bookmark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  LocalizationEngine.text('reader_bookmarks'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 28,
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => const AllBookmarksPage(),
                  ),
                ),
                child: Text(
                  LocalizationEngine.text('view_all'),
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        CupertinoColors.tertiaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_recentBookmarks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                LocalizationEngine.text('reader_bookmarks_empty'),
                style: TextStyle(fontSize: 13, color: secondary),
              ),
            )
          else
            Column(
              children: _recentBookmarks.map((item) {
                final b = item.bookmark;
                final name = b.label.isNotEmpty
                    ? b.label
                    : '${LocalizationEngine.text('reader_nav_progress')} ${b.pageNumber}';
                final timeStr = b.createdAt > 0 ? fmt(b.createdAt) : '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => _openBook(_controller.getBook(item.bookId)),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.bookmark, size: 16, color: primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.label
                                      .resolveFrom(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.title} · $timeStr',
                                style: TextStyle(fontSize: 12, color: secondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: 14,
                          color: secondary,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildRandomMemoryCard(
    CupertinoThemeData theme,
    List<BookModel> books,
  ) {
    final primary = theme.primaryColor;
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final note = _randomMemoryNote;
    final book = note != null ? _controller.getBook(note.bookId) : null;
    final hasData = note != null && book != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionIcon(theme, CupertinoIcons.shuffle),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  LocalizationEngine.text('random_memory'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: labelColor,
                  ),
                ),
              ),
              // 刷新：从真实笔记中重新随机抽一条
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
                onPressed: _loadRandomMemory,
                child: Icon(
                  CupertinoIcons.refresh,
                  color: secondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasData) ...[
            Text(
              book!.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '当时的笔记：${note!.note.summary}',
              style: TextStyle(color: secondaryColor),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.bottomRight,
              child: CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                onPressed: () => _openBook(book),
                child: const Text('继续阅读'),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '还没有笔记，先去读书并记点想法吧～',
                style: TextStyle(color: secondaryColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChartCard(CupertinoThemeData theme, ReadingStats stats) {
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 13));
    final bars = List<int>.generate(14, (index) {
      final date = start.add(Duration(days: index));
      return stats.dailyMinutes[date] ?? 0;
    });
    final maxBarValue = bars.isEmpty
        ? 1
        : bars
              .reduce((a, b) => a > b ? a : b)
              .clamp(1, double.infinity)
              .toInt();
    final durationText =
        '${(stats.weekMinutes / 60).floor()} 小时 ${stats.weekMinutes % 60} 分钟';
    final compareText = stats.weekChangeLabel;
    final isIncrease = stats.weekMinutes >= stats.previousWeekMinutes;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _sectionIcon(theme, CupertinoIcons.clock),
                    const SizedBox(width: 10),
                    Text(
                      LocalizationEngine.text('weekly_reading_duration'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 72,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: bars.map((value) {
                      final barHeight = 18.0 + (value / maxBarValue) * 36.0;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.34),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  durationText,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      LocalizationEngine.text('weekly_compare_prefix'),
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isIncrease
                          ? CupertinoIcons.arrow_up
                          : CupertinoIcons.arrow_down,
                      size: 12,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      compareText,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(CupertinoThemeData theme, List<BookModel> books) {
    final primary = theme.primaryColor;
    final lavenderBg = CupertinoColors.secondarySystemBackground.resolveFrom(context);

    // 按月聚合真实阅读数据（倒序，最近的月份在前），主卡片最多展示最近 5 个月
    final records = MonthTimelineRecord.monthTimeline(books);
    final visible = records.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: lavenderBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionIcon(theme, Icons.timeline),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  LocalizationEngine.text('reading_timeline'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 28,
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => ReadingTimelinePage(books: books),
                  ),
                ),
                child: Text(
                  LocalizationEngine.text('view_all'),
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 时间轴列表：最多展示最近 5 个月，超出部分由「查看全部」进入全量页
          visible.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    LocalizationEngine.text('records_empty'),
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: SingleChildScrollView(
                    child: Column(
                      children: visible.asMap().entries.map((e) {
                        final index = e.key;
                        final record = e.value;
                        return timelineEntryFromRecord(
                          record,
                          context,
                          isFirst: index == 0,
                          isLast: index == visible.length - 1,
                          // 仅一个月时强制竖线延伸到底，暗示时间轴后面还有内容。
                          extendLine: visible.length == 1,
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  /// 构建阅读统计卡片：包含周期切换 Tab（周/月/年/全部）和四项统计数据。
  Widget _buildReadingStatsCard(
    CupertinoThemeData theme,
    List<BookModel> books,
    ReadingStats stats,
  ) {
    final primary = theme.primaryColor;
    final lavenderBg = CupertinoColors.secondarySystemBackground.resolveFrom(context);

    // 周期标签列表
    final periodTabs = [
      LocalizationEngine.text('stats_tab_week'),
      LocalizationEngine.text('stats_tab_month'),
      LocalizationEngine.text('stats_tab_year'),
      LocalizationEngine.text('stats_tab_all'),
    ];

    /// 根据当前选中的周期，从 stats 中提取对应数据
    int _periodMinutes() {
      switch (_selectedPeriodIndex) {
        case 0:
          return stats.weekMinutes; // 周
        case 1:
          return stats.monthMinutes; // 月
        case 2:
          return stats.yearMinutes; // 年
        default:
          return stats.totalMinutes; // 全部
      }
    }

    /// 根据当前选中的周期，计算区间 [start, end)（用于统计「读完」的书籍本数）
    (DateTime, DateTime) _periodBounds() {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      switch (_selectedPeriodIndex) {
        case 0: // 周：本周一 ~ 下周一
          final start = today.subtract(Duration(days: today.weekday - 1));
          return (start, start.add(const Duration(days: 7)));
        case 1: // 月：本月 1 号 ~ 下月 1 号
          final start = DateTime(now.year, now.month, 1);
          return (start, DateTime(now.year, now.month + 1, 1));
        case 2: // 年：今年 1 月 1 号 ~ 明年 1 月 1 号
          final start = DateTime(now.year, 1, 1);
          return (start, DateTime(now.year + 1, 1, 1));
        default: // 全部：极早 ~ 明年（即所有历史读完的书籍）
          return (DateTime(1970), DateTime(now.year + 1, 1, 1));
      }
    }

    final hours = (_periodMinutes() / 60).round();
    // 「阅读书籍本数」统计【已读完】的书籍（进度 100% 且最后阅读时间落在该周期内）
    final (start, end) = _periodBounds();
    final bookCount = ReadingStats.completedBooksInRange(books, start, end);
    // 按平均每分钟 1.5 页估算阅读页数（与导航栏副标题保持一致）
    final pages = (_periodMinutes() * 1.5).round();
    final notesCount = _totalNotesCount; // 收藏笔记真实总数（跨书汇总）

    /// 单个统计数字卡片
    Widget statItem({
      required IconData icon,
      required String value,
      required String label,
    }) {
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: primary, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lavenderBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题：阅读统计（右侧「统计页」入口，点击进入阅读统计详情页）
          Row(
            children: [
              _sectionIcon(theme, CupertinoIcons.chart_bar),
              const SizedBox(width: 10),
              Text(
                LocalizationEngine.text('reading_statistics'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 28,
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const MemoryPage()),
                ),
                child: Text(
                  LocalizationEngine.text('stats_page_enter'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 周期切换 Tab（周/月/年/全部）：移至标题下方，使用 Expanded 均分卡片宽度
          Row(
            children: periodTabs.asMap().entries.map((entry) {
              final index = entry.key;
              final label = entry.value;
              final isSelected = index == _selectedPeriodIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPeriodIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 34,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: isSelected ? primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? CupertinoColors.white
                            : CupertinoColors.secondaryLabel.resolveFrom(
                                context,
                              ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 四列统计数据
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              statItem(
                icon: CupertinoIcons.clock,
                value: '$hours',
                label: LocalizationEngine.text('stats_reading_hours_label'),
              ),
              statItem(
                icon: CupertinoIcons.book,
                value: '$bookCount',
                label: LocalizationEngine.text('stats_reading_books_label'),
              ),
              statItem(
                icon: CupertinoIcons.doc_text,
                value: '$pages',
                label: LocalizationEngine.text('stats_reading_pages_label'),
              ),
              statItem(
                icon: CupertinoIcons.star,
                value: '$notesCount',
                label: LocalizationEngine.text('stats_notes_count_label'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建阅读热力图卡片：日历网格 + 紫色渐变强度 + 底部图例。
  Widget _buildHeatmapCard(CupertinoThemeData theme, ReadingStats stats) {
    final primary = theme.primaryColor;
    final lavenderBg = CupertinoColors.secondarySystemBackground.resolveFrom(context);

    // 当前展示月份的日历数据：按周分行，每行包含 [日期标签 + 7天格子]
    final month = _heatmapMonth;
    // 取展示月第一天（周一为起始）
    final monthStart = DateTime(month.year, month.month, 1);
    // 展示月第一天是周几（1=周一 ... 7=周日），调整偏移使周一为第0列
    var startWeekday = monthStart.weekday; // 1=Mon .. 7=Sun
    // 展示月天数
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    /// 构造按周分行的网格数据：每行 = {weekLabel, List<DayCell?>}
    /// DayCell 为 null 表示该格不属于当前月份
    final gridRows = <_HeatmapRow>[];
    var currentDay = 1;

    // 第一行可能需要填充月初空白
    var firstRowCells = <_DayCell?>[];
    for (var i = 1; i < startWeekday; i++) {
      firstRowCells.add(null); // 上月占位
    }
    while (firstRowCells.length < 7 && currentDay <= daysInMonth) {
      final date = DateTime(month.year, month.month, currentDay);
      final blockMinutes = stats.dailyBlockMinutes[date] ?? [0, 0, 0, 0];
      firstRowCells.add(_DayCell(date: date, blockMinutes: blockMinutes));
      currentDay++;
    }
    if (firstRowCells.isNotEmpty) {
      gridRows.add(_HeatmapRow(
        label: '${month.month}/${firstRowCells.firstWhere((c) => c != null)?.date.day ?? currentDay}',
        cells: firstRowCells,
      ));
    }

    // 后续整行
    while (currentDay <= daysInMonth) {
      final rowCells = <_DayCell?>[];
      for (var col = 0; col < 7 && currentDay <= daysInMonth; col++) {
        final date = DateTime(month.year, month.month, currentDay);
        final blockMinutes = stats.dailyBlockMinutes[date] ?? [0, 0, 0, 0];
        rowCells.add(_DayCell(date: date, blockMinutes: blockMinutes));
        currentDay++;
      }
      if (rowCells.isNotEmpty) {
        gridRows.add(_HeatmapRow(
          label: '${month.month}/${rowCells.firstWhere((c) => c != null)?.date.day ?? currentDay}',
          cells: rowCells,
        ));
      }
    }

    /// 周几表头（周一 ~ 周日）
    const weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

    /// 根据单个「6 小时段」的阅读分钟数返回对应颜色（主题主色派生，不写死十六进制）。
    /// 阈值按 6 小时段等比下调：无数据=极浅灰；其余按 0.20/0.40/0.65/主色 四档。
    Color _blockColor(int minutes) {
      if (minutes <= 0) {
        return CupertinoColors.systemGrey5.resolveFrom(context); // 无数据：浅灰底（比卡片背景深一档，确保方框在明暗模式下都可见）
      }
      if (minutes < 8) return primary.withValues(alpha: 0.20); // Level 1
      if (minutes < 20) return primary.withValues(alpha: 0.40); // Level 2
      if (minutes < 45) return primary.withValues(alpha: 0.65); // Level 3
      return primary; // Level 4+：主色最深
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: lavenderBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              _sectionIcon(theme, CupertinoIcons.flame),
              const SizedBox(width: 10),
              Text(
                LocalizationEngine.text('reading_heatmap'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              const Spacer(),
              GestureDetector(
                // 点击弹出月份选择器，切换热力图展示的月份
                onTap: _showHeatmapMonthPicker,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_heatmapMonth.year}${LocalizationEngine.text('year_unit')}${_heatmapMonth.month}${LocalizationEngine.text('month_unit')}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      CupertinoIcons.chevron_down,
                      size: 12,
                      color: primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 热力图网格：所有方格统一尺寸（用 LayoutBuilder 计算 cellSize，保证每个日期的格子完全一致）
          LayoutBuilder(
            builder: (ctx, constraints) {
              const labelWidth = 32.0;
              const labelGap = 4.0;
              const gap = 4.0; // 格子之间的水平间距
              // 可用宽度 = 总宽 - 左侧日期标签(32+4) - 6 个格子间缝隙；再均分为 7 列
              final cellSize =
                  ((constraints.maxWidth - labelWidth - labelGap - (7 - 1) * gap) / 7)
                      .clamp(10.0, 60.0);

              // 周几表头（与数据列严格对齐：同样左偏移 + 同样 gap + 同样 cellSize）
              final header = Padding(
                padding: const EdgeInsets.only(left: labelWidth + labelGap),
                child: Row(
                  children: [
                    for (var i = 0; i < weekdayLabels.length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      SizedBox(
                        width: cellSize,
                        child: Center(
                          child: Text(
                            weekdayLabels[i],
                            style: TextStyle(
                              fontSize: 11,
                              color: CupertinoColors.tertiaryLabel.resolveFrom(ctx),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );

              // 单个日期格：切分为 2×2 四象限，分别对应当日 4 个「6 小时段」的阅读情况
              Widget _dayCell(_DayCell? cell) {
                if (cell == null) {
                  return SizedBox(width: cellSize, height: cellSize); // 非当月：留空
                }
                final b = cell.blockMinutes;
                const subGap = 2.0; // 象限之间的细微间隙
                Widget quad(int mins) => Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _blockColor(mins),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: CupertinoColors.separator
                                .resolveFrom(context)
                                .withValues(alpha: 0.35),
                            width: 0.5,
                          ),
                        ),
                      ),
                    );
                return SizedBox(
                  width: cellSize,
                  height: cellSize,
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            quad(b[0]),
                            const SizedBox(width: subGap),
                            quad(b[1]),
                          ],
                        ),
                      ),
                      const SizedBox(height: subGap),
                      Expanded(
                        child: Row(
                          children: [
                            quad(b[2]),
                            const SizedBox(width: subGap),
                            quad(b[3]),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // 数据行：左侧日期标签 + 7 个统一尺寸的「四象限日期格」
              final rows = gridRows.map((row) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: gap),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: labelWidth,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            row.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: CupertinoColors.secondaryLabel.resolveFrom(ctx),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: labelGap),
                      for (var i = 0; i < row.cells.length; i++) ...[
                        if (i > 0) const SizedBox(width: gap),
                        _dayCell(row.cells[i]),
                      ],
                    ],
                  ),
                );
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  const SizedBox(height: 6),
                  ...rows,
                  const SizedBox(height: 8),
                  // 说明：每格拆分为 4 块，分别对应当日 4 个「6 小时段」的阅读情况
                  Text(
                    LocalizationEngine.text('heatmap_block_hint'),
                    style: TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 10),

          // 底部图例：少 ———— 渐变条 ———— 多
          Row(
            children: [
              Text(
                LocalizationEngine.text('heatmap_legend_few'),
                style: TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    colors: [
                      CupertinoColors.systemGrey5.resolveFrom(context),
                      primary.withValues(alpha: 0.20),
                      primary.withValues(alpha: 0.40),
                      primary.withValues(alpha: 0.65),
                      primary,
                    ],
                  ),
                ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                LocalizationEngine.text('heatmap_legend_many'),
                style: TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 计算自上次打开以来的天数（从未打开则返回极大值，使其排在列表最前）。
  int _daysSinceOpened(BookModel book) {
    if (book.lastReadAt == null) return 99999;
    return DateTime.now().difference(book.lastReadAt!).inDays;
  }

  /// 弹出月份选择器（Cupertino 风格底部弹层），选择后更新热力图展示的月份。
  /// 仅允许选择当前月起至 2000 年 1 月之间（maximumDate = 此刻），避免选到未来。
  void _showHeatmapMonthPicker() {
    DateTime picked = _heatmapMonth;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: Text(
                    LocalizationEngine.text('cancel'),
                    style: TextStyle(
                      color: CupertinoTheme.of(ctx).primaryColor,
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                ),
                CupertinoButton(
                  child: Text(
                    LocalizationEngine.text('done'),
                    style: TextStyle(
                      color: CupertinoTheme.of(ctx).primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () {
                    setState(() => _heatmapMonth = picked);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.monthYear,
                initialDateTime: _heatmapMonth,
                minimumDate: DateTime(2000, 1),
                maximumDate: DateTime.now(),
                onDateTimeChanged: (d) => picked = d,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 统一的分区标题前置图标：圆角方块 + 主题色（暗色卡片用白色）浅底图标，
  /// 风格现代统一，配合标题让人一眼看懂该分区含义。
  Widget _sectionIcon(CupertinoThemeData theme, IconData icon,
      {bool onDark = false}) {
    final color = onDark ? CupertinoColors.white : theme.primaryColor;
    final bg = onDark
        ? CupertinoColors.white.withValues(alpha: 0.18)
        : theme.primaryColor.withValues(alpha: 0.12);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 17, color: color),
    );
  }

  /// 将阅读秒数压缩为单元格内的短文本（如 1h20m / 45m / 0m），中性不本地化。
  String _compactDuration(int seconds) {
    final m = (seconds / 60).round();
    if (m <= 0) return '0m';
    if (m >= 60) {
      final h = m ~/ 60;
      final mm = m % 60;
      return mm > 0 ? '${h}h${mm}m' : '${h}h';
    }
    return '${m}m';
  }

  /// 由书名生成稳定色块（无封面时占位）。
  Color _coverFallbackColor(String title) {
    const palette = [
      CupertinoColors.systemBlue,
      CupertinoColors.systemGreen,
      CupertinoColors.systemIndigo,
      CupertinoColors.systemOrange,
      CupertinoColors.systemPink,
      CupertinoColors.systemPurple,
      CupertinoColors.systemTeal,
    ];
    return palette[title.hashCode % palette.length];
  }

  /// 构建「阅读日历」卡片：当月网格，每个日期格展示当日阅读时长最多的书封面，
  /// 或（经右上切换）展示当日总阅读时长。数据源为 ReadingSessionService（按日期+按书聚合），
  /// 比 ReadingStats 的「全部堆到 lastReadAt 当天」单点近似更真实。
  Widget _buildReadingCalendarCard(
    CupertinoThemeData theme,
    List<BookModel> books,
  ) {
    final primary = theme.primaryColor;
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final bg = CupertinoColors.secondarySystemBackground.resolveFrom(context);

    final month = _calendarMonth;
    final monthStart = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    // 按 bookId 聚合当日阅读秒数 → 找到时长最多的书与当日总时长。
    Map<String, int> _aggForDay(DateTime day) {
      final byBook = <String, int>{};
      for (final s in ReadingSessionService.sessionsNotifier.value) {
        final d = s.startedAt;
        if (d.year == day.year && d.month == day.month && d.day == day.day) {
          byBook[s.bookId] = (byBook[s.bookId] ?? 0) + s.durationSeconds;
        }
      }
      return byBook;
    }

    final bookMap = <String, BookModel>{for (final b in books) b.id: b};

    // 构造 7 列网格（周一为首列），含月初/月末补空。
    final cells = <DateTime?>[];
    for (var i = 1; i < monthStart.weekday; i++) cells.add(null);
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(month.year, month.month, d));
    }
    while (cells.length % 7 != 0) cells.add(null);

    Widget dayCell(DateTime? day) {
      if (day == null) {
        return const SizedBox.shrink();
      }
      final byBook = _aggForDay(day);
      final has = byBook.isNotEmpty;
      final isToday = day == todayDay;

      // 时长最多的书封面 / 或当日总时长文本
      Widget content;
      if (!has) {
        content = const SizedBox.shrink();
      } else if (_calendarShowDuration) {
        final total = byBook.values.fold(0, (a, b) => a + b);
        content = Center(
          child: Text(
            _compactDuration(total),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
          ),
        );
      } else {
        final top = byBook.entries.reduce((a, b) => a.value >= b.value ? a : b);
        final book = bookMap[top.key];
        if (book?.coverBytes != null) {
          content = Image.memory(
            book!.coverBytes!,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => Container(
              color: _coverFallbackColor(book.title),
            ),
          );
        } else {
          content = Container(color: _coverFallbackColor(book?.title ?? ''));
        }
      }

      return Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: primary, width: 2)
              : null,
          color: has ? null : CupertinoColors.systemGrey6.resolveFrom(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (has) content,
            Positioned(
              top: 3,
              left: 4,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isToday
                      ? primary
                      : (has
                          ? CupertinoColors.white
                          : CupertinoColors.tertiaryLabel.resolveFrom(context)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionIcon(theme, CupertinoIcons.calendar),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '阅读日历',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: labelColor,
                  ),
                ),
              ),
              // 封面 / 时长 切换
              GestureDetector(
                onTap: () =>
                    setState(() => _calendarShowDuration = !_calendarShowDuration),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _calendarShowDuration ? '时长' : '封面',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 月份导航
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 28,
                onPressed: () => setState(() => _calendarMonth =
                    DateTime(month.year, month.month - 1)),
                child: const Icon(CupertinoIcons.chevron_left, size: 18),
              ),
              Text(
                '${month.year}年${month.month}月',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 28,
                onPressed: () => setState(() => _calendarMonth =
                    DateTime(month.year, month.month + 1)),
                child: const Icon(CupertinoIcons.chevron_right, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 星期表头（周一为首列）
          Row(
            children: const ['一', '二', '三', '四', '五', '六', '日']
                .map((w) => Expanded(
                      child: Center(
                        child: Text(
                          w,
                          style: TextStyle(
                            fontSize: 11,
                            color: CupertinoColors.tertiaryLabel,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 1,
            children: cells.map(dayCell).toList(),
          ),
          const SizedBox(height: 6),
          Text(
            '有阅读的日期显示当日阅读最久的书封面；点右上「时长」可切换显示当日总阅读时长。',
            style: TextStyle(fontSize: 11, color: secondaryColor),
          ),
        ],
      ),
    );
  }

  /// 构建"遗忘的书籍"卡片：与截图一致的单行布局——[封面] [标题+天数] [立即查看按钮]。
  Widget _buildForgottenBooksCard(
    CupertinoThemeData theme,
    List<BookModel> books,
  ) {
    final primary = theme.primaryColor;
    final lavenderBg = CupertinoColors.secondarySystemBackground.resolveFrom(context);

    // 筛选「遗忘」书籍：未读完 + 曾经打开过 + 距上次打开已超过 7 天。
    // 刚导入（lastReadAt 为空，从未打开）不计入遗忘，避免新导入即被标记为遗忘。
    final forgotten = books
        .where((b) =>
            b.progress < 1.0 &&
            b.lastReadAt != null &&
            _daysSinceOpened(b) >= 7)
        .toList()
      ..sort((a, b) => _daysSinceOpened(b).compareTo(_daysSinceOpened(a)));

    /// 单行书卡：左侧封面 + 中间标题/天数 + 右侧"立即查看"
    Widget _bookRow(BookModel book) {
      final days = _daysSinceOpened(book);
      final cover = book.coverBytes;
      final daysText = days >= 99999
          ? LocalizationEngine.text('forgotten_never_opened')
          : LocalizationEngine.text('forgotten_days_label')
              .replaceAll('{days}', '$days');
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            // 左侧封面缩略图（48x66，与截图比例一致）
            Container(
              width: 48,
              height: 66,
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
                      size: 22,
                      color: CupertinoColors.systemGrey,
                    ),
            ),
            const SizedBox(width: 12),
            // 中间：书名 + 未打开天数
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
                    daysText,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 右侧：立即查看按钮（紫色圆角药丸）
            GestureDetector(
              onTap: () => _openBook(book),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  LocalizationEngine.text('forgotten_view_now'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lavenderBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：左侧标题 + 右侧「查看更多」入口（布局与阅读时间轴「查看全部」保持一致）
          Row(
            children: [
              _sectionIcon(theme, CupertinoIcons.bookmark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  LocalizationEngine.text('forgotten_books_title'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
              // 仅在遗忘书籍数量超过展示上限（2本）时，于标题右侧显示「查看更多」
              if (forgotten.length > 2)
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(
                        builder: (_) => const ForgottenBooksPage()),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        LocalizationEngine.text('forgotten_view_more'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 13,
                        color: primary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // 书籍列表（纵向堆叠，最多展示 2 本）
          if (forgotten.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  LocalizationEngine.text('forgotten_empty'),
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            )
          else
            ...forgotten.take(2).map(_bookRow),
        ],
      ),
    );
  }
}

/// 热力图单日数据单元
class _DayCell {
  final DateTime date;
  // 4 个「6 小时段」的阅读分钟数：[0]=00~06 [1]=06~12 [2]=12~18 [3]=18~24
  final List<int> blockMinutes;

  _DayCell({required this.date, required this.blockMinutes});

  // 当天总阅读分钟（4 段之和），供需要时回退使用
  int get minutes => blockMinutes.fold<int>(0, (sum, v) => sum + v);
}

/// 热力图按周分行数据
class _HeatmapRow {
  final String label; // 行首日期标签（如 "7/8"）
  final List<_DayCell?> cells; // 7 个格子，null 表示非当月

  _HeatmapRow({required this.label, required this.cells});
}
