import 'package:flutter/cupertino.dart';

/// AppTextStyles 提供统一的语义化文本样式，方便后续统一字体与字号。
class AppTextStyles {
  AppTextStyles._();

  static TextStyle navTitle(BuildContext context) {
    return CupertinoTheme.of(context)
        .textTheme
        .navTitleTextStyle
        .copyWith(color: CupertinoColors.label.resolveFrom(context));
  }

  static TextStyle pageTitle(BuildContext context) {
    return CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: CupertinoColors.label.resolveFrom(context),
        );
  }

  static TextStyle sectionTitle(BuildContext context) {
    return CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.label.resolveFrom(context),
        );
  }

  static TextStyle body(BuildContext context) {
    return CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 16,
          color: CupertinoColors.label.resolveFrom(context),
        );
  }

  static TextStyle secondary(BuildContext context) {
    return CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 14,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        );
  }

  static TextStyle menuItem(BuildContext context, {bool selected = false}) {
    return CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 16,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: CupertinoColors.label.resolveFrom(context),
        );
  }

  /// caption 说明/时间等更小的辅助文字（12 号，三级标签色）。
  static TextStyle caption(BuildContext context) {
    return CupertinoTheme.of(context).textTheme.textStyle.copyWith(
          fontSize: 12,
          color: CupertinoColors.tertiaryLabel.resolveFrom(context),
        );
  }
}
