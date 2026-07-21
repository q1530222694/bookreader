import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../shared/ui/app_text_styles.dart';
import '../controller/data_manager_controller.dart';
import '../model/cloud_drive_config.dart';
import '../service/backup_service.dart';

/// 数据管理页：导出/导入阅读数据，以及配置个人云盘/NAS 后一键同步。
class DataManagerPage extends StatefulWidget {
  const DataManagerPage({super.key});

  @override
  State<DataManagerPage> createState() => _DataManagerPageState();
}

class _DataManagerPageState extends State<DataManagerPage> {
  final DataManagerController _controller = DataManagerController();

  String _t(String key) => LocalizationEngine.text(key);

  /// 弹出不可取消的加载框，返回用于关闭的回调。
  VoidCallback _showLoading() {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        content: Row(
          children: [
            const CupertinoActivityIndicator(),
            const SizedBox(width: 12),
            Text(_t('data_manager_working')),
          ],
        ),
      ),
    );
    return () {
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) nav.pop();
    };
  }

  Future<void> _export() async {
    final dismiss = _showLoading();
    try {
      final path = await _controller.exportData();
      dismiss();
      if (path != null) {
        _showResult(true, _t('data_manager_export_success'), detail: path);
      }
    } catch (e) {
      dismiss();
      _showResult(false, _t('data_manager_export_fail'), detail: e.toString());
    }
  }

  Future<void> _import() async {
    final confirmed = await _confirm(
      _t('data_manager_import'),
      _t('data_manager_import_confirm'),
    );
    if (!confirmed) return;
    final dismiss = _showLoading();
    try {
      final backup = await _controller.importData();
      dismiss();
      _showResult(
        true,
        _t('data_manager_import_success'),
        detail: '${backup.books.length} ${_t('data_manager_books_count')}'
            ' · ${backup.sessions.length} ${_t('data_manager_sessions_count')}',
      );
    } on BackupUserCancelException {
      dismiss();
      // 用户取消选择，静默忽略。
    } catch (e) {
      dismiss();
      _showResult(false, _t('data_manager_import_fail'), detail: e.toString());
    }
  }

  Future<void> _sync() async {
    // 同步门禁：必须先配置至少一个云盘。
    if (!_controller.canSync) {
      _showResult(false, _t('data_manager_no_drive'));
      return;
    }
    // 进度对话框（带百分比，不可取消），多盘顺序同步时实时反映完成比例。
    final progress = ValueNotifier<double>(0);
    _showSyncProgress(progress);
    try {
      final results = await _controller.syncNow(
        onProgress: (p) => progress.value = p,
      );
      progress.value = 1;
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (results.isEmpty) {
        _showResult(false, _t('data_manager_sync_not_supported'));
        return;
      }
      final okCount = results.where((r) => r.success).length;
      // 逐盘结果汇总（单盘失败单独列出，不掩盖其余盘成功）。
      final detail = results.map((r) {
        final status =
            r.success ? _t('data_manager_drive_ok') : _t('data_manager_drive_fail');
        final err = (r.error?.isNotEmpty == true) ? '：${r.error}' : '';
        return '${r.drive.name} · $status$err';
      }).join('\n');
      if (okCount == results.length) {
        _showResult(true, _t('data_manager_sync_success'), detail: detail);
      } else {
        _showResult(false, _t('data_manager_sync_fail'), detail: detail);
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showResult(false, _t('data_manager_sync_fail'), detail: e.toString());
    }
  }

  /// 同步进度对话框：旋转指示器 + 实时百分比，不可取消（同步中途打断会致云盘半写入）。
  void _showSyncProgress(ValueNotifier<double> progress) {
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const CupertinoActivityIndicator(),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_t('data_manager_sync_in_progress')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (_, p, __) => Text('${(p * 100).round()}%'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDriveEditor([CloudDriveConfig? config]) async {
    await Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => _CloudDriveEditPage(initial: config)),
    );
    if (mounted) setState(() {}); // 返回后刷新云盘列表。
  }

  Future<void> _deleteDrive(CloudDriveConfig config) async {
    final confirmed = await _confirm(_t('data_manager_delete'), config.name);
    if (!confirmed) return;
    _controller.deleteDrive(config.id);
    setState(() {});
    _showResult(true, _t('data_manager_drive_deleted'));
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(_t('cancel')),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(_t('ok')),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showResult(bool success, String title, {String? detail}) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: detail == null ? null : Text(detail),
        actions: [
          CupertinoDialogAction(
            child: Text(_t('ok')),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemBackground.resolveFrom(context);
    final drives = _controller.drives;

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_t('data_manager'), style: AppTextStyles.navTitle(context)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 区块一：阅读数据 导入/导出
            Text(_t('data_manager'), style: AppTextStyles.sectionTitle(context)),
            const SizedBox(height: 12),
            _ActionRow(
              icon: CupertinoIcons.download_circle,
              label: _t('data_manager_export'),
              description: _t('data_manager_export_desc'),
              onTap: _export,
            ),
            const SizedBox(height: 10),
            _ActionRow(
              icon: CupertinoIcons.upload_circle,
              label: _t('data_manager_import'),
              description: _t('data_manager_import_desc'),
              onTap: _import,
            ),

            // 区块二：云盘同步
            const SizedBox(height: 24),
            Text(
              _t('data_manager_cloud_sync'),
              style: AppTextStyles.sectionTitle(context),
            ),
            const SizedBox(height: 8),
            Text(
              _t('data_manager_cloud_sync_desc'),
              style: AppTextStyles.secondary(context),
            ),
            const SizedBox(height: 12),

            // 已配置云盘列表
            ...drives.map((d) => _DriveRow(
                  config: d,
                  onTap: () => _openDriveEditor(d),
                  onDelete: () => _deleteDrive(d),
                )),
            if (drives.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _t('data_manager_no_drive_hint'),
                  style: AppTextStyles.caption(context),
                ),
              ),

            const SizedBox(height: 10),
            _ActionRow(
              icon: CupertinoIcons.plus_circle,
              label: _t('data_manager_add_drive'),
              description: '',
              onTap: () => _openDriveEditor(),
            ),
            const SizedBox(height: 10),

            // 立即同步按钮（门禁：需已配置云盘）
            CupertinoButton.filled(
              onPressed: _controller.canSync
                  ? () {
                      _sync();
                    }
                  : null,
              child: Text(_t('data_manager_sync_now')),
            ),
            if (!_controller.canSync)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _t('data_manager_sync_gate_hint'),
                  style: AppTextStyles.caption(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 通用操作行：图标 + 标题 + 描述 + 右箭头，点击触发 [onTap]。
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = CupertinoTheme.of(context).scaffoldBackgroundColor;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: CupertinoColors.separator.resolveFrom(context),
          ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.menuItem(context)),
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        description,
                        style: AppTextStyles.caption(context),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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

/// 云盘列表行：名称 + 类型标签 + 编辑入口 + 删除按钮。
class _DriveRow extends StatelessWidget {
  final CloudDriveConfig config;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DriveRow({
    required this.config,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = CupertinoTheme.of(context).scaffoldBackgroundColor;
    final typeLabel = config.type == CloudDriveConfig.typeWebdav
        ? LocalizationEngine.text('data_manager_drive_type_webdav')
        : LocalizationEngine.text('data_manager_drive_type_other');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(config.name, style: AppTextStyles.menuItem(context)),
                  const SizedBox(height: 4),
                  Text(
                    typeLabel,
                    style: AppTextStyles.caption(context),
                  ),
                ],
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: onTap,
            child: Icon(
              CupertinoIcons.pencil,
              size: 18,
              color: CupertinoTheme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: onDelete,
            child: Icon(
              CupertinoIcons.delete,
              size: 18,
              color: CupertinoColors.destructiveRed.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// 云盘配置编辑页（新增或编辑）。保存经 [DataManagerController] 落盘。
class _CloudDriveEditPage extends StatefulWidget {
  final CloudDriveConfig? initial;

  const _CloudDriveEditPage({this.initial});

  @override
  State<_CloudDriveEditPage> createState() => _CloudDriveEditPageState();
}

class _CloudDriveEditPageState extends State<_CloudDriveEditPage> {
  final DataManagerController _controller = DataManagerController();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _pathCtrl;
  late String _type;

  String _t(String key) => LocalizationEngine.text(key);

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _nameCtrl = TextEditingController(text: i?.name ?? '');
    _urlCtrl = TextEditingController(text: i?.url ?? '');
    _userCtrl = TextEditingController(text: i?.username ?? '');
    _passCtrl = TextEditingController(text: i?.password ?? '');
    _pathCtrl = TextEditingController(text: i?.remotePath ?? '');
    _type = i?.type ?? CloudDriveConfig.typeWebdav;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _pathCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showError(_t('data_manager_drive_name_required'));
      return;
    }
    final config = CloudDriveConfig(
      id: widget.initial?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      type: _type,
      url: _urlCtrl.text.trim(),
      username: _userCtrl.text.trim(),
      password: _passCtrl.text,
      remotePath: _pathCtrl.text.trim(),
    );
    _controller.saveDrive(config);
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(_t('data_manager_tip')),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(_t('ok')),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          isEditing
              ? _t('data_manager_edit_drive')
              : _t('data_manager_add_drive'),
          style: AppTextStyles.navTitle(context),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: Text(_t('data_manager_save')),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _EditField(
              label: _t('data_manager_drive_name'),
              controller: _nameCtrl,
              placeholder: _t('data_manager_drive_name_ph'),
            ),
            const SizedBox(height: 16),
            Text(_t('data_manager_drive_type'),
                style: AppTextStyles.secondary(context)),
            const SizedBox(height: 8),
            CupertinoSlidingSegmentedControl<String>(
              groupValue: _type,
              children: {
                CloudDriveConfig.typeWebdav:
                    Text(_t('data_manager_drive_type_webdav')),
                CloudDriveConfig.typeOther:
                    Text(_t('data_manager_drive_type_other')),
              },
              onValueChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 16),
            _EditField(
              label: _t('data_manager_drive_url'),
              controller: _urlCtrl,
              placeholder: _t('data_manager_drive_url_ph'),
            ),
            const SizedBox(height: 16),
            _EditField(
              label: _t('data_manager_drive_user'),
              controller: _userCtrl,
              placeholder: _t('data_manager_drive_user_ph'),
            ),
            const SizedBox(height: 16),
            _EditField(
              label: _t('data_manager_drive_pass'),
              controller: _passCtrl,
              placeholder: _t('data_manager_drive_pass_ph'),
              obscure: true,
            ),
            const SizedBox(height: 16),
            _EditField(
              label: _t('data_manager_drive_path'),
              controller: _pathCtrl,
              placeholder: _t('data_manager_drive_path_ph'),
            ),
            if (isEditing)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: CupertinoButton(
                  color: CupertinoColors.destructiveRed
                      .resolveFrom(context)
                      .withOpacity(0.12),
                  onPressed: () {
                    _controller.deleteDrive(widget.initial!.id);
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    _t('data_manager_delete'),
                    style: TextStyle(
                      color: CupertinoColors.destructiveRed
                          .resolveFrom(context),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 编辑页单行字段：标签 + [CupertinoTextField]。
class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String placeholder;
  final bool obscure;

  const _EditField({
    required this.label,
    required this.controller,
    required this.placeholder,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.secondary(context)),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          obscureText: obscure,
          style: AppTextStyles.body(context),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }
}
