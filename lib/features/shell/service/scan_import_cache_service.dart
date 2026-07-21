import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../model/scan_candidate_model.dart';

/// 扫描导入缓存的落盘条目：按「子目录游标 + 按目录分组的候选」存储，
/// 支持断点增量复用（见 [ScanImportCacheService]）。
class ScanImportCacheEntry {
  /// 子目录路径 → 该目录的修改时间（毫秒）。用于判断子树是否变化。
  final Map<String, int> dirCursors;

  /// 父目录路径 → 该目录下的候选列表（仅直接子文件，后代归入各自父目录键）。
  final Map<String, List<ScanCandidateModel>> candidatesByDir;

  const ScanImportCacheEntry({
    required this.dirCursors,
    required this.candidatesByDir,
  });

  Map<String, dynamic> toJson() => {
        'v': 2,
        'dirCursors': dirCursors,
        'candidatesByDir': candidatesByDir.map(
          (k, v) => MapEntry(k, v.map((c) => c.toJson()).toList()),
        ),
      };

  factory ScanImportCacheEntry.fromJson(Map<String, dynamic> json) {
    final dirCursors = <String, int>{};
    final rawCursors = json['dirCursors'];
    if (rawCursors is Map) {
      rawCursors.forEach((k, v) {
        if (k is String && v is int) dirCursors[k] = v;
      });
    }
    final candidatesByDir = <String, List<ScanCandidateModel>>{};
    final rawCand = json['candidatesByDir'];
    if (rawCand is Map) {
      rawCand.forEach((k, v) {
        if (k is String && v is List) {
          candidatesByDir[k] = v
              .whereType<Map<Object?, Object?>>()
              .map((e) => ScanCandidateModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      });
    }
    return ScanImportCacheEntry(dirCursors: dirCursors, candidatesByDir: candidatesByDir);
  }
}

/// 扫描导入结果缓存（断点增量：按「子目录修改时间游标」复用，仅重扫变化的子树）。
///
/// 设计动机与正确性修复：
/// - 旧方案用「根目录自身 mtime」作为整棵树的变更签名。但在 Linux/macOS 上，
///   在深层子目录新增/删除文件**不会**改变根目录的 mtime，导致二次扫描命中旧缓存、
///   漏掉新加入的书籍。本方案改为记录**每个子目录**的 mtime 游标，递归比对，
///   未变化的子树直接复用缓存候选、不再下探枚举，从根本上修复「漏扫」。
/// - 增量收益：二次扫描时，仅对发生变化的子目录重新枚举文件，未变化的子树（哪怕
///   内含成千上万个文件）完全跳过磁盘枚举，导入后封面预热也更快。
///
/// 落盘格式为 JSON（与 [PdfOcrCacheService] 同款 `path_provider` 模式），
/// 单文件按「根目录路径」为键保存各自条目。
class ScanImportCacheService {
  ScanImportCacheService._();

  // 版本号说明：
  //  - v1 初版：按「根目录集合签名」整体缓存（已废弃，存在深层漏扫问题）。
  //  - v2 当前：按「根目录路径」为键，每个根存「子目录游标 + 按目录分组候选」。
  static const String _fileName = 'scan_import_cache_v2.json';

  /// 内存缓存：根目录路径 → 缓存条目（进程内二次读取免盘）。
  static final Map<String, ScanImportCacheEntry> _mem = {};

  static Future<File> _file() async =>
      File('${(await getApplicationSupportDirectory()).path}/$_fileName');

  /// 读取单个根的缓存条目（命中则同时写入内存缓存），未缓存返回 null。
  ///
  /// [root] 为扫描根目录的完整路径；返回 null 时调用方应整根全量扫描。
  static Future<ScanImportCacheEntry?> loadRoot(String root) async {
    if (_mem.containsKey(root)) return _mem[root];
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is! Map) return null;
      final entry = decoded[root];
      if (entry is! Map) return null;
      final parsed = ScanImportCacheEntry.fromJson(Map<String, dynamic>.from(entry));
      _mem[root] = parsed;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  /// 写入单个根的缓存条目并异步落盘（全量覆盖该根条目）。
  ///
  /// [entry] 应为本次扫描后的完整快照（含复用 + 新扫的游标与候选）。
  static Future<void> saveRoot(String root, ScanImportCacheEntry entry) async {
    _mem[root] = entry;
    try {
      final all = await _readAll();
      all[root] = entry.toJson();
      final f = await _file();
      await f.writeAsString(jsonEncode(all));
    } catch (_) {
      // 落盘失败忽略（内存缓存仍有效，下次变更重试）。
    }
  }

  /// 是否所有给定根均有缓存条目（用于上层预判是否可快速复用）。
  ///
  /// 仅做一次落盘读取，遍历键集合判断存在性；不保证内容未变化（变化由增量扫描兜底）。
  static Future<bool> hasFresh(List<String> roots) async {
    if (roots.isEmpty) return false;
    try {
      final f = await _file();
      if (!await f.exists()) return false;
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is! Map) return false;
      for (final r in roots) {
        if (!decoded.containsKey(r)) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> _readAll() async {
    try {
      final f = await _file();
      if (!await f.exists()) return {};
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // 损坏则重建。
    }
    return {};
  }
}
