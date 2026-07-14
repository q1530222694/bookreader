import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../shared/ui/app_text_styles.dart';
import '../../membership/ui/membership_page.dart';
import 'about_page.dart';
import 'appearance_page.dart';
import 'daily_sentence_page.dart';
import 'language_page.dart';
import 'settings_page.dart';

/// ProfilePage displays the user's personal section for the shell module.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemBackground.resolveFrom(context);
    final cardColor = CupertinoTheme.of(context).scaffoldBackgroundColor;
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
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoButton.filled(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                      builder: (context) => const MembershipPage()),
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
                              color: CupertinoTheme.of(context).scaffoldBackgroundColor,
                              child: Text(
                                LocalizationEngine.text('sync'),
                                style: TextStyle(color: labelColor),
                              ),
                            ),
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
                        CupertinoPageRoute(
                            builder: (context) => const DailySentencePage()),
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
                        CupertinoPageRoute(
                            builder: (context) => const LanguagePage()),
                      );
                    },
                  ),
                  _ProfileSettingItem(
                    label: LocalizationEngine.text('app_appearance'),
                    icon: CupertinoIcons.paintbrush_fill,
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                            builder: (context) => const AppearancePage()),
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
          color: CupertinoTheme.of(context).scaffoldBackgroundColor,
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
