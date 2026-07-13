import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../engine/localization_engine.dart';
import '../controller/bookshelf_controller.dart';
import '../model/book_model.dart';
import '../model/reading_stats_model.dart';
import 'book_viewer_page.dart';
import 'comic_viewer_page.dart';
import 'epub_viewer_page.dart';
import 'memory_page.dart';
import 'forgotten_books_page.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return ValueListenableBuilder<List<BookModel>>(
      valueListenable: _controller.books,
      builder: (context, books, child) {
        final stats = ReadingStats.fromBooks(books);
        final yearHours = (stats.yearMinutes / 60).round();
        final bookCount = books.length;
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

                    // 阅读时间轴（简化展示）
                    _buildTimelineCard(theme, stats),
                    const SizedBox(height: 12),

                    // 阅读统计卡片（周/月/年/全部 + 四项数据）
                    _buildReadingStatsCard(theme, stats),
                    const SizedBox(height: 12),

                    // 阅读热力图（日历网格）
                    _buildHeatmapCard(theme, stats),
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
        color: CupertinoColors.white,
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
              Text(
                '✨ 去年的今天',
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
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

  Widget _buildRandomMemoryCard(
    CupertinoThemeData theme,
    List<BookModel> books,
  ) {
    final book = books.length > 1 ? books[1] : null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.systemIndigo.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '🔄 随机回忆',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
                onPressed: () {},
                child: const Icon(
                  CupertinoIcons.refresh,
                  color: CupertinoColors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            book?.title ?? '《安波里姆宝典》',
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "当时的想法：'要保持长期主义'",
            style: TextStyle(color: CupertinoColors.white.withOpacity(0.9)),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.bottomRight,
            child:               CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                onPressed: () => _openBook(book),
                child: const Text('继续阅读'),
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
        color: const Color(0xFFF7F5FF),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9D88E9).withOpacity(0.09),
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
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 32,
                      onPressed: () {},
                      child: const Icon(
                        CupertinoIcons.clear_thick,
                        color: Color(0xFFB7B7B7),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '本周阅读时长',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E2E2E),
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
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A2A2A),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '比上周',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6D6D6D)),
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

  Widget _buildTimelineCard(CupertinoThemeData theme, ReadingStats stats) {
    final primary = theme.primaryColor;
    final lavenderBg = const Color(0xFFF7F5FF);
    final mutedGrey = const Color(0xFF8E8E93);

    Widget _marker({required bool filled, required Color color}) {
      return Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          border: Border.all(
            color: filled ? color : const Color(0xFFBDBDBD),
            width: 1.5,
          ),
          shape: BoxShape.circle,
        ),
      );
    }

    Widget _entry({
      required Widget marker,
      required String title,
      required String subtitle,
      bool isLast = false,
    }) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  marker,
                  if (!isLast) ...[
                    const SizedBox(height: 6),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: const Color(0xFFEAE6F8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      );
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    Icons.auto_awesome, // geometric abstract icon
                    color: primary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '阅读时间轴',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 28,
                onPressed: () {},
                child: Text(
                  '查看全部 >',
                  style: TextStyle(fontSize: 13, color: mutedGrey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Timeline entries
          SizedBox(
            height: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left spacer (markers column handled in _entry)
                Expanded(
                  child: Column(
                    children: [
                      _entry(
                        marker: _marker(filled: true, color: primary),
                        title: '2026年7月',
                        subtitle: '阅读 4 本书 · 47 小时 · 收藏 26 条',
                      ),
                      _entry(
                        marker: _marker(
                          filled: false,
                          color: const Color(0xFFBDBDBD),
                        ),
                        title: '2026年6月',
                        subtitle: '完成 《三体》 · 阅读时长 32 小时',
                      ),
                      _entry(
                        marker: _marker(
                          filled: false,
                          color: const Color(0xFFBDBDBD),
                        ),
                        title: '2026年5月',
                        subtitle: '开始阅读 《Flutter 实战》',
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建阅读统计卡片：包含周期切换 Tab（周/月/年/全部）和四项统计数据。
  Widget _buildReadingStatsCard(CupertinoThemeData theme, ReadingStats stats) {
    final primary = theme.primaryColor;
    final lavenderBg = const Color(0xFFF7F5FF);

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

    final hours = (_periodMinutes() / 60).round();
    final bookCount = _controller.books.value.length;
    // 按平均每分钟 1.5 页估算阅读页数（与导航栏副标题保持一致）
    final pages = (_periodMinutes() * 1.5).round();
    const notesCount = 26; // 收藏笔记数（暂用占位值，后续对接笔记模块）

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
          // 标题行 + 周期切换 Tab
          Row(
            children: [
              Text(
                LocalizationEngine.text('reading_statistics'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              const Spacer(),
              // 周期选择胶囊按钮组
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  shrinkWrap: true,
                  itemCount: periodTabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final isSelected = index == _selectedPeriodIndex;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedPeriodIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          periodTabs[index],
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
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

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
    final lavenderBg = const Color(0xFFF7F5FF);

    // 当前月份的日历数据：按周分行，每行包含 [日期标签 + 7天格子]
    final now = DateTime.now();
    // 取当月第一天（周一为起始）
    final monthStart = DateTime(now.year, now.month, 1);
    // 当月第一天是周几（1=周一 ... 7=周日），调整偏移使周一为第0列
    var startWeekday = monthStart.weekday; // 1=Mon .. 7=Sun
    // 当月天数
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

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
      final date = DateTime(now.year, now.month, currentDay);
      final minutes = stats.dailyMinutes[date] ?? 0;
      firstRowCells.add(_DayCell(date: date, minutes: minutes));
      currentDay++;
    }
    if (firstRowCells.isNotEmpty) {
      gridRows.add(_HeatmapRow(
        label: '${now.month}/${firstRowCells.firstWhere((c) => c != null)?.date.day ?? currentDay}',
        cells: firstRowCells,
      ));
    }

    // 后续整行
    while (currentDay <= daysInMonth) {
      final rowCells = <_DayCell?>[];
      for (var col = 0; col < 7 && currentDay <= daysInMonth; col++) {
        final date = DateTime(now.year, now.month, currentDay);
        final minutes = stats.dailyMinutes[date] ?? 0;
        rowCells.add(_DayCell(date: date, minutes: minutes));
        currentDay++;
      }
      if (rowCells.isNotEmpty) {
        gridRows.add(_HeatmapRow(
          label: '${now.month}/${rowCells.firstWhere((c) => c != null)?.date.day ?? currentDay}',
          cells: rowCells,
        ));
      }
    }

    /// 周几表头（周一 ~ 周日）
    const weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

    /// 根据阅读分钟数返回对应颜色（5 级紫色调）
    Color _cellColor(int minutes) {
      if (minutes == 0) return const Color(0xFFF0EDFA); // 无数据：极浅紫底色
      if (minutes < 15) return const Color(0xFFE0D6FC); // Level 1
      if (minutes < 30) return const Color(0xFFC8B8F7); // Level 2
      if (minutes < 60) return const Color(0xFFA98EF0); // Level 3
      return primary;                                    // Level 4+：主色最深
    }

    /// 单个日期格子
    Widget cellWidget(_DayCell? cell) {
      final color = cell != null ? _cellColor(cell.minutes) : Colors.transparent;
      return Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      );
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
                onTap: () {}, // 预留：展开更多月份
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      LocalizationEngine.text('heatmap_month_btn'),
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 12,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 周几表头
          Padding(
            padding: const EdgeInsets.only(left: 36), // 对齐日期标签宽度
            child: Row(
              children: weekdayLabels.map((label) {
                return Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),

          // 日历网格行
          ...gridRows.map((row) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 行首日期标签
                  SizedBox(
                    width: 32,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        row.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // 7 天格子
                  Expanded(
                    child: Row(
                      children: row.cells.map((cell) => Expanded(child: cellWidget(cell))).toList(),
                    ),
                  ),
                ],
              ),
            ),
          )),

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
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFF0EDFA),
                        Color(0xFFE0D6FC),
                        Color(0xFFC8B8F7),
                        Color(0xFFA98EF0),
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

  /// 构建"遗忘的书籍"卡片：与截图一致的单行布局——[封面] [标题+天数] [立即查看按钮]。
  Widget _buildForgottenBooksCard(
    CupertinoThemeData theme,
    List<BookModel> books,
  ) {
    final primary = theme.primaryColor;
    final lavenderBg = const Color(0xFFF7F5FF);

    // 筛选未读完的书籍（已看完的不计算），按未打开天数倒序排列
    final forgotten = books
        .where((b) => b.progress < 1.0)
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
          // 标题行
          Text(
            LocalizationEngine.text('forgotten_books_title'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 14),
          // 书籍列表（纵向堆叠，每行一本书）
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
            ...forgotten.take(3).map(_bookRow),

          // 查看更多入口（超过3本时显示）
          if (forgotten.length > 3) ...[
            const SizedBox(height: 4),
            Center(
              child: GestureDetector(
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
            ),
          ],
        ],
      ),
    );
  }
}

/// 热力图单日数据单元
class _DayCell {
  final DateTime date;
  final int minutes;

  _DayCell({required this.date, required this.minutes});
}

/// 热力图按周分行数据
class _HeatmapRow {
  final String label; // 行首日期标签（如 "7/8"）
  final List<_DayCell?> cells; // 7 个格子，null 表示非当月

  _HeatmapRow({required this.label, required this.cells});
}
