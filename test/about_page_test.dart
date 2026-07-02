import 'package:bookreader/features/shell/ui/about_page.dart';
import 'package:bookreader/features/shell/ui/profile_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AboutPage renders title and support links', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: AboutPage(),
      ),
    );

    expect(find.text('关于'), findsOneWidget);
    expect(find.text('支持与链接'), findsOneWidget);
    expect(find.text('更新日志'), findsOneWidget);
  });

  testWidgets('Premium button opens membership page with architecture and features', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: ProfilePage(),
      ),
    );

    await tester.tap(find.text('开通高级会员'));
    await tester.pumpAndSettle();

    expect(find.text('会员中心'), findsWidgets);
    expect(find.text('会员架构'), findsOneWidget);
    expect(find.text('会员应有的功能'), findsOneWidget);
  });
}
