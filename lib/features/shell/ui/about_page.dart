import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../engine/localization_engine.dart';
import '../../../shared/ui/app_text_styles.dart';

/// AboutPage displays product information and support links.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        showCupertinoDialog<void>(
          context: context,
          builder: (context) {
            return CupertinoAlertDialog(
              title: Text(LocalizationEngine.text('open_failed')),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(LocalizationEngine.text('cancel')),
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemBackground.resolveFrom(context);
    final cardColor = CupertinoColors.secondarySystemBackground.resolveFrom(context);

    final supportItems = <_AboutActionItem>[
      _AboutActionItem(
        title: LocalizationEngine.text('update_log'),
        subtitle: LocalizationEngine.text('update_log_content'),
        icon: CupertinoIcons.doc_text,
        onTap: () => _openLink(context, 'https://example.com/changelog'),
      ),
      _AboutActionItem(
        title: LocalizationEngine.text('check_update'),
        subtitle: LocalizationEngine.text('update_latest'),
        icon: CupertinoIcons.arrow_clockwise,
        onTap: () => _openLink(context, 'https://example.com/check-update'),
      ),
      _AboutActionItem(
        title: LocalizationEngine.text('qq_group'),
        subtitle: '123456789',
        icon: CupertinoIcons.person_2_fill,
        onTap: () => _openLink(context, 'https://jq.qq.com/?_wv=1027&k=your-group'),
      ),
      _AboutActionItem(
        title: LocalizationEngine.text('wechat_group'),
        subtitle: 'bookreader-wechat',
        icon: CupertinoIcons.chat_bubble_2_fill,
        onTap: () => _openLink(context, 'https://weixin.qq.com/'),
      ),
      _AboutActionItem(
        title: LocalizationEngine.text('email'),
        subtitle: 'support@bookreader.app',
        icon: CupertinoIcons.mail_solid,
        onTap: () => _openLink(context, 'mailto:support@bookreader.app'),
      ),
      _AboutActionItem(
        title: LocalizationEngine.text('official_website'),
        subtitle: 'https://bookreader.app',
        icon: CupertinoIcons.globe,
        onTap: () => _openLink(context, 'https://bookreader.app'),
      ),
      _AboutActionItem(
        title: LocalizationEngine.text('privacy_policy'),
        subtitle: 'https://bookreader.app/privacy',
        icon: CupertinoIcons.lock_shield_fill,
        onTap: () => _openLink(context, 'https://bookreader.app/privacy'),
      ),
      _AboutActionItem(
        title: LocalizationEngine.text('user_agreement'),
        subtitle: 'https://bookreader.app/agreement',
        icon: CupertinoIcons.doc_checkmark,
        onTap: () => _openLink(context, 'https://bookreader.app/agreement'),
      ),
    ];

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          LocalizationEngine.text('about'),
          style: AppTextStyles.pageTitle(context),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationEngine.text('about_app_title'),
                        style: AppTextStyles.sectionTitle(context),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        LocalizationEngine.text('about_app_description'),
                        style: AppTextStyles.secondary(context),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: CupertinoButton.filled(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              onPressed: () {},
                              child: Text(LocalizationEngine.text('next_page')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  LocalizationEngine.text('support_and_links'),
                  style: AppTextStyles.sectionTitle(context),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = supportItems[index];
                  return CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: item.onTap,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
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
                              item.icon,
                              size: 20,
                              color: CupertinoTheme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: AppTextStyles.menuItem(context)),
                                const SizedBox(height: 4),
                                Text(
                                  item.subtitle,
                                  style: AppTextStyles.secondary(context),
                                ),
                              ],
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
                },
                childCount: supportItems.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutActionItem {
  const _AboutActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}
