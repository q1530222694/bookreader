import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../controller/settings_controller.dart';

/// SettingsPage provides language and appearance switching UI.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemBackground.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(LocalizationEngine.text('settings')),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader(title: LocalizationEngine.text('language')),
            ValueListenableBuilder<String>(
              valueListenable: SettingsController.language,
              builder: (context, language, child) {
                return Column(
                  children: [
                    _SettingOption(
                      label: LocalizationEngine.text('chinese'),
                      selected: language == SettingsEngine.languageChinese,
                      onTap: () => SettingsController
                          .setLanguage(SettingsEngine.languageChinese),
                    ),
                    _SettingOption(
                      label: LocalizationEngine.text('english'),
                      selected: language == SettingsEngine.languageEnglish,
                      onTap: () => SettingsController
                          .setLanguage(SettingsEngine.languageEnglish),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _SectionHeader(title: LocalizationEngine.text('appearance')),
            ValueListenableBuilder<String>(
              valueListenable: SettingsController.appearance,
              builder: (context, appearance, child) {
                return Column(
                  children: [
                    _SettingOption(
                      label: LocalizationEngine.text('follow_system'),
                      selected: appearance ==
                          SettingsEngine.appearanceSystem,
                      onTap: () => SettingsController.setAppearance(
                        SettingsEngine.appearanceSystem,
                      ),
                    ),
                    _SettingOption(
                      label: LocalizationEngine.text('light_mode'),
                      selected: appearance ==
                          SettingsEngine.appearanceLight,
                      onTap: () => SettingsController.setAppearance(
                        SettingsEngine.appearanceLight,
                      ),
                    ),
                    _SettingOption(
                      label: LocalizationEngine.text('dark_mode'),
                      selected: appearance ==
                          SettingsEngine.appearanceDark,
                      onTap: () => SettingsController.setAppearance(
                        SettingsEngine.appearanceDark,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SettingOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SettingOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? CupertinoColors.activeBlue
                : CupertinoColors.separator.resolveFrom(context),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
            if (selected)
              Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: CupertinoColors.activeBlue,
              ),
          ],
        ),
      ),
    );
  }
}
