import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 每本 PDF 书的阅读设置持久化（按 [bookId] 隔离，落盘到应用支持目录的 JSON 文件）。
///
/// 与全局 [SettingsEngine]（纯内存、仅作默认基线）解耦：这里是「单本书对应设置」的
/// 唯一权威存储。键名与 [SettingsEngine] 的 PDF Key 保持一致，便于映射。
class PdfBookSettingsService {
  PdfBookSettingsService._();

  static final Map<String, Map<String, Object?>> _cache = {};
  static bool _loaded = false;
  static const String _fileName = 'pdf_book_settings_v1.json';

  static Future<Directory> _dir() async => getApplicationSupportDirectory();
  static Future<File> _file() async => File('${(await _dir()).path}/$_fileName');

  /// 懒加载落盘 JSON；重复调用安全（仅首次真正读盘）。
  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = await _file();
      if (await f.exists()) {
        final text = await f.readAsString();
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          for (final e in decoded.entries) {
            if (e.value is Map) {
              _cache[e.key as String] = Map<String, Object?>.from(
                e.value as Map,
              );
            }
          }
        }
      }
    } catch (_) {
      // 文件损坏则忽略，退化为空（不影响阅读）。
    }
  }

  /// 读取指定书的覆盖设置；无记录返回空 Map。
  static Map<String, Object?> load(String bookId) =>
      Map<String, Object?>.from(_cache[bookId] ?? const {});

  /// 写入指定书的覆盖设置（全量覆盖该书条目），并异步落盘。
  static Future<void> save(String bookId, Map<String, Object?> overrides) async {
    _cache[bookId] = Map<String, Object?>.from(overrides);
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode(_cache.map((k, v) => MapEntry(k, v))));
    } catch (_) {
      // 写入失败忽略（下次变更重试）。
    }
  }
}
