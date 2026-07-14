import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../shared/ui/app_text_styles.dart';
import '../../doc_to_pdf/ui/doc_to_pdf_page.dart';
import '../../excel_to_pdf/ui/excel_to_pdf_page.dart';
import '../../image_to_pdf/ui/image_to_pdf_page.dart';
import '../../ppt_to_pdf/ui/ppt_to_pdf_page.dart';
import '../../txt_to_epub/ui/txt_to_epub_page.dart';

/// ToolItem 工具条目数据模型（数据驱动）。
/// 所有展示文案均通过 [titleKey]/[subtitleKey] 走本地化引擎，UI 不出现硬编码中文；
/// 跳转目标页面由 [page] 注入，保持「无状态提线木偶」式纯视图。
class _ToolItem {
  /// 所属分类的本地化键（用于分组标题）
  final String categoryKey;

  /// 图标
  final IconData icon;

  /// 标题本地化键
  final String titleKey;

  /// 副标题本地化键
  final String subtitleKey;

  /// 点击跳转的目标页面
  final Widget page;

  const _ToolItem({
    required this.categoryKey,
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
    required this.page,
  });
}

/// ToolsPage 工具页面，以「分类 + 响应式网格」展示各种实用工具。
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  /// 全部工具定义（顺序即展示顺序，按 categoryKey 自动分组）
  static final List<_ToolItem> _tools = [
    _ToolItem(
      categoryKey: 'tools_cat_ebook',
      icon: CupertinoIcons.book,
      titleKey: 'tool_txt_epub_title',
      subtitleKey: 'tool_txt_epub_sub',
      page: const TxtToEpubPage(),
    ),
    _ToolItem(
      categoryKey: 'tools_cat_pdf',
      icon: CupertinoIcons.doc_text,
      titleKey: 'tool_doc_pdf_title',
      subtitleKey: 'tool_doc_pdf_sub',
      page: const DocToPdfPage(),
    ),
    _ToolItem(
      categoryKey: 'tools_cat_pdf',
      icon: CupertinoIcons.doc,
      titleKey: 'tool_ppt_pdf_title',
      subtitleKey: 'tool_ppt_pdf_sub',
      page: const PptToPdfPage(),
    ),
    _ToolItem(
      categoryKey: 'tools_cat_pdf',
      icon: CupertinoIcons.table,
      titleKey: 'tool_xls_pdf_title',
      subtitleKey: 'tool_xls_pdf_sub',
      page: const ExcelToPdfPage(),
    ),
    _ToolItem(
      categoryKey: 'tools_cat_pdf',
      icon: CupertinoIcons.photo_on_rectangle,
      titleKey: 'tool_img_pdf_title',
      subtitleKey: 'tool_img_pdf_sub',
      page: const ImageToPdfPage(),
    ),
  ];

  /// 根据屏幕宽度返回网格列数（响应式，满足跨端要求）。
  static int _columns(BuildContext context) {
    final double w = MediaQuery.of(context).size.width;
    if (w >= 800) return 4;
    if (w >= 600) return 3;
    return 2;
  }

  /// 构建单个工具卡片（纯展示，数据经构造传入、点击经回调/路由抛出）。
  Widget _buildToolCard(BuildContext context, _ToolItem item) {
    final theme = CupertinoTheme.of(context);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => item.page),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // 卡片背景使用语义化次级系统背景，跟随暗色模式
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(16),
          // 淡阴影取代边框，与书架/回忆页卡片风格一致
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 主色 12% 透明底的图标徽标，随主题色动态变化
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                item.icon,
                color: theme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            // 标题/副标题走语义化文本样式，无硬编码字号
            Text(
              LocalizationEngine.text(item.titleKey),
              style: AppTextStyles.body(context),
            ),
            const SizedBox(height: 4),
            Text(
              LocalizationEngine.text(item.subtitleKey),
              style: AppTextStyles.secondary(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 按分类聚合工具（保持首次出现顺序）
    final Map<String, List<_ToolItem>> grouped = {};
    for (final t in _tools) {
      grouped.putIfAbsent(t.categoryKey, () => []).add(t);
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(LocalizationEngine.text('tools')),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in grouped.entries) ...[
                // 分类标题（本地化键 -> 文案）
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                  child: Text(
                    LocalizationEngine.text(entry.key),
                    style: AppTextStyles.secondary(context)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                // 响应式网格（列数随屏幕宽度变化）
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _columns(context),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: entry.value.length,
                  itemBuilder: (_, i) => _buildToolCard(context, entry.value[i]),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
