import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../controller/settings_controller.dart';

/// 重排阅读视图：将 [paragraphs] 以可调排版重新流式排版，原生滚动保证流畅。
///
/// 字号 / 行距 / 字距 / 段距均来自 [SettingsController] 的实时广播，拖动设置面板滑块时
/// 即时重排，无需重新解析 PDF。顶部提供「退出重排」返回原版式阅读。
class PdfReflowView extends StatefulWidget {
  /// 已聚合的可重排段落（来自 [PdfTextReflowService]）。
  final List<String> paragraphs;

  /// 退出重排回调，返回原 PDF 版式视图。
  final VoidCallback onExit;

  const PdfReflowView({
    super.key,
    required this.paragraphs,
    required this.onExit,
  });

  @override
  State<PdfReflowView> createState() => _PdfReflowViewState();
}

class _PdfReflowViewState extends State<PdfReflowView> {
  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final primaryColor = CupertinoTheme.of(context).primaryColor;

    return Container(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              color: CupertinoColors.systemBackground.resolveFrom(context),
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minSize: 0,
                    onPressed: widget.onExit,
                    child: Icon(CupertinoIcons.clear, color: primaryColor),
                  ),
                  Expanded(
                    child: Text(
                      LocalizationEngine.text('pdf_reflow_exit'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                SettingsController.pdfReflowFontSize,
                SettingsController.pdfReflowLineSpacing,
                SettingsController.pdfReflowLetterSpacing,
                SettingsController.pdfReflowParaSpacing,
              ]),
              builder: (context, _) {
                final fontSize = SettingsController.pdfReflowFontSize.value;
                final lineSpacing = SettingsController.pdfReflowLineSpacing.value;
                final letterSpacing =
                    SettingsController.pdfReflowLetterSpacing.value;
                final paraSpacing = SettingsController.pdfReflowParaSpacing.value;

                return SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final p in widget.paragraphs) ...[
                        Text(
                          p,
                          style: TextStyle(
                            fontSize: fontSize,
                            height: lineSpacing,
                            letterSpacing: letterSpacing,
                            color: labelColor,
                          ),
                        ),
                        SizedBox(height: paraSpacing),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
