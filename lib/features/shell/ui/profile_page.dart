import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../controller/settings_controller.dart';
import 'daily_sentence_page.dart';
import 'settings_page.dart';

/// ProfilePage displays the user's personal section for the shell module.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _showLanguageSheet(BuildContext context) {
    final language = SettingsController.language.value;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: Text(LocalizationEngine.text('language')),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                SettingsController.setLanguage(SettingsEngine.languageChinese);
                Navigator.of(context).pop();
              },
              child: Text(
                '${LocalizationEngine.text('chinese')}${language == SettingsEngine.languageChinese ? ' ✓' : ''}',
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                SettingsController.setLanguage(SettingsEngine.languageEnglish);
                Navigator.of(context).pop();
              },
              child: Text(
                '${LocalizationEngine.text('english')}${language == SettingsEngine.languageEnglish ? ' ✓' : ''}',
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(LocalizationEngine.text('cancel')),
          ),
        );
      },
    );
  }

  void _showAppearanceSheet(BuildContext context) {
    final appearance = SettingsController.appearance.value;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: Text(LocalizationEngine.text('appearance')),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                SettingsController.setAppearance(SettingsEngine.appearanceSystem);
                Navigator.of(context).pop();
              },
              child: Text(
                '${LocalizationEngine.text('follow_system')}${appearance == SettingsEngine.appearanceSystem ? ' ✓' : ''}',
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                SettingsController.setAppearance(SettingsEngine.appearanceLight);
                Navigator.of(context).pop();
              },
              child: Text(
                '${LocalizationEngine.text('light_mode')}${appearance == SettingsEngine.appearanceLight ? ' ✓' : ''}',
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                SettingsController.setAppearance(SettingsEngine.appearanceDark);
                Navigator.of(context).pop();
              },
              child: Text(
                '${LocalizationEngine.text('dark_mode')}${appearance == SettingsEngine.appearanceDark ? ' ✓' : ''}',
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(LocalizationEngine.text('cancel')),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemBackground.resolveFrom(context);
    final cardColor = CupertinoColors.secondarySystemBackground.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          LocalizationEngine.text('profile'),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: labelColor),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocalizationEngine.text('account_settings'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LocalizationEngine.text('welcome_back'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: labelColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            LocalizationEngine.text('placeholder_description'),
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: CupertinoButton.filled(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  onPressed: () {},
                                  child: Text(LocalizationEngine.text('premium')),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CupertinoButton(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  onPressed: () {},
                                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                                  child: Text(LocalizationEngine.text('sync')),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      LocalizationEngine.text('quick_access'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _ProfileSettingItem(
                    label: LocalizationEngine.text('daily_sentence'),
                    icon: CupertinoIcons.quote_bubble,
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(builder: (context) => const DailySentencePage()),
                      );
                    },
                  ),
                  _ProfileSettingItem(
                    label: LocalizationEngine.text('ai_assistant'),
                    icon: CupertinoIcons.chat_bubble_2_fill,
                    onTap: () {},
                  ),
                  _ProfileSettingItem(
                    label: LocalizationEngine.text('language'),
                    icon: CupertinoIcons.globe,
                    onTap: () => _showLanguageSheet(context),
                  ),
                  _ProfileSettingItem(
                    label: LocalizationEngine.text('appearance'),
                    icon: CupertinoIcons.paintbrush_fill,
                    onTap: () => _showAppearanceSheet(context),
                  ),
                  _ProfileSettingItem(
                    label: LocalizationEngine.text('theme_color'),
                    icon: CupertinoIcons.circle_fill,
                    onTap: () {},
                  ),
                  _ProfileSettingItem(
                    label: LocalizationEngine.text('more_settings'),
                    icon: CupertinoIcons.slider_horizontal_3,
                    targetPage: const SettingsPage(),
                  ),
                  _ProfileSettingItem(
                    label: LocalizationEngine.text('about'),
                    icon: CupertinoIcons.info_circle_fill,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// _ProfileSettingItem 是配置入口项的 UI 组件，用于保持界面风格统一。
class _ProfileSettingItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget? targetPage;
  final VoidCallback? onTap;

  const _ProfileSettingItem({
    required this.label,
    required this.icon,
    this.targetPage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap ?? (targetPage == null ? null : () {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (context) => targetPage!),
            );
          }),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CupertinoColors.separator.resolveFrom(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: CupertinoColors.activeBlue,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
            Icon(
              CupertinoIcons.right_chevron,
              color: CupertinoColors.systemGrey3.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }
}
