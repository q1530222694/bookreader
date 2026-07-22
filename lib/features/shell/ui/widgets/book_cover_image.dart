import 'package:flutter/widgets.dart';

import '../../model/book_model.dart';
import '../../service/cover_cache.dart';
import '../../service/cover_store.dart';

/// 书籍封面缩略图组件：优先从 [CoverCache] 内存缓存取图（[Image.memory] 零读盘），
/// 未命中则回退 [CoverStore] 磁盘读（[Image.file]），无封面或解码失败回退 [fallback]。
///
/// 相比旧实现「每个 BookModel 常驻一份封面 Uint8List 再 Image.memory」，本组件：
/// - 封面字节落盘（[CoverStore]），内存中仅保留一个布尔标记 [BookModel.hasCover]；
/// - [CoverCache] 在内存 LRU 持有热封面的原始字节，命中即可跳过文件系统读盘；
/// - [cacheWidth] 限制解码尺寸（约 140px 足够清晰，省内存）；
/// - [RepaintBoundary] 隔离重绘，避免卡片列表滚动时封面无谓重绘。
class BookCoverImage extends StatelessWidget {
  final BookModel book;
  final BoxFit fit;
  final int? cacheWidth;
  final Widget Function(BuildContext context) fallback;

  const BookCoverImage({
    super.key,
    required this.book,
    this.fit = BoxFit.cover,
    this.cacheWidth = 140,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (!book.hasCover) return fallback(context);

    // ★ 优先内存缓存：命中则 Image.memory 零读盘，比 Image.file 快一个量级。
    final cached = CoverCache.get(book.id);
    if (cached != null) {
      return RepaintBoundary(
        child: Image.memory(
          cached,
          width: double.infinity,
          height: double.infinity,
          fit: fit,
          cacheWidth: cacheWidth,
          errorBuilder: (ctx, error, stack) => fallback(ctx),
        ),
      );
    }

    return RepaintBoundary(
      child: Image.file(
        CoverStore.fileForSync(book.id),
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        cacheWidth: cacheWidth,
        errorBuilder: (ctx, error, stack) => fallback(ctx),
      ),
    );
  }
}
