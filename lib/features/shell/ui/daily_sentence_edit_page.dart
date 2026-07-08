import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../controller/daily_sentence_controller.dart';
import '../model/daily_sentence_model.dart';

/// Full-screen page to add or edit a daily sentence.
class DailySentenceEditPage extends StatefulWidget {
  const DailySentenceEditPage({super.key, this.sentence});

  final DailySentenceModel? sentence;

  @override
  State<DailySentenceEditPage> createState() => _DailySentenceEditPageState();
}

class _DailySentenceEditPageState extends State<DailySentenceEditPage> {
  final DailySentenceController _controller = DailySentenceController();
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.sentence != null) {
      _textController.text = widget.sentence!.content;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.sentence != null) {
      await _controller.updateSentence(widget.sentence!.id, _textController.text);
    } else {
      await _controller.addSentence(_textController.text);
    }

    if (_controller.errorText.value == null) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final textColor = CupertinoColors.label.resolveFrom(context);
    final placeholderColor = CupertinoColors.placeholderText.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          widget.sentence == null ? LocalizationEngine.text('daily_sentence') : LocalizationEngine.text('edit'),
          style: TextStyle(color: textColor),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoTextField(
                controller: _textController,
                maxLines: 8,
                placeholder: LocalizationEngine.text('enter_content'),
                style: TextStyle(color: textColor),
                placeholderStyle: TextStyle(color: placeholderColor),
                decoration: BoxDecoration(
                  color: CupertinoTheme.of(context).barBackgroundColor,
                  border: Border.all(color: CupertinoColors.separator.resolveFrom(context)),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const Spacer(),
            // 底部按钮：取消 与 保存 并列
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      color: CupertinoColors.systemGrey5.resolveFrom(context),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        LocalizationEngine.text('cancel'),
                        style: TextStyle(color: textColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoButton.filled(
                      onPressed: _save,
                      child: Text(
                        LocalizationEngine.text('save'),
                        style: TextStyle(color: CupertinoColors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
