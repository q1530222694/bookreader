import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../../../shared/ui/app_text_styles.dart';
import '../controller/settings_controller.dart';

/// LanguagePage provides a dedicated page for switching app language.
class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemBackground.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          LocalizationEngine.text('language'),
          style: AppTextStyles.pageTitle(context),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              LocalizationEngine.text('language_settings_title'),
              style: AppTextStyles.sectionTitle(context),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: SettingsController.language,
              builder: (context, language, child) {
                return Column(
                  children: [
                    _LanguageOption(
                      label: LocalizationEngine.text('chinese'),
                      selected: language == SettingsEngine.languageChinese,
                      onTap: () => SettingsController.setLanguage(SettingsEngine.languageChinese),
                    ),
                    _LanguageOption(
                      label: LocalizationEngine.text('english'),
                      selected: language == SettingsEngine.languageEnglish,
                      onTap: () => SettingsController.setLanguage(SettingsEngine.languageEnglish),
                    ),
                    _LanguageOption(
                      label: LocalizationEngine.text('traditional_chinese'),
                      selected: language == SettingsEngine.languageTraditionalChinese,
                      onTap: () => SettingsController.setLanguage(SettingsEngine.languageTraditionalChinese),
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

class _LanguageOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({
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
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.menuItem(context, selected: selected),
              ),
            ),
            if (selected)
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
