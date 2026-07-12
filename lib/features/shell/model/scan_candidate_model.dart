/// Represents a book file discovered during a scan import operation.
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
}
