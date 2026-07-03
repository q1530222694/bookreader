/// DOC转PDF的数据模型和结果类
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

/// 转换记录数据类
class ExportRecord {
  /// 源文件名
  final String sourceFileName;

  /// 转换后的PDF文件名
  final String pdfFileName;

  /// 转换时间戳
  final int timestamp;

  /// PDF文件路径
  final String filePath;

  ExportRecord({
    required this.sourceFileName,
    required this.pdfFileName,
    required this.timestamp,
    required this.filePath,
  });

  /// JSON序列化
  Map<String, dynamic> toJson() => {
    'sourceFileName': sourceFileName,
    'pdfFileName': pdfFileName,
    'timestamp': timestamp,
    'filePath': filePath,
  };

  /// JSON反序列化
  factory ExportRecord.fromJson(Map<String, dynamic> json) {
    return ExportRecord(
      sourceFileName: json['sourceFileName'] as String,
      pdfFileName: json['pdfFileName'] as String,
      timestamp: json['timestamp'] as int,
      filePath: json['filePath'] as String,
    );
  }
}
