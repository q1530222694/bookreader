import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../engine/localization_engine.dart';

/// 显示时长选择对话框（Cupertino 风格），返回选中的秒数，取消返回 null。
Future<int?> showDurationPickerDialog(BuildContext context, {int initialSeconds = 3}) {
  final commonOptions = [3, 5, 8];

  return showCupertinoModalPopup<int>(
    context: context,
    builder: (context) {
      int selected = initialSeconds;
      final controller = TextEditingController(text: selected.toString());

      return CupertinoActionSheet(
        title: Text(LocalizationEngine.text('duration_picker_title')),
        message: StatefulBuilder(
          builder: (context, setState) {
            final primary = CupertinoTheme.of(context).primaryColor;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: commonOptions.map((sec) {
                    final isSelected = selected == sec;
                    return CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          selected = sec;
                          controller.text = sec.toString();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? primary.withOpacity(0.12) : CupertinoColors.secondarySystemFill.resolveFrom(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? primary : CupertinoColors.separator.resolveFrom(context),
                          ),
                        ),
                        child: Text(
                          '$sec ${LocalizationEngine.text('seconds')}',
                          style: TextStyle(color: isSelected ? primary : CupertinoColors.label.resolveFrom(context)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  placeholder: LocalizationEngine.text('custom_seconds_hint'),
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null && parsed > 0) {
                      setState(() {
                        selected = parsed;
                      });
                    }
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(LocalizationEngine.text('cancel')),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value == null || value <= 0) {
                showCupertinoDialog<void>(
                  context: context,
                  builder: (ctx) => CupertinoAlertDialog(
                    title: Text(LocalizationEngine.text('duration_error')),
                    actions: [
                      CupertinoDialogAction(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(LocalizationEngine.text('cancel')),
                      ),
                    ],
                  ),
                );
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: Text(LocalizationEngine.text('save')),
          ),
        ],
      );
    },
  );
}
