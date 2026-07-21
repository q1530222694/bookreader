import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 封面磁盘缓存：将每本书的封面 PNG 持久化到应用文档目录，避免把全分辨率封面字节
/// 常驻内存（旧实现每个 [BookModel] 都持有一份 [Uint8List]，书架书籍多时内存占用显著）。
///
/// - 存储路径：`<appDocs>/book_covers/<safeId>.png`
/// - [init] 在应用启动时预解析根目录（完成后即可用 [fileForSync] 零成本取 [File]）。
/// - [save] 写出封面；[fileForSync] 供 UI 同步构建 `Image.file`；[fileFor] 供需要异步取的场景。
/// - [delete] 在移除书籍时清理对应封面，避免孤儿文件堆积。
class CoverStore {
  CoverStore._();

  /// 封面根目录（应用文档目录下的 book_covers），由 [init] 预解析并缓存。
  static Directory? _baseDir;

  /// 安全文件名：把 bookId 中的非常规字符替换为下划线，避免路径穿越/非法文件名。
  static String _safeId(String bookId) {
    final cleaned = bookId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return cleaned.isEmpty ? 'unknown' : cleaned;
  }

  /// 预解析并创建封面根目录（应用启动时调用一次，确保 [fileForSync] 可用）。
  ///
  /// 必须在 [runApp] 前 await 完成，使整个运行期内 [_baseDir] 非 null，
  /// 从而 UI 可同步、零成本地取得封面 [File]。
  static Future<void> init() async {
    final docs = await getApplicationDocumentsDirectory();
    _baseDir = Directory('${docs.path}/book_covers');
    await _baseDir!.create(recursive: true);
  }

  /// 返回某本书封面对应的 [File]（同步；必须 [init] 已完成后使用）。
  ///
  /// 由于 [init] 在 main 中已被 await，运行期调用本方法时 [_baseDir] 必然就绪；
  /// 若仍为空（如测试未调用 init），则尽力回退到临时目录，避免抛错导致整页崩溃。
  static File fileForSync(String bookId) {
    final base = _baseDir;
    if (base == null) {
      // 兜底：理论上不可达；返回临时目录下的占位路径，decode 失败会触发 errorBuilder。
      return File('${Directory.systemTemp.path}/book_covers/${_safeId(bookId)}.png');
    }
    return File('${base.path}/${_safeId(bookId)}.png');
  }

  /// 异步取封面 [File]（等价于 [fileForSync]，但可在未 init 时等待解析）。
  static Future<File> fileFor(String bookId) async {
    if (_baseDir == null) await init();
    return fileForSync(bookId);
  }

  /// 写出封面字节到磁盘（覆盖式写入）。
  static Future<void> save(String bookId, Uint8List bytes) async {
    final file = await fileFor(bookId);
    await file.writeAsBytes(bytes, flush: true);
  }

  /// 该书是否存在已落盘的封面文件。
  static Future<bool> exists(String bookId) async {
    final file = await fileFor(bookId);
    return file.exists();
  }

  /// 删除该书封面（移除书籍时调用，避免孤儿文件）。
  static Future<void> delete(String bookId) async {
    try {
      final file = await fileFor(bookId);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 删除失败不应影响书籍移除主流程。
    }
  }
}
