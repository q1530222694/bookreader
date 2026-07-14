import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../../../shared/ui/app_text_styles.dart';
import '../controller/settings_controller.dart';

/// SplashSettingsPage 提供「启动页设置」的完整配置 UI。
///
/// 与旧版仅配置了 UI 不同，本页现在已接通实际逻辑：
/// - 内容类型（不显示 / 文字 / 图片）写入 [SettingsEngine.startupSplashType]；
/// - 图片卡片可选取本地图片并实时预览，文字卡片可弹窗编辑；
/// - 显示时长写入 [SettingsEngine.startupSplashDuration]；
/// - 进入方式（自动 / 点击）写入 [SettingsEngine.startupSplashEntryMode]；
/// - 启动后跳转页面写入 [SettingsEngine.startupPage]，启动屏 [SplashScreen] 会据此定位首页标签。
class SplashSettingsPage extends StatelessWidget {
  const SplashSettingsPage({super.key});

  /// 选取本地图片并持久化到启动屏图片路径。
  ///
  /// 先按平台申请相册/存储权限，再用 [FilePicker] 选择单张图片；
  /// 选择成功则写入 [SettingsController.setStartupSplashImagePath]，失败给出提示。
  Future<void> _pickImage(BuildContext context) async {
    try {
      // 按平台申请相册/存储权限（Android 13+ 用 photos，旧版用 storage；iOS 用 photos）。
      if (Platform.isAndroid) {
        final photos = await Permission.photos.request();
        if (!photos.isGranted) {
          final storage = await Permission.storage.request();
          if (!storage.isGranted) {
            if (context.mounted) _showDenied(context);
            return;
          }
        }
      } else if (Platform.isIOS) {
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          if (context.mounted) _showDenied(context);
          return;
        }
      }

      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final path = result.files.first.path;
      if (path == null || path.isEmpty) {
        if (context.mounted) _showPickFailed(context);
        return;
      }
      // 真实写入配置，预览与启动屏会立即响应。
      SettingsController.setStartupSplashImagePath(path);
    } catch (e) {
      if (context.mounted) _showPickFailed(context);
    }
  }

  /// 弹出授权失败提示。
  void _showDenied(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(LocalizationEngine.text('splash_permission_denied')),
        actions: [
          CupertinoDialogAction(
            child: Text(LocalizationEngine.text('done')),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// 弹出图片选择失败提示。
  void _showPickFailed(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(LocalizationEngine.text('splash_image_failed')),
        actions: [
          CupertinoDialogAction(
            child: Text(LocalizationEngine.text('done')),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// 弹出文字编辑对话框，保存后写入 [SettingsController.setStartupSplashText]。
  void _editText(BuildContext context) {
    final controller = TextEditingController(text: SettingsEngine.startupSplashText);
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(LocalizationEngine.text('splash_edit_text')),
        content: CupertinoTextField(
          controller: controller,
          placeholder: LocalizationEngine.text('splash_text_placeholder'),
          maxLines: 3,
          textInputAction: TextInputAction.done,
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(LocalizationEngine.text('conv_cancel')),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            child: Text(LocalizationEngine.text('splash_save')),
            onPressed: () {
              SettingsController.setStartupSplashText(controller.text.trim());
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  /// 弹出底部动作面板，选择启动后打开的目标页面。
  void _selectStartupPage(BuildContext context) {
    final options = <(String, String)>[
      (SettingsEngine.startupPageNone, 'startup_page_none'),
      (SettingsEngine.startupPageHome, 'startup_page_home'),
      (SettingsEngine.startupPageBookshelf, 'startup_page_bookshelf'),
      (SettingsEngine.startupPageMemory, 'startup_page_memory'),
      (SettingsEngine.startupPageTools, 'startup_page_tools'),
      (SettingsEngine.startupPageProfile, 'startup_page_profile'),
    ];
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(LocalizationEngine.text('splash_jump_select')),
        actions: options
            .map(
              (o) => CupertinoActionSheetAction(
                child: Text(LocalizationEngine.text(o.$2)),
                onPressed: () {
                  SettingsController.setStartupPage(o.$1);
                  Navigator.of(context).pop();
                },
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          child: Text(LocalizationEngine.text('conv_cancel')),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemBackground.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          LocalizationEngine.text('splash_settings'),
          style: AppTextStyles.pageTitle(context),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ValueListenableBuilder<String>(
            valueListenable: SettingsController.startupSplashType,
            builder: (context, splashType, _) {
              return ValueListenableBuilder<int>(
                valueListenable: SettingsController.startupSplashDuration,
                builder: (context, duration, _) {
                  return ValueListenableBuilder<String>(
                    valueListenable: SettingsController.startupPage,
                    builder: (context, startupPage, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PreviewCard(
                            splashType: splashType,
                            duration: duration,
                            startupPage: startupPage,
                          ),
                          const SizedBox(height: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocalizationEngine.text('splash_content_type'),
                                style: AppTextStyles.sectionTitle(context),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _OptionTile(
                                      icon: null,
                                      label: LocalizationEngine.text('startup_content_none'),
                                      selected: splashType == SettingsEngine.startupSplashTypeNone,
                                      onTap: () => SettingsController.setStartupSplashType(
                                        SettingsEngine.startupSplashTypeNone,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _OptionTile(
                                      icon: CupertinoIcons.photo,
                                      label: LocalizationEngine.text('startup_content_image'),
                                      selected: splashType == SettingsEngine.startupSplashTypeImage,
                                      onTap: () => SettingsController.setStartupSplashType(
                                        SettingsEngine.startupSplashTypeImage,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _OptionTile(
                                      icon: CupertinoIcons.textformat,
                                      label: LocalizationEngine.text('startup_content_text'),
                                      selected: splashType == SettingsEngine.startupSplashTypeText,
                                      onTap: () => SettingsController.setStartupSplashType(
                                        SettingsEngine.startupSplashTypeText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // 图片 / 文字 设置卡片（现在可点击并实时预览）
                          ValueListenableBuilder<String>(
                            valueListenable: SettingsController.startupSplashImagePath,
                            builder: (context, imagePath, _) {
                              final hasImage = _isValidImagePath(imagePath);
                              return Row(
                                children: [
                                  Expanded(
                                    child: _SettingOptionCard(
                                      title: LocalizationEngine.text('splash_text_settings_left'),
                                      primaryText: hasImage
                                          ? _fileName(imagePath)
                                          : LocalizationEngine.text('splash_image_empty'),
                                      secondaryText: LocalizationEngine.text('splash_change_image'),
                                      leading: hasImage
                                          ? _imageThumb(imagePath)
                                          : Icon(
                                              CupertinoIcons.photo,
                                              color: CupertinoColors.white,
                                              size: 18,
                                            ),
                                      onTap: () => _pickImage(context),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ValueListenableBuilder<String>(
                                      valueListenable: SettingsController.startupSplashText,
                                      builder: (context, splashText, _) {
                                        return _SettingOptionCard(
                                          title: LocalizationEngine.text('splash_text_settings_right'),
                                          primaryText: splashText.isNotEmpty
                                              ? splashText
                                              : LocalizationEngine.text('splash_text_empty'),
                                          secondaryText: LocalizationEngine.text('splash_change_text'),
                                          useLetterBadge: true,
                                          onTap: () => _editText(context),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocalizationEngine.text('splash_display_duration'),
                                style: AppTextStyles.sectionTitle(context),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _OptionTile(
                                      icon: CupertinoIcons.clock,
                                      label: LocalizationEngine.text('splash_duration_1s'),
                                      selected: duration == 1,
                                      onTap: () => SettingsController.setStartupSplashDuration(1),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _OptionTile(
                                      icon: CupertinoIcons.check_mark_circled_solid,
                                      label: LocalizationEngine.text('splash_duration_3s'),
                                      selected: duration == 3,
                                      onTap: () => SettingsController.setStartupSplashDuration(3),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _OptionTile(
                                      icon: CupertinoIcons.clock,
                                      label: LocalizationEngine.text('splash_duration_5s'),
                                      selected: duration == 5,
                                      onTap: () => SettingsController.setStartupSplashDuration(5),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _OptionTile(
                                      icon: CupertinoIcons.settings,
                                      label: LocalizationEngine.text('splash_duration_always'),
                                      selected: duration <= 0,
                                      onTap: () => SettingsController.setStartupSplashDuration(0),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // 进入方式（自动 / 点击）—— 绑定真实配置状态
                          ValueListenableBuilder<String>(
                            valueListenable: SettingsController.startupSplashEntryMode,
                            builder: (context, entryMode, _) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    LocalizationEngine.text('splash_entry_mode'),
                                    style: AppTextStyles.sectionTitle(context),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _OptionTile(
                                          icon: CupertinoIcons.bolt_fill,
                                          label: LocalizationEngine.text('splash_auto_home'),
                                          selected: entryMode == SettingsEngine.startupSplashEntryModeAuto,
                                          showCheck: entryMode == SettingsEngine.startupSplashEntryModeAuto,
                                          onTap: () => SettingsController.setStartupSplashEntryMode(
                                            SettingsEngine.startupSplashEntryModeAuto,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _OptionTile(
                                          icon: CupertinoIcons.hand_draw,
                                          label: LocalizationEngine.text('splash_wait_click'),
                                          selected: entryMode == SettingsEngine.startupSplashEntryModeTap,
                                          showCheck: entryMode == SettingsEngine.startupSplashEntryModeTap,
                                          onTap: () => SettingsController.setStartupSplashEntryMode(
                                            SettingsEngine.startupSplashEntryModeTap,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocalizationEngine.text('splash_jump_page'),
                                style: AppTextStyles.sectionTitle(context),
                              ),
                              const SizedBox(height: 10),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => _selectStartupPage(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: CupertinoColors.separator.resolveFrom(context),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _startupPageLabel(startupPage, context),
                                          style: AppTextStyles.body(context),
                                        ),
                                      ),
                                      const Icon(CupertinoIcons.right_chevron),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// 判断路径是否为可加载的图片（本地文件存在或网络 URL）。
  bool _isValidImagePath(String path) {
    if (path.isEmpty) return false;
    if (path.startsWith('http://') || path.startsWith('https://')) return true;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// 取文件名的展示文本（网络 URL 取最后一段）。
  String _fileName(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final seg = Uri.parse(path).pathSegments;
      return seg.isNotEmpty ? seg.last : path;
    }
    return path.split(Platform.pathSeparator).last;
  }

  /// 构建图片缩略图（用于设置卡片与预览）。
  Widget _imageThumb(String path) {
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    final image = isNetwork
        ? Image.network(
            path,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const Icon(
              CupertinoIcons.photo,
              color: CupertinoColors.white,
              size: 18,
            ),
          )
        : Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const Icon(
              CupertinoIcons.photo,
              color: CupertinoColors.white,
              size: 18,
            ),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: 42, height: 42, child: image),
    );
  }

  String _startupPageLabel(String startupPage, BuildContext context) {
    switch (startupPage) {
      case SettingsEngine.startupPageHome:
        return LocalizationEngine.text('startup_page_home');
      case SettingsEngine.startupPageBookshelf:
        return LocalizationEngine.text('startup_page_bookshelf');
      case SettingsEngine.startupPageMemory:
        return LocalizationEngine.text('startup_page_memory');
      case SettingsEngine.startupPageTools:
        return LocalizationEngine.text('startup_page_tools');
      case SettingsEngine.startupPageProfile:
        return LocalizationEngine.text('startup_page_profile');
      case SettingsEngine.startupPageNone:
      default:
        return LocalizationEngine.text('startup_page_none');
    }
  }
}

/// 启动页预览卡片：真实反映当前配置（不显示 / 文字 / 图片）。
class _PreviewCard extends StatelessWidget {
  final String splashType;
  final int duration;
  final String startupPage;

  const _PreviewCard({
    required this.splashType,
    required this.duration,
    required this.startupPage,
  });

  @override
  Widget build(BuildContext context) {
    // 由主题主色派生深色，避免使用硬编码渐变色。
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final darkColor = HSLColor.fromColor(primaryColor)
        .withLightness(0.25)
        .toColor();

    // 不显示：直接展示提示占位卡。
    if (splashType == SettingsEngine.startupSplashTypeNone) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          border: Border.all(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 1,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              LocalizationEngine.text('splash_preview_none'),
              textAlign: TextAlign.center,
              style: AppTextStyles.secondary(context),
            ),
          ),
        ),
      );
    }

    // 图片 / 文字类型统一用渐变背景承载，图片类型可叠加用户图片。
    final DecorationImage? bgImage = splashType == SettingsEngine.startupSplashTypeImage
        ? _buildDecorationImage()
        : null;

    return ValueListenableBuilder<String>(
      valueListenable: SettingsController.startupSplashText,
      builder: (context, splashText, _) {
        final showText = splashType == SettingsEngine.startupSplashTypeText ||
            splashText.isNotEmpty;
        return Container(
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [primaryColor, darkColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            image: bgImage,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: CupertinoColors.black.withValues(alpha: 0.16),
                  ),
                ),
              ),
              if (showText)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      splashText.isNotEmpty
                          ? splashText
                          : LocalizationEngine.text('splash_preview_title'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.pageTitle(context).copyWith(
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      LocalizationEngine.text('splash_skip_now'),
                      style: AppTextStyles.caption(context)
                          .copyWith(color: CupertinoColors.black),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 依据当前图片路径构建装饰图（本地文件或网络 URL）。
  DecorationImage? _buildDecorationImage() {
    final path = SettingsController.startupSplashImagePath.value;
    if (path.isEmpty) return null;
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    try {
      if (!isNetwork && !File(path).existsSync()) return null;
    } catch (_) {
      return null;
    }
    final ImageProvider image =
        isNetwork ? NetworkImage(path) : FileImage(File(path));
    return DecorationImage(image: image, fit: BoxFit.cover);
  }
}

/// 图片 / 文字设置卡片：显示当前值（缩略图或文字），点击触发对应操作。
class _SettingOptionCard extends StatelessWidget {
  final String title;
  final String primaryText;
  final String secondaryText;
  final Widget? leading;
  final bool useLetterBadge;
  final VoidCallback? onTap;

  const _SettingOptionCard({
    required this.title,
    required this.primaryText,
    required this.secondaryText,
    this.leading,
    this.useLetterBadge = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = CupertinoColors.separator.resolveFrom(context);
    final innerBoxColor = CupertinoColors.tertiarySystemFill.resolveFrom(context);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.body(context).copyWith(
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: innerBoxColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: CupertinoTheme.of(context).primaryColor,
                  ),
                  alignment: Alignment.center,
                  child: leading ??
                      (useLetterBadge
                          ? Text(
                              'Aa',
                              style: AppTextStyles.body(context).copyWith(
                                color: CupertinoColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : Icon(
                              CupertinoIcons.photo,
                              color: CupertinoColors.white,
                              size: 18,
                            )),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        primaryText,
                        style: AppTextStyles.secondary(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        secondaryText,
                        style: AppTextStyles.caption(context),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.right_chevron,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 通用选项块（内容类型 / 时长 / 进入方式）。
class _OptionTile extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool selected;
  final bool showCheck;
  final VoidCallback? onTap;

  const _OptionTile({
    this.icon,
    required this.label,
    required this.selected,
    this.showCheck = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? CupertinoTheme.of(context).primaryColor
        : CupertinoColors.separator.resolveFrom(context);
    final fillColor = selected
        ? CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.10)
        : CupertinoColors.secondarySystemBackground.resolveFrom(context);
    final iconColor = selected
        ? CupertinoTheme.of(context).primaryColor
        : CupertinoColors.label.resolveFrom(context);

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 1.2 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, size: 16, color: iconColor)
            else
              const SizedBox.shrink(),
            if (icon != null) const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.secondary(context).copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (showCheck)
              Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: CupertinoTheme.of(context).primaryColor,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}
