import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// CJK 中文字体加载器（共享工具）。
///
/// 转换类功能（doc/ppt/excel 转 PDF）需要把中文字形内嵌进 PDF，
/// 否则 [pdf] 包默认的 Helvetica 不含中文字形，中文会渲染成空白/方块。
///
/// 字体资源为 `assets/fonts/cjk.ttf`（见 `pubspec.yaml` 的 assets 配置，
/// 当前取自系统黑体 SimHei，含完整中文字形）。
///
/// 重要：转换逻辑运行在 `compute` 创建的 isolates 中，isolate 无法访问
/// `rootBundle`，因此必须在主线程（本加载器）把字体字节读出来，
/// 再通过 `compute` 的 `args` 传入 isolate 内部用 [pw.Font.ttf] 注册。
class CjkFontLoader {
  CjkFontLoader._();

  /// 字体资源在 assets 中的路径（需与 pubspec.yaml 的 assets 保持一致）。
  static const String assetPath = 'assets/fonts/cjk.ttf';

  /// 缓存已加载的字体字节，避免每次转换重复读取资源。
  static Uint8List? _cachedBytes;

  /// 加载 CJK 字体字节（带缓存）。
  ///
  /// 返回可在 isolate 中直接传给 [pw.Font.ttf] 的字节数据。
  static Future<Uint8List> loadBytes() async {
    if (_cachedBytes != null) return _cachedBytes!;

    final ByteData data = await rootBundle.load(assetPath);
    _cachedBytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return _cachedBytes!;
  }
}
