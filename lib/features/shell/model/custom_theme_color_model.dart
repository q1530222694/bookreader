import 'dart:ui';

/// 自定义主题色模型：用户可创建、编辑、删除的专属配色。
///
/// 颜色以 32 位 ARGB 整型（[colorValue]）持久化，避免直接序列化 [Color] 对象。
class CustomThemeColor {
  /// 全局唯一标识，用于编辑/删除/选中态比对。
  final String id;

  /// 32 位 ARGB 颜色值（[Color.toARGB32()]），便于 JSON 存储。
  final int colorValue;

  /// 用户给该配色起的名称，可为空（为空时界面仅展示色块）。
  final String? name;

  const CustomThemeColor({
    required this.id,
    required this.colorValue,
    this.name,
  });

  /// 由整型值还原为 [Color]，供界面直接绘制。
  Color get color => Color(colorValue);

  /// 生成副本，仅替换提供的字段，便于局部更新而不丢失其它元数据。
  CustomThemeColor copyWith({String? id, int? colorValue, String? name}) {
    return CustomThemeColor(
      id: id ?? this.id,
      colorValue: colorValue ?? this.colorValue,
      name: name ?? this.name,
    );
  }

  /// 转为 JSON Map，供本地持久化。
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'colorValue': colorValue,
      if (name != null) 'name': name,
    };
  }

  /// 从 JSON Map 还原；缺省值保证健壮性。
  factory CustomThemeColor.fromJson(Map<String, dynamic> json) {
    return CustomThemeColor(
      id: json['id'] as String? ?? '',
      colorValue: json['colorValue'] as int? ?? 0xFF000000,
      name: json['name'] as String?,
    );
  }
}
