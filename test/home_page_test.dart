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
        home: HomePage(controller: controller),
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
    expect(find.text('18天'), findsOneWidget);
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
}
