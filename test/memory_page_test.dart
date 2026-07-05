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
    expect(find.text('今日阅读'), findsOneWidget);
    expect(find.text('最长阅读一天'), findsOneWidget);
    expect(find.text('阅读趋势'), findsOneWidget);
  });
}
