import 'dart:typed_data';

/// BookModel represents an imported book file with preview metadata.
class BookModel {
  final String id;
  final String title;
  final String path;
  final String type;
  final Uint8List? coverBytes;
  final double progress;

  const BookModel({
    required this.id,
    required this.title,
    required this.path,
    required this.type,
    this.coverBytes,
    this.progress = 0.0,
  });
}
