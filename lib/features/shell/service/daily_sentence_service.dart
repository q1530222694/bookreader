import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../model/daily_sentence_model.dart';

/// DailySentenceService persists the daily sentence list to local storage.
class DailySentenceService {
  static const String _storageFileName = 'daily_sentences.json';

  static final ValueNotifier<List<DailySentenceModel>> sentencesNotifier =
      ValueNotifier<List<DailySentenceModel>>([]);

  /// Load saved daily sentences from local document storage.
  Future<void> loadSentences() async {
    try {
      final file = await _dataFile();
      if (!await file.exists()) {
        sentencesNotifier.value = [];
        return;
      }

      final jsonString = await file.readAsString();
      if (jsonString.trim().isEmpty) {
        sentencesNotifier.value = [];
        return;
      }

      final rawList = jsonDecode(jsonString) as List<dynamic>;
      sentencesNotifier.value = rawList
          .cast<Map<String, dynamic>>()
          .map(DailySentenceModel.fromJson)
          .toList();
    } catch (_) {
      sentencesNotifier.value = sentencesNotifier.value;
    }
  }

  /// Add a new daily sentence and persist the updated list.
  Future<void> addSentence(DailySentenceModel sentence) async {
    final current = List<DailySentenceModel>.from(sentencesNotifier.value)
      ..add(sentence);
    sentencesNotifier.value = current;
    await _saveSentences(current);
  }

  Future<File> _dataFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_storageFileName');
  }

  Future<void> _saveSentences(List<DailySentenceModel> sentences) async {
    final file = await _dataFile();
    final encoded = jsonEncode(sentences.map((item) => item.toJson()).toList());
    await file.writeAsString(encoded);
  }
}
