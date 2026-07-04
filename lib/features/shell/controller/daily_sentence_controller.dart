import 'package:flutter/cupertino.dart';

import '../model/daily_sentence_model.dart';
import '../service/daily_sentence_service.dart';

/// DailySentenceController manages the daily sentence list and save logic.
class DailySentenceController {
  final DailySentenceService _service = DailySentenceService();
  final ValueNotifier<List<DailySentenceModel>> sentences =
      DailySentenceService.sentencesNotifier;
  final ValueNotifier<String?> errorText = ValueNotifier<String?>(null);

  DailySentenceController() {
    _service.loadSentences();
  }

  /// Add a new daily sentence entry.
  Future<void> addSentence(String content) async {
    if (content.trim().isEmpty) {
      errorText.value = '内容不能为空';
      return;
    }

    final sentence = DailySentenceModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      content: content.trim(),
    );
    await _service.addSentence(sentence);
    errorText.value = null;
  }

  /// Dispose controller notifiers.
  void dispose() {
    errorText.dispose();
  }
}
