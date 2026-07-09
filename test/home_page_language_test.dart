import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookreader/engine/config.dart';
import 'package:bookreader/engine/settings_engine.dart';
import 'package:bookreader/features/shell/controller/settings_controller.dart';
import 'package:bookreader/features/shell/ui/home_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Config.set(SettingsEngine.languageKey, SettingsEngine.languageEnglish);
    SettingsController.language.value = SettingsEngine.languageEnglish;
  });

  testWidgets('HomePage updates the app launch count label when language changes', (tester) async {
    await tester.pumpWidget(const CupertinoApp(home: HomePage()));

    expect(find.text('App Launches'), findsOneWidget);
    expect(find.text('打开次数'), findsNothing);

    SettingsController.setLanguage(SettingsEngine.languageChinese);
    await tester.pump();

    expect(find.text('打开次数'), findsOneWidget);
    expect(find.text('App Launches'), findsNothing);
  });
}
