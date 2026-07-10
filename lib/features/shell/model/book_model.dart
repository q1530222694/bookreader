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
