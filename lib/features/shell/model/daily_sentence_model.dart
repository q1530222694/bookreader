/// DailySentenceModel represents a single daily sentence entry.
class DailySentenceModel {
  /// Unique identifier for this sentence item.
  final String id;

  /// The full content of the daily sentence.
  final String content;

  const DailySentenceModel({required this.id, required this.content});
}
