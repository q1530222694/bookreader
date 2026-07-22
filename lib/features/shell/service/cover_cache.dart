import 'dart:collection';
import 'dart:typed_data';

/// 封面内存 LRU 缓存：减少重复磁盘 I/O，提升书架封面首次加载与滚动速度。
///
/// [CoverStore] 磁盘缓存在 [Image.file] 创建时仍需读盘解码；本缓存在内存持有原始字节，
/// 供 [Image.memory] 使用，比 [Image.file] 省去一次文件系统调用与解码器初始化。
///
/// - 最大容量：默认 20 张封面（每张 ≤400px 最长边约 15–60KB，20 张 ≤ 1.2MB）。
/// - LRU 驱逐：最近最少使用的条目在超容时自动移除。
/// - [CoverStore] 仍为唯一磁盘源。`put` 不同步写盘（已有 [CoverStore.save] 负责落盘）。
/// - **零外部依赖**：纯内存缓存，避免与 [CoverStore] 循环引用。
class CoverCache {
  CoverCache._();

  /// 内存缓存最大条目数。
  static const int _maxSize = 20;

  /// LRU 有序映射：键=bookId，值=封面 PNG 字节。
  static final LinkedHashMap<String, Uint8List> _lru = LinkedHashMap<String, Uint8List>();

  /// 从内存缓存取封面字节；未命中返回 null，不读盘（调用方自行走 [CoverStore] 盘路）。
  static Uint8List? get(String bookId) {
    final bytes = _lru.remove(bookId);
    if (bytes != null) {
      _lru[bookId] = bytes; // 重新插入末尾 → 最近使用
    }
    return bytes;
  }

  /// 将封面字节写入内存缓存。如已存在同 key，更新值并刷新 LRU 位置。
  static void put(String bookId, Uint8List bytes) {
    _lru.remove(bookId);
    _lru[bookId] = bytes;
    if (_lru.length > _maxSize) {
      _lru.remove(_lru.keys.first);
    }
  }

  /// 从内存清除指定 bookId（封面被更新/删除时调用）。
  static void remove(String bookId) {
    _lru.remove(bookId);
  }

  /// 清空全部内存缓存（不影响磁盘）。
  static void clear() {
    _lru.clear();
  }
}
