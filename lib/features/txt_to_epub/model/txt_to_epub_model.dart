/// TXT转EPUB的数据模型和结果类
class ConversionResult {
  /// 是否转换成功
  final bool success;

  /// 结果消息
  final String message;

  /// 生成的EPUB文件路径
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

/// 转换记录数据类
class ExportRecord {
  /// 源文件名
  final String sourceFileName;

  /// 转换后的EPUB文件名
  final String epubFileName;

  /// 转换时间戳
  final int timestamp;

  /// EPUB文件路径
  final String filePath;

  ExportRecord({
    required this.sourceFileName,
    required this.epubFileName,
    required this.timestamp,
    required this.filePath,
  });

  /// JSON序列化
  Map<String, dynamic> toJson() => {
    'sourceFileName': sourceFileName,
    'epubFileName': epubFileName,
    'timestamp': timestamp,
    'filePath': filePath,
  };

  /// JSON反序列化
  factory ExportRecord.fromJson(Map<String, dynamic> json) {
    return ExportRecord(
      sourceFileName: json['sourceFileName'] as String,
      epubFileName: json['epubFileName'] as String,
      timestamp: json['timestamp'] as int,
      filePath: json['filePath'] as String,
    );
  }
}
