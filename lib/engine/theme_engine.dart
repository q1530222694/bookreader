import 'package:flutter/cupertino.dart';

import '../core/theme/font_manager.dart';

/// ThemeEngine provides a centralized theme construction entry.
///
/// 所有全局主题相关的样式（包括字体、颜色、亮度）都应通过此类生成。
class ThemeEngine {
  ThemeEngine._();

  static CupertinoThemeData buildThemeData({
    required Brightness brightness,
    required Color primaryColor,
    required Color scaffoldBackgroundColor,
    required String fontFamilyKey,
  }) {
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(
          fontFamily: FontManager.resolveFontFamily(fontFamilyKey),
          fontFamilyFallback: FontManager.defaultFontFamilyFallback,
        ),
      ),
    );
  }
}
