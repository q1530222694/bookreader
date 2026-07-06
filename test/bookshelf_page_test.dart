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

    final bookTitleFinder = find.text('Test Book');
    expect(bookTitleFinder, findsOneWidget);

    await tester.longPress(bookTitleFinder);
    await tester.pumpAndSettle();

    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('BookshelfPage uses a popover for long-press actions', (tester) async {
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

    final bookTitleFinder = find.text('Test Book');
    expect(bookTitleFinder, findsOneWidget);

    await tester.longPress(bookTitleFinder);
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoActionSheet), findsNothing);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('BookshelfPage shows only one recent-reading card for a single book', (tester) async {
    final controller = BookshelfController();
    controller.books.value = [
      const BookModel(
        id: 'book-1',
        title: 'Test Book',
        path: '/tmp/test.pdf',
        type: 'pdf',
        progress: 0.5,
      ),
    ];

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: BookshelfPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    final listViews = tester.widgetList<ListView>(find.byType(ListView));
    expect(listViews.any((view) => view.childrenDelegate.estimatedChildCount == 1), isTrue);
  });

  testWidgets('BookshelfPage uses a compact book card without progress bar in grid mode', (tester) async {
    final controller = BookshelfController();
    controller.books.value = [
      const BookModel(
        id: 'book-1',
        title: 'Test Book',
        path: '/tmp/test.pdf',
        type: 'pdf',
        progress: 0.91,
      ),
    ];

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: BookshelfPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Book'), findsOneWidget);
    expect(find.textContaining('PDF'), findsAtLeastNWidgets(1));
    expect(find.textContaining('已读'), findsAtLeastNWidgets(1));

    final compactCardAncestor = find.ancestor(
      of: find.text('Test Book'),
      matching: find.byWidgetPredicate(
        (widget) => widget is Padding && widget.padding == const EdgeInsets.only(top: 2, right: 18),
      ),
    );
    expect(find.descendant(of: compactCardAncestor, matching: find.byType(FractionallySizedBox)), findsNothing);
  });

  testWidgets('BookshelfPage shows imported title and file size metadata', (tester) async {
    final controller = BookshelfController();
    controller.books.value = [
      const BookModel(
        id: 'book-2',
        title: 'Imported Novel',
        path: '/tmp/imported-novel.pdf',
        type: 'pdf',
        fileSizeBytes: 1548000,
      ),
    ];

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: BookshelfPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Imported Novel'), findsOneWidget);
    expect(find.textContaining('PDF'), findsAtLeastNWidgets(1));
    expect(find.textContaining('1.5 MB'), findsOneWidget);
  });
}
