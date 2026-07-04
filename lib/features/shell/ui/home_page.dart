import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../service/daily_sentence_service.dart';
import '../model/daily_sentence_model.dart';
import 'daily_sentence_page.dart';

/// HomePage displays the main dashboard content for the shell module.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: Text(
          LocalizationEngine.text('home'),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: CupertinoColors.label.resolveFrom(context)),
        ),
      ),
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    final sentences = DailySentenceService.sentencesNotifier.value;
                    final latest = sentences.isNotEmpty
                        ? sentences.last.content
                        : LocalizationEngine.text('no_sentences');
                    showCupertinoDialog<void>(
                      context: context,
                      builder: (context) {
                        return CupertinoAlertDialog(
                          title: Text(LocalizationEngine.text('view_full')),
                          content: Text(latest),
                          actions: [
                            CupertinoDialogAction(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(LocalizationEngine.text('cancel')),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: CupertinoColors.separator.resolveFrom(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                LocalizationEngine.text('daily_sentence'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: CupertinoColors.label.resolveFrom(context),
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 32,
                              onPressed: () {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (context) => const DailySentencePage(),
                                  ),
                                );
                              },
                              child: const Icon(CupertinoIcons.add),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<List<DailySentenceModel>>(
                          valueListenable: DailySentenceService.sentencesNotifier,
                          builder: (context, sentences, child) {
                            final latestSentence = sentences.isNotEmpty
                                ? sentences.last.content
                                : LocalizationEngine.text('no_sentences');
                            return Text(
                              latestSentence,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
