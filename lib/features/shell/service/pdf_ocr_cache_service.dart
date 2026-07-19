import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../model/pdf_ocr_document.dart';

/// OCR 结果缓存（按「文件」落盘，避免重复识别浪费算力）。
///
/// 键由 [sourceKey] 派生（见 [computeKey]）：用文件路径 + 文件大小 + 修改时间
/// 拼成稳定标识，**不引入额外依赖**（避免 crypto 包）。同一本扫描 PDF 重开时
/// 直接命中缓存、秒开，后台不再重跑整本 OCR。
///
/// 落盘格式为 JSON（与 [PdfBookSettingsService] 同款 `path_provider` 模式），
/// 单文件存全部页，结构简单、便于调试。
class PdfOcrCacheService {
  PdfOcrCacheService._();

  // 版本号说明：v2 起图片块检测改为「行带（row-band）」整块裁剪算法（一图一截图，
  // 正文页 0 图块）。旧 v1 缓存里存的是过度碎裂的图块，直接换文件名令其失效，
  // 重排时按新算法重跑，避免沿用旧的「一堆截图」结果。
  static const String _fileName = 'pdf_ocr_cache_v2.json';

  /// 内存缓存：sourceKey → 反序列化文档（进程内二次读取免盘）。
  static final Map<String, PdfOcrDocument> _mem = {};

  static Future<File> _file() async =>
      File('${(await getApplicationSupportDirectory()).path}/$_fileName');

  /// 由文件路径派生稳定键：路径 + 大小 + 修改时间（任一变更即视为新书/新版）。
  static Future<String> computeKey(String filePath) async {
    try {
      final f = File(filePath);
      final stat = await f.stat();
      return '$filePath#${stat.size}#${stat.modified.millisecondsSinceEpoch}';
    } catch (_) {
      return filePath;
    }
  }

  /// 命中缓存则返回结构化文档（同时写入内存缓存），否则返回 null（需重新识别）。
  static Future<PdfOcrDocument?> load(String sourceKey) async {
    if (_mem.containsKey(sourceKey)) return _mem[sourceKey];
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final text = await f.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      final entry = decoded[sourceKey];
      if (entry is! Map) return null;
      final doc = PdfOcrDocument.fromJson(entry as Map<String, dynamic>);
      _mem[sourceKey] = doc;
      return doc;
    } catch (_) {
      return null;
    }
  }

  /// 写入结构化文档（全量覆盖该 sourceKey 条目），并异步落盘。
  static Future<void> save(PdfOcrDocument doc) async {
    _mem[doc.sourceKey] = doc;
    try {
      final all = await _readAll();
      all[doc.sourceKey] = doc.toJson();
      final f = await _file();
      await f.writeAsString(jsonEncode(all));
    } catch (_) {
      // 落盘失败忽略（内存缓存仍有效，下次变更重试）。
    }
  }

  /// 把单页数据合并进已缓存文档并落盘（用于后台逐页识别时的增量持久化）。
  /// [doc] 为当前内存文档（会被原地更新该页），[page] 为新增/更新的页。
  static Future<void> savePage(PdfOcrDocument doc, PdfOcrPageData page) async {
    final idx = doc.pages.indexWhere((p) => p.pageIndex == page.pageIndex);
    if (idx >= 0) {
      doc.pages[idx] = page;
    } else {
      doc.pages.add(page);
      doc.pages.sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
    }
    await save(doc);
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
