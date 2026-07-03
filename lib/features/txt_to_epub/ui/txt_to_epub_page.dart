import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../controller/txt_to_epub_controller.dart';
import '../model/txt_to_epub_model.dart';

/// TxtToEpubPage 纯UI层，负责显示界面和处理用户交互
class TxtToEpubPage extends StatefulWidget {
  const TxtToEpubPage({super.key});

  @override
  State<TxtToEpubPage> createState() => _TxtToEpubPageState();
}

class _TxtToEpubPageState extends State<TxtToEpubPage> {
  /// 已选择的TXT文件路径
  String? _selectedTxtFile;

  /// 转换状态信息
  String _statusMessage = '请选择TXT文件开始转换';

  /// 是否正在转换中
  bool _isConverting = false;

  /// 转换记录列表
  List<ExportRecord> _exportRecords = [];

  /// 当前显示的tab（0=文件转换，1=转换记录）
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _loadExportRecords();
  }

  /// 加载转换记录列表
  Future<void> _loadExportRecords() async {
    final records = await TxtToEpubController.getExportRecords();
    if (mounted) {
      setState(() {
        _exportRecords = records;
      });
    }
  }

  /// 处理选择TXT文件按钮点击
  Future<void> _onSelectFilePressed() async {
    final filePath = await TxtToEpubController.selectTxtFile();

    if (mounted) {
      setState(() {
        if (filePath != null && filePath.isNotEmpty) {
          _selectedTxtFile = filePath;
          final fileName = filePath.split(Platform.pathSeparator).last;
          _statusMessage = '已选择: $fileName，点击下方按钮开始转换';
        }
      });
    }
  }

  /// 处理转换为EPUB按钮点击
  Future<void> _onConvertPressed() async {
    if (_selectedTxtFile == null || _selectedTxtFile!.isEmpty) {
      if (mounted) {
        setState(() {
          _statusMessage = '请先选择TXT文件';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isConverting = true;
        _statusMessage = '正在转换...';
      });
    }

    // 获取文件名和输出文件名
    final fileName =
        _selectedTxtFile!.split(Platform.pathSeparator).last;
    final fileNameWithoutExt = fileName.replaceAll('.txt', '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final epubFileName = '${fileNameWithoutExt}_$timestamp.epub';

    try {
      // 执行转换
      final result = await TxtToEpubController.convertToEpub(
        txtFilePath: _selectedTxtFile!,
        epubFileName: epubFileName,
        bookTitle: fileNameWithoutExt,
      );

      if (mounted) {
        setState(() {
          _isConverting = false;
          if (result.success) {
            _statusMessage = result.message;

            // 保存转换记录
            final record = ExportRecord(
              sourceFileName: fileName,
              epubFileName: epubFileName,
              timestamp: timestamp,
              filePath: result.filePath ?? '',
            );
            TxtToEpubController.saveExportRecord(record);

            // 刷新记录列表
            _loadExportRecords();

            // 重置已选择文件
            _selectedTxtFile = null;
          } else {
            _statusMessage = result.message;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConverting = false;
          _statusMessage = '转换异常: ${e.toString()}';
        });
      }
    }
  }

  /// 打开EPUB文件
  Future<void> _openEpubFile(String filePath) async {
    try {
      if (Platform.isWindows) {
        // Windows 平台使用默认应用打开
        await Process.run('start', [filePath], runInShell: true);
      } else if (Platform.isAndroid || Platform.isIOS) {
        // 移动平台可以集成第三方EPUB阅读器
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('EPUB已保存'),
              content: const Text('EPUB文件已保存，请使用阅读器打开'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('关闭'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
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
            actions: [
              CupertinoDialogAction(
                child: const Text('关闭'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
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
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.back),
        ),
        middle: const Text('TXT转EPUB'),
      ),
      child: SafeArea(
        child: CupertinoTabScaffold(
          tabBar: CupertinoTabBar(
            items: [
              BottomNavigationBarItem(
                icon: const Icon(CupertinoIcons.doc),
                label: '转换',
              ),
              BottomNavigationBarItem(
                icon: const Icon(CupertinoIcons.list_bullet),
                label: '记录',
              ),
            ],
            currentIndex: _currentTab,
            onTap: (index) {
              setState(() {
                _currentTab = index;
              });
            },
          ),
          tabBuilder: (context, index) {
            return IndexedStack(
              index: index,
              children: [
                // 转换标签页
                _buildConversionTab(theme),
                // 记录标签页
                _buildRecordsTab(theme),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 构建转换标签页
  Widget _buildConversionTab(CupertinoThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '转换步骤',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          // 选择文件按钮
          CupertinoButton.filled(
            onPressed: _isConverting ? null : _onSelectFilePressed,
            child: const Text('选择TXT文件'),
          ),
          const SizedBox(height: 16),
          // 状态信息显示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 转换按钮
          CupertinoButton.filled(
            onPressed:
                _isConverting || _selectedTxtFile == null
                    ? null
                    : _onConvertPressed,
            child: _isConverting
                ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoActivityIndicator(),
                    SizedBox(width: 8),
                    Text('转换中...'),
                  ],
                )
                : const Text('转换为EPUB'),
          ),
          const SizedBox(height: 24),
          // 文件信息显示
          if (_selectedTxtFile != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: CupertinoColors.systemGrey5,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '已选择的文件:',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedTxtFile!.split(Platform.pathSeparator).last,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.primaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 构建转换记录标签页
  Widget _buildRecordsTab(CupertinoThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _exportRecords.isEmpty
          ? Center(
            child: Text(
              '还没有转换记录',
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.systemGrey,
              ),
            ),
          )
          : ListView.builder(
            itemCount: _exportRecords.length,
            itemBuilder: (context, index) {
              final record = _exportRecords[index];
              final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
              final dateStr =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
                  '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: CupertinoColors.systemGrey5,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.sourceFileName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '→ ${record.epubFileName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () =>
                              _openEpubFile(record.filePath),
                          child: const Text(
                            '打开',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }
}
