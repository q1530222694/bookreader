import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../controller/bookshelf_controller.dart';
import '../model/book_model.dart';
import '../model/reading_stats_model.dart';

/// MemoryPage displays a modern reading statistics experience for the shell module.
class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  final BookshelfController _controller = BookshelfController();
  _ReadingPeriod _period = _ReadingPeriod.day;
  _ChartMode _chartMode = _ChartMode.bar;
  int _selectedPoint = 0;

  @override
  void initState() {
    super.initState();
    _selectedPoint = 0;
  }

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
        final stats = ReadingStats.fromBooks(books);
        final data = _buildPeriodDataFor(_period, stats);

        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.maybePop(context),
              child: const Icon(CupertinoIcons.back, size: 22),
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
              child: const Icon(CupertinoIcons.share, size: 20),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSegmentedControl(theme, stats),
                  const SizedBox(height: 14),
                  _buildDateSwitcher(theme),
                  const SizedBox(height: 18),
                  _buildChartCard(theme, data),
                  const SizedBox(height: 16),
                  _buildMetricGrid(theme, stats),
                  const SizedBox(height: 16),
                  _buildReadingTimeDistribution(theme, stats),
                  const SizedBox(height: 16),
                  _buildTrendCard(theme, stats),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSegmentedControl(CupertinoThemeData theme, ReadingStats stats) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: _ReadingPeriod.values.map((period) {
          final selected = period == _period;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _period = period;
                  _selectedPoint =
                      _buildPeriodDataFor(period, stats).values.length - 1;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? theme.primaryColor
                      : CupertinoColors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    _labelForPeriod(period),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? CupertinoColors.white
                          : CupertinoColors.systemGrey,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateSwitcher(CupertinoThemeData theme) {
    return Row(
      children: [
        CupertinoButton(
          padding: const EdgeInsets.all(8),
          minSize: 36,
          borderRadius: BorderRadius.circular(999),
          color: CupertinoColors.systemGrey6,
          onPressed: () {},
          child: const Icon(CupertinoIcons.chevron_left, size: 18),
        ),
        Expanded(
          child: Center(
            child: Text(
              _dateLabelForPeriod(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        CupertinoButton(
          padding: const EdgeInsets.all(8),
          minSize: 36,
          borderRadius: BorderRadius.circular(999),
          color: CupertinoColors.systemGrey6,
          onPressed: () {},
          child: const Icon(CupertinoIcons.calendar, size: 18),
        ),
      ],
    );
  }

  Widget _buildMetricGrid(CupertinoThemeData theme, ReadingStats stats) {
    final metricItems = <_StatItem>[
      _StatItem(
        LocalizationEngine.text('today_reading'),
        stats.formattedTodayReading,
        stats.todayChangeLabel,
        CupertinoIcons.book_solid,
        const Color(0xFFE5F0FF),
      ),
      _StatItem(
        LocalizationEngine.text('this_week_reading'),
        stats.formattedWeekReading,
        stats.weekChangeLabel,
        CupertinoIcons.calendar,
        const Color(0xFFE5F6EC),
      ),
      _StatItem(
        LocalizationEngine.text('cumulative_reading'),
        stats.formattedTotalReading,
        '${stats.activeDays}${LocalizationEngine.text('days_short')}',
        CupertinoIcons.chart_bar_fill,
        const Color(0xFFE9F4FF),
      ),
      _StatItem(
        LocalizationEngine.text('longest_reading_day'),
        stats.longestReadingDayLabel,
        stats.longestReadingDurationLabel,
        CupertinoIcons.flame_fill,
        const Color(0xFFFFF4E5),
      ),
      _StatItem(
        LocalizationEngine.text('continuous_reading'),
        '${stats.streakDays}${LocalizationEngine.text('days_short')}',
        '${stats.activeDays}${LocalizationEngine.text('days_short')}',
        CupertinoIcons.flame_fill,
        const Color(0xFFF3E8FF),
      ),
      _StatItem(
        LocalizationEngine.text('cumulative_reading_days'),
        '${stats.activeDays}${LocalizationEngine.text('days_short')}',
        '',
        CupertinoIcons.calendar_badge_plus,
        const Color(0xFFEFF6FF),
      ),
      _StatItem(
        LocalizationEngine.text('average_daily_reading'),
        stats.formattedAverageDailyReading,
        '',
        CupertinoIcons.timer,
        const Color(0xFFF5F3FF),
      ),
      _StatItem(
        LocalizationEngine.text('completed_books'),
        '${stats.completedBooks}${LocalizationEngine.text('books_short')}',
        '',
        CupertinoIcons.book_circle_fill,
        const Color(0xFFEDEDED),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metricItems.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.98,
      ),
      itemBuilder: (context, index) {
        final item = metricItems[index];
        final textColor = theme.textTheme.textStyle.color ?? CupertinoColors.label;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CupertinoColors.systemGrey6, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: item.iconBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.iconData,
                      size: 14,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              if (item.subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor.withOpacity(0.6),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartCard(CupertinoThemeData theme, _PeriodData data) {
    final textColor = theme.textTheme.textStyle.color ?? CupertinoColors.label;
    final labels = data.labels;
    final values = data.values;
    final selectedIndex = _selectedPoint.clamp(0, values.length - 1);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocalizationEngine.text('total_reading_duration'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatDurationForLocale(data.totalDuration),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${LocalizationEngine.text('daily_average')}: ${data.averageDuration}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${LocalizationEngine.text('vs_previous_period')}: ${data.changeRate}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 将图表下方的选中数据移到“总阅读时长”区域下方，保持在同一行显示
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            labels[selectedIndex],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          values[selectedIndex].toStringAsFixed(0) +
                              LocalizationEngine.text('hours_short'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildChartToggle(
                    _ChartMode.bar,
                    CupertinoIcons.chart_bar_fill,
                  ),
                  const SizedBox(width: 8),
                  _buildChartToggle(
                    _ChartMode.line,
                    CupertinoIcons.graph_square_fill,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ReadingChart(
            labels: labels,
            values: values,
            isBarChart: _chartMode == _ChartMode.bar,
            selectedIndex: selectedIndex,
            onSelect: (index) => setState(() => _selectedPoint = index),
            accentColor: theme.primaryColor,
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildReadingTimeDistribution(
    CupertinoThemeData theme,
    ReadingStats stats,
  ) {
    final distributionData = <_DistributionItem>[
      _DistributionItem(
        '1小时以下',
        stats.distributionUnder1HourMinutes,
        const Color(0xFF007AFF),
      ),
      _DistributionItem(
        '1-2小时',
        stats.distribution1To2HoursMinutes,
        const Color(0xFF34C759),
      ),
      _DistributionItem(
        '2-3小时',
        stats.distribution2To3HoursMinutes,
        const Color(0xFFFFA500),
      ),
      _DistributionItem(
        '3小时以上',
        stats.distribution3HoursMoreMinutes,
        const Color(0xFFFF3B30),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CupertinoColors.systemGrey6, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 把“阅读时长分布”标签放在环形图上方并加粗
          Builder(
            builder: (context) {
              final textColor =
                  theme.textTheme.textStyle.color ?? CupertinoColors.label;
              return Text(
                LocalizationEngine.text('reading_time_distribution'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // 主题色与文本色
          Builder(
            builder: (context) {
              final textColor =
                  theme.textTheme.textStyle.color ?? CupertinoColors.label;
              final accent = theme.primaryColor;
              return Row(
                children: [
                  Column(
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(140, 140),
                              painter: _DonutChartPainter(
                                data: distributionData,
                              ),
                            ),
                            // 中心只显示时长数值，标签已移至上方
                            Text(
                              stats.formattedDistributionTotal,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: distributionData.map((item) {
                        final totalMinutes = distributionData.fold<int>(
                          0,
                          (sum, entry) => sum + entry.minutes,
                        );
                        final percentage = totalMinutes > 0
                            ? (item.minutes / totalMinutes) * 100
                            : 0.0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: item.color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              Text(
                                '${percentage.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(CupertinoThemeData theme, ReadingStats stats) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CupertinoColors.systemGrey6, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocalizationEngine.text('trend_summary'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                CupertinoIcons.graph_circle_fill,
                size: 18,
                color: CupertinoColors.systemGrey,
              ),
              const SizedBox(width: 8),
              Text(
                LocalizationEngine.text('reading_trend'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            LocalizationEngine.text('reading_trend_insight'),
            style: const TextStyle(
              fontSize: 13,
              color: CupertinoColors.systemGrey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildTrendPill(
                '${stats.streakDays}${LocalizationEngine.text('days_short')}',
                LocalizationEngine.text('continuous_reading_label'),
              ),
              _buildTrendPill(
                stats.formattedAverageDailyReading,
                LocalizationEngine.text('average_daily_reading'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendPill(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: CupertinoColors.black),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const TextSpan(text: '  '),
            TextSpan(
              text: label,
              style: const TextStyle(color: CupertinoColors.systemGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartToggle(_ChartMode mode, IconData icon) {
    final selected = _chartMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _chartMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? CupertinoColors.white : CupertinoColors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: CupertinoColors.systemGrey.withOpacity(0.16),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 16,
          color: selected
              ? CupertinoTheme.of(context).primaryColor
              : CupertinoColors.systemGrey,
        ),
      ),
    );
  }

  _PeriodData _buildPeriodDataFor(_ReadingPeriod period, ReadingStats stats) {
    switch (period) {
      case _ReadingPeriod.day:
        return _buildDailyPeriodData(stats);
      case _ReadingPeriod.week:
        return _buildWeeklyPeriodData(stats);
      case _ReadingPeriod.month:
        return _buildMonthlyPeriodData(stats);
      case _ReadingPeriod.year:
        return _buildYearlyPeriodData(stats);
    }
  }

  _PeriodData _buildDailyPeriodData(ReadingStats stats) {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final labels = List<String>.generate(12, (index) {
      final date = normalizedToday.subtract(Duration(days: 11 - index));
      return '${date.month}/${date.day}';
    });
    final values = List<double>.generate(12, (index) {
      final date = normalizedToday.subtract(Duration(days: 11 - index));
      final normalizedDate = DateTime(date.year, date.month, date.day);
      return stats.dailyMinutes[normalizedDate]?.toDouble() ?? 0.0;
    }).map((minutes) => minutes / 60.0).toList();
    final total = values.fold(0.0, (sum, value) => sum + value);
    final previousTotal = stats.previousDailyWindowMinutes / 60.0;
    return _PeriodData(
      totalDuration: _formatDuration((total * 60).round()),
      averageDuration: _formatDuration((total * 60 / 12).round()),
      changeRate: _formatChangeRate(total, previousTotal),
      labels: labels,
      values: values,
    );
  }

  _PeriodData _buildWeeklyPeriodData(ReadingStats stats) {
    final today = DateTime.now();
    final currentWeekStart = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    final labels = List<String>.generate(12, (index) {
      final weekStart = currentWeekStart.subtract(
        Duration(days: 7 * (11 - index)),
      );
      return '${weekStart.month}/${weekStart.day}';
    });
    final values = List<double>.generate(12, (index) {
      final weekStart = currentWeekStart.subtract(
        Duration(days: 7 * (11 - index)),
      );
      final weekEnd = weekStart.add(const Duration(days: 7));
      return stats.minutesBetween(weekStart, weekEnd) / 60.0;
    });
    return _PeriodData(
      totalDuration: _formatDuration((stats.weekMinutes).round()),
      averageDuration: _formatDuration((stats.weekMinutes / 7).round()),
      changeRate: _formatChangeRate(
        stats.weekMinutes / 60.0,
        stats.previousWeekMinutes / 60.0,
      ),
      labels: labels,
      values: values,
    );
  }

  _PeriodData _buildMonthlyPeriodData(ReadingStats stats) {
    final today = DateTime.now();
    final labels = List<String>.generate(12, (index) {
      final monthStart = DateTime(today.year, today.month - 11 + index, 1);
      return '${monthStart.month}月';
    });
    final values = List<double>.generate(12, (index) {
      final monthStart = DateTime(today.year, today.month - 11 + index, 1);
      final nextMonthStart = DateTime(monthStart.year, monthStart.month + 1, 1);
      return stats.minutesBetween(monthStart, nextMonthStart) / 60.0;
    });
    return _PeriodData(
      totalDuration: _formatDuration(stats.monthMinutes),
      averageDuration: _formatDuration(
        (stats.monthMinutes /
                (DateTime(
                  today.year,
                  today.month + 1,
                  1,
                ).difference(DateTime(today.year, today.month, 1)).inDays))
            .round(),
      ),
      changeRate: _formatChangeRate(
        stats.monthMinutes / 60.0,
        stats.previousMonthMinutes / 60.0,
      ),
      labels: labels,
      values: values,
    );
  }

  _PeriodData _buildYearlyPeriodData(ReadingStats stats) {
    final today = DateTime.now();
    final labels = List<String>.generate(10, (index) {
      final year = today.year - 9 + index;
      return year.toString();
    });
    final values = List<double>.generate(10, (index) {
      final year = today.year - 9 + index;
      final yearStart = DateTime(year, 1, 1);
      final nextYearStart = DateTime(year + 1, 1, 1);
      return stats.minutesBetween(yearStart, nextYearStart) / 60.0;
    });
    return _PeriodData(
      totalDuration: _formatDuration(stats.yearMinutes),
      averageDuration: _formatDuration((stats.yearMinutes / 365).round()),
      changeRate: _formatChangeRate(
        stats.yearMinutes / 60.0,
        stats.previousYearMinutes / 60.0,
      ),
      labels: labels,
      values: values,
    );
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) {
      return '0${LocalizationEngine.text('minutes_short')}';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final hourLabel = hours > 0
        ? '${hours}${LocalizationEngine.text('hours_short')}'
        : '';
    final minuteLabel = '${mins}${LocalizationEngine.text('minutes_short')}';
    return hourLabel.isNotEmpty ? '$hourLabel $minuteLabel' : minuteLabel;
  }

  String _formatChangeRate(double current, double previous) {
    if (previous <= 0) {
      return current <= 0 ? '0%' : '+100%';
    }
    final rate = ((current - previous) / previous) * 100;
    final sign = rate >= 0 ? '+' : '';
    return '$sign${rate.toStringAsFixed(0)}%';
  }

  String _labelForPeriod(_ReadingPeriod period) {
    switch (period) {
      case _ReadingPeriod.day:
        return LocalizationEngine.text('period_day');
      case _ReadingPeriod.week:
        return LocalizationEngine.text('period_week');
      case _ReadingPeriod.month:
        return LocalizationEngine.text('period_month');
      case _ReadingPeriod.year:
        return LocalizationEngine.text('period_year');
    }
  }

  String _dateLabelForPeriod() {
    final now = DateTime.now();
    switch (_period) {
      case _ReadingPeriod.day:
        return _formatDate(now);
      case _ReadingPeriod.week:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        return '${_formatDate(weekStart)} ~ ${_formatDate(weekEnd)}';
      case _ReadingPeriod.month:
        return '${now.year}/${now.month.toString().padLeft(2, '0')}';
      case _ReadingPeriod.year:
        return now.year.toString();
    }
  }

  String _formatDate(DateTime value) {
    return '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';
  }

  String _formatDurationForLocale(String duration) {
    // 如果是中文语言，输出形如 “XX小时XX分钟” 的格式，默认回退原始字符串
    if (SettingsEngine.language == SettingsEngine.languageChinese) {
      if (duration.contains('小时') || duration.contains('分钟')) return duration;
      final hourMatch = RegExp(r"(\d+)h").firstMatch(duration);
      final minMatch = RegExp(r"(\d+)m").firstMatch(duration);
      final hours = hourMatch?.group(1);
      final mins = minMatch?.group(1);
      var out = '';
      if (hours != null) out += '${hours}小时';
      if (mins != null) out += '${mins}分钟';
      if (out.isNotEmpty) return out;
    }
    return duration;
  }
}

class _PeriodData {
  const _PeriodData({
    required this.totalDuration,
    required this.averageDuration,
    required this.changeRate,
    required this.labels,
    required this.values,
  });

  final String totalDuration;
  final String averageDuration;
  final String changeRate;
  final List<String> labels;
  final List<double> values;
}

class _StatItem {
  const _StatItem(
    this.title,
    this.value,
    this.subtitle, [
    this.iconData = CupertinoIcons.info,
    this.iconBackground = CupertinoColors.systemGrey5,
  ]);

  final String title;
  final String value;
  final String subtitle;
  final IconData iconData;
  final Color iconBackground;
}

enum _ReadingPeriod { day, week, month, year }

enum _ChartMode { bar, line }

class _ReadingChart extends StatelessWidget {
  const _ReadingChart({
    required this.labels,
    required this.values,
    required this.isBarChart,
    required this.selectedIndex,
    required this.onSelect,
    required this.accentColor,
  });

  final List<String> labels;
  final List<double> values;
  final bool isBarChart;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: CustomPaint(
        painter: _ChartPainter(
          values: values,
          labels: labels,
          isBarChart: isBarChart,
          selectedIndex: selectedIndex,
          accentColor: accentColor,
          gridColor: CupertinoColors.systemGrey5,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final chartLeft = 44.0;
            final chartRight = constraints.maxWidth - 12.0;
            final chartWidth = chartRight - chartLeft;
            final chartBottom = constraints.maxHeight - 12.0;
            final maxValue = math.max(values.isEmpty ? 0.0 : values.reduce(math.max), 1.0);
            final points = <Rect>[];

            if (values.isEmpty) {
              return const SizedBox.shrink();
            }

            if (isBarChart) {
              final barWidth = math.min(chartWidth / values.length * 0.6, 34.0);
              final spacing = math.max(
                (chartWidth - barWidth * values.length) / (values.length + 1),
                4.0,
              );
              for (var index = 0; index < values.length; index++) {
                final x = chartLeft + spacing + index * (barWidth + spacing);
                final height =
                    (values[index] / maxValue) * (constraints.maxHeight - 40);
                final y = chartBottom - height;
                points.add(Rect.fromLTWH(x, y, barWidth, height));
              }
            } else {
              final step = chartWidth / math.max(values.length - 1, 1);
              for (var index = 0; index < values.length; index++) {
                final x = chartLeft + step * index;
                final y =
                    chartBottom -
                    (values[index] / maxValue) * (constraints.maxHeight - 40);
                points.add(
                  Rect.fromCenter(center: Offset(x, y), width: 24, height: 24),
                );
              }
            }

            return GestureDetector(
              onTapUp: (details) {
                final tapX = details.localPosition.dx;
                if (isBarChart) {
                  for (var i = 0; i < points.length; i++) {
                    if (points[i].contains(details.localPosition)) {
                      onSelect(i);
                      return;
                    }
                  }
                } else {
                  final closestIndex =
                      ((tapX - chartLeft) /
                              (values.length > 1
                                  ? chartWidth / (values.length - 1)
                                  : chartWidth))
                          .round();
                  final index = closestIndex.clamp(0, values.length - 1);
                  onSelect(index);
                }
              },
              child: Stack(
                children: points
                    .map(
                      (rect) => Positioned.fromRect(
                        rect: rect,
                        child: const SizedBox(),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter({
    required this.values,
    required this.labels,
    required this.isBarChart,
    required this.selectedIndex,
    required this.accentColor,
    required this.gridColor,
  });

  final List<String> labels;
  final List<double> values;
  final bool isBarChart;
  final int selectedIndex;
  final Color accentColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final chartLeft = 44.0;
    final chartRight = size.width - 12.0;
    final chartTop = 12.0;
    final chartBottom = size.height - 12.0;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;
    final maxValue = values.isEmpty ? 1.0 : math.max(values.reduce(math.max), 1.0);
    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke;
    final axisPaint = Paint()
      ..color = CupertinoColors.systemGrey4
      ..strokeWidth = 1;
    final fillPaint = Paint()
      ..color = accentColor.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final selectedPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    const labelCount = 5;
    final stepValue = maxValue / (labelCount - 1);
    final labelStyle = const TextStyle(
      fontSize: 10,
      color: CupertinoColors.systemGrey,
    );

    for (var i = 0; i < labelCount; i++) {
      final y = chartBottom - chartHeight / (labelCount - 1) * i;
      final labelValue = stepValue * i;
      final formatted = labelValue % 1 == 0
          ? labelValue.toInt().toString()
          : labelValue.toStringAsFixed(1);
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$formatted${LocalizationEngine.text('hours_short')}',
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
      )..layout(minWidth: 0, maxWidth: chartLeft - 8);
      textPainter.paint(
        canvas,
        Offset(chartLeft - textPainter.width - 6, y - textPainter.height / 2),
      );
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
    }

    canvas.drawLine(
      Offset(chartLeft, chartTop),
      Offset(chartLeft, chartBottom),
      axisPaint,
    );

    if (values.isNotEmpty) {
      final labelStyle = const TextStyle(
        fontSize: 10,
        color: CupertinoColors.systemGrey,
      );
      final xStep = values.length > 1
          ? chartWidth / (values.length - 1)
          : chartWidth;
      for (var index = 0; index < values.length; index++) {
        if (values.length > 10 && index.isOdd) continue;
        final label = labels[index];
        final textPainter = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(minWidth: 0, maxWidth: xStep + 4);
        final x = isBarChart
            ? chartLeft +
                  math.max(
                    (chartWidth -
                            math.min(chartWidth / values.length * 0.6, 34.0) *
                                values.length) /
                        (values.length + 1),
                    4.0,
                  ) +
                  index *
                      (math.min(chartWidth / values.length * 0.6, 34.0) +
                          math.max(
                            (chartWidth -
                                    math.min(
                                          chartWidth / values.length * 0.6,
                                          34.0,
                                        ) *
                                        values.length) /
                                (values.length + 1),
                            4.0,
                          )) +
                  math.min(chartWidth / values.length * 0.6, 34.0) / 2
            : chartLeft + xStep * index;
        final dx = x - textPainter.width / 2;
        textPainter.paint(
          canvas,
          Offset(
            dx.clamp(
              chartLeft - textPainter.width / 2,
              chartRight - textPainter.width / 2,
            ),
            chartBottom + 4,
          ),
        );
      }
    }

    canvas.drawLine(
      Offset(chartLeft, chartBottom),
      Offset(chartRight, chartBottom),
      axisPaint,
    );

    if (isBarChart) {
      final barWidth = math.min(chartWidth / values.length * 0.6, 34.0);
      final spacing = math.max(
        (chartWidth - barWidth * values.length) / (values.length + 1),
        4.0,
      );
      for (var index = 0; index < values.length; index++) {
        final x = chartLeft + spacing + index * (barWidth + spacing);
        final barHeight = (values[index] / maxValue) * chartHeight;
        final rect = Rect.fromLTWH(
          x,
          chartBottom - barHeight,
          barWidth,
          barHeight,
        );
        final color = index == selectedIndex
            ? accentColor
            : accentColor.withOpacity(0.72);
        final barPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          barPaint,
        );
      }
    } else {
      final points = <Offset>[];
      for (var index = 0; index < values.length; index++) {
        final x =
            chartLeft + (chartWidth / math.max(values.length - 1, 1)) * index;
        final y = chartBottom - (values[index] / maxValue) * chartHeight;
        points.add(Offset(x, y));
      }
      if (points.length > 1) {
        final fillPath = Path()..moveTo(points.first.dx, chartBottom);
        for (final point in points) {
          fillPath.lineTo(point.dx, point.dy);
        }
        fillPath.lineTo(points.last.dx, chartBottom);
        fillPath.close();
        canvas.drawPath(fillPath, fillPaint);

        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, linePaint);
      }
      for (var index = 0; index < points.length; index++) {
        final point = points[index];
        final radius = index == selectedIndex ? 6.0 : 4.5;
        canvas.drawCircle(point, radius, selectedPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DistributionItem {
  const _DistributionItem(this.label, this.minutes, this.color);

  final String label;
  final int minutes;
  final Color color;
}

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({required this.data});

  final List<_DistributionItem> data;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 16.0;

    var startAngle = -math.pi / 2;
    final total = data.fold<int>(0, (sum, item) => sum + item.minutes);

    if (total <= 0) {
      return;
    }

    for (final item in data) {
      final sweepAngle = (item.minutes / total) * 2 * math.pi;

      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
