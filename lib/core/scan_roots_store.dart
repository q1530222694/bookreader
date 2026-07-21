import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 扫描导入「用户追加根目录」的跨启动持久化存储。
///
/// 旧实现仅存于内存 [Config]，App 重启后用户追加的扫描目录即丢失、需重复操作。
/// 本存储用 `path_provider` 在应用私有目录落盘一个 JSON 文件（与项目内其它缓存
/// 服务同款方案，**不引入新依赖**），内存镜像 + 启动时 [load] + 写时 [persist]，
/// 确保「添加扫描目录」真正长期生效。
class ScanRootsStore {
  ScanRootsStore._();

  // 版本号说明：
  //  - v1 初版：持久化用户通过 UI 追加的扫描根目录列表（字符串数组）。
  static const String _fileName = 'scan_roots_v1.json';

  /// 内存镜像：当前已持久化的根目录列表（进程内读取免盘）。
  static List<String> _mem = const <String>[];

  /// 是否已从磁盘加载过（避免重复读取；加载前返回内存空列表）。
  static bool _loaded = false;

  /// 同步读取当前根目录列表（内存镜像）。若尚未加载过，返回空列表，
  /// 待 [load] 完成后下次访问即返回磁盘值。UI 调用方应在 App 启动时先 [load]。
  static List<String> get roots => List<String>.from(_mem);

  /// 从磁盘加载持久化的根目录列表到内存镜像（幂等，仅首次真正读取）。
  ///
  /// 在 `main()` 启动时 await 调用一次即可，之后 [roots] 直接返回内存值。
  static Future<List<String>> load() async {
    if (_loaded) return List<String>.from(_mem);
    try {
      final f = await _file();
      if (await f.exists()) {
        final decoded = jsonDecode(await f.readAsString());
        if (decoded is List) {
          _mem = List<String>.from(decoded.whereType<String>());
        }
      }
    } catch (_) {
      // 读取/解析失败：保留空列表（不阻塞启动）。
    }
    _loaded = true;
    return List<String>.from(_mem);
  }

  /// 写入根目录列表：更新内存镜像并异步落盘（落盘失败忽略，内存仍有效）。
  static Future<void> persist(List<String> roots) async {
    _mem = List<String>.from(roots);
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
