/// DailySentenceModel represents a single daily sentence entry.
class DailySentenceModel {
  /// Unique identifier for this sentence item.
  final String id;

  /// The full content of the daily sentence.
  final String content;

  const DailySentenceModel({required this.id, required this.content});

  /// Convert model to JSON map for persistence.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
    };
  }

  /// Create model from JSON map.
  factory DailySentenceModel.fromJson(Map<String, dynamic> json) {
    return DailySentenceModel(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }
}
