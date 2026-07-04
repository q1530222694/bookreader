import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../service/bookshelf_service.dart';

/// MemoryPage displays recall and note-related content for the shell module.
class MemoryPage extends StatelessWidget {
  const MemoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: Text(
          LocalizationEngine.text('memory'),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: CupertinoTheme.of(context).primaryColor),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CalendarCard(),
              const SizedBox(height: 16),
              Text(
                LocalizationEngine.text('memory_reading_duration_hint'),
                style: const TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CalendarCard extends StatelessWidget {
  const CalendarCard({super.key});

  static const List<String> _monthKeys = [
    'calendar_january',
    'calendar_february',
    'calendar_march',
    'calendar_april',
    'calendar_may',
    'calendar_june',
    'calendar_july',
    'calendar_august',
    'calendar_september',
    'calendar_october',
    'calendar_november',
    'calendar_december',
  ];

  static const List<String> _weekdayKeys = [
    'calendar_sunday',
    'calendar_monday',
    'calendar_tuesday',
    'calendar_wednesday',
    'calendar_thursday',
    'calendar_friday',
    'calendar_saturday',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final now = DateTime.now();
    final monthLabel = LocalizationEngine.text(_monthKeys[now.month - 1]);
    final firstDay = DateTime(now.year, now.month, 1);
    final leadingEmpty = firstDay.weekday % 7;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final rowCount = ((leadingEmpty + daysInMonth) / 7).ceil();
    final itemCount = rowCount * 7;

    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: BookshelfService.booksNotifier,
      builder: (context, books, child) {
        final hasReadBooks = books.isNotEmpty;
        return Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CupertinoColors.systemGrey4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    monthLabel,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _weekdayKeys
                        .map(
                          (key) => Expanded(
                            child: Center(
                              child: Text(
                                LocalizationEngine.text(key),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: itemCount,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final dayNumber = index - leadingEmpty + 1;
                      final showDay = dayNumber > 0 && dayNumber <= daysInMonth;
                      final isToday = showDay && dayNumber == now.day;

                      return Container(
                        decoration: BoxDecoration(
                          color: isToday ? theme.primaryColor : CupertinoColors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            showDay ? '$dayNumber' : '',
                            style: TextStyle(
                              fontSize: 14,
                              color: isToday ? CupertinoColors.white : CupertinoColors.black,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (hasReadBooks)
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
