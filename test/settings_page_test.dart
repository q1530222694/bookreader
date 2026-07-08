import 'package:bookreader/engine/localization_engine.dart';
import 'package:bookreader/features/shell/ui/appearance_page.dart';
import 'package:bookreader/features/shell/ui/settings_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SettingsPage hides language and appearance entries', (tester) async {
    await tester.pumpWidget(const CupertinoApp(home: SettingsPage()));
    await tester.pumpAndSettle();

    expect(find.text(LocalizationEngine.text('language')), findsNothing);
    expect(find.text(LocalizationEngine.text('appearance')), findsNothing);
    expect(find.text(LocalizationEngine.text('app_appearance')), findsNothing);
  });

  testWidgets('AppearancePage shows a single splash settings entry', (tester) async {
    await tester.pumpWidget(const CupertinoApp(home: AppearancePage()));
    await tester.pumpAndSettle();

    final splashSettingsLabel = LocalizationEngine.text('splash_settings');
    expect(find.text(splashSettingsLabel), findsOneWidget);
    await tester.tap(find.text(splashSettingsLabel));
    await tester.pumpAndSettle();

    expect(find.text(LocalizationEngine.text('splash_content_type')), findsOneWidget);
  });

  testWidgets('AppearancePage exposes the new six theme color options', (tester) async {
    await tester.pumpWidget(const CupertinoApp(home: AppearancePage()));
    await tester.pumpAndSettle();

    expect(find.text(LocalizationEngine.text('theme_color_purple')), findsOneWidget);
    expect(find.text(LocalizationEngine.text('theme_color_red')), findsOneWidget);
  });
}
