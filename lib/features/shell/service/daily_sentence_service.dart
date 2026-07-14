import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../engine/settings_engine.dart';
import '../model/daily_sentence_builtin.dart';
import '../model/daily_sentence_model.dart';

/// DailySentenceService persists the daily sentence list to local storage.
class DailySentenceService {
  static const String _storageFileName = 'daily_sentences.json';

  static final ValueNotifier<List<DailySentenceModel>> sentencesNotifier =
      ValueNotifier<List<DailySentenceModel>>([]);

  /// 主页「每日一句」当前展示的句子（由 UI 监听，不持久化）。
  static final ValueNotifier<String> displaySentenceNotifier =
      ValueNotifier<String>('');

  /// 按开关与来源选取要展示的每日一句。
  /// [useBuiltin] 为 true 时从内置池选取；false 时仅从用户自定义列表选取。
  /// [refresh] 为 true 时强制随机换一句（尽量与 [current] 不同）；否则按日期稳定返回。
  static String _selectSentence(bool useBuiltin,
      {bool refresh = false, String? current}) {
    if (useBuiltin) {
      final pool = builtinReadingSentences;
      if (pool.isEmpty) return '';
      if (!refresh) {
        // 按日期稳定：同一天展示同一句
        final dayIndex =
            DateTime.now().difference(DateTime(2020)).inDays;
        return pool[dayIndex % pool.length];
      }
      if (pool.length == 1) return pool.first;
      var next = pool[DateTime.now().microsecondsSinceEpoch % pool.length];
      var guard = 0;
      while (next == current && guard < 20) {
        next = pool[DateTime.now().microsecondsSinceEpoch % pool.length];
        guard++;
      }
      return next;
    } else {
      final custom = sentencesNotifier.value;
      if (custom.isEmpty) return '';
      if (!refresh) return custom.last.content;
      if (custom.length == 1) return custom.first.content;
      var next =
          custom[DateTime.now().microsecondsSinceEpoch % custom.length].content;
      var guard = 0;
      while (next == current && guard < 20) {
        next = custom[DateTime.now().microsecondsSinceEpoch % custom.length]
            .content;
        guard++;
      }
      return next;
    }
  }

  /// 初始化展示句子（按日期稳定）。建议在页面 initState 调用。
  static void initDisplaySentence() {
    displaySentenceNotifier.value =
        _selectSentence(SettingsEngine.dailySentenceUseBuiltin);
  }

  /// 刷新：换一句不同的句子（随机）。
  static void refreshDisplaySentence() {
    displaySentenceNotifier.value = _selectSentence(
      SettingsEngine.dailySentenceUseBuiltin,
      refresh: true,
      current: displaySentenceNotifier.value,
    );
  }

  /// 开关或自定义列表变化时重新同步展示内容（保持按日期稳定，不随机）。
  static void syncDisplaySentence() {
    displaySentenceNotifier.value =
        _selectSentence(SettingsEngine.dailySentenceUseBuiltin);
  }


  /// Load saved daily sentences from local document storage.
  static Future<void> loadSentences() async {
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

  /// Update an existing daily sentence and persist the updated list.
  Future<void> updateSentence(DailySentenceModel sentence) async {
    final current = List<DailySentenceModel>.from(sentencesNotifier.value);
    final index = current.indexWhere((item) => item.id == sentence.id);
    if (index < 0) {
      return;
    }

    current[index] = sentence;
    sentencesNotifier.value = current;
    await _saveSentences(current);
  }

  /// Delete a daily sentence by id and persist the updated list.
  static Future<void> deleteSentence(String id) async {
    final current = List<DailySentenceModel>.from(sentencesNotifier.value)
      ..removeWhere((item) => item.id == id);
    sentencesNotifier.value = current;
    await _saveSentences(current);
  }

  /// Reorder sentences by moving item at [oldIndex] to [newIndex].
  static Future<void> reorderSentence(int oldIndex, int newIndex) async {
    final current = List<DailySentenceModel>.from(sentencesNotifier.value);
    if (oldIndex < current.length && newIndex < current.length) {
      final item = current.removeAt(oldIndex);
      current.insert(newIndex, item);
      sentencesNotifier.value = current;
      await _saveSentences(current);
    }
  }

  static Future<File> _dataFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_storageFileName');
  }

  static Future<void> _saveSentences(List<DailySentenceModel> sentences) async {
    final file = await _dataFile();
    final encoded = jsonEncode(sentences.map((item) => item.toJson()).toList());
    await file.writeAsString(encoded);
  }
}
