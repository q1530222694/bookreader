import 'dart:typed_data';

import 'package:bookreader/engine/localization_engine.dart';
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

  testWidgets('BookshelfPage uses a compact header size matching the home page title', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: BookshelfPage(),
      ),
    );
    await tester.pumpAndSettle();

    final titleText = LocalizationEngine.text('bookshelf');
    final titleWidget = tester.widget<Text>(find.text(titleText));
    expect(titleWidget.style?.fontSize, 20);

    final searchIcon = tester.widget<Icon>(find.byIcon(CupertinoIcons.search));
    expect(searchIcon.size, 20);

    final moreIcon = tester.widget<Icon>(find.byIcon(CupertinoIcons.ellipsis));
    expect(moreIcon.size, 20);
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

  testWidgets('BookshelfPage shows recent reading title with bold matching size', (tester) async {
    final controller = BookshelfController();
    controller.books.value = [
      const BookModel(
        id: 'book-3',
        title: 'Recent Book',
        path: '/tmp/recent-book.pdf',
        type: 'pdf',
      ),
    ];

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: BookshelfPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    final recentTitle = find.text('最近阅读');
    final viewAllText = find.textContaining('查看全部');

    expect(recentTitle, findsOneWidget);
    expect(viewAllText, findsOneWidget);

    final recentTitleWidget = tester.widget<Text>(recentTitle);
    final viewAllWidget = tester.widget<Text>(viewAllText);

    expect(recentTitleWidget.style?.fontSize, 16);
    expect(viewAllWidget.style?.fontSize, 14);
    expect(recentTitleWidget.style?.fontWeight, FontWeight.w800);
    expect(viewAllWidget.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('BookshelfPage switches to a download-style list item when filter button is tapped', (tester) async {
    final controller = BookshelfController();
    controller.books.value = [
      const BookModel(
        id: 'book-4',
        title: 'Flutter 实战',
        path: '/tmp/flutter.pdf',
        type: 'pdf',
        progress: 0.48,
        fileSizeBytes: 1548000,
        lastReadAt: null,
      ),
    ];

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: BookshelfPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.slider_horizontal_3));
    await tester.pumpAndSettle();

    expect(find.text('Flutter 实战'), findsOneWidget);
    expect(find.text('PDF · 1.5 MB'), findsOneWidget);
    expect(find.text('48%').evaluate().isNotEmpty, isTrue);
    expect(find.text(LocalizationEngine.text('just_now')), findsOneWidget);
  });

  testWidgets('BookshelfPage uses a fixed-width progress bar in list mode', (tester) async {
    final controller = BookshelfController();
    controller.books.value = [
      const BookModel(
        id: 'book-6',
        title: 'Fixed Progress Book',
        path: '/tmp/fixed-progress.pdf',
        type: 'pdf',
        progress: 0.48,
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

    await tester.tap(find.byIcon(CupertinoIcons.slider_horizontal_3));
    await tester.pumpAndSettle();

    expect(find.byWidgetPredicate((widget) => widget is SizedBox && widget.width == 140), findsAtLeastNWidgets(1));
  });

  testWidgets('BookshelfPage shows real statistics counts in the summary cards', (tester) async {
    final controller = BookshelfController();
    controller.books.value = [
      const BookModel(
        id: 'book-5',
        title: 'Cover Book',
        path: '/tmp/cover.pdf',
        type: 'pdf',
        progress: 0.6,
        fileSizeBytes: 2048000,
        isFavorite: true,
      ),
      const BookModel(
        id: 'book-6',
        title: 'Finished Book',
        path: '/tmp/finished.pdf',
        type: 'epub',
        progress: 1.0,
        fileSizeBytes: 1024000,
      ),
      const BookModel(
        id: 'book-7',
        title: 'Unread Book',
        path: '/tmp/unread.txt',
        type: 'txt',
        progress: 0.0,
        fileSizeBytes: 512000,
      ),
    ];

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: BookshelfPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3'), findsWidgets);
    expect(find.text('1'), findsWidgets);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('在读'), findsOneWidget);
    expect(find.text('已读'), findsOneWidget);
  });

  testWidgets('BookshelfPage shows a real cover and more-button actions in list mode', (tester) async {
    final controller = BookshelfController();
    controller.books.value = [
      BookModel(
        id: 'book-5',
        title: 'Cover Book',
        path: '/tmp/cover.pdf',
        type: 'pdf',
        progress: 0.6,
        fileSizeBytes: 2048000,
        coverBytes: Uint8List.fromList([1, 2, 3, 4]),
      ),
    ];

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: BookshelfPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.slider_horizontal_3));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsAtLeastNWidgets(1));

    await tester.tap(find.byKey(const ValueKey('bookshelf_list_more_button_book-5')));
    await tester.pumpAndSettle();

    expect(find.text('删除'), findsOneWidget);
  });
}
