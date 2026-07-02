import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';

import '../model/daily_sentence_model.dart';

/// DailySentenceController manages the daily sentence list and save logic.
class DailySentenceController {
  final ValueNotifier<List<DailySentenceModel>> sentences =
      ValueNotifier<List<DailySentenceModel>>([]);

  final ValueNotifier<String?> errorText = ValueNotifier<String?>(null);

  final Uuid _uuid = const Uuid();

  /// Add a new daily sentence entry.
  void addSentence(String content) {
    if (content.trim().isEmpty) {
      errorText.value = '内容不能为空';
      return;
    }

    final sentence = DailySentenceModel(
      id: _uuid.v4(),
      content: content.trim(),
    );
    sentences.value = List<DailySentenceModel>.from(sentences.value)
      ..add(sentence);
    errorText.value = null;
  }

  /// Dispose controller notifiers.
  void dispose() {
    sentences.dispose();
    errorText.dispose();
  }
}
