import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 个人云盘/NAS 配置列表的跨启动持久化存储。
///
/// 与 [ScanRootsStore] 同款方案（应用私有目录落盘 JSON，**不引入新依赖**）：
/// 内存镜像 + 启动 [load] + 写时 [persist]。存储的是「配置字典列表」，
/// 不直接依赖 feature 层的 [CloudDriveConfig] 模型，避免 core 反向依赖 lib/features。
/// 真正的模型转换由 feature 的 [CloudDriveService] 负责。
class CloudDriveStore {
  CloudDriveStore._();

  static const String _fileName = 'cloud_drives_v1.json';

  /// 内存镜像：当前已持久化的云盘配置字典列表（进程内读取免盘）。
  static List<Map<String, dynamic>> _mem = const <Map<String, dynamic>>[];

  /// 是否已从磁盘加载过（避免重复读取；加载前返回内存空列表）。
  static bool _loaded = false;

  /// 同步读取当前云盘配置列表（内存镜像）。
  static List<Map<String, dynamic>> get drives =>
      List<Map<String, dynamic>>.from(_mem);

  /// 从磁盘加载持久化的云盘配置到内存镜像（幂等，仅首次真正读取）。
  ///
  /// 在 `main()` 启动时 await 调用一次即可，之后 [drives] 直接返回内存值。
  static Future<List<Map<String, dynamic>>> load() async {
    if (_loaded) return List<Map<String, dynamic>>.from(_mem);
    try {
      final f = await _file();
      if (await f.exists()) {
        final decoded = jsonDecode(await f.readAsString());
        if (decoded is List) {
          _mem = List<Map<String, dynamic>>.from(
            decoded.whereType<Map<String, dynamic>>(),
          );
        }
      }
    } catch (_) {
      // 读取/解析失败：保留空列表（不阻塞启动）。
    }
    _loaded = true;
    return List<Map<String, dynamic>>.from(_mem);
  }

  /// 写入云盘配置列表：更新内存镜像并异步落盘（落盘失败忽略，内存仍有效）。
  static Future<void> persist(List<Map<String, dynamic>> drives) async {
    _mem = List<Map<String, dynamic>>.from(drives);
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode(_mem));
    } catch (_) {
      // 落盘失败忽略（下次变更重试）。
    }
  }

  static Future<File> _file() async =>
      File('${(await getApplicationSupportDirectory()).path}/$_fileName');
}
