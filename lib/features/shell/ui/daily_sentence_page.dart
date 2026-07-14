import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        DefaultMaterialLocalizations,
        ReorderableListView,
        ReorderableDragStartListener;

import '../../../engine/localization_engine.dart';
import '../controller/daily_sentence_controller.dart';
import '../controller/settings_controller.dart';
import '../model/daily_sentence_model.dart';
import '../service/daily_sentence_service.dart';
import 'daily_sentence_edit_page.dart';

/// 每日一句管理页 —— 按截图改版：开关卡 / 今日预览 / 语句列表（可编辑/删除/拖拽排序）/ 添加按钮。
class DailySentencePage extends StatefulWidget {
  const DailySentencePage({super.key});

  @override
  State<DailySentencePage> createState() => _DailySentencePageState();
}

class _DailySentencePageState extends State<DailySentencePage> {
  final DailySentenceController _controller = DailySentenceController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ─── 构建顶部开关卡片（带图标） ──────────────────────────────────────

  /// 「启用内置每日一句」设置卡，含图标、标题、描述与开关。
  Widget _buildUseBuiltinCard(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // 左侧图标容器（主题色底）
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                CupertinoIcons.quote_bubble_fill,
                size: 18,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocalizationEngine.text('daily_sentence_use_builtin'),
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    LocalizationEngine.text('daily_sentence_use_builtin_desc'),
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 11,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: SettingsController.dailySentenceUseBuiltin,
              builder: (context, value, child) {
                return CupertinoSwitch(
                  value: value,
                  onChanged: (v) =>
                      SettingsController.setDailySentenceUseBuiltin(v),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── 构建「今日预览」卡片 ─────────────────────────────────────────

  /// 预览卡片：显示「今天可能会看到」的句子 + 右侧刷新按钮。
  Widget _buildPreviewCard(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签「今天可能会看到」
          Text(
            LocalizationEngine.text('today_preview'),
            style: theme.textTheme.textStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 8),
          // 句子展示行：引用文本 + 刷新按钮
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: DailySentenceService.displaySentenceNotifier,
                  builder: (context, text, _) {
                    final displayText =
                        text.isEmpty ? LocalizationEngine.text('daily_sentence_empty_custom') : text;
                    return Text(
                      '"$displayText"',
                      style: theme.textTheme.textStyle.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              // 刷新按钮（图标+文字垂直排列）
              GestureDetector(
                onTap: () => DailySentenceService.refreshDisplaySentence(),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.refresh_circled_solid,
                        size: 22,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        LocalizationEngine.text('refresh_one'),
                        style: theme.textTheme.textStyle.copyWith(
                          fontSize: 10,
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 构建单条语句项 ──────────────────────────────────────────────

  /// 单条自定义语句：引用图标 + 文案（点击编辑）+ 拖拽手柄 + 更多操作按钮。
  Widget _buildSentenceItem(
    BuildContext context,
    DailySentenceModel item, {
    required int index,
  }) {
    final theme = CupertinoTheme.of(context);

    return Container(
      key: ValueKey<String>(item.id),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // 引用图标（主题色）
            Icon(
              CupertinoIcons.quote_bubble,
              size: 22,
              color: theme.primaryColor.withOpacity(0.75),
            ),
            const SizedBox(width: 10),
            // 文案（点击进入编辑）
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _navigateToEdit(item),
                child: Text(
                  item.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.textStyle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
            ),
            // 三点更多操作
            CupertinoButton(
              padding: const EdgeInsets.all(6),
              minSize: 32,
              onPressed: () => _showMoreActions(context, item, index),
              child: Icon(
                CupertinoIcons.ellipsis,
                size: 20,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
            // 拖拽手柄（Cupertino 风格三横线），按住可拖动排序
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                CupertinoIcons.line_horizontal_3,
                size: 22,
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 更多操作弹层（编辑/删除/移动） ─────────────────────────────

  /// 点击「...」弹出操作菜单。
  void _showMoreActions(
    BuildContext context,
    DailySentenceModel item,
    int index,
  ) {
    final sentences = _controller.sentences.value;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) {
        return CupertinoActionSheet(
          title: Text(
            item.content.length > 20
                ? '${item.content.substring(0, 20)}...'
                : item.content,
            style: TextStyle(
              color: CupertinoColors.label.resolveFrom(context),
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            // 编辑
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(popupContext).pop();
                _navigateToEdit(item);
              },
              child: Text(LocalizationEngine.text('edit')),
            ),
            // 上移
            if (index > 0)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(popupContext).pop();
                  DailySentenceService.reorderSentence(index, index - 1);
                },
                child: Text(LocalizationEngine.text('move_up')),
              ),
            // 下移
            if (index < sentences.length - 1)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(popupContext).pop();
                  DailySentenceService.reorderSentence(index, index + 1);
                },
                child: Text(LocalizationEngine.text('move_down')),
              ),
            // 删除
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(popupContext).pop();
                _confirmDelete(context, item);
              },
              child: Text(LocalizationEngine.text('bookshelf_delete')),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(popupContext).pop(),
            child: Text(LocalizationEngine.text('cancel')),
          ),
        );
      },
    );
  }

  // ─── 删除确认对话框 ─────────────────────────────────────────────

  void _confirmDelete(BuildContext context, DailySentenceModel item) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text(LocalizationEngine.text('sentence_delete_confirm')),
          content: Text(
            item.content.length > 30
                ? '${item.content.substring(0, 30)}...'
                : item.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(LocalizationEngine.text('cancel')),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _controller.deleteSentence(item.id);
                if (mounted) {
                  // 触发同步更新主页展示句
                  DailySentenceService.syncDisplaySentence();
                }
              },
              child: Text(LocalizationEngine.text('bookshelf_delete')),
            ),
          ],
        );
      },
    );
  }

  // ─── 跳转编辑页 ──────────────────────────────────────────────────

  void _navigateToEdit(DailySentenceModel? sentence) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => DailySentenceEditPage(sentence: sentence),
      ),
    );
  }

  // ─── 底部添加新语句按钮 ─────────────────────────────────────────

  Widget _buildAddButton(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 14),
        onPressed: () => _navigateToEdit(null),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.add,
              size: 18,
              color: theme.primaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              LocalizationEngine.text('add_new_sentence'),
              style: theme.textTheme.textStyle.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          LocalizationEngine.text('daily_sentence'),
          style: TextStyle(color: CupertinoTheme.of(context).primaryColor),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _navigateToEdit(null),
          child: Icon(
            CupertinoIcons.add,
            color: CupertinoTheme.of(context).primaryColor,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // ── 开关卡 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildUseBuiltinCard(context),
            ),

            const SizedBox(height: 10),

            // ── 今日预览卡片 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildPreviewCard(context),
            ),

            const SizedBox(height: 16),

            // ── 语句列表区域 ──
            Expanded(
              child: ValueListenableBuilder<List<DailySentenceModel>>(
                valueListenable: _controller.sentences,
                builder: (context, sentences, child) {
                  return Column(
                    children: [
                      // 「我的语句 (N)」标题栏
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${LocalizationEngine.text('my_sentences')} (${sentences.length})',
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                        ),
                      ),

                      // 列表或空状态
                      if (sentences.isEmpty)
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 80),
                              child: Text(
                                LocalizationEngine.text('no_sentences'),
                                style: TextStyle(
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        // ReorderableListView 是 Material 组件，需要 MaterialLocalizations
                        // 祖先；本 App 为纯 Cupertino，这里仅包裹一层 Localizations 提供
                        // 其所需的文案环境（不引入 MaterialApp，避免嵌套导航冲突）。
                        Expanded(
                            child: Localizations(
                              locale: const Locale('en'),
                              delegates: const [
                                DefaultWidgetsLocalizations.delegate,
                                DefaultMaterialLocalizations.delegate,
                              ],
                            child: ReorderableListView.builder(
                              scrollDirection: Axis.vertical,
                              shrinkWrap: true,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: sentences.length,
                              buildDefaultDragHandles: false,
                              onReorderItem: (oldIndex, newIndex) {
                                DailySentenceService.reorderSentence(
                                    oldIndex, newIndex);
                              },
                              itemBuilder: (context, index) {
                                final item = sentences[index];
                                return _buildSentenceItem(
                                  context,
                                  item,
                                  index: index,
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            // ── 底部：添加按钮 + 提示文字 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAddButton(context),
                  const SizedBox(height: 8),
                  Text(
                    LocalizationEngine.text('long_press_reorder'),
                    style: TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
