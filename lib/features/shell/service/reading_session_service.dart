import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../engine/localization_engine.dart';

/// 单次阅读会话记录：用户在某个阅读器里从打开到离开的一次连续阅读。
/// 用于在「阅读记录」中展示会话级数据（几点开始、读了多久、是否读完），
/// 这是原有 BookModel 仅保存「每本书总时长 + 最后阅读时间」所无法表达的粒度。
class ReadingSession {
  /// 书籍 id（与 BookModel.id 对应，用于反查书名/封面）。
  final String bookId;

  /// 会话开始时间（UTC 毫秒，存 JSON 时转 int）。
  final int startedAtMs;

  /// 本次会话累计阅读秒数。
  final int durationSeconds;

  /// 本次会话结束时，该书是否已读完（progress >= 1.0）。
  final bool finished;

  const ReadingSession({
    required this.bookId,
    required this.startedAtMs,
    required this.durationSeconds,
    required this.finished,
  });

  DateTime get startedAt =>
      DateTime.fromMillisecondsSinceEpoch(startedAtMs, isUtc: false);

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'startedAtMs': startedAtMs,
        'durationSeconds': durationSeconds,
        'finished': finished,
      };

  factory ReadingSession.fromJson(Map<String, dynamic> json) => ReadingSession(
        bookId: json['bookId'] as String,
        startedAtMs: json['startedAtMs'] as int,
        durationSeconds: json['durationSeconds'] as int,
        finished: json['finished'] as bool,
      );
}

/// 阅读会话日志服务：持久化全部阅读会话，供阅读记录页实时查询。
/// 数据写入应用文档目录下的 reading_sessions.json，随 App 启动加载到内存。
class ReadingSessionService {
  /// 全部会话（内存镜像，按开始时间倒序）。
  static final ValueNotifier<List<ReadingSession>> sessionsNotifier =
      ValueNotifier<List<ReadingSession>>([]);

  static late String _filePath;
  static bool _loaded = false;

  /// 初始化：解析文件路径并加载历史会话。需在 App 启动时与 AppStatsService.initialize() 一起调用。
  static Future<void> initialize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _filePath = '${directory.path}/reading_sessions.json';
      await _load();
    } catch (e) {
      debugPrint('ReadingSessionService 初始化失败: $e');
    }
  }

  static Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final file = File(_filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = (jsonDecode(content) as List<dynamic>)
            .map((e) => ReadingSession.fromJson(e as Map<String, dynamic>))
            .toList();
        list.sort((a, b) => b.startedAtMs.compareTo(a.startedAtMs));
        sessionsNotifier.value = list;
      }
    } catch (e) {
      debugPrint('ReadingSessionService 加载失败: $e');
      sessionsNotifier.value = [];
    }
  }

  static Future<void> _persist(List<ReadingSession> list) async {
    try {
      final file = File(_filePath);
      await file.writeAsString(jsonEncode(list.map((s) => s.toJson()).toList()));
    } catch (e) {
      debugPrint('ReadingSessionService 保存失败: $e');
    }
  }

  /// 记录一次阅读会话并落盘。
  static Future<void> logSession({
    required String bookId,
    required DateTime startedAt,
    required int durationSeconds,
    required bool finished,
  }) async {
    if (durationSeconds <= 0) return;
    final session = ReadingSession(
      bookId: bookId,
      startedAtMs: startedAt.millisecondsSinceEpoch,
      durationSeconds: durationSeconds,
      finished: finished,
    );
    final list = [session, ...sessionsNotifier.value];
    sessionsNotifier.value = list;
    await _persist(list);
  }

  /// 返回落在 [day] 当天的会话（按开始时间倒序）。
  static List<ReadingSession> sessionsOnDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _inRange(start, end);
  }

  /// 返回开始时间落在 [startInclusive, endExclusive) 内的会话（按开始时间倒序）。
  static List<ReadingSession> sessionsInRange(
    DateTime startInclusive,
    DateTime endExclusive,
  ) =>
      _inRange(startInclusive, endExclusive);

  /// 从备份恢复阅读会话：按 (bookId + startedAtMs) 去重合并（保留导入的会话），
  /// 合并后按开始时间倒序并落盘。供「数据管理 - 导入阅读数据」调用。
  static Future<void> importSessions(List<ReadingSession> incoming) async {
    final existing = <String>{};
    final merged = <ReadingSession>[];
    for (final s in sessionsNotifier.value) {
      existing.add('${s.bookId}@${s.startedAtMs}');
      merged.add(s);
    }
    for (final s in incoming) {
      final key = '${s.bookId}@${s.startedAtMs}';
      if (!existing.contains(key)) {
        existing.add(key);
        merged.add(s);
      }
    }
    merged.sort((a, b) => b.startedAtMs.compareTo(a.startedAtMs));
    sessionsNotifier.value = merged;
    await _persist(merged);
  }

  static List<ReadingSession> _inRange(
    DateTime startInclusive,
    DateTime endExclusive,
  ) {
    final result = sessionsNotifier.value.where((s) {
      final t = s.startedAt;
      return !t.isBefore(startInclusive) && t.isBefore(endExclusive);
    }).toList();
    result.sort((a, b) => b.startedAtMs.compareTo(a.startedAtMs));
    return result;
  }

  /// 统计区间内「读完」的书籍 id 集合（会话 finished=true 即视为该次读完）。
  static Set<String> finishedBookIdsInRange(
    DateTime startInclusive,
    DateTime endExclusive,
  ) {
    final ids = <String>{};
    for (final s in _inRange(startInclusive, endExclusive)) {
      if (s.finished) ids.add(s.bookId);
    }
    return ids;
  }
}

/// 阅读会话计时器：供各阅读器在生命周期内调用，自动记录一次会话。
/// 用法：State 中持有实例，initState 调 [start]，dispose / 应用退后台时调 [stop]。
class ReadingSessionTracker {
  DateTime? _start;

  /// 开始计时（若已在计时则忽略，避免重复）。
  void start() => _start ??= DateTime.now();

  /// 结束计时并记录会话。返回本次会话秒数（未记录返回 0）。
  /// [isFinished] 用于判定该次结束时书籍是否已读完；[onDuration] 可顺带更新书籍累计时长。
  int stop({
    required String bookId,
    required bool Function() isFinished,
    void Function(int seconds)? onDuration,
  }) {
    final begin = _start;
    _start = null;
    if (begin == null) return 0;
    final elapsed = DateTime.now().difference(begin).inSeconds;
    if (elapsed <= 0) return 0;
    onDuration?.call(elapsed);
    ReadingSessionService.logSession(
      bookId: bookId,
      startedAt: begin,
      durationSeconds: elapsed,
      finished: isFinished(),
    );
    return elapsed;
  }

  /// 当前是否正在计时。
  bool get active => _start != null;
}

/// 将「HH:MM」格式化（本地化中性数字，不硬编码文本）。
String formatSessionTime(DateTime t) {
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '$hh:${mm}';
}

/// 将阅读秒数格式化为「X小时Y分钟」/「Y分钟」（单位走本地化）。
String formatSessionDuration(int seconds) {
  final min = seconds ~/ 60;
  if (min <= 0) return '0${LocalizationEngine.text('minutes_short')}';
  final h = min ~/ 60;
  final m = min % 60;
  final hourUnit = LocalizationEngine.text('hours_short');
  final minUnit = LocalizationEngine.text('minutes_short');
  if (h > 0) return '$h$hourUnit$m$minUnit';
  return '$m$minUnit';
}
