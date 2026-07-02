import 'package:bookreader/features/shell/ui/bookshelf_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BookshelfPage shows search entry for imported books', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: BookshelfPage(),
      ),
    );

    expect(find.byIcon(CupertinoIcons.search), findsOneWidget);
  });
}
