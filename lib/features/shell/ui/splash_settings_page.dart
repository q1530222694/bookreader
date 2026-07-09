import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../../../shared/ui/app_text_styles.dart';
import '../controller/settings_controller.dart';

/// SplashSettingsPage provides a consolidated splash screen configuration UI.
class SplashSettingsPage extends StatelessWidget {
  const SplashSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemBackground.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(LocalizationEngine.text('splash_settings'), style: AppTextStyles.pageTitle(context)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ValueListenableBuilder<String>(
            valueListenable: SettingsController.startupSplashType,
            builder: (context, splashType, _) {
              return ValueListenableBuilder<int>(
                valueListenable: SettingsController.startupSplashDuration,
                builder: (context, duration, _) {
                  return ValueListenableBuilder<String>(
                    valueListenable: SettingsController.startupPage,
                    builder: (context, startupPage, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PreviewCard(),
                          const SizedBox(height: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocalizationEngine.text('splash_content_type'),
                                style: AppTextStyles.sectionTitle(context),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _OptionTile(
                                      icon: null,
                                      label: LocalizationEngine.text('startup_content_none'),
                                      selected: splashType == SettingsEngine.startupSplashTypeNone,
                                      onTap: () => SettingsController.setStartupSplashType(SettingsEngine.startupSplashTypeNone),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _OptionTile(
                                      icon: CupertinoIcons.photo,
                                      label: LocalizationEngine.text('startup_content_image'),
                                      selected: splashType == SettingsEngine.startupSplashTypeImage,
                                      onTap: () => SettingsController.setStartupSplashType(SettingsEngine.startupSplashTypeImage),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _OptionTile(
                                      icon: CupertinoIcons.textformat,
                                      label: LocalizationEngine.text('startup_content_text'),
                                      selected: splashType == SettingsEngine.startupSplashTypeText,
                                      onTap: () => SettingsController.setStartupSplashType(SettingsEngine.startupSplashTypeText),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _SettingOptionCard(
                                      title: LocalizationEngine.text('splash_text_settings_left'),
                                      primaryText: LocalizationEngine.text('splash_current_image'),
                                      secondaryText: LocalizationEngine.text('splash_change_image'),
                                      icon: CupertinoIcons.photo,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _SettingOptionCard(
                                      title: LocalizationEngine.text('splash_text_settings_right'),
                                      primaryText: LocalizationEngine.text('splash_current_text'),
                                      secondaryText: LocalizationEngine.text('splash_change_text'),
                                      icon: CupertinoIcons.textformat,
                                      useLetterBadge: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocalizationEngine.text('splash_display_duration'),
                                style: AppTextStyles.sectionTitle(context),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _OptionTile(
                                      icon: CupertinoIcons.clock,
                                      label: LocalizationEngine.text('splash_duration_1s'),
                                      selected: duration == 1,
                                      onTap: () => SettingsController.setStartupSplashDuration(1),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _OptionTile(
                                      icon: CupertinoIcons.check_mark_circled_solid,
                                      label: LocalizationEngine.text('splash_duration_3s'),
                                      selected: duration == 3,
                                      onTap: () => SettingsController.setStartupSplashDuration(3),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _OptionTile(
                                      icon: CupertinoIcons.clock,
                                      label: LocalizationEngine.text('splash_duration_5s'),
                                      selected: duration == 5,
                                      onTap: () => SettingsController.setStartupSplashDuration(5),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _OptionTile(
                                      icon: CupertinoIcons.settings,
                                      label: LocalizationEngine.text('splash_duration_always'),
                                      selected: duration <= 0,
                                      onTap: () => SettingsController.setStartupSplashDuration(0),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocalizationEngine.text('splash_entry_mode'),
                                style: AppTextStyles.sectionTitle(context),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _OptionTile(
                                      icon: CupertinoIcons.bolt_fill,
                                      label: LocalizationEngine.text('splash_auto_home'),
                                      selected: true,
                                      showCheck: true,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _OptionTile(
                                      icon: CupertinoIcons.hand_draw,
                                      label: LocalizationEngine.text('splash_wait_click'),
                                      selected: false,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocalizationEngine.text('splash_jump_page'),
                                style: AppTextStyles.sectionTitle(context),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: Text(_startupPageLabel(startupPage, context), style: AppTextStyles.body(context))),
                                  const Icon(CupertinoIcons.right_chevron),
                                ],
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _startupPageLabel(String startupPage, BuildContext context) {
    switch (startupPage) {
      case SettingsEngine.startupPageHome:
        return LocalizationEngine.text('startup_page_home');
      case SettingsEngine.startupPageBookshelf:
        return LocalizationEngine.text('startup_page_bookshelf');
      case SettingsEngine.startupPageMemory:
        return LocalizationEngine.text('startup_page_memory');
      case SettingsEngine.startupPageTools:
        return LocalizationEngine.text('startup_page_tools');
      case SettingsEngine.startupPageProfile:
        return LocalizationEngine.text('startup_page_profile');
      case SettingsEngine.startupPageNone:
      default:
        return LocalizationEngine.text('startup_page_none');
    }
  }
}

class _PreviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF6D8DFF), Color(0xFF1D3557)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: CupertinoColors.black.withOpacity(0.16),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  LocalizationEngine.text('splash_preview_title'),
                  style: AppTextStyles.pageTitle(context).copyWith(
                    color: CupertinoColors.white,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  LocalizationEngine.text('splash_preview_subtitle'),
                  style: AppTextStyles.secondary(context).copyWith(
                    color: CupertinoColors.white.withOpacity(0.92),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CupertinoColors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  LocalizationEngine.text('splash_skip'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingOptionCard extends StatelessWidget {
  final String title;
  final String primaryText;
  final String secondaryText;
  final IconData icon;
  final bool useLetterBadge;

  const _SettingOptionCard({
    required this.title,
    required this.primaryText,
    required this.secondaryText,
    required this.icon,
    this.useLetterBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = CupertinoColors.separator.resolveFrom(context);
    final innerBoxColor = CupertinoColors.tertiarySystemFill.resolveFrom(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.body(context).copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.label.resolveFrom(context),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: innerBoxColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: CupertinoTheme.of(context).primaryColor,
                ),
                alignment: Alignment.center,
                child: useLetterBadge
                    ? Text(
                        'Aa',
                        style: AppTextStyles.body(context).copyWith(
                          color: CupertinoColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : Icon(icon, color: CupertinoColors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primaryText,
                      style: AppTextStyles.body(context).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      secondaryText,
                      style: AppTextStyles.secondary(context).copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.right_chevron,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool selected;
  final bool showCheck;
  final VoidCallback? onTap;

  const _OptionTile({this.icon, required this.label, required this.selected, this.showCheck = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? CupertinoTheme.of(context).primaryColor : CupertinoColors.separator.resolveFrom(context);
    final fillColor = selected
        ? CupertinoTheme.of(context).primaryColor.withOpacity(0.10)
        : CupertinoColors.secondarySystemBackground.resolveFrom(context);
    final iconColor = selected ? CupertinoTheme.of(context).primaryColor : CupertinoColors.label.resolveFrom(context);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 1.2 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, size: 16, color: iconColor)
            else
              const SizedBox.shrink(),
            if (icon != null) const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(context).copyWith(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (showCheck)
              Icon(CupertinoIcons.check_mark_circled_solid, color: CupertinoTheme.of(context).primaryColor, size: 16),
          ],
        ),
      ),
    );
  }
}
