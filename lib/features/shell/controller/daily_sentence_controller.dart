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
    DailySentenceService.loadSentences();
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

  /// Update an existing daily sentence entry.
  Future<void> updateSentence(String id, String content) async {
    if (content.trim().isEmpty) {
      errorText.value = '内容不能为空';
      return;
    }

    final sentence = DailySentenceModel(
      id: id,
      content: content.trim(),
    );
    await _service.updateSentence(sentence);
    errorText.value = null;
  }

  /// Delete a daily sentence entry by id.
  Future<void> deleteSentence(String id) async {
    await DailySentenceService.deleteSentence(id);
  }

  /// Dispose controller notifiers.
  void dispose() {
    errorText.dispose();
  }
}
