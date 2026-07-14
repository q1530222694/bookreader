import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../shared/ui/app_text_styles.dart';
import '../../../shared/ui/conversion_scaffold.dart';
import '../controller/txt_to_epub_controller.dart';
import '../model/txt_to_epub_model.dart';

/// TxtToEpubPage 纯 UI 层：TXT 转 EPUB。
///
/// 使用统一转换脚手架 [ConversionScaffold]，保证与其它转换页视觉/交互一致，
/// 并在 Android / iOS / iPad 上均有良好观感（宽屏内容居中限宽）。
class TxtToEpubPage extends StatefulWidget {
  const TxtToEpubPage({super.key});

  @override
  State<TxtToEpubPage> createState() => _TxtToEpubPageState();
}

class _TxtToEpubPageState extends State<TxtToEpubPage> {
  String? _selectedFile;
  String _statusMessage = '';
  bool _isConverting = false;
  List<ExportRecord> _exportRecords = [];
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _loadExportRecords();
  }

  Future<void> _loadExportRecords() async {
    final records = await TxtToEpubController.getExportRecords();
    if (mounted) {
      setState(() => _exportRecords = records);
    }
  }

  Future<void> _onSelectFilePressed() async {
    final filePath = await TxtToEpubController.selectTxtFile();
    if (mounted && filePath != null && filePath.isNotEmpty) {
      setState(() {
        _selectedFile = filePath;
        _statusMessage = '';
      });
    }
  }

  Future<void> _onConvertPressed() async {
    if (_selectedFile == null || _selectedFile!.isEmpty) return;

    setState(() {
      _isConverting = true;
      _statusMessage = '';
    });

    final fileName = _selectedFile!.split(Platform.pathSeparator).last;
    final fileNameWithoutExt = fileName.replaceAll('.txt', '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final epubFileName = '${fileNameWithoutExt}_$timestamp.epub';

    try {
      final result = await TxtToEpubController.convertToEpub(
        txtFilePath: _selectedFile!,
        epubFileName: epubFileName,
        bookTitle: fileNameWithoutExt,
      );

      if (!mounted) return;
      setState(() {
        _isConverting = false;
        _statusMessage = result.message;
        if (result.success) {
          TxtToEpubController.saveExportRecord(
            ExportRecord(
              sourceFileName: fileName,
              epubFileName: epubFileName,
              timestamp: timestamp,
              filePath: result.filePath ?? '',
            ),
          );
          _loadExportRecords();
          _selectedFile = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConverting = false;
        _statusMessage = '${LocalizationEngine.text('conv_convert_failed')}: $e';
      });
    }
  }

  Future<void> _onDeleteRecord(int timestamp) async {
    final ok = await confirmConversionDelete(context);
    if (!ok) return;
    final success = await TxtToEpubController.deleteExportRecord(timestamp);
    if (mounted && success) {
      setState(() =>
          _exportRecords.removeWhere((r) => r.timestamp == timestamp));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConversionScaffold(
      title: LocalizationEngine.text('tool_txt_epub_title'),
      currentTab: _currentTab,
      onTabChanged: (v) => setState(() => _currentTab = v),
      convertTab: _buildConvertTab(),
      recordsTab: _buildRecordsTab(),
    );
  }

  Widget _buildConvertTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ConversionInfoCard(
          icon: CupertinoIcons.info_circle,
          text: LocalizationEngine.text('conv_tip_txt'),
        ),
        const SizedBox(height: 16),
        ConversionPrimaryButton(
          label: LocalizationEngine.text('conv_select_txt'),
          icon: CupertinoIcons.folder,
          onPressed: _isConverting ? null : _onSelectFilePressed,
        ),
        if (_selectedFile != null) ...[
          const SizedBox(height: 12),
          ConversionInfoCard(
            icon: CupertinoIcons.doc_text,
            text:
                '${LocalizationEngine.text('conv_selected_file')}: ${_selectedFile!.split(Platform.pathSeparator).last}',
          ),
        ],
        const SizedBox(height: 16),
        ConversionPrimaryButton(
          label: LocalizationEngine.text('conv_start'),
          loadingLabel: LocalizationEngine.text('conv_converting'),
          icon: CupertinoIcons.arrow_right_circle,
          loading: _isConverting,
          onPressed: _selectedFile == null ? null : _onConvertPressed,
        ),
        if (_statusMessage.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: AppTextStyles.secondary(context),
          ),
        ],
      ],
    );
  }

  Widget _buildRecordsTab() {
    if (_exportRecords.isEmpty) {
      return ConversionEmptyState(
        icon: CupertinoIcons.doc_on_doc,
        message: LocalizationEngine.text('conv_no_record'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _exportRecords.length,
      itemBuilder: (context, index) {
        final record = _exportRecords[index];
        return ConversionRecordCard(
          title: record.sourceFileName,
          subtitle: '→ ${record.epubFileName}',
          time: ConversionFormat.timestamp(record.timestamp),
          actions: [
            ConversionRecordActions.primary(
              context: context,
              label: LocalizationEngine.text('conv_open'),
              icon: CupertinoIcons.arrow_up_right_square,
              onPressed: () => openConversionFile(
                context,
                record.filePath,
                onMessage: (m) => setState(() => _statusMessage = m),
              ),
            ),
            ConversionRecordActions.gap,
            ConversionRecordActions.danger(
              context: context,
              onPressed: () => _onDeleteRecord(record.timestamp),
            ),
          ],
        );
      },
    );
  }
}
