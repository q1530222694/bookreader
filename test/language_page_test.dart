import 'package:bookreader/engine/localization_engine.dart';
import 'package:bookreader/engine/settings_engine.dart';
import 'package:bookreader/features/shell/ui/language_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LanguagePage shows traditional Chinese option', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: LanguagePage(),
      ),
    );

    expect(find.text('繁体'), findsOneWidget);
  });

  test('Traditional Chinese locale uses traditional characters', () {
    SettingsEngine.setLanguage(SettingsEngine.languageTraditionalChinese);

    expect(LocalizationEngine.text('home'), '主頁');
    expect(LocalizationEngine.text('welcome_back'), '歡迎回來！');
  });
}
