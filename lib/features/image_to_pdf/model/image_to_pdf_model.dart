/// 图片转PDF的数据模型和结果类
class ConversionResult {
  /// 是否转换成功
  final bool success;

  /// 结果消息
  final String message;

  /// 生成的PDF文件路径
  final String? filePath;

  ConversionResult({
    required this.success,
    required this.message,
    this.filePath,
  });

  /// 工厂构造器 - 成功结果
  factory ConversionResult.success({
    required String message,
    required String filePath,
  }) {
    return ConversionResult(
      success: true,
      message: message,
      filePath: filePath,
    );
  }

  /// 工厂构造器 - 失败结果
  factory ConversionResult.failure({required String message}) {
    return ConversionResult(
      success: false,
      message: message,
      filePath: null,
    );
  }
}

/// 单个图片信息
class ImageInfo {
  /// 图片文件路径
  final String path;

  /// 图片文件名
  final String fileName;

  /// 排序顺序（从0开始）
  final int order;

  ImageInfo({
    required this.path,
    required this.fileName,
    required this.order,
  });
}
