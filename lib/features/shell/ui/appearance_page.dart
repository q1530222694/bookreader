import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../engine/permission_engine.dart';
import '../../../engine/settings_engine.dart';
import '../../../shared/ui/app_text_styles.dart';
import '../controller/settings_controller.dart';
import '../model/custom_theme_color_model.dart';
import '../../membership/ui/membership_page.dart';
import 'custom_color_picker_sheet.dart';
import 'splash_settings_page.dart';

/// AppearancePage 提供应用外观模式与主题配色设置。
///
/// 该页面遵循项目全局 Theme 引擎与语义化样式要求，避免使用弹窗式选择。
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemBackground.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          LocalizationEngine.text('app_appearance'),
          style: AppTextStyles.pageTitle(context),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              LocalizationEngine.text('theme_mode'),
              style: AppTextStyles.sectionTitle(context),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: SettingsController.appearance,
              builder: (context, appearance, child) {
                return Row(
                  children: [
                    Expanded(
                      child: _AppearanceModeCard(
                        label: LocalizationEngine.text('follow_system'),
                        icon: null,
                        iconText: 'Auto',
                        selected: appearance == SettingsEngine.appearanceSystem,
                        onTap: () => SettingsController.setAppearance(SettingsEngine.appearanceSystem),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AppearanceModeCard(
                        label: LocalizationEngine.text('dark_mode'),
                        icon: CupertinoIcons.moon_fill,
                        selected: appearance == SettingsEngine.appearanceDark,
                        onTap: () => SettingsController.setAppearance(SettingsEngine.appearanceDark),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AppearanceModeCard(
                        label: LocalizationEngine.text('light_mode'),
                        icon: CupertinoIcons.sun_max_fill,
                        selected: appearance == SettingsEngine.appearanceLight,
                        onTap: () => SettingsController.setAppearance(SettingsEngine.appearanceLight),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              LocalizationEngine.text('theme_color'),
              style: AppTextStyles.sectionTitle(context),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: SettingsController.themeColor,
              builder: (context, themeColor, child) {
                return ValueListenableBuilder<String?>(
                  valueListenable: SettingsController.activeCustomColorId,
                  builder: (context, activeId, _) {
                    final colorKeys = [
                      SettingsEngine.themeColorBlue,
                      SettingsEngine.themeColorGreen,
                      SettingsEngine.themeColorPink,
                      SettingsEngine.themeColorOrange,
                      SettingsEngine.themeColorPurple,
                      SettingsEngine.themeColorRed,
                    ];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: colorKeys.map((colorKey) {
                            final color =
                                SettingsController.resolveThemeColor(colorKey);
                            final selected =
                                activeId == null && themeColor == colorKey;
                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: _ColorTile(
                                  color: color,
                                  label: LocalizationEngine.text(
                                      'theme_color_$colorKey'),
                                  selected: selected,
                                  onTap: () =>
                                      SettingsController.setPresetColor(colorKey),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          LocalizationEngine.text('theme_color_description'),
                          style: AppTextStyles.secondary(context),
                        ),
                        const SizedBox(height: 24),
                        // 自定义配色区：会员功能，受 PermissionEngine 统一管控。
                        const _CustomColorSection(),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            _SettingOption(
              label: LocalizationEngine.text('splash_settings'),
              selected: false,
              trailing: Icon(
                CupertinoIcons.right_chevron,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(builder: (context) => const SplashSettingsPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingOption extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? CupertinoTheme.of(context).primaryColor
                : CupertinoColors.separator.resolveFrom(context),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: AppTextStyles.menuItem(context, selected: selected),
                ),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: trailing!,
              )
            else if (selected)
              Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: CupertinoTheme.of(context).primaryColor,
              ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceModeCard extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? iconText;
  final bool selected;
  final VoidCallback onTap;

  const _AppearanceModeCard({
    required this.label,
    this.icon,
    this.iconText,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final borderColor = selected
        ? primaryColor
        : CupertinoColors.separator.resolveFrom(context);
    final backgroundColor = selected
        ? primaryColor.withOpacity(0.12)
        : CupertinoColors.secondarySystemBackground.resolveFrom(context);
    final textColor = selected ? primaryColor : CupertinoColors.label.resolveFrom(context);
    final secondaryColor = selected
        ? primaryColor
        : CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        constraints: const BoxConstraints(minHeight: 96),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.16),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconText != null)
              Text(
                iconText!,
                style: AppTextStyles.body(context).copyWith(
                  color: secondaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              )
            else if (icon != null)
              Icon(
                icon,
                size: 18,
                color: secondaryColor,
              ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(context).copyWith(
                color: textColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// _ColorTile 统一配色块：主题预设色与自定义配色共用同一组件，保证
/// 「框 / 圆点 / 命名 / 尺寸」四处完全一致。
/// [color] 为要展示的配色；[icon] 非空时（如「添加」占位）以图标替代色圈。
/// [label] 显示在色圈下方的命名；[selected] 选中态以主色描边高亮；
/// [onTap]/[onLongPress] 交互回调（长按可选，用于自定义色编辑/删除）。
class _ColorTile extends StatelessWidget {
  final Color? color;
  final Widget? icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ColorTile({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final borderColor = selected
        ? primaryColor
        : CupertinoColors.separator.resolveFrom(context);

    // 色圈：默认展示真实配色圆点；icon 非空（如「添加」）时以图标替代。
    final Widget swatch = icon ??
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        );

    final Widget tile = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: selected ? 2 : 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          swatch,
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.secondary(context).copyWith(fontSize: 12),
          ),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: tile,
    );
  }
}

/// _CustomColorSection 承载「应用外观」页的自定义配色能力（会员功能）：
/// 自定义配色网格大小一致、每行最多 7 个、放不下自动换行，末尾一个同尺寸的
/// 「添加」框。自定义配色支持点按应用、长按编辑/删除，并受会员权限控制。
class _CustomColorSection extends StatelessWidget {
  const _CustomColorSection();

  /// 自定义配色是否可用（由权限引擎统一判定，符合服务端驱动权限铁律）。
  bool get _canCustomize => PermissionEngine.hasPermission('theme.customColor');

  /// 跳转会员页（未开通会员时，锁定入口引导至此）。
  void _goMembership(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (context) => const MembershipPage()),
    );
  }

  /// 打开取色弹层：existing 为空表示新增，否则为编辑已有配色。
  Future<void> _openPicker(BuildContext context,
      {CustomThemeColor? existing}) async {
    final initialColor =
        existing?.color ?? CupertinoTheme.of(context).primaryColor;
    await showCustomColorPicker(
      context: context,
      initialColor: initialColor,
      initialName: existing?.name,
      onConfirm: (color, name) async {
        if (existing != null) {
          await SettingsController.updateCustomColor(
            existing.id,
            color,
            name: name.isEmpty ? null : name,
          );
        } else {
          await SettingsController.addCustomColor(
            color,
            name: name.isEmpty ? null : name,
          );
        }
      },
    );
  }

  /// 长按自定义色块：弹出编辑 / 删除操作表。
  void _showEditActionSheet(BuildContext context, CustomThemeColor item) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: Text(
            item.name?.isNotEmpty == true
                ? item.name!
                : LocalizationEngine.text('custom_theme_color'),
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _openPicker(context, existing: item);
              },
              child: Text(LocalizationEngine.text('edit')),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _confirmDelete(context, item);
              },
              child: Text(LocalizationEngine.text('custom_color_delete')),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: Text(LocalizationEngine.text('cancel')),
          ),
        );
      },
    );
  }

  /// 删除二次确认弹窗。
  void _confirmDelete(BuildContext context, CustomThemeColor item) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text(LocalizationEngine.text('custom_color_delete')),
          content: Text(LocalizationEngine.text('custom_color_delete_confirm')),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(dialogContext).pop();
                SettingsController.deleteCustomColor(item.id);
              },
              child: Text(LocalizationEngine.text('custom_color_delete')),
            ),
            CupertinoDialogAction(
              child: Text(LocalizationEngine.text('cancel')),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocalizationEngine.text('custom_theme_color'),
          style: AppTextStyles.sectionTitle(context),
        ),
        const SizedBox(height: 4),
        Text(
          LocalizationEngine.text('custom_color_section_hint'),
          style: AppTextStyles.secondary(context),
        ),
        const SizedBox(height: 12),
        // 自定义配色网格：与主题预设色同一 _ColorTile，列数 6 与预设一致，
        // 保证「框 / 圆点 / 命名 / 尺寸」完全对齐。
        ValueListenableBuilder<List<CustomThemeColor>>(
          valueListenable: SettingsController.customColors,
          builder: (context, colors, _) {
            return ValueListenableBuilder<String?>(
              valueListenable: SettingsController.activeCustomColorId,
              builder: (context, activeId, _) {
                final primaryColor =
                    CupertinoTheme.of(context).primaryColor;
                final secondaryColor =
                    CupertinoColors.secondaryLabel.resolveFrom(context);

                return LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 8.0;
                    const countPerRow = 6;
                    final itemWidth =
                        (constraints.maxWidth - spacing * (countPerRow - 1)) /
                            countPerRow;

                    // 已有自定义色：复用 _ColorTile，色圈展示真实配色、下方显示命名。
                    final children = <Widget>[
                      for (final item in colors)
                        _ColorTile(
                          color: item.color,
                          label: item.name?.isNotEmpty == true
                              ? item.name!
                              : LocalizationEngine.text('custom_theme_color'),
                          selected: activeId == item.id,
                          onTap: () =>
                              SettingsController.applyCustomColorById(item.id),
                          onLongPress: () {
                            if (_canCustomize) {
                              _showEditActionSheet(context, item);
                            } else {
                              _goMembership(context);
                            }
                          },
                        ),
                      // 末尾「添加」占位：同样 _ColorTile，图标替代色圈、标注命名。
                      _ColorTile(
                        color: null,
                        icon: Icon(
                          _canCustomize
                              ? CupertinoIcons.add
                              : CupertinoIcons.lock_fill,
                          color: _canCustomize
                              ? primaryColor
                              : secondaryColor,
                          size: 22,
                        ),
                        label: LocalizationEngine.text('custom_color_add'),
                        selected: false,
                        onTap: () {
                          if (_canCustomize) {
                            _openPicker(context);
                          } else {
                            _goMembership(context);
                          }
                        },
                      ),
                    ];

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: children
                          .map(
                            (w) => SizedBox(
                              width: itemWidth,
                              child: w,
                            ),
                          )
                          .toList(),
                    );
                  },
                );
              },
            );
          },
        ),
        if (!_canCustomize)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              LocalizationEngine.text('custom_color_membership_hint'),
              style: AppTextStyles.secondary(context),
            ),
          ),
      ],
    );
  }
}

/// _CustomColorSwatch 与 _CustomColorAddTile 已合并为统一的 _ColorTile，
/// 由主题预设色与自定义配色共用，保证「框 / 圆点 / 命名 / 尺寸」完全一致。

