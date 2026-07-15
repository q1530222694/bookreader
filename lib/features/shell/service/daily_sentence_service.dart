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

  /// 自增盐值，用于保证同一次运行中批量新增的句子 id 唯一（避免同一微秒内的碰撞）。
  static int _idSalt = 0;

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
    // 先更新内存列表，保证 UI 立即反映（即使落盘失败也不影响界面）
    sentencesNotifier.value = current;
    try {
      await _saveSentences(current);
    } catch (e) {
      debugPrint('保存每日一句失败: $e');
    }
  }

  /// 批量新增每日一句：将多行文本逐条拆分为独立句子并一次性落盘。
  /// [contents] 为原始文本行（可含空行），内部会自动去除首尾空白并过滤空行。
  /// 每条句子生成唯一 id（微秒时间戳 + 自增盐值），避免同一微秒内的 id 碰撞。
  static Future<int> addSentencesBatch(List<String> contents) async {
    final trimmed =
        contents.map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    if (trimmed.isEmpty) return 0;

    final current = List<DailySentenceModel>.from(sentencesNotifier.value);
    for (final content in trimmed) {
      _idSalt++;
      current.add(DailySentenceModel(
        id: '${DateTime.now().microsecondsSinceEpoch}_$_idSalt',
        content: content,
      ));
    }
    // 先更新内存列表，保证 UI 立即反映新增（即使落盘失败也不影响界面）
    sentencesNotifier.value = current;
    try {
      await _saveSentences(current);
    } catch (e) {
      debugPrint('批量保存每日一句失败: $e');
    }
    return trimmed.length;
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
    try {
      await _saveSentences(current);
    } catch (e) {
      debugPrint('更新每日一句失败: $e');
    }
  }

  /// Delete a daily sentence by id and persist the updated list.
  static Future<void> deleteSentence(String id) async {
    final current = List<DailySentenceModel>.from(sentencesNotifier.value)
      ..removeWhere((item) => item.id == id);
    // 先更新内存列表，保证 UI 立即反映删除（即使落盘失败也不影响界面）
    sentencesNotifier.value = current;
    try {
      await _saveSentences(current);
    } catch (e) {
      debugPrint('删除每日一句失败: $e');
    }
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
