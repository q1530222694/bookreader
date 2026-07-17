import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../engine/localization_engine.dart';
import '../model/reading_stats_model.dart';

/// 阅读时间轴单条记录（无状态展示组件 / Dumb UI）。
///
/// 颜色全部由调用方以「主题派生色」传入，组件内部不写死任何色值；
/// 标题/副标题/详情文本均由调用方拼好（走 LocalizationEngine）后传入。
class TimelineEntry extends StatelessWidget {
  /// 节点是否实心填充（通常为最新一条=true，其余=false）。
  final bool markerFilled;

  /// 节点/线条的主题色（如 primary），由调用方传入。
  final Color themeColor;

  /// 线条颜色（如 systemGrey4），由调用方传入。
  final Color lineColor;

  /// 标题（如「2026年7月」）。
  final String title;

  /// 副标题摘要（如「阅读 4 本书 · 12 小时 · 收藏 2 条」）。
  final String subtitle;

  /// 额外详情区块（如读完/开始的书名列表），可为 null。
  final List<Widget>? detail;

  /// 是否为最后一条（最后一条不画向下延伸的竖线）。
  final bool isLast;

  /// 是否强制向下延伸竖线到边框底部（即使 isLast=true）。
  /// 用于「回忆页时间轴仅有一个月」时，让竖线延伸到底，暗示后面还有内容。
  final bool extendLine;

  const TimelineEntry({
    super.key,
    required this.markerFilled,
    required this.themeColor,
    required this.lineColor,
    required this.title,
    required this.subtitle,
    this.detail,
    this.isLast = false,
    this.extendLine = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final tertiary = CupertinoColors.tertiaryLabel.resolveFrom(context);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧：节点圆点 + 向下延伸的竖线
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: markerFilled ? themeColor : Colors.transparent,
                    border: Border.all(
                      color: markerFilled ? themeColor : tertiary,
                      width: 1.5,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast || extendLine) ...[
                  const SizedBox(height: 6),
                  Expanded(
                    child: Container(width: 2, color: lineColor),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 右侧：标题 + 摘要 + 可选详情
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: labelColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: secondary),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 8),
                  ...detail!,
                  const SizedBox(height: 4),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 由 [MonthTimelineRecord] 构建一条 [TimelineEntry]（标题/摘要/详情均走本地化）。
///
/// [isFirst] 控制首个节点实心高亮；[isLast] 控制是否绘制向下延伸的竖线。
TimelineEntry timelineEntryFromRecord(
  MonthTimelineRecord record,
  BuildContext context, {
  required bool isFirst,
  required bool isLast,
  bool extendLine = false,
}) {
  final theme = CupertinoTheme.of(context);
  final primary = theme.primaryColor;
  final yearUnit = LocalizationEngine.text('year_unit');
  final monthUnit = LocalizationEngine.text('month_unit');

  // 标题：2026年7月
  final title = '${record.month.year}$yearUnit${record.month.month}$monthUnit';

  // 摘要：阅读 {books} 本书 · {hours} 小时 · 收藏 {fav} 条
  final summary = LocalizationEngine.text('timeline_summary')
      .replaceAll('{books}', '${record.bookCount}')
      .replaceAll('{hours}', '${(record.minutes / 60).round()}')
      .replaceAll('{fav}', '${record.favorites}');

  // 详情：读完/开始的书名列表（最多 3 本，超出用「等」）
  final List<Widget> detail = [];
  final sep = LocalizationEngine.text('timeline_book_sep');
  final etc = LocalizationEngine.text('timeline_etc');
  final tertiary = CupertinoColors.tertiaryLabel.resolveFrom(context);

  if (record.finished.isNotEmpty) {
    final titles = record.finished.map((b) => '《${b.title}》').take(3).join(sep);
    final suffix = record.finished.length > 3 ? etc : '';
    detail.add(
      Text(
        '${LocalizationEngine.text('timeline_finished_prefix')}$titles$suffix',
        style: TextStyle(fontSize: 13, color: tertiary),
      ),
    );
  }
  if (record.started.isNotEmpty) {
    final titles = record.started.map((b) => '《${b.title}》').take(3).join(sep);
    final suffix = record.started.length > 3 ? etc : '';
    detail.add(
      Text(
        '${LocalizationEngine.text('timeline_started_prefix')}$titles$suffix',
        style: TextStyle(fontSize: 13, color: tertiary),
      ),
    );
  }

  return TimelineEntry(
    markerFilled: isFirst,
    themeColor: primary,
    lineColor: CupertinoColors.systemGrey4.resolveFrom(context),
    title: title,
    subtitle: summary,
    detail: detail.isNotEmpty ? detail : null,
    isLast: isLast,
    extendLine: extendLine,
  );
}
