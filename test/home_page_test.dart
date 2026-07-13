import 'package:bookreader/engine/settings_engine.dart';
import 'package:bookreader/features/shell/controller/bookshelf_controller.dart';
import 'package:bookreader/features/shell/model/book_model.dart';
import 'package:bookreader/features/shell/ui/home_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HomePage shows the reading progress percentage for the current book', (tester) async {
    final controller = BookshelfController();
    controller.books.value = [
      const BookModel(id: 'book-1', title: 'Book One', path: '/tmp/book1.pdf', type: 'pdf', progress: 0.37),
    ];

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: HomePage(
          controller: controller,
          currentTimeProvider: () => DateTime(2026, 7, 11, 14, 30),
        ),
      ),
    );

    expect(find.text('最近阅读'), findsOneWidget);
    expect(find.text('阅读进度'), findsOneWidget);
    expect(find.text('37%'), findsWidgets);
    expect(find.text('继续阅读'), findsOneWidget);
    expect(find.text('下午好，万志豪！'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.globe), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.sun_max), findsOneWidget);
  });

  testWidgets('HomePage shows a late-night greeting and rest reminder after midnight', (tester) async {
    SettingsEngine.setLanguage(SettingsEngine.languageChinese);
    final controller = BookshelfController();
    controller.books.value = const [];

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: HomePage(
          controller: controller,
          currentTimeProvider: () => DateTime(2026, 7, 11, 4, 30),
        ),
      ),
    );

    expect(find.text('很晚了，万志豪！'), findsOneWidget);
    expect(find.text('请注意休息，保护好眼睛。'), findsOneWidget);
  });

  testWidgets('HomePage uses Chinese label for cumulative reading when Chinese language is selected', (tester) async {
    SettingsEngine.setLanguage(SettingsEngine.languageChinese);
    final controller = BookshelfController();
    controller.books.value = const [];

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: HomePage(controller: controller),
      ),
    );

    expect(find.text('累计阅读'), findsOneWidget);
  });

  testWidgets('HomePage shows the streak reading block with an icon and day count', (tester) async {
    SettingsEngine.setLanguage(SettingsEngine.languageChinese);
    final controller = BookshelfController();
    controller.books.value = const [];

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: HomePage(controller: controller),
      ),
    );

    expect(find.text('连续阅读'), findsOneWidget);
    expect(find.text('0 天'), findsWidgets);
    expect(find.byIcon(CupertinoIcons.sparkles), findsOneWidget);
  });

  testWidgets('HomePage shows the daily sentence title and default content', (tester) async {
    SettingsEngine.setLanguage(SettingsEngine.languageChinese);
    final controller = BookshelfController();
    controller.books.value = const [];

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: HomePage(controller: controller),
      ),
    );

    expect(find.text('每日一句'), findsOneWidget);
    expect(find.text('知识改变命运，阅读点亮人生。'), findsOneWidget);
  });

  testWidgets('HomePage uses real bookshelf data for reading stats', (tester) async {
    SettingsEngine.setLanguage(SettingsEngine.languageChinese);
    final controller = BookshelfController();
    controller.books.value = [
      const BookModel(
        id: 'book-1',
        title: 'Book One',
        path: '/tmp/book1.pdf',
        type: 'pdf',
        progress: 0.60,
        lastReadAt: null,
      ),
      BookModel(
        id: 'book-2',
        title: 'Book Two',
        path: '/tmp/book2.pdf',
        type: 'pdf',
        progress: 0.85,
        lastReadAt: DateTime(2026, 7, 8),
      ),
    ];

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: HomePage(controller: controller),
      ),
    );

    expect(find.text('本月阅读'), findsOneWidget);
    expect(find.text('今年阅读'), findsOneWidget);
    expect(find.text('累计阅读'), findsOneWidget);
    expect(find.textContaining('小时'), findsWidgets);
  });

  testWidgets('HomePage stat cards use theme-aware background in dark mode', (tester) async {
    SettingsEngine.setLanguage(SettingsEngine.languageChinese);
    final controller = BookshelfController();
    controller.books.value = const [];

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        home: HomePage(controller: controller),
      ),
    );

    final labelElement = tester.element(find.text('本月阅读'));
    final cardFinder = find.ancestor(of: find.text('本月阅读'), matching: find.byType(Container));
    final cardContainer = tester.widget<Container>(cardFinder.last);

    final decoration = (cardContainer.decoration as BoxDecoration).color;
    final expectedColor = CupertinoColors.secondarySystemBackground.resolveFrom(labelElement);

    expect(decoration, expectedColor);
  });

  testWidgets('HomePage stat cards do not render leading icons', (tester) async {
    SettingsEngine.setLanguage(SettingsEngine.languageChinese);
    final controller = BookshelfController();
    controller.books.value = const [];

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: HomePage(controller: controller),
      ),
    );

    expect(find.byIcon(CupertinoIcons.calendar), findsNothing);
    expect(find.byIcon(CupertinoIcons.calendar_badge_plus), findsNothing);
    expect(find.byIcon(CupertinoIcons.chart_pie), findsNothing);
  });
}
