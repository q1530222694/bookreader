import 'package:bookreader/engine/settings_engine.dart';
import 'package:bookreader/features/shell/model/daily_sentence_model.dart';
import 'package:bookreader/features/shell/service/daily_sentence_service.dart';
import 'package:bookreader/features/shell/ui/daily_sentence_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('批量新增：按行拆分、过滤空行、生成唯一 id', () async {
    DailySentenceService.sentencesNotifier.value = [];
    // 模拟用户在文本框输入多行（含空白行、首尾空白、纯换行）
    final count = await DailySentenceService.addSentencesBatch(
      const ['第一句', '   ', '\n第二句\n', '第三句', ''],
    );
    expect(count, 3);

    final items = DailySentenceService.sentencesNotifier.value;
    expect(items.length, 3);
    expect(
      items.map((e) => e.content).toList(),
      ['第一句', '第二句', '第三句'],
    );
    // 每条 id 必须唯一（避免同微秒内碰撞）
    expect(items.map((e) => e.id).toSet().length, 3);
  });

  test('批量新增：全部为空时返回 0 且不新增', () async {
    DailySentenceService.sentencesNotifier.value = const [
      DailySentenceModel(id: 'x', content: '已有'),
    ];
    final count = await DailySentenceService.addSentencesBatch(
      const ['', '   ', '\n'],
    );
    expect(count, 0);
    expect(DailySentenceService.sentencesNotifier.value.length, 1);
  });

  testWidgets('删除每日一句后列表重建不崩溃（修复崩溃）', (tester) async {
    SettingsEngine.setLanguage(SettingsEngine.languageChinese);
    await tester.pumpWidget(CupertinoApp(home: DailySentencePage()));
    await tester.pumpAndSettle();

    // 等 loadSentences 完成后，预置两条自定义语句并重建
    DailySentenceService.sentencesNotifier.value = const [
      DailySentenceModel(id: 'a', content: '句一'),
      DailySentenceModel(id: 'b', content: '句二'),
    ];
    await tester.pumpAndSettle();
    expect(find.text('句一'), findsOneWidget);
    expect(find.text('句二'), findsOneWidget);

    // 执行删除（模拟确认删除后 notifier 变化触发的列表重建）
    await DailySentenceService.deleteSentence('a');
    await tester.pumpAndSettle();

    // 重建不应抛出任何 FlutterError（此前使用 Material 的 ReorderableListView，
    // 删除导致 itemCount 变小时会在重建帧断言崩溃；现改用原生 ListView 已修复）
    expect(tester.takeException(), isNull);
    expect(DailySentenceService.sentencesNotifier.value.length, 1);
    expect(find.text('句一'), findsNothing);
    expect(find.text('句二'), findsOneWidget);
  });
}
