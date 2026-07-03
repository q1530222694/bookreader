import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../controller/image_to_pdf_controller.dart';
import '../model/export_record_model.dart';

/// ImageToPdfPage 纯UI层，负责显示界面和处理用户交互
class ImageToPdfPage extends StatefulWidget {
  const ImageToPdfPage({super.key});

  @override
  State<ImageToPdfPage> createState() => _ImageToPdfPageState();
}

class _ImageToPdfPageState extends State<ImageToPdfPage> {
  /// 已选择的图片路径列表
  List<String> _selectedImages = [];

  /// 转换状态信息
  String _statusMessage = '请选择图片开始转换';

  /// 是否正在转换中
  bool _isConverting = false;

  /// 导出记录列表
  List<ExportRecord> _exportRecords = [];

  /// 当前显示的tab（0=图片转换，1=导出记录）
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _loadExportRecords();
  }

  /// 加载导出记录列表
  Future<void> _loadExportRecords() async {
    final records = await ImageToPdfController.getExportRecords();
    if (mounted) {
      setState(() {
        _exportRecords = records;
      });
    }
  }

  /// 处理选择图片按钮点击
  Future<void> _onSelectImagesPressed() async {
    final images = await ImageToPdfController.selectImages();

    if (mounted) {
      setState(() {
        if (images.isNotEmpty) {
          _selectedImages = images;
          _statusMessage = '已选择 ${_selectedImages.length} 张图片，点击下方按钮开始转换';
        }
      });
    }
  }

  /// 删除指定索引的图片
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _statusMessage = _selectedImages.isEmpty
          ? '请选择图片'
          : '已选择 ${_selectedImages.length} 张图片';
    });
  }

  /// 处理转换为PDF按钮点击
  Future<void> _onConvertPressed() async {
    if (_selectedImages.isEmpty) {
      if (mounted) {
        setState(() {
          _statusMessage = '请先选择图片';
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

    // 获取输出文件名（当前时间戳）
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final pdfFileName = 'images_$timestamp.pdf';

    // 执行转换
    final result = await ImageToPdfController.convertToPdf(
      imagePaths: _selectedImages,
      pdfFileName: pdfFileName,
    );

    if (mounted) {
      setState(() {
        _isConverting = false;
        _statusMessage = result.message;
        if (result.success) {
          _selectedImages = [];
          // 刷新导出记录列表
          _loadExportRecords();
        }
      });
    }
  }

  /// 处理从导出记录中删除
  Future<void> _onDeleteRecord(String recordId) async {
    final success = await ImageToPdfController.deleteExportRecord(recordId);

    if (mounted) {
      setState(() {
        if (success) {
          _exportRecords.removeWhere((r) => r.id == recordId);
          _statusMessage = '删除成功';
        } else {
          _statusMessage = '删除失败';
        }
      });
    }
  }

  /// 构建图片预览项
  Widget _buildImagePreviewItem(String imagePath, int index) {
    return GestureDetector(
      onLongPress: () {
        // 长按删除图片
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('确认删除'),
            content: const Text('确定要删除此图片吗？'),
            actions: [
              CupertinoDialogAction(
                child: const Text('取消'),
                onPressed: () => Navigator.pop(context),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text('删除'),
                onPressed: () {
                  Navigator.pop(context);
                  _removeImage(index);
                },
              ),
            ],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          border: Border.all(color: CupertinoColors.systemGrey4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图片缩略图
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
              child: Image.file(
                File(imagePath),
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 80,
                    height: 80,
                    color: CupertinoColors.systemGrey6,
                    child: const Icon(CupertinoIcons.photo),
                  );
                },
              ),
            ),
            // 序号标签
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: const BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(7),
                  bottomRight: Radius.circular(7),
                ),
              ),
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建导出记录项
  Widget _buildExportRecordItem(ExportRecord record) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 文件名和日期
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.fileName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${record.imageCount} 张图片 • ${ImageToPdfController.formatFileSize(record.fileSize)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
              // 时间
              Text(
                _formatDateTime(record.exportedAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 操作按钮
          Row(
            children: [
              // 打开按钮
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  onPressed: () async {
                    final file = File(record.filePath);
                    if (await file.exists()) {
                      // 这里可以集成打开PDF的功能
                      _statusMessage = '点击打开：${record.fileName}';
                    } else {
                      _statusMessage = 'PDF文件不存在';
                    }
                  },
                  child: const Text('查看'),
                ),
              ),
              const SizedBox(width: 8),

              // 添加到书架按钮
              if (!record.addedToShelf)
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    onPressed: () async {
                      // TODO: 实现添加到书架功能
                      _statusMessage = '已添加到书架：${record.fileName}';
                    },
                    child: const Text('加入书架'),
                  ),
                )
              else
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '已加入书架',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.systemGreen,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),

              // 删除按钮
              CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                onPressed: () => _onDeleteRecord(record.id),
                child: const Icon(
                  CupertinoIcons.trash,
                  color: CupertinoColors.systemRed,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (targetDay == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (targetDay == today.subtract(const Duration(days: 1))) {
      return '昨天';
    } else {
      return '${dateTime.month}月${dateTime.day}日';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.back),
        ),
        middle: const Text('图片转PDF'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Tab 选择器
            CupertinoSegmentedControl<int>(
              children: const {
                0: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('转换'),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('记录'),
                ),
              },
              groupValue: _currentTab,
              onValueChanged: (value) {
                setState(() {
                  _currentTab = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // 内容区域
            Expanded(
              child: _currentTab == 0
                  ? _buildConversionTab(theme)
                  : _buildRecordsTab(),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建转换 Tab
  Widget _buildConversionTab(CupertinoThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 说明文本
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '支持选择多张图片，将按照显示顺序转换为单个PDF文件\n长按图片可删除，拖拽重新排序',
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 选择图片按钮
          CupertinoButton.filled(
            onPressed: _isConverting ? null : _onSelectImagesPressed,
            child: const Text('选择图片（支持多选）'),
          ),
          const SizedBox(height: 16),

          // 图片预览列表
          if (_selectedImages.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已选择 ${_selectedImages.length} 张图片',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) =>
                        _buildImagePreviewItem(_selectedImages[index], index),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),

          // 转换为PDF按钮
          CupertinoButton.filled(
            onPressed: _isConverting ? null : _onConvertPressed,
            child: _isConverting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CupertinoActivityIndicator(),
                  )
                : const Text('转换为PDF'),
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
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建导出记录 Tab
  Widget _buildRecordsTab() {
    if (_exportRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.doc,
              size: 64,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            const Text(
              '暂无导出记录',
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '导出历史 (${_exportRecords.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ..._exportRecords.map((record) => _buildExportRecordItem(record)),
      ],
    );
  }
}
