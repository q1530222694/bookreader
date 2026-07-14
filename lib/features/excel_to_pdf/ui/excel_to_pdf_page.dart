import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../shared/ui/app_text_styles.dart';
import '../../../shared/ui/conversion_scaffold.dart';
import '../controller/excel_to_pdf_controller.dart';
import '../model/excel_to_pdf_model.dart';

/// ExcelToPdfPage 纯 UI 层：XLS / XLSX 转 PDF。使用统一转换脚手架。
class ExcelToPdfPage extends StatefulWidget {
  const ExcelToPdfPage({super.key});

  @override
  State<ExcelToPdfPage> createState() => _ExcelToPdfPageState();
}

class _ExcelToPdfPageState extends State<ExcelToPdfPage> {
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
    final records = await ExcelToPdfController.getExportRecords();
    if (mounted) {
      setState(() => _exportRecords = records);
    }
  }

  Future<void> _onSelectFilePressed() async {
    final filePath = await ExcelToPdfController.selectExcelFile();
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
    final base = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final pdfFileName = '${base}_$timestamp.pdf';

    try {
      final result = await ExcelToPdfController.convertToPdf(
        excelFilePath: _selectedFile!,
        pdfFileName: pdfFileName,
      );

      if (!mounted) return;
      setState(() {
        _isConverting = false;
        _statusMessage = result.message;
        if (result.success) {
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
    final success = await ExcelToPdfController.deleteExportRecord(timestamp);
    if (mounted && success) {
      setState(() =>
          _exportRecords.removeWhere((r) => r.timestamp == timestamp));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConversionScaffold(
      title: LocalizationEngine.text('tool_xls_pdf_title'),
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
          text: LocalizationEngine.text('conv_tip_excel'),
        ),
        const SizedBox(height: 16),
        ConversionPrimaryButton(
          label: LocalizationEngine.text('conv_select_excel'),
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
          subtitle: '→ ${record.pdfFileName}',
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
