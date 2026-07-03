import 'package:bookreader/features/shell/controller/bookshelf_controller.dart';
import 'package:bookreader/features/shell/model/book_model.dart';
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

  testWidgets('BookshelfPage shows random reading action in more menu', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: BookshelfPage(),
      ),
    );

    await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
    await tester.pumpAndSettle();

    expect(find.text('随机读书'), findsOneWidget);
  });

  testWidgets('BookshelfPage shows delete action on long press', (tester) async {
    final controller = BookshelfController();
    controller.books.value = [
      const BookModel(
        id: 'book-1',
        title: 'Test Book',
        path: '/tmp/test.pdf',
        type: 'pdf',
      ),
    ];

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: BookshelfPage(controller: controller),
      ),
    );

    await tester.longPress(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(find.text('删除'), findsOneWidget);
  });
}
