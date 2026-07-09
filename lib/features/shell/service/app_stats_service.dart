import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// AppStatsService 管理应用级统计数据，如打开次数
class AppStatsService {
  static final ValueNotifier<int> appLaunchCountNotifier = ValueNotifier<int>(0);

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
      } else {
        appLaunchCountNotifier.value = 0;
      }
    } catch (e) {
      debugPrint('AppStatsService 加载统计数据失败: $e');
      appLaunchCountNotifier.value = 0;
    }
  }

  // 保存统计数据到 JSON 文件
  static Future<void> _saveStats() async {
    try {
      final file = File(_statsFilePath);
      final data = {
        'appLaunchCount': appLaunchCountNotifier.value,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('AppStatsService 保存统计数据失败: $e');
    }
  }

  // 增加应用打开次数
  static Future<void> incrementAppLaunchCount() async {
    appLaunchCountNotifier.value++;
    await _saveStats();
  }

  // 获取当前应用打开次数
  static int getAppLaunchCount() {
    return appLaunchCountNotifier.value;
  }

  // 重置应用打开次数（仅用于测试或重置）
  static Future<void> resetAppLaunchCount() async {
    appLaunchCountNotifier.value = 0;
    await _saveStats();
  }
}
