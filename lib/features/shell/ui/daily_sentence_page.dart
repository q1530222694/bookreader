import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../controller/daily_sentence_controller.dart';
import '../model/daily_sentence_model.dart';
import 'daily_sentence_edit_page.dart';

/// DailySentencePage displays the list of saved daily sentences and allows adding new entries.
class DailySentencePage extends StatefulWidget {
  const DailySentencePage({super.key});

  @override
  State<DailySentencePage> createState() => _DailySentencePageState();
}

class _DailySentencePageState extends State<DailySentencePage> {
  final DailySentenceController _controller = DailySentenceController();
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  // 使用独立页面 `DailySentenceEditPage` 进行添加/编辑，不再使用底部 action sheet

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(LocalizationEngine.text('daily_sentence'), style: TextStyle(color: CupertinoTheme.of(context).primaryColor)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (context) => const DailySentenceEditPage()),
            );
          },
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Expanded(
              child: ValueListenableBuilder<List<DailySentenceModel>>(
                valueListenable: _controller.sentences,
                builder: (context, sentences, child) {
                  if (sentences.isEmpty) {
                    return Center(
                      child: Text(
                        LocalizationEngine.text('no_sentences'),
                        style: TextStyle(
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sentences.length,
                    itemBuilder: (context, index) {
                      final item = sentences[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: CupertinoColors.separator.resolveFrom(context)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    showCupertinoDialog<void>(
                                      context: context,
                                      builder: (context) {
                                        return CupertinoAlertDialog(
                                          title: Text(LocalizationEngine.text('view_full')),
                                          content: Text(item.content),
                                          actions: [
                                            CupertinoDialogAction(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: Text(LocalizationEngine.text('cancel')),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                  child: Text(
                                    item.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: CupertinoColors.label.resolveFrom(context),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              CupertinoButton(
                                padding: const EdgeInsets.all(6),
                                minSize: 36,
                                onPressed: () {
                                  Navigator.of(context).push(
                                    CupertinoPageRoute(
                                      builder: (context) => DailySentenceEditPage(sentence: item),
                                    ),
                                  );
                                },
                                child: Icon(
                                  CupertinoIcons.pencil,
                                  size: 18,
                                  color: CupertinoTheme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
