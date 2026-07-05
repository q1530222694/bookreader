import 'package:bookreader/features/shell/controller/bookshelf_controller.dart';
import 'package:bookreader/features/shell/model/book_model.dart';
import 'package:bookreader/features/shell/ui/home_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HomePage shows the latest three books in a recent reading section', (tester) async {
    final controller = BookshelfController();
    controller.books.value = [
      const BookModel(id: 'book-1', title: 'Book One', path: '/tmp/book1.pdf', type: 'pdf'),
      const BookModel(id: 'book-2', title: 'Book Two', path: '/tmp/book2.pdf', type: 'pdf'),
      const BookModel(id: 'book-3', title: 'Book Three', path: '/tmp/book3.pdf', type: 'pdf'),
      const BookModel(id: 'book-4', title: 'Book Four', path: '/tmp/book4.pdf', type: 'pdf'),
    ];

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: HomePage(controller: controller),
      ),
    );

    expect(find.text('最近阅读'), findsOneWidget);
    expect(find.text('Book Two'), findsOneWidget);
    expect(find.text('Book Three'), findsOneWidget);
    expect(find.text('Book Four'), findsOneWidget);
    expect(find.text('Book One'), findsNothing);
  });
}
