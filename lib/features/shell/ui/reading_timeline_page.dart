import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../model/book_model.dart';
import '../model/reading_stats_model.dart';
import 'timeline_entry.dart';

/// 阅读时间轴「查看全部」页：按时间轴格式展示全部月份的阅读记录，
/// 风格与回忆页「阅读时间轴」卡片保持一致。
class ReadingTimelinePage extends StatelessWidget {
  final List<BookModel> books;

  const ReadingTimelinePage({super.key, required this.books});

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    // 按月聚合（倒序，最近的月份在前）
    final records = MonthTimelineRecord.monthTimeline(books);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          LocalizationEngine.text('reading_timeline'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label.resolveFrom(context),
          ),
        ),
        previousPageTitle: LocalizationEngine.text('memory'),
      ),
      child: SafeArea(
        child: records.isEmpty
            ? Center(
                child: Text(
                  LocalizationEngine.text('records_empty'),
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...records.asMap().entries.map((e) {
                          final index = e.key;
                          final record = e.value;
                          return timelineEntryFromRecord(
                            record,
                            context,
                            isFirst: index == 0,
                            isLast: index == records.length - 1,
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
