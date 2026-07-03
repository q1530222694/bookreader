/// Excel转PDF的数据模型和结果类
class ConversionResult {
  final bool success;
  final String message;
  final String? filePath;

  ConversionResult({required this.success, required this.message, this.filePath});

  factory ConversionResult.success({required String message, required String filePath}) {
    return ConversionResult(success: true, message: message, filePath: filePath);
  }

  factory ConversionResult.failure({required String message}) {
    return ConversionResult(success: false, message: message, filePath: null);
  }
}

class ExportRecord {
  final String sourceFileName;
  final String pdfFileName;
  final int timestamp;
  final String filePath;

  ExportRecord({required this.sourceFileName, required this.pdfFileName, required this.timestamp, required this.filePath});

  Map<String, dynamic> toJson() => {
        'sourceFileName': sourceFileName,
        'pdfFileName': pdfFileName,
        'timestamp': timestamp,
        'filePath': filePath,
      };

  factory ExportRecord.fromJson(Map<String, dynamic> json) {
    return ExportRecord(
      sourceFileName: json['sourceFileName'] as String,
      pdfFileName: json['pdfFileName'] as String,
      timestamp: json['timestamp'] as int,
      filePath: json['filePath'] as String,
    );
  }
}
