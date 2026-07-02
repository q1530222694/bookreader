import '../../engine/settings_engine.dart';

/// FontManager centralizes application font selection and resolution.
///
/// 所有字体名称映射、默认字体解析和后续自定义字体逻辑都应集中在这里。
class FontManager {
  FontManager._();

  static const Map<String, String> _fontFamilyMap = {
    SettingsEngine.fontFamilySystem: '',
    SettingsEngine.fontFamilySansSerif: 'Roboto',
    SettingsEngine.fontFamilySerif: 'Noto Serif',
    SettingsEngine.fontFamilyMonospace: 'monospace',
  };

  /// 统一中文字体回退列表，避免部分汉字使用不同字体导致粗细不一致。
  static const List<String> defaultFontFamilyFallback = [
    'Noto Sans SC',
    'PingFang SC',
    'Microsoft YaHei',
    'Heiti SC',
    'Segoe UI Historic',
  ];

  static List<String> get fontOptions => _fontFamilyMap.keys.toList();

  /// 将逻辑字体键映射为可用于 Theme 的 fontFamily 名称。
  ///
  /// 如果返回 null，则使用系统默认字体。
  static String? resolveFontFamily(String fontFamilyKey) {
    final family = _fontFamilyMap[fontFamilyKey];
    return (family?.isEmpty ?? true) ? null : family;
  }
}
