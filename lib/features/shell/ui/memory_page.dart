import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';

/// MemoryPage displays a modern reading statistics experience for the shell module.
class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  _ReadingPeriod _period = _ReadingPeriod.day;
  _ChartMode _chartMode = _ChartMode.bar;
  int _selectedPoint = 5;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final data = _buildPeriodData();

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
              _buildSegmentedControl(theme),
              const SizedBox(height: 14),
              _buildDateSwitcher(theme),
              const SizedBox(height: 18),
              _buildChartCard(theme, data),
              const SizedBox(height: 16),
              _buildMetricGrid(theme),
              const SizedBox(height: 16),
              _buildReadingTimeDistribution(theme),
              const SizedBox(height: 16),
              _buildTrendCard(theme),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedControl(CupertinoThemeData theme) {
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
                  _selectedPoint = 5;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? theme.primaryColor : CupertinoColors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    _labelForPeriod(period),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? CupertinoColors.white : CupertinoColors.systemGrey,
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

  Widget _buildMetricGrid(CupertinoThemeData theme) {
    final metricItems = <_StatItem>[
      _StatItem(
        LocalizationEngine.text('today_reading'),
        '2小时45分钟',
        LocalizationEngine.text('vs_yesterday') + ' ↑ 15%',
        CupertinoIcons.book_solid,
        const Color(0xFFE5F0FF),
      ),
      _StatItem(
        LocalizationEngine.text('this_week_reading'),
        '12小时30分钟',
        LocalizationEngine.text('vs_last_week') + ' ↑ 28%',
        CupertinoIcons.calendar,
        const Color(0xFFE5F6EC),
      ),
      _StatItem(
        LocalizationEngine.text('cumulative_reading'),
        '382小时',
        '126' + LocalizationEngine.text('days_short'),
        CupertinoIcons.chart_bar_fill,
        const Color(0xFFE9F4FF),
      ),
      _StatItem(
        LocalizationEngine.text('longest_reading_day'),
        '6月17日',
        '2h 45m',
        CupertinoIcons.flame_fill,
        const Color(0xFFFFF4E5),
      ),
      _StatItem(
        LocalizationEngine.text('continuous_reading'),
        '🔥 ' + LocalizationEngine.text('continuous_reading_label'),
        '18' + LocalizationEngine.text('days_short'),
        CupertinoIcons.sparkles,
        const Color(0xFFF3E8FF),
      ),
      _StatItem(
        LocalizationEngine.text('cumulative_reading'),
        '382' + LocalizationEngine.text('hours_short'),
        '',
        CupertinoIcons.chart_bar_circle_fill,
        const Color(0xFFE8F7ED),
      ),
      _StatItem(
        LocalizationEngine.text('cumulative_reading_days'),
        '126' + LocalizationEngine.text('days_short'),
        '',
        CupertinoIcons.calendar_badge_plus,
        const Color(0xFFEFF6FF),
      ),
      _StatItem(
        LocalizationEngine.text('average_daily_reading'),
        '1h 32m',
        '',
        CupertinoIcons.timer,
        const Color(0xFFF5F3FF),
      ),
      _StatItem(
        LocalizationEngine.text('completed_books'),
        '18' + LocalizationEngine.text('books_short'),
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
                    child: Icon(item.iconData, size: 14, color: theme.primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.value,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              if (item.subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: const TextStyle(fontSize: 10, color: CupertinoColors.systemGrey),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartCard(CupertinoThemeData theme, _PeriodData data) {
    final labels = data.labels;
    final values = data.values;

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
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CupertinoColors.systemGrey),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data.totalDuration,
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${LocalizationEngine.text('daily_average')}: ${data.averageDuration}',
                      style: const TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${LocalizationEngine.text('vs_previous_period')}: ${data.changeRate}',
                      style: const TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildChartToggle(_ChartMode.bar, CupertinoIcons.chart_bar_fill),
                  const SizedBox(width: 8),
                  _buildChartToggle(_ChartMode.line, CupertinoIcons.graph_square_fill),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ReadingChart(
            labels: labels,
            values: values,
            isBarChart: _chartMode == _ChartMode.bar,
            selectedIndex: _selectedPoint,
            onSelect: (index) => setState(() => _selectedPoint = index),
            accentColor: theme.primaryColor,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    labels[_selectedPoint],
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    values[_selectedPoint].toStringAsFixed(0) + LocalizationEngine.text('hours_short'),
                    style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadingTimeDistribution(CupertinoThemeData theme) {
    final distributionData = <_DistributionItem>[
      _DistributionItem('小时段下', 25, const Color(0xFF007AFF)),
      _DistributionItem('1-2小时', 40, const Color(0xFF34C759)),
      _DistributionItem('2-3小时', 20, const Color(0xFFFFA500)),
      _DistributionItem('3小时以上', 15, const Color(0xFFFF3B30)),
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
          Text(
            LocalizationEngine.text('reading_time_distribution'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CustomPaint(
                      painter: _DonutChartPainter(
                        data: distributionData,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        LocalizationEngine.text('reading_time_distribution'),
                        style: const TextStyle(fontSize: 10, color: CupertinoColors.systemGrey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '18h 45m',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: distributionData.map((item) {
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
                              style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                            ),
                          ),
                          Text(
                            '${item.percentage}%',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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

  Widget _buildTrendCard(CupertinoThemeData theme) {
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
              Icon(CupertinoIcons.graph_circle_fill, size: 18, color: CupertinoColors.systemGrey),
              const SizedBox(width: 8),
              Text(
                LocalizationEngine.text('reading_trend'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CupertinoColors.systemGrey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            LocalizationEngine.text('reading_trend_insight'),
            style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildTrendPill('18' + LocalizationEngine.text('days_short'), LocalizationEngine.text('continuous_reading_label')),
              _buildTrendPill('3.2' + LocalizationEngine.text('hours_short'), LocalizationEngine.text('average_daily_reading')),
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
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(text: '  '),
            TextSpan(text: label, style: const TextStyle(color: CupertinoColors.systemGrey)),
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
        child: Icon(icon, size: 16, color: selected ? CupertinoTheme.of(context).primaryColor : CupertinoColors.systemGrey),
      ),
    );
  }

  _PeriodData _buildPeriodData() {
    switch (_period) {
      case _ReadingPeriod.day:
        return _PeriodData(
          totalDuration: '18h 45m',
          averageDuration: '1h 34m',
          changeRate: '+23%',
          labels: ['6/12', '6/13', '6/14', '6/15', '6/16', '6/17', '6/18', '6/19', '6/20', '6/21', '6/22', '6/23'],
          values: [2.0, 1.4, 2.6, 1.8, 2.2, 2.6, 2.9, 3.1, 1.9, 2.4, 3.2, 2.7],
        );
      case _ReadingPeriod.week:
        return _PeriodData(
          totalDuration: '34h 12m',
          averageDuration: '4h 52m',
          changeRate: '+18%',
          labels: ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7', 'W8', 'W9', 'W10', 'W11', 'W12'],
          values: [4.6, 5.1, 4.9, 5.6, 6.1, 5.8, 6.5, 7.2, 6.3, 7.4, 8.0, 8.5],
        );
      case _ReadingPeriod.month:
        return _PeriodData(
          totalDuration: '126h 40m',
          averageDuration: '10h 33m',
          changeRate: '+12%',
          labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
          values: [8.3, 9.4, 10.2, 10.6, 11.1, 10.8, 11.6, 12.2, 11.7, 12.9, 13.4, 14.1],
        );
      case _ReadingPeriod.year:
        return _PeriodData(
          totalDuration: '382h 00m',
          averageDuration: '38h 12m',
          changeRate: '+9%',
          labels: ['2017', '2018', '2019', '2020', '2021', '2022', '2023', '2024', '2025', '2026'],
          values: [14.2, 18.6, 22.1, 26.7, 31.4, 34.0, 37.2, 41.5, 44.8, 49.6],
        );
    }
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
            final points = <Rect>[];
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final chartWidth = width - 24;
            final chartHeight = height - 28;
            final step = chartWidth / math.max(values.length - 1, 1);
            for (var index = 0; index < values.length; index++) {
              final x = 12 + step * index;
              final y = chartHeight - ((values[index] / values.reduce(math.max)) * (chartHeight - 18)) - 12;
              points.add(Rect.fromCenter(center: Offset(x, y), width: 24, height: 24));
            }
            return GestureDetector(
              onTapUp: (details) {
                final localX = details.localPosition.dx;
                final index = ((localX - 12) / step).round();
                if (index >= 0 && index < values.length) {
                  onSelect(index.clamp(0, values.length - 1));
                }
              },
              child: Stack(children: points.map((rect) => Positioned.fromRect(rect: rect, child: const SizedBox())).toList()),
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
    final chartHeight = size.height - 24;
    final chartWidth = size.width - 24;
    final maxValue = values.reduce(math.max);
    final gridPaint = Paint()..color = gridColor..style = PaintingStyle.stroke;
    final axisPaint = Paint()..color = CupertinoColors.systemGrey4..strokeWidth = 1;
    final fillPaint = Paint()..color = accentColor.withOpacity(0.18)..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final selectedPaint = Paint()..color = accentColor..style = PaintingStyle.fill;

    for (var index = 0; index < 4; index++) {
      final y = 16 + index * (chartHeight / 3);
      canvas.drawLine(Offset(12, y), Offset(chartWidth, y), gridPaint);
    }

    if (isBarChart) {
      final barWidth = chartWidth / (values.length * 1.6);
      for (var index = 0; index < values.length; index++) {
        final x = 12 + barWidth * (index * 1.3 + 0.3);
        final h = (values[index] / maxValue) * (chartHeight - 24);
        final rect = Rect.fromLTWH(x, chartHeight - h, barWidth * 0.7, h);
        final color = index == selectedIndex ? accentColor : accentColor.withOpacity(0.7);
        final barPaint = Paint()..color = color..style = PaintingStyle.fill;
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), barPaint);
      }
    } else {
      final points = <Offset>[];
      for (var index = 0; index < values.length; index++) {
        final x = 12 + (chartWidth / math.max(values.length - 1, 1)) * index;
        final y = chartHeight - (values[index] / maxValue) * (chartHeight - 24);
        points.add(Offset(x, y));
      }
      if (points.length > 1) {
        final fillPath = Path()
          ..moveTo(points.first.dx, chartHeight)
          ..lineTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          fillPath.lineTo(point.dx, point.dy);
        }
        fillPath.lineTo(points.last.dx, chartHeight);
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

    canvas.drawLine(Offset(12, chartHeight), Offset(chartWidth, chartHeight), axisPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DistributionItem {
  const _DistributionItem(this.label, this.percentage, this.color);

  final String label;
  final int percentage;
  final Color color;
}

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({required this.data});

  final List<_DistributionItem> data;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final innerRadius = radius * 0.55;
    const strokeWidth = 16.0;

    var startAngle = -math.pi / 2;
    final total = data.fold<int>(0, (sum, item) => sum + item.percentage);

    for (final item in data) {
      final sweepAngle = (item.percentage / total) * 2 * math.pi;

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
