import 'package:flutter/widgets.dart';

import '../../model/book_model.dart';
import '../../service/cover_store.dart';

/// 书籍封面缩略图组件：懒加载磁盘封面（[CoverStore]），无封面或解码失败时回退 [fallback]。
///
/// 相比旧实现「每个 BookModel 常驻一份封面 Uint8List 再 Image.memory」，本组件：
/// - 封面字节落盘（[CoverStore]），内存中仅保留一个布尔标记 [BookModel.hasCover]；
/// - 仅在需要显示时才由 `Image.file` 同步从磁盘解码，天然「按需懒加载」；
/// - [cacheWidth] 限制解码尺寸（约 140px 足够清晰，省内存）；
/// - [RepaintBoundary] 隔离重绘，避免卡片列表滚动时封面无谓重绘；
/// - 显式 width/height:double.infinity 配合 BoxFit.cover 完整铺满父容器封面位
///   （修复「封面缩在左上角」的回归）。
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
