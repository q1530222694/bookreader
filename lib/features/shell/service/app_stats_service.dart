import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// AppStatsService 管理应用级统计数据，如打开次数。
/// 同时维护「每次打开的时间戳」列表，以支持按统计区间统计打开次数。
class AppStatsService {
  static final ValueNotifier<int> appLaunchCountNotifier = ValueNotifier<int>(0);

  /// 每次应用打开的时间戳列表（升序），用于按区间统计打开次数。
  /// 初始化前为空列表，调用方读取安全。
  static final ValueNotifier<List<DateTime>> launchTimestampsNotifier =
      ValueNotifier<List<DateTime>>([]);

  // JSON 文件路径
  static late String _statsFilePath;

  // 初始化服务并加载已保存的统计数据
  static Future<void> initialize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _statsFilePath = '${directory.path}/app_stats.json';

      // 加载已有的数据
      await _loadStats();
    } catch (e) {
      debugPrint('AppStatsService 初始化失败: $e');
    }
  }

  // 从 JSON 文件加载统计数据
  static Future<void> _loadStats() async {
    try {
      final file = File(_statsFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        appLaunchCountNotifier.value = data['appLaunchCount'] as int? ?? 0;
        // 解析历史打开时间戳（容错：跳过无法解析的条目）
        final raw = data['launchTimestamps'];
        if (raw is List) {
          final list = <DateTime>[];
          for (final item in raw) {
            if (item is String) {
              final dt = DateTime.tryParse(item);
              if (dt != null) list.add(dt);
            }
          }
          list.sort((a, b) => a.compareTo(b));
          launchTimestampsNotifier.value = list;
        }
      } else {
        appLaunchCountNotifier.value = 0;
        launchTimestampsNotifier.value = [];
      }
    } catch (e) {
      debugPrint('AppStatsService 加载统计数据失败: $e');
      appLaunchCountNotifier.value = 0;
      launchTimestampsNotifier.value = [];
    }
  }

  // 保存统计数据到 JSON 文件
  static Future<void> _saveStats() async {
    try {
      final file = File(_statsFilePath);
      final data = {
        'appLaunchCount': appLaunchCountNotifier.value,
        'launchTimestamps':
            launchTimestampsNotifier.value.map((d) => d.toIso8601String()).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('AppStatsService 保存统计数据失败: $e');
    }
  }

  // 增加应用打开次数，并记录本次打开时间戳
  static Future<void> incrementAppLaunchCount() async {
    appLaunchCountNotifier.value++;
    final updated = List<DateTime>.from(launchTimestampsNotifier.value)
      ..add(DateTime.now());
    launchTimestampsNotifier.value = updated;
    await _saveStats();
  }

  // 获取当前应用打开次数（全局累计）
  static int getAppLaunchCount() {
    return appLaunchCountNotifier.value;
  }

  /// 统计区间 [start, end) 内的应用打开次数。
  /// 与阅读统计的按区间口径一致：遍历打开时间戳，落在区间内的计数。
  static int getAppLaunchCountInRange(DateTime start, DateTime end) {
    var count = 0;
    for (final t in launchTimestampsNotifier.value) {
      if (!t.isBefore(start) && t.isBefore(end)) count++;
    }
    return count;
  }

  // 重置应用打开次数（仅用于测试或重置）
  static Future<void> resetAppLaunchCount() async {
    appLaunchCountNotifier.value = 0;
    launchTimestampsNotifier.value = [];
    await _saveStats();
  }
}
