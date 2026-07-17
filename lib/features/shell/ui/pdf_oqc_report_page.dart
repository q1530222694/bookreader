import 'package:flutter/cupertino.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../engine/localization_engine.dart';
import '../model/pdf_oqc_result.dart';
import '../service/pdf_oqc_service.dart';

/// 扫描件质检（OQC）报告页：对当前打开的 PDF 整本质检，展示逐页问题清单。
///
/// 进入后先逐页渲染统计（带进度），再展示概览（空白/模糊/黑边/重影/最大倾斜计数）
/// 与逐页明细列表。问题页高亮，正常页显示清晰度评分。
class PdfOqcReportPage extends StatefulWidget {
  final PdfDocument document;

  const PdfOqcReportPage({super.key, required this.document});

  @override
  State<PdfOqcReportPage> createState() => _PdfOqcReportPageState();
}

class _PdfOqcReportPageState extends State<PdfOqcReportPage> {
  PdfOqcReport? _report;
  int _current = 0;
  int _total = 0;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final report = await PdfOqcService.run(
      widget.document,
      onProgress: (c, t) => setState(() {
        _current = c;
        _total = t;
      }),
    );
    if (!mounted) return;
    setState(() {
      _report = report;
      _running = false;
    });
  }

  String _progressText() {
    final t = LocalizationEngine.text('pdf_oqc_running');
    return t
        .replaceFirst('%d', '$_current')
        .replaceFirst('%d', '$_total');
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(LocalizationEngine.text('pdf_oqc_title')),
      ),
      child: SafeArea(
        child: _running
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CupertinoActivityIndicator(),
                    const SizedBox(height: 12),
                    Text(_progressText()),
                    const SizedBox(height: 6),
                    Text(
                      LocalizationEngine.text('pdf_oqc_running_hint'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              )
            : _report == null || _report!.totalPages == 0
                ? Center(
                    child: Text(LocalizationEngine.text('pdf_oqc_failed')),
                  )
                : _buildReport(),
      ),
    );
  }

  Widget _buildReport() {
    final r = _report!;
    final theme = CupertinoTheme.of(context);
    return Column(
      children: [
        // 概览卡片
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocalizationEngine.text('pdf_oqc_summary'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 10,
                children: [
                  _Stat(LocalizationEngine.text('pdf_oqc_total'),
                      '${r.totalPages}', theme),
                  _Stat(LocalizationEngine.text('pdf_oqc_blank'),
                      '${r.blankCount}', theme),
                  _Stat(LocalizationEngine.text('pdf_oqc_blurry'),
                      '${r.blurryCount}', theme),
                  _Stat(LocalizationEngine.text('pdf_oqc_margin'),
                      '${r.marginCount}', theme),
                  _Stat(LocalizationEngine.text('pdf_oqc_ghost'),
                      '${r.ghostCount}', theme),
                  _Stat(LocalizationEngine.text('pdf_oqc_skew'),
                      '${r.maxSkew.toStringAsFixed(1)}°', theme),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                r.issueCount == 0
                    ? LocalizationEngine.text('pdf_oqc_no_issue')
                    : LocalizationEngine.text('pdf_oqc_issue_hint')
                        .replaceFirst('%d', '${r.issueCount}'),
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
        // 逐页明细
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: r.pages.length,
            itemBuilder: (_, i) => _buildRow(r.pages[i], theme),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(PdfOqcPageResult p, CupertinoThemeData theme) {
    final issues = <String>[];
    if (p.isBlank) issues.add(LocalizationEngine.text('pdf_oqc_blank'));
    if (p.isBlurry) issues.add(LocalizationEngine.text('pdf_oqc_blurry'));
    if (p.hasBlackMargin) issues.add(LocalizationEngine.text('pdf_oqc_margin'));
    if (p.hasGhost) issues.add(LocalizationEngine.text('pdf_oqc_ghost'));
    if (p.skewAngle.abs() > 2.0) {
      issues.add(
          '${LocalizationEngine.text('pdf_oqc_skew')} ${p.skewAngle.toStringAsFixed(1)}°');
    }
    final ok = issues.isEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ok
              ? CupertinoColors.systemGrey5.resolveFrom(context)
              : theme.primaryColor.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ok
                ? CupertinoIcons.check_mark_circled
                : CupertinoIcons.exclamationmark_circle,
            color: ok
                ? CupertinoColors.systemGreen
                : CupertinoColors.systemOrange,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocalizationEngine.text('pdf_oqc_page')
                      .replaceFirst('%d', '${p.pageNumber}'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: ok
                      ? Text(
                          '${LocalizationEngine.text('pdf_enhance_sharpness')}: ${p.blurScore}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        )
                      : Text(
                          issues.join(' · '),
                          style: const TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final CupertinoThemeData theme;

  const _Stat(this.label, this.value, this.theme);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: theme.primaryColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      ],
    );
  }
}
