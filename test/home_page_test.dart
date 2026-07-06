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
  });
}
