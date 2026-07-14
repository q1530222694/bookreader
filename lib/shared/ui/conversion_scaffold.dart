import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:open_filex/open_filex.dart';

import '../../engine/localization_engine.dart';
import 'app_text_styles.dart';

/// 转换类工具页统一 UI 脚手架与构件集合。
///
/// 设计目标（遵循 `docs/提示词.md`）：
/// - 纯展示（Dumb UI）：所有数据经参数传入、交互经回调抛出，无业务依赖；
/// - 无硬编码：颜色走 `CupertinoColors` / 主题，字号走 [AppTextStyles]，
///   文案由调用方传入（已经过 `LocalizationEngine` 本地化）；
/// - 跨端响应式（禁区 7）：宽屏（iPad / 横屏）内容居中并限制最大宽度，
///   手机端全宽，保证在 Android / iOS / iPad 上均有良好观感。

/// 卡片圆角半径（统一视觉语言）
const double kConvRadius = 16.0;

/// 内容在宽屏下的最大宽度（iPad / 横屏时内容居中，不铺满整屏）
const double kConvMaxContentWidth = 560.0;

/// 统一卡片装饰：次级系统背景 + 柔和阴影，跟随暗色模式。
BoxDecoration conversionCardDecoration(BuildContext context) {
  return BoxDecoration(
    color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
    borderRadius: BorderRadius.circular(kConvRadius),
    boxShadow: [
      BoxShadow(
        color: CupertinoColors.systemGrey.withValues(alpha: 0.10),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

/// ConversionScaffold 转换页统一外壳。
///
/// 结构：导航栏（返回 + 标题）→ 内容区（IndexedStack）→ 底部分段控件（转换 / 记录）。
/// 分段控件置于底部，更贴近拇指，单手在 Android / iOS / iPad 上切换更顺手。
/// 内容由 [convertTab] 与 [recordsTab] 两个插槽提供，外部持有当前 Tab 状态。
class ConversionScaffold extends StatelessWidget {
  /// 页面标题（已本地化）
  final String title;

  /// 当前选中的 Tab（0=转换，1=记录）
  final int currentTab;

  /// Tab 切换回调
  final ValueChanged<int> onTabChanged;

  /// 「转换」Tab 内容
  final Widget convertTab;

  /// 「记录」Tab 内容
  final Widget recordsTab;

  const ConversionScaffold({
    super.key,
    required this.title,
    required this.currentTab,
    required this.onTabChanged,
    required this.convertTab,
    required this.recordsTab,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.back),
        ),
        middle: Text(title),
      ),
      child: SafeArea(
        // 底部安全区交由底部分段栏自身处理，避免双重内边距
        bottom: false,
        child: Column(
          children: [
            // 内容区（转换 / 记录 共享同一区域，按 currentTab 切换）
            Expanded(
              child: IndexedStack(
                index: currentTab,
                children: [
                  _centered(convertTab),
                  _centered(recordsTab),
                ],
              ),
            ),
            // 底部分段切换（转换 / 记录）：贴近拇指，单手操作更顺手
            _buildBottomTabBar(context),
          ],
        ),
      ),
    );
  }

  /// 底部分段切换栏（转换 / 记录）。
  ///
  /// 固定在页面底部、贴近拇指：带顶部发丝分隔线，背景跟随系统；
  /// 自身处理底部安全区（home indicator / 全面屏底部），宽屏下同样居中限宽。
  Widget _buildBottomTabBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: _centered(
            CupertinoSlidingSegmentedControl<int>(
              groupValue: currentTab,
              onValueChanged: (v) {
                if (v != null) onTabChanged(v);
              },
              children: {
                0: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: Text(LocalizationEngine.text('conv_tab_convert')),
                ),
                1: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  child: Text(LocalizationEngine.text('conv_tab_records')),
                ),
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 宽屏（≥600）内容居中并限制最大宽度，手机端全宽。
  Widget _centered(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kConvMaxContentWidth),
              child: child,
            ),
          );
        }
        return child;
      },
    );
  }
}

/// ConversionInfoCard 说明 / 状态提示卡片（图标 + 文本）。
class ConversionInfoCard extends StatelessWidget {
  /// 展示文本（已本地化或运行时拼装）
  final String text;

  /// 前置图标（可选）
  final IconData? icon;

  const ConversionInfoCard({super.key, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.secondary(context).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// ConversionPrimaryButton 主操作按钮（填充色，支持 loading 态）。
class ConversionPrimaryButton extends StatelessWidget {
  /// 按钮文案
  final String label;

  /// 点击回调；为 null 时禁用
  final VoidCallback? onPressed;

  /// 是否处于加载中（显示指示器 + loadingLabel）
  final bool loading;

  /// 加载时文案（可选）
  final String? loadingLabel;

  /// 前置图标（可选）
  final IconData? icon;

  const ConversionPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton.filled(
        onPressed: loading ? null : onPressed,
        child: loading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CupertinoActivityIndicator(
                    color: CupertinoColors.white,
                  ),
                  if (loadingLabel != null) ...[
                    const SizedBox(width: 8),
                    Text(loadingLabel!),
                  ],
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

/// ConversionEmptyState 统一空态（居中图标 + 文案）。
class ConversionEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const ConversionEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 60,
            color: CupertinoColors.systemGrey2.resolveFrom(context),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: AppTextStyles.secondary(context),
          ),
        ],
      ),
    );
  }
}

/// ConversionRecordCard 统一记录卡片。
///
/// 参数化以适配不同 feature 的记录模型：标题、副标题、时间、操作按钮列表。
class ConversionRecordCard extends StatelessWidget {
  /// 主标题（如源文件名）
  final String title;

  /// 副标题（如 → xxx.pdf / N 张图片 · 大小）
  final String subtitle;

  /// 时间文本
  final String time;

  /// 操作按钮（使用 [ConversionRecordActions] 构造）
  final List<Widget> actions;

  const ConversionRecordCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: conversionCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.body(context)
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(time, style: AppTextStyles.caption(context)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTextStyles.secondary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: actions),
          ],
        ],
      ),
    );
  }
}

/// ConversionRecordActions 记录卡操作按钮工厂（统一样式）。
class ConversionRecordActions {
  ConversionRecordActions._();

  /// 主要文字按钮（如「打开 / 查看 / 加入书架」），默认使用主题主色，占据剩余空间。
  static Widget primary({
    required BuildContext context,
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
  }) {
    final color = CupertinoTheme.of(context).primaryColor;
    return Expanded(
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.secondary(context).copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 成功态标签（如「已加入书架」，不可点击）。
  static Widget successBadge({
    required BuildContext context,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGreen.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.checkmark_alt,
              size: 16,
              color: CupertinoColors.systemGreen,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.secondary(context).copyWith(
                  color: CupertinoColors.systemGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 危险图标按钮（如「删除」）。
  static Widget danger({
    required BuildContext context,
    required VoidCallback onPressed,
    IconData icon = CupertinoIcons.trash,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      minSize: 0,
      onPressed: onPressed,
      child: Icon(icon, size: 20, color: CupertinoColors.systemRed),
    );
  }

  /// 按钮之间的间隔
  static const Widget gap = SizedBox(width: 8);
}

/// ConversionFormat 转换页通用格式化工具（时间 / 文件大小）。
class ConversionFormat {
  ConversionFormat._();

  /// 将毫秒时间戳格式化为 `YYYY-MM-DD HH:mm`。
  static String timestamp(int ms) {
    return dateTime(DateTime.fromMillisecondsSinceEpoch(ms));
  }

  /// 将 [DateTime] 格式化为 `YYYY-MM-DD HH:mm`。
  static String dateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  /// 将字节数格式化为易读的文件大小。
  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// 统一的跨端文件打开逻辑（Android / iOS / iPad / 桌面均通过 open_filex）。
///
/// 修复了旧版移动端「只弹提示、不真正打开」的 BUG：
/// - 先校验文件存在；不存在时通过 [onMessage] 回传本地化提示；
/// - 调用系统默认应用打开；失败时弹出本地化错误弹窗。
Future<void> openConversionFile(
  BuildContext context,
  String filePath, {
  ValueChanged<String>? onMessage,
}) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) {
      onMessage?.call(LocalizationEngine.text('conv_file_not_found'));
      return;
    }
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done && context.mounted) {
      _showOpenError(context, result.message);
    }
  } catch (e) {
    if (context.mounted) {
      _showOpenError(context, e.toString());
    }
  }
}

void _showOpenError(BuildContext context, String detail) {
  showCupertinoDialog(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(LocalizationEngine.text('conv_open_failed')),
      content: Text(detail),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(LocalizationEngine.text('conv_cancel')),
        ),
      ],
    ),
  );
}

/// 统一的删除确认弹窗，返回用户是否确认删除。
Future<bool> confirmConversionDelete(BuildContext context) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(LocalizationEngine.text('conv_delete_confirm_title')),
      content: Text(LocalizationEngine.text('conv_delete_confirm_msg')),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(LocalizationEngine.text('conv_cancel')),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(LocalizationEngine.text('conv_delete')),
        ),
      ],
    ),
  );
  return result ?? false;
}
