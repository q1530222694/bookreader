import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../shared/ui/app_text_styles.dart';

/// 自定义取色弹层（纯展示 Dumb UI）。
///
/// [initialColor] 预填颜色，[initialName] 预填名称；用户点「保存」后通过
/// [onConfirm] 回传最终颜色与名称。所有颜色走主题/系统色，文案走 [LocalizationEngine]。
Future<void> showCustomColorPicker({
  required BuildContext context,
  required Color initialColor,
  String? initialName,
  required Future<void> Function(Color color, String name) onConfirm,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (popupContext) {
      return _CustomColorPickerContent(
        initialColor: initialColor,
        initialName: initialName,
        onConfirm: onConfirm,
      );
    },
  );
}

class _CustomColorPickerContent extends StatefulWidget {
  final Color initialColor;
  final String? initialName;
  final Future<void> Function(Color color, String name) onConfirm;

  const _CustomColorPickerContent({
    required this.initialColor,
    this.initialName,
    required this.onConfirm,
  });

  @override
  State<_CustomColorPickerContent> createState() =>
      _CustomColorPickerContentState();
}

class _CustomColorPickerContentState extends State<_CustomColorPickerContent> {
  late Color _currentColor;
  late TextEditingController _nameController;
  late int _r;
  late int _g;
  late int _b;
  bool _saving = false;

  // 常用调色板，供快速选取；颜色本身即数据，可硬编码色值。
  static const List<Color> _palette = [
    Color(0xFFE57373),
    Color(0xFFF06292),
    Color(0xFFBA68C8),
    Color(0xFF9575CD),
    Color(0xFF7986CB),
    Color(0xFF64B5F6),
    Color(0xFF4FC3F7),
    Color(0xFF4DD0E1),
    Color(0xFF4DB6AC),
    Color(0xFF81C784),
    Color(0xFFAED581),
    Color(0xFFFFF176),
    Color(0xFFFFD54F),
    Color(0xFFFFB74D),
    Color(0xFFFF8A65),
    Color(0xFFA1887F),
  ];

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _r = (_currentColor.r * 255).round();
    _g = (_currentColor.g * 255).round();
    _b = (_currentColor.b * 255).round();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 由 RGB 滑杆数值合成新颜色并刷新预览。
  void _syncFromRgb() {
    setState(() {
      _currentColor = Color.fromRGBO(_r, _g, _b, 1);
    });
  }

  /// 由调色板色块更新颜色及对应的 RGB 滑杆位置。
  void _applyPalette(Color color) {
    setState(() {
      _currentColor = color;
      _r = (color.r * 255).round();
      _g = (color.g * 255).round();
      _b = (color.b * 255).round();
    });
  }

  Future<void> _confirm(BuildContext popupContext) async {
    if (_saving) return;
    setState(() => _saving = true);
    // 提前捕获 NavigatorState，避免跨异步间隙使用 BuildContext。
    final navigator = Navigator.of(popupContext);
    await widget.onConfirm(_currentColor, _nameController.text.trim());
    if (mounted) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        CupertinoColors.secondarySystemBackground.resolveFrom(context);
    final borderColor = CupertinoColors.separator.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  LocalizationEngine.text('custom_color_pick'),
                  style: AppTextStyles.pageTitle(context),
                ),
              ),
              const SizedBox(height: 16),
              // 实时预览 + 名称输入
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _currentColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoTextField(
                      controller: _nameController,
                      placeholder: LocalizationEngine.text('custom_color_name'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.tertiarySystemFill
                            .resolveFrom(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      style: AppTextStyles.body(context)
                          .copyWith(color: labelColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                LocalizationEngine.text('custom_color_palette'),
                style: AppTextStyles.sectionTitle(context),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _palette.map((color) {
                  final selected = _currentColor.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () => _applyPalette(color),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? primaryColor : borderColor,
                          width: selected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              _buildSlider(context, 'R', _r, (v) {
                _r = v;
                _syncFromRgb();
              }),
              _buildSlider(context, 'G', _g, (v) {
                _g = v;
                _syncFromRgb();
              }),
              _buildSlider(context, 'B', _b, (v) {
                _b = v;
                _syncFromRgb();
              }),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        LocalizationEngine.text('cancel'),
                        style: AppTextStyles.body(context)
                            .copyWith(color: labelColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoButton.filled(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: _saving
                          ? null
                          : () => _confirm(context),
                      child: Text(LocalizationEngine.text('save')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建单条 RGB 滑杆（R/G/B + 数值标签）。
  Widget _buildSlider(
    BuildContext context,
    String label,
    int value,
    void Function(int) onChanged,
  ) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Text(
              label,
              style: AppTextStyles.body(context).copyWith(
                color: labelColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: CupertinoSlider(
              value: value.toDouble(),
              min: 0,
              max: 255,
              activeColor: primaryColor,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 32,
            child: Text(
              value.toString(),
              textAlign: TextAlign.right,
              style: AppTextStyles.secondary(context),
            ),
          ),
        ],
      ),
    );
  }
}
