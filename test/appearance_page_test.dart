import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookreader/features/shell/ui/appearance_page.dart';

void main() {
  testWidgets('theme mode selector uses a three-card flex row', (tester) async {
    await tester.pumpWidget(const CupertinoApp(home: AppearancePage()));
    await tester.pumpAndSettle();

    final rowFinder = find.byWidgetPredicate((widget) {
      if (widget is! Row) {
        return false;
      }

      final expandedChildren = widget.children.whereType<Expanded>().length;
      final spacerChildren = widget.children.whereType<SizedBox>().length;
      return expandedChildren == 3 && spacerChildren == 2;
    });

    expect(rowFinder, findsOneWidget);
  });
}
