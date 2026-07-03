/// 导出记录数据模型
class ExportRecord {
  /// 记录ID（使用导出时间戳）
  final String id;

  /// 导出的PDF文件路径
  final String filePath;

  /// PDF文件名
  final String fileName;

  /// 转换的图片数量
  final int imageCount;

  /// 导出时间
  final DateTime exportedAt;

  /// 文件大小（字节）
  final int fileSize;

  /// PDF是否已添加到书架
  final bool addedToShelf;

  ExportRecord({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.imageCount,
    required this.exportedAt,
    required this.fileSize,
    this.addedToShelf = false,
  });

  /// 将记录序列化为JSON格式
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'fileName': fileName,
      'imageCount': imageCount,
      'exportedAt': exportedAt.toIso8601String(),
      'fileSize': fileSize,
      'addedToShelf': addedToShelf,
    };
  }

  /// 从JSON反序列化
  factory ExportRecord.fromJson(Map<String, dynamic> json) {
    return ExportRecord(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      fileName: json['fileName'] as String,
      imageCount: json['imageCount'] as int,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      fileSize: json['fileSize'] as int,
      addedToShelf: json['addedToShelf'] as bool? ?? false,
    );
  }

  /// 创建副本并修改部分属性
  ExportRecord copyWith({
    String? id,
    String? filePath,
    String? fileName,
    int? imageCount,
    DateTime? exportedAt,
    int? fileSize,
    bool? addedToShelf,
  }) {
    return ExportRecord(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      imageCount: imageCount ?? this.imageCount,
      exportedAt: exportedAt ?? this.exportedAt,
      fileSize: fileSize ?? this.fileSize,
      addedToShelf: addedToShelf ?? this.addedToShelf,
    );
  }
}
