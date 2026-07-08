import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../../../shared/ui/app_text_styles.dart';
import '../controller/settings_controller.dart';
import 'splash_settings_page.dart';

/// AppearancePage 提供应用外观模式与主题配色设置。
///
/// 该页面遵循项目全局 Theme 引擎与语义化样式要求，避免使用弹窗式选择。
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  Color _resolveThemeColor(BuildContext context, String themeColor) {
    switch (themeColor) {
      case SettingsEngine.themeColorGreen:
        return CupertinoColors.activeGreen;
      case SettingsEngine.themeColorPink:
        return CupertinoColors.systemPink;
      case SettingsEngine.themeColorOrange:
        return CupertinoColors.systemOrange;
      case SettingsEngine.themeColorPurple:
        return CupertinoColors.systemIndigo;
      case SettingsEngine.themeColorRed:
        return CupertinoColors.systemRed;
      case SettingsEngine.themeColorBlue:
      default:
        return CupertinoColors.activeBlue;
    }
  }

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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _AppearanceModeCard(
                      label: LocalizationEngine.text('follow_system'),
                      icon: null,
                      iconText: 'Auto',
                      selected: appearance == SettingsEngine.appearanceSystem,
                      onTap: () => SettingsController.setAppearance(SettingsEngine.appearanceSystem),
                    ),
                    _AppearanceModeCard(
                      label: LocalizationEngine.text('dark_mode'),
                      icon: CupertinoIcons.moon_fill,
                      selected: appearance == SettingsEngine.appearanceDark,
                      onTap: () => SettingsController.setAppearance(SettingsEngine.appearanceDark),
                    ),
                    _AppearanceModeCard(
                      label: LocalizationEngine.text('light_mode'),
                      icon: CupertinoIcons.sun_max_fill,
                      selected: appearance == SettingsEngine.appearanceLight,
                      onTap: () => SettingsController.setAppearance(SettingsEngine.appearanceLight),
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
                final primaryColor = _resolveThemeColor(context, themeColor);
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
                        final color = _resolveThemeColor(context, colorKey);
                        final selected = themeColor == colorKey;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _ThemeColorTile(
                              color: color,
                              label: LocalizationEngine.text('theme_color_$colorKey'),
                              selected: selected,
                              onTap: () => SettingsController.setThemeColor(colorKey),
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
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _SettingOption(
              label: LocalizationEngine.text('splash_settings'),
              selected: false,
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

    return Expanded(
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? primaryColor.withOpacity(0.12)
                : CupertinoColors.secondarySystemFill.resolveFrom(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconText != null)
                Text(
                  iconText!,
                  style: AppTextStyles.body(context).copyWith(
                    color: selected ? primaryColor : CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                )
              else if (icon != null)
                Icon(
                  icon,
                  size: 16,
                  color: selected ? primaryColor : CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(context).copyWith(
                  color: selected ? primaryColor : CupertinoColors.label.resolveFrom(context),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeColorTile extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeColorTile({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? CupertinoTheme.of(context).primaryColor
        : CupertinoColors.separator.resolveFrom(context);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
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
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.secondary(context).copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
