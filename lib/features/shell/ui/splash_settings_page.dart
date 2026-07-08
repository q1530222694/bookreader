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
                          _SectionCard(
                            title: LocalizationEngine.text('splash_content_type'),
                            children: [
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
                          _SectionCard(
                            title: LocalizationEngine.text('splash_image_settings'),
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF7BA6FF), Color(0xFF4A7CFF)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(LocalizationEngine.text('splash_current_image'), style: AppTextStyles.body(context)),
                                        const SizedBox(height: 2),
                                        Text(LocalizationEngine.text('splash_change_image'), style: AppTextStyles.secondary(context)),
                                      ],
                                    ),
                                  ),
                                  const Icon(CupertinoIcons.right_chevron),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: LocalizationEngine.text('splash_display_duration'),
                            children: [
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
                          _SectionCard(
                            title: LocalizationEngine.text('splash_entry_mode'),
                            children: [
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
                          _SectionCard(
                            title: LocalizationEngine.text('splash_jump_page'),
                            children: [
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
      height: 190,
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
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: CupertinoColors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(LocalizationEngine.text('splash_skip')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.sectionTitle(context)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
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
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, size: 16, color: selected ? CupertinoTheme.of(context).primaryColor : CupertinoColors.label.resolveFrom(context))
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
