import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../controller/ppt_to_pdf_controller.dart';
import '../model/ppt_to_pdf_model.dart';

class PptToPdfPage extends StatefulWidget {
  const PptToPdfPage({super.key});

  @override
  State<PptToPdfPage> createState() => _PptToPdfPageState();
}

class _PptToPdfPageState extends State<PptToPdfPage> {
  String? _selectedFile;
  String _statusMessage = '请选择PPT/PPTX文件开始转换';
  bool _isConverting = false;
  List<ExportRecord> _exportRecords = [];
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _loadExportRecords();
  }

  Future<void> _loadExportRecords() async {
    final records = await PptToPdfController.getExportRecords();
    if (mounted) setState(() => _exportRecords = records);
  }

  Future<void> _onSelectFilePressed() async {
    final filePath = await PptToPdfController.selectPptFile();
    if (mounted) {
      setState(() {
        if (filePath != null && filePath.isNotEmpty) {
          _selectedFile = filePath;
          final fileName = filePath.split(Platform.pathSeparator).last;
          _statusMessage = '已选择: $fileName，点击下方按钮开始转换';
        }
      });
    }
  }

  Future<void> _onConvertPressed() async {
    if (_selectedFile == null || _selectedFile!.isEmpty) {
      if (mounted) setState(() => _statusMessage = '请先选择PPT文件');
      return;
    }

    if (mounted) setState(() { _isConverting = true; _statusMessage = '正在转换...'; });

    final fileName = _selectedFile!.split(Platform.pathSeparator).last;
    final base = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final pdfFileName = '${base}_$timestamp.pdf';

    final result = await PptToPdfController.convertToPdf(pptFilePath: _selectedFile!, pdfFileName: pdfFileName);

    if (mounted) {
      setState(() {
        _isConverting = false;
        _statusMessage = result.success ? result.message : result.message;
        if (result.success) {
          _loadExportRecords();
          _selectedFile = null;
        }
      });
    }
  }

  Future<void> _openPdfFile(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('start', [filePath], runInShell: true);
      } else if (Platform.isAndroid || Platform.isIOS) {
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('PDF已保存'),
              content: const Text('PDF文件已保存，请使用阅读器打开'),
              actions: [CupertinoDialogAction(child: const Text('关闭'), onPressed: () => Navigator.pop(context))],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('打开失败'),
            content: Text('打开文件失败: ${e.toString()}'),
            actions: [CupertinoDialogAction(child: const Text('关闭'), onPressed: () => Navigator.pop(context))],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: GestureDetector(onTap: () => Navigator.of(context).pop(), child: const Icon(CupertinoIcons.back)),
        middle: const Text('PPT转PDF'),
      ),
      child: SafeArea(
        child: CupertinoTabScaffold(
          tabBar: CupertinoTabBar(
            items: const [
              BottomNavigationBarItem(icon: Icon(CupertinoIcons.doc), label: '转换'),
              BottomNavigationBarItem(icon: Icon(CupertinoIcons.list_bullet), label: '记录'),
            ],
            currentIndex: _currentTab,
            onTap: (i) { setState(() => _currentTab = i); },
          ),
          tabBuilder: (context, index) {
            return IndexedStack(index: index, children: [_buildConversionTab(theme), _buildRecordsTab(theme)]);
          },
        ),
      ),
    );
  }

  Widget _buildConversionTab(CupertinoThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('转换步骤', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: theme.primaryColor)),
        const SizedBox(height: 16),
        CupertinoButton.filled(onPressed: _isConverting ? null : _onSelectFilePressed, child: const Text('选择PPT/PPTX文件')),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: CupertinoColors.systemGrey6, borderRadius: BorderRadius.circular(8)), child: Text(_statusMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: theme.primaryColor))),
        const SizedBox(height: 16),
        CupertinoButton.filled(onPressed: _isConverting || _selectedFile == null ? null : _onConvertPressed, child: _isConverting ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [CupertinoActivityIndicator(), SizedBox(width: 8), Text('转换中...')]) : const Text('转换为PDF')),
        const SizedBox(height: 24),
        if (_selectedFile != null)
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: CupertinoColors.systemGrey5, width: 1), borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('已选择的文件:', style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey)), const SizedBox(height: 8), Text(_selectedFile!.split(Platform.pathSeparator).last, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.primaryColor), maxLines: 2, overflow: TextOverflow.ellipsis)])),
      ]),
    );
  }

  Widget _buildRecordsTab(CupertinoThemeData theme) {
    return Padding(padding: const EdgeInsets.all(16.0), child: _exportRecords.isEmpty ? Center(child: Text('还没有转换记录', style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey))) : ListView.builder(itemCount: _exportRecords.length, itemBuilder: (context, index) {
      final record = _exportRecords[index];
      final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
      final dateStr = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')} ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
      return Container(margin: const EdgeInsets.only(bottom:12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: CupertinoColors.systemGrey6, borderRadius: BorderRadius.circular(8), border: Border.all(color: CupertinoColors.systemGrey5, width: 1)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(record.sourceFileName, style: TextStyle(fontSize:14, fontWeight: FontWeight.w600, color: theme.primaryColor), maxLines:1, overflow: TextOverflow.ellipsis), const SizedBox(height:8), Text('→ ${record.pdfFileName}', style: const TextStyle(fontSize:12, color: CupertinoColors.systemGrey), maxLines:1, overflow: TextOverflow.ellipsis), const SizedBox(height:8), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(dateStr, style: const TextStyle(fontSize:11, color: CupertinoColors.systemGrey)), CupertinoButton(padding: EdgeInsets.zero, onPressed: () => _openPdfFile(record.filePath), child: const Text('打开', style: TextStyle(fontSize:12)) )]) ]));
    }));
  }
}
