import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../../../shared/ui/app_text_styles.dart';
import '../../../shared/ui/duration_picker_dialog.dart';
import '../controller/settings_controller.dart';

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
                      icon: CupertinoIcons.globe,
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SettingsEngine.themeColorBlue,
                        SettingsEngine.themeColorGreen,
                        SettingsEngine.themeColorPink,
                        SettingsEngine.themeColorOrange,
                      ].map((colorKey) {
                        final color = _resolveThemeColor(context, colorKey);
                        final selected = themeColor == colorKey;
                        return _ThemeColorTile(
                          color: color,
                          label: LocalizationEngine.text('theme_color_$colorKey'),
                          selected: selected,
                          onTap: () => SettingsController.setThemeColor(colorKey),
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
            Text(
              LocalizationEngine.text('startup_page'),
              style: AppTextStyles.sectionTitle(context),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<String>(
              valueListenable: SettingsController.startupPage,
              builder: (context, startupPage, child) {
                String currentLabel;
                switch (startupPage) {
                  case SettingsEngine.startupPageHome:
                    currentLabel = LocalizationEngine.text('startup_page_home');
                    break;
                  case SettingsEngine.startupPageBookshelf:
                    currentLabel = LocalizationEngine.text('startup_page_bookshelf');
                    break;
                  case SettingsEngine.startupPageMemory:
                    currentLabel = LocalizationEngine.text('startup_page_memory');
                    break;
                  case SettingsEngine.startupPageTools:
                    currentLabel = LocalizationEngine.text('startup_page_tools');
                    break;
                  case SettingsEngine.startupPageProfile:
                    currentLabel = LocalizationEngine.text('startup_page_profile');
                    break;
                  case SettingsEngine.startupPageNone:
                  default:
                    currentLabel = LocalizationEngine.text('startup_page_none');
                    break;
                }

                return _SettingOption(
                  label: LocalizationEngine.text('startup_page'),
                  selected: false,
                  trailing: Text(currentLabel, style: AppTextStyles.secondary(context)),
                  onTap: () async {
                    await showCupertinoModalPopup<void>(
                      context: context,
                      builder: (context) => CupertinoActionSheet(
                        title: Text(LocalizationEngine.text('startup_page')),
                        actions: [
                          CupertinoActionSheetAction(
                            onPressed: () {
                              SettingsController.setStartupPage(SettingsEngine.startupPageNone);
                              Navigator.of(context).pop();
                            },
                            child: Text(LocalizationEngine.text('startup_page_none')),
                          ),
                          CupertinoActionSheetAction(
                            onPressed: () {
                              SettingsController.setStartupPage(SettingsEngine.startupPageHome);
                              Navigator.of(context).pop();
                            },
                            child: Text(LocalizationEngine.text('startup_page_home')),
                          ),
                          CupertinoActionSheetAction(
                            onPressed: () {
                              SettingsController.setStartupPage(SettingsEngine.startupPageBookshelf);
                              Navigator.of(context).pop();
                            },
                            child: Text(LocalizationEngine.text('startup_page_bookshelf')),
                          ),
                          CupertinoActionSheetAction(
                            onPressed: () {
                              SettingsController.setStartupPage(SettingsEngine.startupPageMemory);
                              Navigator.of(context).pop();
                            },
                            child: Text(LocalizationEngine.text('startup_page_memory')),
                          ),
                          CupertinoActionSheetAction(
                            onPressed: () {
                              SettingsController.setStartupPage(SettingsEngine.startupPageTools);
                              Navigator.of(context).pop();
                            },
                            child: Text(LocalizationEngine.text('startup_page_tools')),
                          ),
                          CupertinoActionSheetAction(
                            onPressed: () {
                              SettingsController.setStartupPage(SettingsEngine.startupPageProfile);
                              Navigator.of(context).pop();
                            },
                            child: Text(LocalizationEngine.text('startup_page_profile')),
                          ),
                        ],
                        cancelButton: CupertinoActionSheetAction(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(LocalizationEngine.text('cancel')),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              LocalizationEngine.text('startup_content'),
              style: AppTextStyles.sectionTitle(context),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<String>(
              valueListenable: SettingsController.startupSplashType,
              builder: (context, type, child) {
                return Column(
                  children: [
                    _SettingOption(
                      label: LocalizationEngine.text('startup_content_none'),
                      selected: type == SettingsEngine.startupSplashTypeNone,
                      onTap: () => SettingsController.setStartupSplashType(SettingsEngine.startupSplashTypeNone),
                    ),
                    _SettingOption(
                      label: LocalizationEngine.text('startup_content_text'),
                      selected: type == SettingsEngine.startupSplashTypeText,
                      onTap: () => SettingsController.setStartupSplashType(SettingsEngine.startupSplashTypeText),
                    ),
                    if (type == SettingsEngine.startupSplashTypeText)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: CupertinoTextField(
                          controller: TextEditingController(text: SettingsController.startupSplashText.value),
                          maxLines: 4,
                          placeholder: LocalizationEngine.text('startup_content_text_placeholder'),
                          decoration: BoxDecoration(
                            color: CupertinoColors.secondarySystemFill.resolveFrom(context),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          onChanged: (value) => SettingsController.setStartupSplashText(value),
                        ),
                      ),
                    _SettingOption(
                      label: LocalizationEngine.text('startup_content_image'),
                      selected: type == SettingsEngine.startupSplashTypeImage,
                      onTap: () => SettingsController.setStartupSplashType(SettingsEngine.startupSplashTypeImage),
                    ),
                    if (type == SettingsEngine.startupSplashTypeImage)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: CupertinoTextField(
                          controller: TextEditingController(text: SettingsController.startupSplashImagePath.value),
                          placeholder: LocalizationEngine.text('startup_content_image_placeholder'),
                          decoration: BoxDecoration(
                            color: CupertinoColors.secondarySystemFill.resolveFrom(context),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          onChanged: (value) => SettingsController.setStartupSplashImagePath(value),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              LocalizationEngine.text('startup_duration'),
              style: AppTextStyles.sectionTitle(context),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<int>(
              valueListenable: SettingsController.startupSplashDuration,
              builder: (context, duration, child) {
                return _SettingOption(
                  label: '$duration ${LocalizationEngine.text('seconds')}',
                  selected: false,
                  onTap: () async {
                    final result = await showDurationPickerDialog(context, initialSeconds: duration);
                    if (result != null) {
                      SettingsController.setStartupSplashDuration(result);
                    }
                  },
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
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AppearanceModeCard({
    required this.label,
    required this.icon,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
              Icon(icon, color: selected ? primaryColor : CupertinoColors.secondaryLabel.resolveFrom(context)),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(context).copyWith(
                  color: selected ? primaryColor : CupertinoColors.label.resolveFrom(context),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
        width: 90,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.secondary(context),
            ),
          ],
        ),
      ),
    );
  }
}
