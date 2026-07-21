import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../engine/localization_engine.dart';
import '../controller/bookshelf_controller.dart';
import '../model/book_model.dart';
import '../model/reading_stats_model.dart';
import '../service/app_stats_service.dart';
import '../service/reader_data_service.dart';
import '../service/reading_session_service.dart';
import 'book_viewer_page.dart';
import 'comic_viewer_page.dart';
import 'epub_viewer_page.dart';
import 'reading_records_page.dart';
import 'txt_viewer_page.dart';
import 'widgets/book_cover_image.dart';

/// MemoryPage —— 阅读统计详情页。
/// 布局严格参照设计稿（周期选择器 → 区间切换 → 四项数据 → 时长趋势 → 热力图 → 时间分布 → 阅读记录），
/// 所有颜色走主题系统，不硬编码色值；文本全部走 LocalizationEngine。
class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

/// 统计周期枚举：日 / 周 / 月 / 年 / 全部
enum _StatsPeriod { day, week, month, year, all }

class _MemoryPageState extends State<MemoryPage> {
  final BookshelfController _controller = BookshelfController();

  /// 当前选中的统计周期（默认「月」）
  _StatsPeriod _period = _StatsPeriod.month;

  /// 当前展示的月份（用于「月」视图下的区间切换）
  DateTime _displayMonth;

  /// 当前展示的周锚点（用于「周」视图区间切换，取该周周一）
  DateTime _weekAnchor;

  /// 当前展示的年份（用于「年」视图区间切换）
  int _displayYear;

  /// 当前选中的「日」（用于「日」视图区间切换，归一到零点）
  DateTime _selectedDay;

  /// 时间分布切换索引（0=时段, 1=频率）
  int _timeDistTabIndex = 0;

  /// 趋势图类型（0=条形, 1=折线）
  int _trendChartType = 0;

  /// 收藏笔记真实总数（跨书汇总，替代占位 0）。
  int _totalNotesCount = 0;

  _MemoryPageState()
      : _now = DateTime.now(),
        _displayMonth = DateTime(DateTime.now().year, DateTime.now().month),
        _weekAnchor = DateTime.now().subtract(
            Duration(days: DateTime.now().weekday - 1)),
        _displayYear = DateTime.now().year,
        _selectedDay = DateTime(
            DateTime.now().year, DateTime.now().month, DateTime.now().day);

  final DateTime _now;

  @override
  void initState() {
    super.initState();
    _loadTotalNotes();
    _controller.books.addListener(_loadTotalNotes);
  }

  @override
  void dispose() {
    _controller.books.removeListener(_loadTotalNotes);
    _controller.dispose();
    super.dispose();
  }

  /// 加载跨书收藏笔记总数（真实数据）。
  void _loadTotalNotes() {
    final ids = _controller.books.value.map((b) => b.id).toList();
    ReaderDataStore.countAllNotes(ids).then((count) {
      if (!mounted) return;
      setState(() => _totalNotesCount = count);
    });
  }

  // ──────────────────── 区间与数据提取 ────────────────────

  /// 根据当前周期与导航状态，返回统计区间的起止时间（左闭右开）。
  ({DateTime start, DateTime end}) _rangeBounds(ReadingStats stats) {
    switch (_period) {
      case _StatsPeriod.day:
        final start =
            DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
        return (start: start, end: start.add(const Duration(days: 1)));
      case _StatsPeriod.week:
        final start =
            DateTime(_weekAnchor.year, _weekAnchor.month, _weekAnchor.day);
        return (start: start, end: start.add(const Duration(days: 7)));
      case _StatsPeriod.month:
        final start = DateTime(_displayMonth.year, _displayMonth.month, 1);
        return (
          start: start,
          end: DateTime(_displayMonth.year, _displayMonth.month + 1, 1)
        );
      case _StatsPeriod.year:
        final start = DateTime(_displayYear, 1, 1);
        return (start: start, end: DateTime(_displayYear + 1, 1, 1));
      case _StatsPeriod.all:
        // 从最早有数据的那天到今天，最多回溯 24 个月，避免图表过长
        DateTime? earliest;
        for (final d in stats.dailyMinutes.keys) {
          if (earliest == null || d.isBefore(earliest)) earliest = d;
        }
        final fallback = DateTime(_now.year, _now.month - 23, _now.day);
        final start =
            earliest == null ? fallback : (earliest.isBefore(fallback) ? fallback : earliest);
        return (start: start, end: _now.add(const Duration(days: 1)));
    }
  }

  /// 返回当前区间内的趋势数据点（按周期自适应粒度）：
  /// 日 → 按小时（0~23 时）；周/月 → 按天；年/全部 → 按月聚合。
  List<MapEntry<DateTime, int>> _trendEntries(ReadingStats stats) {
    final (:start, :end) = _rangeBounds(stats);

    if (_period == _StatsPeriod.day) {
      // 日视图：以选中日的 24 个小时为横轴，每点 = 该小时阅读分钟数
      final dayKey =
          DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
      final hourly = stats.dailyHourlyMinutes[dayKey] ?? List.filled(24, 0);
      final list = <MapEntry<DateTime, int>>[];
      for (var h = 0; h < 24; h++) {
        list.add(MapEntry(
          DateTime(dayKey.year, dayKey.month, dayKey.day, h),
          hourly[h],
        ));
      }
      return list;
    }

    if (_period == _StatsPeriod.week || _period == _StatsPeriod.month) {
      final map = stats.dailyMinutes.entries
          .where((e) => !e.key.isBefore(start) && e.key.isBefore(end))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return map;
    }

    // 年/全部：按月聚合
    final monthly = <DateTime, int>{};
    for (final e in stats.dailyMinutes.entries) {
      if (e.key.isBefore(start) || !e.key.isBefore(end)) continue;
      final key = DateTime(e.key.year, e.key.month, 1);
      monthly[key] = (monthly[key] ?? 0) + e.value;
    }
    final keys = monthly.keys.toList()..sort();
    return keys.map((k) => MapEntry(k, monthly[k]!)).toList();
  }

  /// 统计区间内「读完」的书籍数量：进度达到 100%（progress>=1.0），
  /// 且最后阅读时间落在区间 [start, end) 内。与「点开过几本书」区分。
  int _booksCompletedInRange(
    List<BookModel> books,
    DateTime start,
    DateTime end,
  ) {
    var count = 0;
    for (final b in books) {
      if (b.progress < 1.0) continue; // 未读完，不计入
      final lr = b.lastReadAt;
      if (lr == null) continue;
      if (!lr.isBefore(start) && lr.isBefore(end)) count++;
    }
    return count;
  }

  /// 根据阅读分钟数返回热力图单元格颜色（主题主色派生，不写死十六进制）。
  Color _heatColor(
    int minutes,
    CupertinoThemeData theme,
    BuildContext ctx,
  ) {
    if (minutes < 0) return Colors.transparent; // 超出当前区间
    if (minutes == 0) {
      return CupertinoColors.systemGrey5.resolveFrom(ctx); // 无数据：浅灰底（比卡片背景深一档，确保方框在明暗模式下都可见）
    }
    if (minutes < 15) return theme.primaryColor.withValues(alpha: 0.20);
    if (minutes < 30) return theme.primaryColor.withValues(alpha: 0.40);
    if (minutes < 60) return theme.primaryColor.withValues(alpha: 0.65);
    return theme.primaryColor;
  }

  /// 根据单个「6 小时段」的阅读分钟数返回对应颜色（主题主色派生，不写死十六进制）。
  /// 阈值按 6 小时段等比下调：无数据=极浅灰；其余按 0.20/0.40/0.65/主色 四档。
  Color _blockColor(
    int minutes,
    CupertinoThemeData theme,
    BuildContext ctx,
  ) {
    if (minutes <= 0) {
      return CupertinoColors.systemGrey5.resolveFrom(ctx); // 无数据：浅灰底（比卡片背景深一档，确保方框在明暗模式下都可见）
    }
    if (minutes < 8) return theme.primaryColor.withValues(alpha: 0.20); // Level 1
    if (minutes < 20) return theme.primaryColor.withValues(alpha: 0.40); // Level 2
    if (minutes < 45) return theme.primaryColor.withValues(alpha: 0.65); // Level 3
    return theme.primaryColor; // Level 4+：主色最深
  }

  // ──────────────────── 主构建 ────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return ValueListenableBuilder<List<BookModel>>(
      valueListenable: _controller.books,
      builder: (context, books, child) {
        final stats = ReadingStats.fromBooks(books);

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
              LocalizationEngine.text('reading_statistics'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.textStyle.color,
              ),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {},
              child: Icon(
                CupertinoIcons.share,
                size: 20,
                color: theme.textTheme.textStyle.color,
              ),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ① 周期选择器（周 / 月 / 年 / 全部）
                  _buildPeriodTabs(theme),
                  const SizedBox(height: 12),

                  // ② 区间切换器（周/月/年 显示导航箭头；全部不显示）
                  _buildRangeSwitcher(theme),
                  const SizedBox(height: 14),

                  // ③ 四项数据卡片（时长 / 书籍 / 页数 / 笔记）
                  _buildFourStatCards(theme, books, stats),
                  const SizedBox(height: 12),

                  // ③-b 追加两项统计框：软件打开次数 / 累计阅读天数（布局与上方一致）
                  _buildExtraStatCards(theme, stats),
                  const SizedBox(height: 16),

                  // ④ 阅读时长趋势（条形 / 折线 可切换）
                  _buildTrendSection(theme, stats),
                  const SizedBox(height: 16),

                  // ⑤ 阅读热力图（跟随周期：周=单周 / 月=月历 / 年·全部=年度贡献图）
                  _buildHeatmapSection(theme, stats),
                  const SizedBox(height: 16),

                  // ⑥ 阅读时间分布（时段 / 频率 切换，均来自真实数据）
                  _buildTimeDistribution(theme, stats),
                  const SizedBox(height: 16),

                  // ⑦ 阅读记录（按当前周期筛选：看完了 / 在读 两组）
                  _buildMonthlyRecords(theme, books, stats),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════
  // ① 周期选择器（胶囊分段控件，均分宽度）
  // ══════════════════════════════════════════════════

  Widget _buildPeriodTabs(CupertinoThemeData theme) {
    final tabs = [
      LocalizationEngine.text('stats_tab_day'), // 日
      LocalizationEngine.text('stats_tab_week'), // 周
      LocalizationEngine.text('stats_tab_month'), // 月
      LocalizationEngine.text('stats_tab_year'), // 年
      LocalizationEngine.text('stats_tab_all'), // 全部
    ];

    return Row(
      children: _StatsPeriod.values.map((p) {
        final idx = p.index;
        final isSelected = p == _period;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _period = p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 34,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isSelected ? theme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(17),
              ),
              alignment: Alignment.center,
              child: Text(
                tabs[idx],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? CupertinoColors.white
                      : CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ══════════════════════════════════════════════════
  // ② 区间切换器（与周期联动：周/月/年 提供上/下导航；全部无）
  // ══════════════════════════════════════════════════

  Widget _buildRangeSwitcher(CupertinoThemeData theme) {
    if (_period == _StatsPeriod.all) return const SizedBox.shrink();

    late final String label;
    late final VoidCallback onPrev;
    late final VoidCallback onNext;

    switch (_period) {
      case _StatsPeriod.day:
        final start =
            DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
        label = '${start.month}/${start.day}';
        onPrev = () => setState(
            () => _selectedDay = _selectedDay.subtract(const Duration(days: 1)));
        onNext = () =>
            setState(() => _selectedDay = _selectedDay.add(const Duration(days: 1)));
        break;
      case _StatsPeriod.week:
        final start =
            DateTime(_weekAnchor.year, _weekAnchor.month, _weekAnchor.day);
        final end = start.add(const Duration(days: 7));
        final last = end.subtract(const Duration(days: 1));
        label = '${start.month}/${start.day} - ${last.month}/${last.day}';
        onPrev = () =>
            setState(() => _weekAnchor = _weekAnchor.subtract(const Duration(days: 7)));
        onNext = () =>
            setState(() => _weekAnchor = _weekAnchor.add(const Duration(days: 7)));
        break;
      case _StatsPeriod.month:
        label =
            '${_displayMonth.year}${LocalizationEngine.text('year_unit')}${_displayMonth.month}${LocalizationEngine.text('month_unit')}';
        onPrev = () => setState(
            () => _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1));
        onNext = () => setState(
            () => _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1));
        break;
      case _StatsPeriod.year:
        label = '$_displayYear${LocalizationEngine.text('year_unit')}';
        onPrev = () => setState(() => _displayYear--);
        onNext = () => setState(() => _displayYear++);
        break;
      case _StatsPeriod.all:
        label = '';
        onPrev = () {};
        onNext = () {};
    }

    return Row(
      children: [
        _navArrow(theme, CupertinoIcons.chevron_left, onPrev),
        Expanded(
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
        ),
        _navArrow(theme, CupertinoIcons.chevron_right, onNext),
      ],
    );
  }

  /// 区间切换器两侧的小圆箭头按钮。
  /// 使用原生 CupertinoButton（而非 GestureDetector），在 macOS / iOS / Android 上点击命中更稳定；
  /// 命中区域由 minSize 保证不小于 44，圆形图标仍为 32，触控更友好。
  Widget _navArrow(CupertinoThemeData theme, IconData icon, VoidCallback onTap) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: CupertinoColors.systemGrey5.resolveFrom(context),
        ),
        child: Icon(icon, size: 16),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // ③ 四项数据卡片（一行四列：时长 / 书籍 / 页数 / 笔记）
  // ══════════════════════════════════════════════════

  Widget _buildFourStatCards(
    CupertinoThemeData theme,
    List<BookModel> books,
    ReadingStats stats,
  ) {
    final (:start, :end) = _rangeBounds(stats);
    final minutes = stats.minutesBetween(start, end);
    final hours = (minutes / 60).round();
    final bookCount = _booksCompletedInRange(books, start, end);
    final pages = (minutes * 1.5).round(); // 按每分钟约 1.5 页估算（无逐页数据）
    final notesCount = _totalNotesCount; // 收藏笔记真实总数（跨书汇总）

    final items = <_MetricCard>[
      _MetricCard(
        icon: CupertinoIcons.clock,
        value: '$hours',
        label: LocalizationEngine.text('stats_reading_hours_label'),
      ),
      _MetricCard(
        icon: CupertinoIcons.book,
        value: '$bookCount',
        label: LocalizationEngine.text('stats_reading_books_label'),
      ),
      _MetricCard(
        icon: CupertinoIcons.doc_text,
        value: '$pages',
        label: LocalizationEngine.text('stats_reading_pages_label'),
      ),
      _MetricCard(
        icon: CupertinoIcons.star,
        value: '$notesCount',
        label: LocalizationEngine.text('stats_notes_count_label'),
      ),
    ];

    return Row(
      children: items.map((item) {
        return Expanded(
          child: _MetricTile(theme: theme, item: item),
        );
      }).toList(),
    );
  }

  /// ③-b 追加的两项统计框：软件打开次数（全局）、累计阅读天数（当前区间）。
  /// 复用 _MetricTile 与上方四项保持完全相同的卡片样式。
  Widget _buildExtraStatCards(CupertinoThemeData theme, ReadingStats stats) {
    final (:start, :end) = _rangeBounds(stats);
    // 软件打开次数：按当前统计区间统计（与阅读统计口径一致），而非全局累计
    final openCount = AppStatsService.getAppLaunchCountInRange(start, end);
    final readingDays = stats.activeDaysInRange(start, end); // 当前区间内阅读天数

    // 日均阅读时间：当前区间内总阅读分钟 / 区间天数（天数至少 1，避免除零）
    final totalMinutes = stats.minutesBetween(start, end);
    final days = end.difference(start).inDays.clamp(1, 99999);
    final avgMin = (totalMinutes / days).round();
    final avgValue =
        avgMin >= 60 ? '${(avgMin / 60).toStringAsFixed(1)} 时' : '$avgMin 分';

    final items = <_MetricCard>[
      _MetricCard(
        icon: CupertinoIcons.app_badge,
        value: '$openCount',
        label: LocalizationEngine.text('app_open_count_label'),
      ),
      _MetricCard(
        icon: CupertinoIcons.calendar,
        value: '$readingDays',
        label: LocalizationEngine.text('cumulative_reading_days_label'),
      ),
      _MetricCard(
        icon: CupertinoIcons.stopwatch,
        value: avgValue,
        label: LocalizationEngine.text('daily_avg_reading_label'),
      ),
    ];

    return Row(
      children: items.map((item) {
        return Expanded(
          child: _MetricTile(theme: theme, item: item),
        );
      }).toList(),
    );
  }

  // ══════════════════════════════════════════════════
  // ④ 阅读时长趋势（标题 + 区间时长 + 条形/折线切换 + 图表）
  // ══════════════════════════════════════════════════

  Widget _buildTrendSection(CupertinoThemeData theme, ReadingStats stats) {
    final primary = theme.primaryColor;
    final (:start, :end) = _rangeBounds(stats);
    final hours = (stats.minutesBetween(start, end) / 60).round();
    final entries = _trendEntries(stats);

    // 「日」视图下横轴为小时，使用小时标签；其余周期沿用「月/日」标签。
    final xLabelBuilder = _period == _StatsPeriod.day
        ? (DateTime d) => '${d.hour}'
        : null;

    // 自动计算纵坐标：区间内单点最大阅读量 ≤ 3 小时时按「分钟」刻度，
    // 否则按「小时」；纵坐标上限取整为易读的「漂亮数」（1/2/2.5/5 × 10ⁿ），
    // 确保读数少时柱子/折线依然明显。
    final maxMin = entries.isEmpty
        ? 0
        : entries.fold<int>(0, (m, e) => math.max(m, e.value));
    final useMinutes = maxMin <= 180;
    final unit = useMinutes ? 1.0 : 60.0;
    final axisMax = _niceCeil(maxMin / unit).clamp(
      useMinutes ? 10.0 : 1.0,
      double.infinity,
    );
    final unitLabel = useMinutes
        ? LocalizationEngine.text('minutes_short')
        : LocalizationEngine.text('hours_short');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行 + 图表类型切换
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                LocalizationEngine.text('detail_trend_title'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              _chartTypeToggle(theme),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_periodLabelShort()} · $hours${LocalizationEngine.text('hours_short')}',
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 12),

          // 图表区域（条形 / 折线）
          SizedBox(
            height: 140,
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      LocalizationEngine.text('forgotten_empty'),
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context),
                      ),
                    ),
                  )
                : _trendChartType == 0
                    ? _TrendBarChart(
                        entries: entries,
                        accentColor: primary,
                        axisMax: axisMax,
                        unit: unit,
                        unitLabel: unitLabel,
                        xLabelBuilder: xLabelBuilder,
                      )
                    : _TrendLineChart(
                        entries: entries,
                        accentColor: primary,
                        axisMax: axisMax,
                        unit: unit,
                        unitLabel: unitLabel,
                        xLabelBuilder: xLabelBuilder,
                      ),
          ),
        ],
      ),
    );
  }

  /// 趋势图类型切换（条形 / 折线）。
  Widget _chartTypeToggle(CupertinoThemeData theme) {
    final opts = [
      LocalizationEngine.text('trend_chart_bar'),
      LocalizationEngine.text('trend_chart_line'),
    ];
    return Row(
      children: opts.asMap().entries.map((e) {
        final idx = e.key;
        final lbl = e.value;
        final sel = idx == _trendChartType;
        return GestureDetector(
          onTap: () => setState(() => _trendChartType = idx),
          child: Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: sel ? theme.primaryColor : Colors.transparent,
              border: Border.all(
                color: sel
                    ? theme.primaryColor
                    : CupertinoColors.systemGrey4.resolveFrom(context),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              lbl,
              style: TextStyle(
                fontSize: 11,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                color: sel
                    ? CupertinoColors.white
                    : CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 返回当前周期的短标签文本（如"本月阅读"/"本周阅读"/"今年阅读"/"全部"）。
  String _periodLabelShort() {
    switch (_period) {
      case _StatsPeriod.day:
        return LocalizationEngine.text('today_reading_label');
      case _StatsPeriod.week:
        return LocalizationEngine.text('this_week_reading');
      case _StatsPeriod.month:
        return LocalizationEngine.text('monthly_reading');
      case _StatsPeriod.year:
        return LocalizationEngine.text('yearly_reading');
      case _StatsPeriod.all:
        return LocalizationEngine.text('stats_tab_all');
    }
  }

  // ══════════════════════════════════════════════════
  // ⑤ 阅读热力图（跟随周期：周=单周 / 月=月历 / 年·全部=年度贡献图）
  // ══════════════════════════════════════════════════

  Widget _buildHeatmapSection(CupertinoThemeData theme, ReadingStats stats) {
    final primary = theme.primaryColor;
    late final String headerLabel;
    late final Widget grid;

    switch (_period) {
      case _StatsPeriod.day:
        final dayKey =
            DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
        headerLabel = '${dayKey.month}/${dayKey.day}';
        grid = _buildDayHeatGrid(theme, stats, dayKey);
        break;
      case _StatsPeriod.week:
        final (:start, :end) = _rangeBounds(stats);
        final last = end.subtract(const Duration(days: 1));
        headerLabel = '${start.month}/${start.day} - ${last.month}/${last.day}';
        grid = _buildWeekHeatGrid(theme, stats, start, end);
        break;
      case _StatsPeriod.month:
        headerLabel =
            '${_displayMonth.year}/${_displayMonth.month.toString().padLeft(2, '0')}';
        grid = _buildMonthHeatGrid(theme, stats);
        break;
      case _StatsPeriod.year:
        final (:start, :end) = _rangeBounds(stats);
        grid = _buildYearHeatGrid(theme, stats, start, end);
        headerLabel = '$_displayYear${LocalizationEngine.text('year_unit')}';
        break;
      case _StatsPeriod.all:
        final (:start, :end) = _rangeBounds(stats);
        grid = _buildYearHeatGrid(theme, stats, start, end);
        headerLabel = LocalizationEngine.text('stats_tab_all');
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：左侧标题 + 右侧区间标签
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                LocalizationEngine.text('reading_heatmap'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              Text(
                headerLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          grid,
          // 周/月为四象限日历热力图，补充说明；「日」视图说明每小时切 4 格；年/全部(贡献图)不显示
          if (_period == _StatsPeriod.week || _period == _StatsPeriod.month) ...[
            const SizedBox(height: 8),
            Text(
              LocalizationEngine.text('heatmap_block_hint'),
              style: TextStyle(
                fontSize: 11,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ] else if (_period == _StatsPeriod.day) ...[
            const SizedBox(height: 8),
            Text(
              LocalizationEngine.text('heatmap_day_block_hint'),
              style: TextStyle(
                fontSize: 11,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ],
          const SizedBox(height: 8),

          // 底部图例（主题主色派生渐变）
          Row(
            children: [
              Text(
                LocalizationEngine.text('heatmap_legend_few'),
                style: TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3.5),
                    gradient: LinearGradient(
                      colors: [
                        CupertinoColors.systemGrey5.resolveFrom(context),
                        primary.withValues(alpha: 0.20),
                        primary.withValues(alpha: 0.40),
                        primary.withValues(alpha: 0.70),
                        primary,
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
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

  /// 通用日历热力图网格：表头为周一~周日，body 为若干行（每行 7 格，null 表示占位）。
  /// 表头列与数据列使用完全相同的横向间距，严格对齐；单元格为正方形，周/月风格统一、现代。
  Widget _buildCalendarHeatGrid(
    CupertinoThemeData theme,
    List<List<_DayCell?>> rows,
  ) {
    final ctx = context;
    const weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];
    const cellMargin = 2.0;
    const subGap = 2.0; // 四象限之间的细微间隙

    // 单个日期格：2×2 四象限，分别对应当日 4 个「6 小时段」的阅读情况
    Widget _dayBlockCell(_DayCell? cell) {
      if (cell == null) return const SizedBox.shrink(); // 非当月占位留空
      final b = cell.blockMinutes;
      Widget quad(int m) => Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _blockColor(m, theme, ctx),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: CupertinoColors.separator
                      .resolveFrom(ctx)
                      .withValues(alpha: 0.35),
                  width: 0.5,
                ),
              ),
            ),
          );
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: cellMargin),
        child: AspectRatio(
          aspectRatio: 1,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [quad(b[0]), const SizedBox(width: subGap), quad(b[1])],
                ),
              ),
              const SizedBox(height: subGap),
              Expanded(
                child: Row(
                  children: [quad(b[2]), const SizedBox(width: subGap), quad(b[3])],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // 周几表头（与下方数据列完全对齐）
        Row(
          children: weekdayLabels
              .map((l) => Expanded(
                    child: Container(
                      margin:
                          const EdgeInsets.symmetric(horizontal: cellMargin),
                      alignment: Alignment.center,
                      child: Text(
                        l,
                        style: TextStyle(
                          fontSize: 11,
                          color: CupertinoColors.tertiaryLabel.resolveFrom(ctx),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        // 数据行
        ...rows.map((row) => Padding(
              padding: const EdgeInsets.only(bottom: cellMargin * 2),
              child: Row(
                children: row
                    .map((cell) => Expanded(child: _dayBlockCell(cell)))
                    .toList(),
              ),
            )),
      ],
    );
  }

  /// 周热力图：单行 7 格（周一~周日），复用通用日历网格。
  Widget _buildWeekHeatGrid(
    CupertinoThemeData theme,
    ReadingStats stats,
    DateTime start,
    DateTime end,
  ) {
    final cells = <_DayCell>[];
    var d = start;
    while (d.isBefore(end)) {
      final blocks = stats.dailyBlockMinutes[d] ?? [0, 0, 0, 0];
      cells.add(_DayCell(
        date: d,
        minutes: blocks.fold<int>(0, (sum, v) => sum + v),
        blockMinutes: blocks,
      ));
      d = d.add(const Duration(days: 1));
    }
    return _buildCalendarHeatGrid(theme, [cells]);
  }

  /// 月热力图：周一起始的月历网格（含上月/下月占位，始终保持 7 列对齐）。
  Widget _buildMonthHeatGrid(CupertinoThemeData theme, ReadingStats stats) {
    final gridStart = DateTime(_displayMonth.year, _displayMonth.month, 1);
    final gridEnd = DateTime(_displayMonth.year, _displayMonth.month + 1, 1);
    final daysInMonth = gridEnd.difference(gridStart).inDays;
    final startWeekday = gridStart.weekday; // 1=Mon .. 7=Sun

    final rows = <List<_DayCell?>>[];
    var currentDay = 1;
    final firstRow = <_DayCell?>[];
    for (var i = 1; i < startWeekday; i++) {
      firstRow.add(null); // 上月占位
    }
    while (firstRow.length < 7 && currentDay <= daysInMonth) {
      final date = DateTime(gridStart.year, gridStart.month, currentDay);
      final blocks = stats.dailyBlockMinutes[date] ?? [0, 0, 0, 0];
      firstRow.add(_DayCell(
        date: date,
        minutes: blocks.fold<int>(0, (sum, v) => sum + v),
        blockMinutes: blocks,
      ));
      currentDay++;
    }
    rows.add(firstRow);
    while (currentDay <= daysInMonth) {
      final rowCells = <_DayCell?>[];
      for (var col = 0; col < 7 && currentDay <= daysInMonth; col++) {
        final date = DateTime(gridStart.year, gridStart.month, currentDay);
        final blocks = stats.dailyBlockMinutes[date] ?? [0, 0, 0, 0];
        rowCells.add(_DayCell(
          date: date,
          minutes: blocks.fold<int>(0, (sum, v) => sum + v),
          blockMinutes: blocks,
        ));
        currentDay++;
      }
      while (rowCells.length < 7) rowCells.add(null); // 补齐 7 列
      rows.add(rowCells);
    }

    return _buildCalendarHeatGrid(theme, rows);
  }

  /// 年/全部热力图：GitHub 风格贡献图（按周分列、周一~周日分行，横向滚动）。
  Widget _buildYearHeatGrid(
    CupertinoThemeData theme,
    ReadingStats stats,
    DateTime start,
    DateTime end,
  ) {
    final ctx = context;
    final lastDate = end.subtract(const Duration(days: 1));

    // 对齐到周一为起点的整周
    var gridStart = start;
    while (gridStart.weekday != 1) {
      gridStart = gridStart.subtract(const Duration(days: 1));
    }
    var gridEndAligned = lastDate;
    while (gridEndAligned.weekday != 7) {
      gridEndAligned = gridEndAligned.add(const Duration(days: 1));
    }
    gridEndAligned = gridEndAligned.add(const Duration(days: 1)); // 转为右开

    final weeks = <List<_DayCell>>[];
    var cursor = gridStart;
    while (cursor.isBefore(gridEndAligned)) {
      final week = <_DayCell>[];
      for (var i = 0; i < 7; i++) {
        final inRange = !cursor.isBefore(start) && !cursor.isAfter(lastDate);
        week.add(_DayCell(
          date: cursor,
          minutes: inRange ? (stats.dailyMinutes[cursor] ?? 0) : -1,
        ));
        cursor = cursor.add(const Duration(days: 1));
      }
      weeks.add(week);
    }

    const weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];
    const cellSize = 13.0;
    const cellGap = 3.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 周几标签列
        Column(
          children: weekdayLabels
              .map((l) => Container(
                    width: 14,
                    height: cellSize,
                    margin: const EdgeInsets.only(bottom: cellGap),
                    child: Center(
                      child: Text(
                        l,
                        style: TextStyle(
                          fontSize: 9,
                          color: CupertinoColors.tertiaryLabel.resolveFrom(ctx),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(width: 6),
        // 周列（横向滚动）
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: weeks
                  .map((week) => Column(
                        children: week
                            .map((c) {
                        final inRange = c.minutes >= 0;
                        return Container(
                          width: cellSize,
                          height: cellSize,
                          margin: const EdgeInsets.all(cellGap / 2),
                          decoration: BoxDecoration(
                            color: _heatColor(c.minutes, theme, ctx),
                            borderRadius: BorderRadius.circular(3),
                            border: inRange
                                ? Border.all(
                                    color: CupertinoColors.separator
                                        .resolveFrom(ctx)
                                        .withValues(alpha: 0.35),
                                    width: 0.5,
                                  )
                                : null,
                          ),
                        );
                      })
                            .toList(),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  /// 日热力图：将选中的一天按「15 分钟段」展开为紧凑小方格网格，风格与周视图一致。
  /// 4 行 = 4 个「6 小时段」（0-6 / 6-12 / 12-18 / 18-24）；每行 6 个小时，
  /// 每个小时再切成 4 个小方格（每格 = 1 个 15 分钟段），共 4×6×4 = 96 格。
  /// 小方格内不显示数字，颜色深浅对应该 15 分钟段的阅读分钟数。
  Widget _buildDayHeatGrid(
    CupertinoThemeData theme,
    ReadingStats stats,
    DateTime day,
  ) {
    final ctx = context;
    final quarters = stats.dailyQuarterMinutes[day] ?? List.filled(96, 0);

    const bands = ['0-6', '6-12', '12-18', '18-24']; // 4 个时段行标签
    const subGap = 2.0;

    // 单个 15 分钟段小方格（无数字，纯色块，颜色深浅表示该段阅读量）
    Widget _quarterCell(int quarterIndex) {
      final m = quarters[quarterIndex];
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: subGap / 2),
          child: AspectRatio(
            aspectRatio: 1, // 紧凑正方形，与周视图小方格一致
            child: Container(
              decoration: BoxDecoration(
                color: _quarterColor(m, theme, ctx),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: CupertinoColors.separator
                      .resolveFrom(ctx)
                      .withValues(alpha: 0.35),
                  width: 0.5,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: List.generate(4, (band) {
        final startHour = band * 6;
        return Padding(
          padding: const EdgeInsets.only(bottom: subGap * 1.5),
          child: Row(
            children: [
              // 时段标签（左侧）
              SizedBox(
                width: 44,
                child: Text(
                  '${bands[band]}${LocalizationEngine.text('hour_unit')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: CupertinoColors.tertiaryLabel.resolveFrom(ctx),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // 6 个小时 × 每列 4 个 15 分钟段小方格
              Expanded(
                child: Row(
                  children: List.generate(6, (col) {
                    final hour = startHour + col;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: col < 5 ? subGap : 0),
                        child: Row(
                          children: List.generate(4, (q) {
                            final quarterIndex = hour * 4 + q;
                            return _quarterCell(quarterIndex);
                          }),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  /// 根据单个「15 分钟段」的阅读分钟数返回对应颜色（主题主色派生，不写死十六进制）。
  /// 阈值按 15 分钟段设定：无数据=极浅灰；其余按 0.20/0.40/0.65/主色 四档。
  Color _quarterColor(
    int minutes,
    CupertinoThemeData theme,
    BuildContext ctx,
  ) {
    if (minutes <= 0) {
      return CupertinoColors.systemGrey5.resolveFrom(ctx); // 无数据：浅灰底
    }
    if (minutes < 4) return theme.primaryColor.withValues(alpha: 0.20); // Level 1
    if (minutes < 8) return theme.primaryColor.withValues(alpha: 0.40); // Level 2
    if (minutes < 12) return theme.primaryColor.withValues(alpha: 0.65); // Level 3
    return theme.primaryColor; // Level 4+：主色最深
  }


  // ══════════════════════════════════════════════════
  // ⑦ 阅读时间分布（时段 / 频率 切换，均来自真实数据）
  // ══════════════════════════════════════════════════

  Widget _buildTimeDistribution(CupertinoThemeData theme, ReadingStats stats) {
    final primary = theme.primaryColor;

    // 时段分布所用的「小时→分钟」映射：
    // 非「日」视图用全局小时分布；「日」视图用选中当天按小时的明细，
    // 使下方「时间分布」区块与当天数据保持一致（与周视图布局相同）。
    final Map<int, int> h;
    if (_period == _StatsPeriod.day) {
      final dayKey =
          DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
      final list = stats.dailyHourlyMinutes[dayKey] ?? List.filled(24, 0);
      h = {for (var i = 0; i < 24; i++) i: list[i]};
    } else {
      h = stats.hourlyMinutes;
    }

    // 按时段聚合真实小时分布（4 个「6 小时段」，与热力图口径完全一致）：
    // 白天 6-11 / 午后 12-17 / 晚上 18-23 / 深夜 0-5
    int sumHours(List<int> hours) =>
        hours.fold(0, (s, x) => s + (h[x] ?? 0));

    final List<_RingSegment> segments;
    if (_timeDistTabIndex == 0) {
      final morning = sumHours([6, 7, 8, 9, 10, 11]);
      final afternoon = sumHours([12, 13, 14, 15, 16, 17]);
      final evening = sumHours([18, 19, 20, 21, 22, 23]);
      final night = sumHours([0, 1, 2, 3, 4, 5]);
      final total =
          (morning + afternoon + evening + night).toDouble();
      final safe = total > 0 ? total : 1.0;
      segments = [
        _RingSegment(
          label: LocalizationEngine.text('time_morning'),
          percent: morning / safe,
          color: primary.withValues(alpha: 0.28),
        ),
        _RingSegment(
          label: LocalizationEngine.text('time_afternoon'),
          percent: afternoon / safe,
          color: primary.withValues(alpha: 0.58),
        ),
        _RingSegment(
          label: LocalizationEngine.text('time_evening'),
          percent: evening / safe,
          color: primary,
        ),
        _RingSegment(
          label: LocalizationEngine.text('time_night'),
          percent: night / safe,
          color: primary.withValues(alpha: 0.85),
        ),
      ];
    } else {
      // 按频率聚合真实时长分布桶（<1h / 1-2h / 2-3h / >3h）
      final u1 = stats.distributionUnder1HourMinutes;
      final h12 = stats.distribution1To2HoursMinutes;
      final h23 = stats.distribution2To3HoursMinutes;
      final h3 = stats.distribution3HoursMoreMinutes;
      final total = (u1 + h12 + h23 + h3).toDouble();
      final safe = total > 0 ? total : 1.0;
      segments = [
        _RingSegment(
          label: LocalizationEngine.text('freq_under_1h'),
          percent: u1 / safe,
          color: primary.withValues(alpha: 0.28),
        ),
        _RingSegment(
          label: LocalizationEngine.text('freq_1_2h'),
          percent: h12 / safe,
          color: primary.withValues(alpha: 0.58),
        ),
        _RingSegment(
          label: LocalizationEngine.text('freq_2_3h'),
          percent: h23 / safe,
          color: primary,
        ),
        _RingSegment(
          label: LocalizationEngine.text('freq_3h_plus'),
          percent: h3 / safe,
          color: primary.withValues(alpha: 0.85),
        ),
      ];
    }

    final tabLabels = [
      LocalizationEngine.text('time_tab_period'),
      LocalizationEngine.text('time_tab_alt'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocalizationEngine.text('detail_time_distribution'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 12),
          // 切换按钮组
          Row(
            children: tabLabels.asMap().entries.map((e) {
              final idx = e.key;
              final lbl = e.value;
              final sel = idx == _timeDistTabIndex;
              return GestureDetector(
                onTap: () => setState(() => _timeDistTabIndex = idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: sel ? primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    lbl,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                      color: sel
                          ? CupertinoColors.white
                          : CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          // 环形图 + 图例
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: CustomPaint(
                  size: const Size(110, 110),
                  painter: _RingPainter(segments: segments),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: segments.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: s.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.label,
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.label.resolveFrom(context),
                              ),
                            ),
                          ),
                          Text(
                            '${(s.percent * 100).round()}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // ⑧ 本月阅读记录（看完了 / 在读 两组）
  // ══════════════════════════════════════════════════

  Widget _buildMonthlyRecords(
    CupertinoThemeData theme,
    List<BookModel> books,
    ReadingStats stats,
  ) {
    // 按当前周期筛选区间
    final (:start, :end) = _rangeBounds(stats);
    bool inRange(BookModel b) {
      final lr = b.lastReadAt;
      if (lr == null) return false;
      return !lr.isBefore(start) && lr.isBefore(end);
    }

    // 反查表：bookId -> BookModel，用于将会话映射到书名/封面
    final bookMap = <String, BookModel>{for (final b in books) b.id: b};

    // 区间内的阅读会话（会话级数据：几点开始、读了多久、是否读完）
    final sessions = ReadingSessionService.sessionsInRange(start, end);
    final sessionRows = sessions.take(2).map((s) {
      final book = bookMap[s.bookId];
      return _SessionRow(
        theme: theme,
        book: book,
        session: s,
        onTap: () => _openBook(book),
      );
    }).toList();

    // 读完了：进度 100% 且区间内阅读过；累计这些书的阅读总时长
    final finished = books
        .where((b) => b.progress >= 1.0 && inRange(b))
        .toList()
      ..sort((a, b) =>
          (b.lastReadAt ?? DateTime(2000)).compareTo(a.lastReadAt ?? DateTime(2000)));
    final finishedSeconds =
        finished.fold<int>(0, (sum, b) => sum + b.readingDurationSeconds);

    final children = <Widget>[];
    // 概览：阅读次数 / 读完本数 / 读完耗时
    children.add(_buildRecordSummary(theme, sessions.length, finished.length, finishedSeconds));
    children.add(const SizedBox(height: 14));
    // 阅读明细（会话列表）
    children.add(_recordSectionHeader(LocalizationEngine.text('records_detail')));
    if (sessionRows.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          LocalizationEngine.text('records_detail_empty'),
          style: TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ));
    } else {
      children.addAll(sessionRows);
    }
    // 读完了
    if (finished.isNotEmpty) {
      children.add(const SizedBox(height: 14));
      children.add(_recordSectionHeader(
          '${LocalizationEngine.text('records_finished')} (${finished.length})'));
      children.addAll(finished.take(2).map((book) => _RecordCard(
            theme: theme,
            book: book,
            onTap: () => _openBook(book),
          )));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.06),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                LocalizationEngine.text('detail_monthly_records'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              GestureDetector(
                // 跳转至全部阅读记录页
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => const ReadingRecordsPage(),
                  ),
                ),
                child: Text(
                  LocalizationEngine.text('view_all'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  /// 阅读记录概览：阅读次数 / 读完本数 / 读完耗时 三块统计。
  Widget _buildRecordSummary(
    CupertinoThemeData theme,
    int sessionCount,
    int finishedCount,
    int finishedSeconds,
  ) {
    return Row(
      children: [
        Expanded(
          child: _RecordStatTile(
            value: '$sessionCount',
            label: LocalizationEngine.text('records_session_count'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RecordStatTile(
            value: '$finishedCount',
            label: LocalizationEngine.text('records_finished_count'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RecordStatTile(
            value: formatSessionDuration(finishedSeconds),
            label: LocalizationEngine.text('records_finished_time'),
          ),
        ),
      ],
    );
  }

  /// 阅读记录概览单块统计（数值 + 标签）。
  Widget _RecordStatTile({
    required String value,
    required String label,
  }) {
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


  /// 阅读记录分组的子标题（如「看完了 (3)」）。
  Widget _recordSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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

  /// 根据书籍格式跳转到对应阅读器。
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

// ╔════════════════════════════════════════════════╗
// ║           子组件 / 数据类                       ║
// ╚════════════════════════════════════════════════╝

/// 单项指标数据模型
class _MetricCard {
  final IconData icon;
  final String value;
  final String label;

  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });
}

/// 四项指标单格 Tile（图标居上、数值居中、标签居下）
class _MetricTile extends StatelessWidget {
  final CupertinoThemeData theme;
  final _MetricCard item;

  const _MetricTile({required this.theme, required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(item.icon, size: 19, color: theme.primaryColor),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: TextStyle(fontSize: 11, color: labelColor),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// 将数值向上取整为「漂亮数」（1/2/2.5/5 × 10ⁿ），让坐标轴刻度易读。
double _niceCeil(double v) {
  if (v <= 0) return 1;
  final exp = (math.log(v) / math.ln10).floor();
  final base = math.pow(10, exp).toDouble();
  final f = v / base;
  final nf = f <= 1
      ? 1.0
      : f <= 2
          ? 2.0
          : f <= 2.5
              ? 2.5
              : f <= 5
                  ? 5.0
                  : 10.0;
  return nf * base;
}

/// 坐标轴刻度文本：整数不显示小数，否则保留 1 位。
String _fmtTick(double v) {
  if (v == v.roundToDouble()) return v.round().toString();
  return v.toStringAsFixed(1);
}

/// 阅读时长趋势柱状图（纯绘制，支持自适应宽度）
class _TrendBarChart extends StatelessWidget {
  final List<MapEntry<DateTime, int>> entries;
  final Color accentColor;
  final double axisMax; // 纵坐标上限（以 unit 为单位）
  final double unit; // 每分钟对应的刻度单位：1=分钟，60=小时
  final String unitLabel; // 纵坐标单位文案（分/时）
  final String? Function(DateTime)? xLabelBuilder; // 横轴标签自定义（日视图按小时）

  const _TrendBarChart({
    super.key,
    required this.entries,
    required this.accentColor,
    required this.axisMax,
    required this.unit,
    required this.unitLabel,
    this.xLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _TrendPainter(
        entries: entries,
        accentColor: accentColor,
        axisMax: axisMax,
        unit: unit,
        unitLabel: unitLabel,
        xLabelBuilder: xLabelBuilder,
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<MapEntry<DateTime, int>> entries;
  final Color accentColor;
  final double axisMax;
  final double unit;
  final String unitLabel;
  final String? Function(DateTime)? xLabelBuilder;

  _TrendPainter({
    required this.entries,
    required this.accentColor,
    required this.axisMax,
    required this.unit,
    required this.unitLabel,
    this.xLabelBuilder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    final safeMax = axisMax;

    final barW = math.max(
      (size.width - 20) / entries.length * 0.55,
      6.0,
    );
    final gap = ((size.width - 20) - barW * entries.length) /
        (entries.length + 1);

    final baseY = size.height - 18; // 底部留空间放日期

    // Y轴刻度线（左侧数字 0~N，顶部刻度带单位）
    const ySteps = 5;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var i = 0; i <= ySteps; i++) {
      final y = baseY - (baseY - 10) * (i / ySteps);
      final val = safeMax * i / ySteps;
      final isTop = i == ySteps;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = CupertinoColors.systemGrey5
          ..strokeWidth = 0.5,
      );

      if (i % 2 == 0) {
        final labelText = isTop ? '${_fmtTick(val)}$unitLabel' : _fmtTick(val);
        textPainter.text = TextSpan(
          text: labelText,
          style: const TextStyle(fontSize: 9, color: CupertinoColors.systemGrey),
        );
        textPainter.layout(minWidth: 0, maxWidth: 30);
        textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
      }
    }

    // 画柱子
    for (var i = 0; i < entries.length; i++) {
      final x = gap + i * (barW + gap);
      final v = entries[i].value / unit;
      final h = (v / safeMax) * (baseY - 16);
      final rect = Rect.fromLTWH(x, baseY - h, barW, h);

      final paint = Paint()
        ..color = accentColor.withOpacity(0.72)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        paint,
      );
    }

    // X轴日期标签（每隔几个显示一个避免重叠）
    final step = entries.length > 15 ? (entries.length ~/ 15).clamp(3, 7) : 1;
    for (var i = 0; i < entries.length; i += step) {
      final x = gap + i * (barW + gap) + barW / 2;
      final d = entries[i].key;
      final label =
          xLabelBuilder != null ? xLabelBuilder!(d) : '${d.month}/${d.day}';
      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(fontSize: 9, color: CupertinoColors.systemGrey),
      );
      textPainter.layout(minWidth: 0, maxWidth: 36);
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, baseY + 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 阅读时长趋势折线图（纯绘制，支持自适应宽度）
class _TrendLineChart extends StatelessWidget {
  final List<MapEntry<DateTime, int>> entries;
  final Color accentColor;
  final double axisMax; // 纵坐标上限（以 unit 为单位）
  final double unit; // 每分钟对应的刻度单位：1=分钟，60=小时
  final String unitLabel; // 纵坐标单位文案（分/时）
  final String? Function(DateTime)? xLabelBuilder; // 横轴标签自定义（日视图按小时）

  const _TrendLineChart({
    super.key,
    required this.entries,
    required this.accentColor,
    required this.axisMax,
    required this.unit,
    required this.unitLabel,
    this.xLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _TrendLinePainter(
        entries: entries,
        accentColor: accentColor,
        axisMax: axisMax,
        unit: unit,
        unitLabel: unitLabel,
        xLabelBuilder: xLabelBuilder,
      ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  final List<MapEntry<DateTime, int>> entries;
  final Color accentColor;
  final double axisMax;
  final double unit;
  final String unitLabel;
  final String? Function(DateTime)? xLabelBuilder;

  _TrendLinePainter({
    required this.entries,
    required this.accentColor,
    required this.axisMax,
    required this.unit,
    required this.unitLabel,
    this.xLabelBuilder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    final safeMax = axisMax;

    final baseY = size.height - 18;
    final n = entries.length;
    final x0 = n > 1 ? 10.0 : size.width / 2;
    final stepX = n > 1 ? (size.width - 20) / (n - 1) : 0.0;

    // Y轴刻度线（顶部刻度带单位）
    final ySteps = 5;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= ySteps; i++) {
      final y = baseY - (baseY - 10) * (i / ySteps);
      final val = safeMax * i / ySteps;
      final isTop = i == ySteps;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = CupertinoColors.systemGrey5
          ..strokeWidth = 0.5,
      );
      if (i % 2 == 0) {
        final labelText = isTop ? '${_fmtTick(val)}$unitLabel' : _fmtTick(val);
        textPainter.text = TextSpan(
          text: labelText,
          style: const TextStyle(fontSize: 9, color: CupertinoColors.systemGrey),
        );
        textPainter.layout(minWidth: 0, maxWidth: 30);
        textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
      }
    }

    // 计算各点坐标
    final pts = <Offset>[];
    for (var i = 0; i < n; i++) {
      final x = n > 1 ? x0 + i * stepX : x0;
      final v = entries[i].value / unit;
      final y = baseY - (v / safeMax) * (baseY - 16);
      pts.add(Offset(x, y));
    }

    // 面积填充
    final areaPath = Path()..moveTo(pts.first.dx, baseY);
    for (final p in pts) areaPath.lineTo(p.dx, p.dy);
    areaPath.lineTo(pts.last.dx, baseY);
    areaPath.close();
    canvas.drawPath(
      areaPath,
      Paint()..color = accentColor.withOpacity(0.12)..style = PaintingStyle.fill,
    );

    // 折线
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) linePath.lineTo(p.dx, p.dy);
    canvas.drawPath(
      linePath,
      Paint()
        ..color = accentColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 数据点
    for (final p in pts) {
      canvas.drawCircle(p, 2.5, Paint()..color = accentColor);
    }

    // X轴标签
    final step = n > 15 ? (n ~/ 15).clamp(3, 7) : 1;
    for (var i = 0; i < n; i += step) {
      final x = n > 1 ? x0 + i * stepX : x0;
      final d = entries[i].key;
      final label =
          xLabelBuilder != null ? xLabelBuilder!(d) : '${d.month}/${d.day}';
      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(fontSize: 9, color: CupertinoColors.systemGrey),
      );
      textPainter.layout(minWidth: 0, maxWidth: 36);
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, baseY + 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 热力图单日单元格
class _DayCell {
  final DateTime date;
  final int minutes;
  // 4 个「6 小时段」的阅读分钟数：[0]=00~06 [1]=06~12 [2]=12~18 [3]=18~24
  // 仅周/月日历热力图使用；年/全部贡献图不依赖，默认全 0。
  final List<int> blockMinutes;

  _DayCell({
    required this.date,
    required this.minutes,
    List<int>? blockMinutes,
  }) : blockMinutes = blockMinutes ?? [0, 0, 0, 0];
}


/// 时间分布环形扇区
class _RingSegment {
  final String label;
  final double percent;
  final Color color;

  _RingSegment({
    required this.label,
    required this.percent,
    required this.color,
  });
}

/// 环形图画笔（带中心空白）
class _RingPainter extends CustomPainter {
  final List<_RingSegment> segments;

  _RingPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const outerR = 52.0;
    const innerR = 38.0;

    var startAngle = -math.pi / 2;
    for (final seg in segments) {
      final sweep = seg.percent * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: outerR),
        startAngle,
        sweep,
        false,
        Paint()
          ..color = seg.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = outerR - innerR
          ..strokeCap = StrokeCap.butt,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 本月阅读记录单行卡片
class _RecordCard extends StatelessWidget {
  final CupertinoThemeData theme;
  final BookModel book;
  final VoidCallback onTap;

  const _RecordCard({
    required this.theme,
    required this.book,
    required this.onTap,
    super.key,
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

  /// 阅读进度文本：读完显示「已读完」，在读显示「读到 X%」。
  /// 说明：书籍模型仅持久化 progress（0~1 百分比），未存储绝对页码，
  /// 故此处以真实进度百分比表达「读到第几页」的语义。
  String _progressText() {
    if (book.progress >= 1.0) {
      return LocalizationEngine.text('record_done_label');
    }
    final pct = (book.progress * 100).round();
    if (pct <= 0) return '';
    return '${LocalizationEngine.text('record_progress_prefix')} $pct%';
  }

  @override
  Widget build(BuildContext context) {
    final durText = _durationText();
    final dateStr = _dateText();
    final progText = _progressText();

    // 副标题：阅读进度 + 阅读时长 + 阅读日期，按有无数据动态拼接
    final parts = <String>[];
    if (progText.isNotEmpty) {
      parts.add(progText);
    }
    if (durText.isNotEmpty) {
      parts.add('${LocalizationEngine.text('record_duration_label')} $durText');
    }
    if (dateStr.isNotEmpty) {
      parts.add('${LocalizationEngine.text('record_read_on')} $dateStr');
    }
    final subtitle = parts.join('  ·  ');

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: BookCoverImage(
                  book: book,
                  fallback: (_) => const Icon(
                    CupertinoIcons.book,
                    size: 20,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
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
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
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
          ],
        ),
      ),
    );
  }
}

/// 单次阅读会话行：封面 + 书名 + 「HH:MM 开始 · 读了 Y 分钟」。
/// 用于「阅读记录」的阅读明细：每次打开阅读器即产生一条会话记录。
class _SessionRow extends StatelessWidget {
  final CupertinoThemeData theme;
  final BookModel? book;
  final ReadingSession session;
  final VoidCallback onTap;

  const _SessionRow({
    required this.theme,
    required this.book,
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = book?.title ?? LocalizationEngine.text('unknown_book');
    // 副标题：开始时间 + 本次阅读时长（均走本地化）
    final timeText =
        '${formatSessionTime(session.startedAt)}${LocalizationEngine.text('session_start_suffix')} · ${LocalizationEngine.text('session_read_prefix')}${formatSessionDuration(session.durationSeconds)}';

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            // 封面缩略图（无书籍时显示占位图标）
            Container(
              width: 44,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: CupertinoColors.systemGrey5,
              ),
              child: book != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: BookCoverImage(
                        book: book!,
                        fallback: (_) => const Icon(
                          CupertinoIcons.book,
                          size: 20,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    )
                  : const Icon(
                      CupertinoIcons.book,
                      size: 20,
                      color: CupertinoColors.systemGrey,
                    ),
            ),
            const SizedBox(width: 10),
            // 书名 + 开始时间 / 时长
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
                  const SizedBox(height: 3),
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
