import 'package:bookreader/features/shell/model/book_model.dart';
import 'package:bookreader/features/shell/model/reading_stats_model.dart';
import 'package:bookreader/features/shell/ui/memory_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MemoryPage shows reading statistics overview', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: MemoryPage(),
      ),
    );

    expect(find.text('阅读统计'), findsOneWidget);
    expect(find.text('今日阅读'), findsWidgets);
    expect(find.text('最长阅读一天'), findsOneWidget);
    expect(find.text('阅读趋势'), findsOneWidget);
  });

  test('ReadingStats uses normalized day ranges and duration-based distribution buckets', () {
    final stats = ReadingStats.fromBooks([
      const BookModel(
        id: 'book-1',
        title: 'Book One',
        path: '/tmp/book1.pdf',
        type: 'pdf',
        progress: 0.5,
        lastReadAt: null,
        readingDurationSeconds: 5400,
      ),
      const BookModel(
        id: 'book-2',
        title: 'Book Two',
        path: '/tmp/book2.pdf',
        type: 'pdf',
        progress: 0.25,
        lastReadAt: null,
        readingDurationSeconds: 3600,
      ),
    ]);

    final start = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 12);
    final end = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day + 1, 0);

    expect(stats.totalMinutes, 150);
    expect(stats.minutesBetween(start, end), 150);
    expect(stats.distributionUnder1HourMinutes, 90);
    expect(stats.distribution1To2HoursMinutes, 60);
  });
}
