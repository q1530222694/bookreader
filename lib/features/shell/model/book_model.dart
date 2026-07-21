/// BookModel represents an imported book file with preview metadata.
class BookModel {
  final String id;
  final String title;
  final String path;
  final String type;

  /// 是否已在磁盘落盘封面（见 [CoverStore]）。
  ///
  /// 改为「布尔标记 + 磁盘文件」而非常驻封面 [Uint8List]，书架书籍多时显著省内存；
  /// 真正的封面字节由 UI 经 `BookCoverImage` 从磁盘懒加载。
  final bool hasCover;
  final double progress;
  final DateTime? lastReadAt;
  final int readingDurationSeconds;
  final bool isFavorite;
  final int? fileSizeBytes;
  final List<String> tags;

  /// 根据路径扩展名和原始类型，得到统一的书籍分类。
  String get normalizedType => normalizeBookType(path: path, rawType: type);

  const BookModel({
    required this.id,
    required this.title,
    required this.path,
    required this.type,
    this.hasCover = false,
    this.progress = 0.0,
    this.lastReadAt,
    this.readingDurationSeconds = 0,
    this.isFavorite = false,
    this.fileSizeBytes,
    this.tags = const [],
  });

  /// 根据路径扩展名和原始类型，得到统一的书籍分类。
  static String normalizeBookType({required String path, String? rawType}) {
    final lowerPath = path.toLowerCase();
    final pathType = _detectTypeByPath(lowerPath);
    if (pathType != 'file') {
      return pathType;
    }

    final raw = (rawType ?? '').trim().toLowerCase();
    if (raw == 'pdf' || raw == 'epub' || raw == 'txt' || raw == 'mobi' || raw == 'comic') {
      return raw;
    }
    return 'file';
  }

  static String _detectTypeByPath(String pathLower) {
    if (pathLower.endsWith('.pdf')) return 'pdf';
    if (pathLower.endsWith('.epub')) return 'epub';
    if (pathLower.endsWith('.txt')) return 'txt';
    if (pathLower.endsWith('.mobi')) return 'mobi';
    if (pathLower.endsWith('.cbz') || pathLower.endsWith('.cbr') || pathLower.endsWith('.cb7') || pathLower.endsWith('.cbt') || pathLower.endsWith('.zip')) {
      return 'comic';
    }
    return 'file';
  }

  /// 序列化为 JSON（封面字节不入库，仅保留 [hasCover] 标记；[lastReadAt] 转毫秒）。
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'path': path,
        'type': type,
        'hasCover': hasCover,
        'progress': progress,
        'lastReadAt': lastReadAt?.millisecondsSinceEpoch,
        'readingDurationSeconds': readingDurationSeconds,
        'isFavorite': isFavorite,
        'fileSizeBytes': fileSizeBytes,
        'tags': tags,
      };

  /// 从 JSON 还原（字段缺失安全兜底，避免单条损坏导致整批导入失败）。
  factory BookModel.fromJson(Map<String, dynamic> json) => BookModel(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        path: json['path'] as String? ?? '',
        type: json['type'] as String? ?? 'file',
        hasCover: json['hasCover'] as bool? ?? false,
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
        lastReadAt: json['lastReadAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['lastReadAt'] as int),
        readingDurationSeconds: json['readingDurationSeconds'] as int? ?? 0,
        isFavorite: json['isFavorite'] as bool? ?? false,
        fileSizeBytes: json['fileSizeBytes'] as int?,
        tags: (json['tags'] as List?)?.map((e) => e as String).toList() ?? const [],
      );

  /// Returns a copy with the provided fields replaced.
  BookModel copyWith({
    String? id,
    String? title,
    String? path,
    String? type,
    bool? hasCover,
    double? progress,
    DateTime? lastReadAt,
    int? readingDurationSeconds,
    bool? isFavorite,
    int? fileSizeBytes,
    List<String>? tags,
  }) {
    return BookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      path: path ?? this.path,
      type: type ?? this.type,
      hasCover: hasCover ?? this.hasCover,
      progress: progress ?? this.progress,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      readingDurationSeconds: readingDurationSeconds ?? this.readingDurationSeconds,
      isFavorite: isFavorite ?? this.isFavorite,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      tags: tags ?? this.tags,
    );
  }
}
