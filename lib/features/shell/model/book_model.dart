import 'dart:typed_data';

/// BookModel represents an imported book file with preview metadata.
class BookModel {
  final String id;
  final String title;
  final String path;
  final String type;
  final Uint8List? coverBytes;
  final double progress;
  final DateTime? lastReadAt;
  final int readingDurationSeconds;
  final bool isFavorite;
  final int? fileSizeBytes;

  /// 根据路径扩展名和原始类型，得到统一的书籍分类。
  String get normalizedType => normalizeBookType(path: path, rawType: type);

  const BookModel({
    required this.id,
    required this.title,
    required this.path,
    required this.type,
    this.coverBytes,
    this.progress = 0.0,
    this.lastReadAt,
    this.readingDurationSeconds = 0,
    this.isFavorite = false,
    this.fileSizeBytes,
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

  /// Returns a copy with the provided fields replaced.
  BookModel copyWith({
    String? id,
    String? title,
    String? path,
    String? type,
    Uint8List? coverBytes,
    double? progress,
    DateTime? lastReadAt,
    int? readingDurationSeconds,
    bool? isFavorite,
    int? fileSizeBytes,
  }) {
    return BookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      path: path ?? this.path,
      type: type ?? this.type,
      coverBytes: coverBytes ?? this.coverBytes,
      progress: progress ?? this.progress,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      readingDurationSeconds: readingDurationSeconds ?? this.readingDurationSeconds,
      isFavorite: isFavorite ?? this.isFavorite,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }
}
