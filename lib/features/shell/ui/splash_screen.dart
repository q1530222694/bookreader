import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../../../shared/ui/app_text_styles.dart';

/// SplashScreen 是真正消费「启动页设置」的启动屏。
///
/// 行为完全由 [SettingsEngine] 中的配置驱动：
/// - 内容类型（[SettingsEngine.startupSplashType]）：不显示 / 文字 / 图片；
/// - 文字（[SettingsEngine.startupSplashText]）、图片路径（[SettingsEngine.startupSplashImagePath]）；
/// - 显示时长（[SettingsEngine.startupSplashDuration]）：>0 倒计时后自动进入，<=0 永久等待手动进入；
/// - 进入方式（[SettingsEngine.startupSplashEntryMode]）：自动（点跳过按钮）或点击（点屏幕任意处）。
///
/// 启动完成后调用 [Navigator.pop] 关闭本屏，露出底层已按 [SettingsEngine.startupPage]
/// 定位到对应标签的 Tab 容器。UI 颜色全部取自主题，无硬编码。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final int _duration;
  late final String _entryMode;
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _duration = SettingsEngine.startupSplashDuration;
    _entryMode = SettingsEngine.startupSplashEntryMode;
    _remaining = _duration > 0 ? _duration : 0;

    // 内容类型设为「不显示」时，本屏不应被压入栈；即便被压入也立即关闭。
    final type = SettingsEngine.startupSplashType;
    if (type == SettingsEngine.startupSplashTypeNone) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
      return;
    }

    // 仅在有时长限制时启动倒计时；归零自动进入。
    if (_duration > 0) {
      _startCountdown();
    }
  }

  /// 启动每秒倒计时，归零后自动进入应用。
  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _remaining -= 1);
      if (_remaining <= 0) {
        timer.cancel();
        _finish();
      }
    });
  }

  /// 关闭启动屏，露出底层 Tab 容器（已在 [ShellController] 构造时按启动页定位）。
  void _finish() {
    _timer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final darkColor = HSLColor.fromColor(primaryColor)
        .withLightness(0.25)
        .toColor();

    final type = SettingsEngine.startupSplashType;
    final text = SettingsEngine.startupSplashText;
    final imagePath = SettingsEngine.startupSplashImagePath;

    // 背景：图片类型且路径有效时用用户图片，否则用主题渐变兜底。
    final DecorationImage? bgImage =
        type == SettingsEngine.startupSplashTypeImage
            ? _buildDecorationImage(imagePath)
            : null;

    final bool showText =
        type == SettingsEngine.startupSplashTypeText || text.isNotEmpty;

    final String pillText = _buildPillText();
    final bool tapAnywhere = _entryMode == SettingsEngine.startupSplashEntryModeTap;

    final content = Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, darkColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              image: bgImage,
            ),
            child: Container(
              // 半透明黑层，保证文字/按钮在图片或渐变上都清晰可读。
              color: CupertinoColors.black.withValues(alpha: 0.16),
            ),
          ),
        ),
        if (showText)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                text.isNotEmpty
                    ? text
                    : LocalizationEngine.text('splash_preview_title'),
                textAlign: TextAlign.center,
                style: AppTextStyles.pageTitle(context)
                    .copyWith(color: CupertinoColors.white),
              ),
            ),
          ),
        // 底部进入/跳过按钮
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 36),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _finish,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: CupertinoColors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pillText,
                  style: AppTextStyles.caption(context)
                      .copyWith(color: CupertinoColors.black),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    // 「点击」进入方式：整屏可点击立即进入；「自动」方式仅按钮可点。
    return GestureDetector(
      onTap: tapAnywhere ? _finish : null,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: CupertinoColors.black, // 兜底底色，避免图片加载前白屏
        child: content,
      ),
    );
  }

  /// 依据进入方式与剩余秒数生成按钮文案。
  String _buildPillText() {
    if (_entryMode == SettingsEngine.startupSplashEntryModeTap) {
      if (_remaining > 0) {
        return LocalizationEngine.text('splash_tap_countdown')
            .replaceAll('%d', '$_remaining');
      }
      return LocalizationEngine.text('splash_tap_enter_now');
    }
    if (_remaining > 0) {
      return LocalizationEngine.text('splash_auto_countdown')
          .replaceAll('%d', '$_remaining');
    }
    return LocalizationEngine.text('splash_skip_now');
  }

  /// 依据图片路径构建装饰图（本地文件或网络 URL）。
  DecorationImage? _buildDecorationImage(String path) {
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
