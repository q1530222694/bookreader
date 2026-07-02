import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../shared/ui/app_text_styles.dart';
import '../controller/membership_controller.dart';

/// MembershipPage displays membership status and permission-driven UI.
class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  bool _membershipEnabled = false;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _membershipEnabled = MembershipController.isMembershipEnabled();
    _statusText = LocalizationEngine.text('membership_loading');
    _loadMembershipStatus();
  }

  Future<void> _loadMembershipStatus() async {
    final status = await MembershipController.fetchMembershipStatus();
    if (!mounted) {
      return;
    }
    setState(() {
      _statusText = status.isVip
          ? '${LocalizationEngine.text('membership_vip_status')}${status.level}'
          : '${LocalizationEngine.text('membership_non_vip_status')}${status.level}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = CupertinoColors.systemBackground.resolveFrom(context);
    final borderColor = CupertinoColors.separator.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(LocalizationEngine.text('membership_center')),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocalizationEngine.text('membership_center'),
                style: AppTextStyles.pageTitle(context),
              ),
              const SizedBox(height: 8),
              Text(
                LocalizationEngine.text('membership_intro'),
                style: AppTextStyles.secondary(context),
              ),
              const SizedBox(height: 20),
              _MembershipSection(
                title: LocalizationEngine.text('membership_architecture'),
                body: LocalizationEngine.text('membership_architecture_body'),
                cardColor: cardColor,
                borderColor: borderColor,
              ),
              const SizedBox(height: 16),
              _MembershipSection(
                title: LocalizationEngine.text('membership_features'),
                body: null,
                cardColor: cardColor,
                borderColor: borderColor,
                items: [
                  LocalizationEngine.text('membership_feature_1'),
                  LocalizationEngine.text('membership_feature_2'),
                  LocalizationEngine.text('membership_feature_3'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocalizationEngine.text('membership_status_label'),
                      style: AppTextStyles.sectionTitle(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _membershipEnabled
                          ? LocalizationEngine.text('membership_enabled')
                          : LocalizationEngine.text('membership_disabled'),
                      style: AppTextStyles.body(context),
                    ),
                    const SizedBox(height: 6),
                    Text(_statusText, style: AppTextStyles.secondary(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembershipSection extends StatelessWidget {
  const _MembershipSection({
    required this.title,
    required this.cardColor,
    required this.borderColor,
    this.body,
    this.items,
  });

  final String title;
  final Color cardColor;
  final Color borderColor;
  final String? body;
  final List<String>? items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.sectionTitle(context)),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(body!, style: AppTextStyles.body(context)),
          ],
          if (items != null && items!.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...items!.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      CupertinoIcons.check_mark_circled_solid,
                      size: 18,
                      color: CupertinoTheme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item, style: AppTextStyles.body(context))),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
