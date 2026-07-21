/// 扫描导入过程中发现的一本候选书籍（尚未导入书架）。
class ScanCandidateModel {
  const ScanCandidateModel({
    required this.path,
    required this.title,
    required this.type,
    required this.fileSizeBytes,
  });

  final String path;
  final String title;
  final String type;
  final int fileSizeBytes;

  /// 序列化为 JSON Map（供扫描结果缓存落盘，见 [ScanImportCacheService]）。
  Map<String, dynamic> toJson() => {
        'path': path,
        'title': title,
        'type': type,
        'fileSizeBytes': fileSizeBytes,
      };

  /// 从 JSON Map 反序列化（与 [toJson] 字段一一对应，漏字段用安全默认值兜底）。
  factory ScanCandidateModel.fromJson(Map<String, dynamic> json) => ScanCandidateModel(
        path: json['path'] as String? ?? '',
        title: json['title'] as String? ?? '',
        type: json['type'] as String? ?? '',
        fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      );
}
