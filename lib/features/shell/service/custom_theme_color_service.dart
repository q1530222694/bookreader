import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../model/custom_theme_color_model.dart';

/// CustomThemeColorService 负责持久化用户自定义主题色列表（本地 JSON）。
///
/// 该服务不依赖任何 UI 组件，遵循「服务层持久化、UI 仅监听 notifier」的架构铁律：
/// UI 通过 [colorsNotifier] 读取列表变化，所有增删改都经本服务落盘。
class CustomThemeColorService {
  static const String _storageFileName = 'custom_theme_colors.json';

  /// 自定义配色列表的全局通知器，供 UI 监听刷新。
  static final ValueNotifier<List<CustomThemeColor>> colorsNotifier =
      ValueNotifier<List<CustomThemeColor>>([]);

  /// 应用启动时调用：从本地磁盘加载已保存的自定义配色。
  static Future<void> initialize() async {
    await loadColors();
  }

  /// 读取本地 JSON 并刷新 [colorsNotifier]；文件不存在或解析失败时回退为空列表。
  static Future<void> loadColors() async {
    try {
      final file = await _dataFile();
      if (!await file.exists()) {
        colorsNotifier.value = [];
        return;
      }

      final jsonString = await file.readAsString();
      if (jsonString.trim().isEmpty) {
        colorsNotifier.value = [];
        return;
      }

      final rawList = jsonDecode(jsonString) as List<dynamic>;
      colorsNotifier.value = rawList
          .cast<Map<String, dynamic>>()
          .map(CustomThemeColor.fromJson)
          .toList();
    } catch (_) {
      // 解析异常时保留当前数据，避免界面闪退。
      colorsNotifier.value = colorsNotifier.value;
    }
  }

  /// 新增一个自定义配色并落盘。
  static Future<void> addColor(CustomThemeColor color) async {
    final current = List<CustomThemeColor>.from(colorsNotifier.value)
      ..add(color);
    colorsNotifier.value = current;
    await _save(current);
  }

  /// 依据 id 更新已存在的自定义配色（颜色/名称）并落盘。
  static Future<void> updateColor(CustomThemeColor color) async {
    final current = List<CustomThemeColor>.from(colorsNotifier.value);
    final index = current.indexWhere((item) => item.id == color.id);
    if (index < 0) {
      return;
    }

    current[index] = color;
    colorsNotifier.value = current;
    await _save(current);
  }

  /// 依据 id 删除自定义配色并落盘。
  static Future<void> deleteColor(String id) async {
    final current = List<CustomThemeColor>.from(colorsNotifier.value)
      ..removeWhere((item) => item.id == id);
    colorsNotifier.value = current;
    await _save(current);
  }

  /// 返回指定 id 的自定义配色（不存在则为 null）。
  static CustomThemeColor? findById(String id) {
    for (final item in colorsNotifier.value) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// 获取本地存储文件句柄（应用文档目录）。
  static Future<File> _dataFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_storageFileName');
  }

  /// 将列表写入本地 JSON。
  static Future<void> _save(List<CustomThemeColor> list) async {
    final file = await _dataFile();
    final encoded = jsonEncode(list.map((item) => item.toJson()).toList());
    await file.writeAsString(encoded);
  }
}
