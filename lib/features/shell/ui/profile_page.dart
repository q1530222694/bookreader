import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../../../shared/ui/app_text_styles.dart';
import '../controller/settings_controller.dart';
import '../../membership/ui/membership_page.dart';
import 'about_page.dart';
import 'appearance_page.dart';
import 'daily_sentence_page.dart';
import 'language_page.dart';
import 'settings_page.dart';

/// ProfilePage displays the user's personal section for the shell module.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

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
              child: SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(LocalizationEngine.text('follow_system')),
                    if (appearance == SettingsEngine.appearanceSystem)
                      Icon(
                        CupertinoIcons.check_mark_circled_solid,
                        color: CupertinoTheme.of(context).primaryColor,
                      ),
                  ],
                ),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                SettingsController.setAppearance(SettingsEngine.appearanceLight);
                Navigator.of(context).pop();
              },
              child: SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(LocalizationEngine.text('light_mode')),
                    if (appearance == SettingsEngine.appearanceLight)
                      Icon(
                        CupertinoIcons.check_mark_circled_solid,
                        color: CupertinoTheme.of(context).primaryColor,
                      ),
                  ],
                ),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                SettingsController.setAppearance(SettingsEngine.appearanceDark);
                Navigator.of(context).pop();
              },
              child: SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(LocalizationEngine.text('dark_mode')),
                    if (appearance == SettingsEngine.appearanceDark)
                      Icon(
                        CupertinoIcons.check_mark_circled_solid,
                        color: CupertinoTheme.of(context).primaryColor,
                      ),
                  ],
                ),
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

  void _showFontSheet(BuildContext context) {
    final fontFamily = SettingsController.fontFamily.value;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: Text(LocalizationEngine.text('font_family')),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                SettingsController.setFontFamily(SettingsEngine.fontFamilySystem);
                Navigator.of(context).pop();
              },
              child: SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(LocalizationEngine.text('system_font')),
                    if (fontFamily == SettingsEngine.fontFamilySystem)
                      Icon(CupertinoIcons.check_mark_circled_solid, color: CupertinoTheme.of(context).primaryColor),
                  ],
                ),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                SettingsController.setFontFamily(SettingsEngine.fontFamilySansSerif);
                Navigator.of(context).pop();
              },
              child: SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(LocalizationEngine.text('sans_serif')),
                    if (fontFamily == SettingsEngine.fontFamilySansSerif)
                      Icon(CupertinoIcons.check_mark_circled_solid, color: CupertinoTheme.of(context).primaryColor),
                  ],
                ),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                SettingsController.setFontFamily(SettingsEngine.fontFamilySerif);
                Navigator.of(context).pop();
              },
              child: SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(LocalizationEngine.text('serif')),
                    if (fontFamily == SettingsEngine.fontFamilySerif)
                      Icon(CupertinoIcons.check_mark_circled_solid, color: CupertinoTheme.of(context).primaryColor),
                  ],
                ),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                SettingsController.setFontFamily(SettingsEngine.fontFamilyMonospace);
                Navigator.of(context).pop();
              },
              child: SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(LocalizationEngine.text('monospace')),
                    if (fontFamily == SettingsEngine.fontFamilyMonospace)
                      Icon(CupertinoIcons.check_mark_circled_solid, color: CupertinoTheme.of(context).primaryColor),
                  ],
                ),
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

  void _showThemeSheet(BuildContext context) {
    final themeColor = SettingsController.themeColor.value;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: Text(LocalizationEngine.text('theme_color')),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                SettingsController.setThemeColor(SettingsEngine.themeColorBlue);
                Navigator.of(context).pop();
              },
              child: SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(LocalizationEngine.text('theme_color_blue')),
                    if (themeColor == SettingsEngine.themeColorBlue)
                      Icon(CupertinoIcons.check_mark_circled_solid, color: CupertinoTheme.of(context).primaryColor),
                  ],
                ),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                SettingsController.setThemeColor(SettingsEngine.themeColorGreen);
                Navigator.of(context).pop();
              },
              child: SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(LocalizationEngine.text('theme_color_green')),
                    if (themeColor == SettingsEngine.themeColorGreen)
                      Icon(CupertinoIcons.check_mark_circled_solid, color: CupertinoTheme.of(context).primaryColor),
                  ],
                ),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                SettingsController.setThemeColor(SettingsEngine.themeColorPink);
                Navigator.of(context).pop();
              },
              child: SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(LocalizationEngine.text('theme_color_pink')),
                    if (themeColor == SettingsEngine.themeColorPink)
                      Icon(CupertinoIcons.check_mark_circled_solid, color: CupertinoTheme.of(context).primaryColor),
                  ],
                ),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                SettingsController.setThemeColor(SettingsEngine.themeColorOrange);
                Navigator.of(context).pop();
              },
              child: SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(LocalizationEngine.text('theme_color_orange')),
                    if (themeColor == SettingsEngine.themeColorOrange)
                      Icon(CupertinoIcons.check_mark_circled_solid, color: CupertinoTheme.of(context).primaryColor),
                  ],
                ),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop();
                // open font sheet
                Future.delayed(Duration(milliseconds: 200), () => _showFontSheet(context));
              },
              child: Text(LocalizationEngine.text('font_family')),
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
          style: AppTextStyles.pageTitle(context),
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
                      style: AppTextStyles.sectionTitle(context),
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
                            style: AppTextStyles.body(context).copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            LocalizationEngine.text('placeholder_description'),
                            style: AppTextStyles.secondary(context),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: CupertinoButton.filled(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      CupertinoPageRoute(builder: (context) => const MembershipPage()),
                                    );
                                  },
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
                      style: AppTextStyles.sectionTitle(context),
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
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(builder: (context) => const LanguagePage()),
                      );
                    },
                  ),
                  _ProfileSettingItem(
                    label: LocalizationEngine.text('app_appearance'),
                    icon: CupertinoIcons.paintbrush_fill,
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(builder: (context) => const AppearancePage()),
                      );
                    },
                  ),
                  _ProfileSettingItem(
                    label: LocalizationEngine.text('theme_color'),
                    icon: CupertinoIcons.circle_fill,
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(builder: (context) => const AppearancePage()),
                      );
                    },
                  ),
                  _ProfileSettingItem(
                    label: LocalizationEngine.text('more_settings'),
                    icon: CupertinoIcons.slider_horizontal_3,
                    targetPage: const SettingsPage(),
                  ),
                  _ProfileSettingItem(
                    label: LocalizationEngine.text('about'),
                    icon: CupertinoIcons.info_circle_fill,
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(builder: (context) => const AboutPage()),
                      );
                    },
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
                color: CupertinoTheme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.menuItem(context),
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
