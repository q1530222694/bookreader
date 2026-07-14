import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        DefaultMaterialLocalizations,
        DefaultWidgetsLocalizations,
        Localizations,
        ReorderableDragStartListener,
        ReorderableListView;

import '../../../engine/localization_engine.dart';
import '../../../shared/ui/app_text_styles.dart';
import '../../../shared/ui/conversion_scaffold.dart';
import '../controller/image_to_pdf_controller.dart';
import '../model/export_record_model.dart';
import '../service/filepicker_diagnostics.dart';
import '../../shell/service/bookshelf_service.dart';

/// ImageToPdfPage 纯 UI 层：多张图片合并转 PDF。使用统一转换脚手架。
///
/// 相比其它转换页额外支持：多选、拖动重新排序、缩略图角标删除、加入书架。
class ImageToPdfPage extends StatefulWidget {
  const ImageToPdfPage({super.key});

  @override
  State<ImageToPdfPage> createState() => _ImageToPdfPageState();
}

class _ImageToPdfPageState extends State<ImageToPdfPage> {
  List<String> _selectedImages = [];
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
    final records = await ImageToPdfController.getExportRecords();
    if (mounted) {
      setState(() => _exportRecords = records);
    }
  }

  Future<void> _onSelectImagesPressed() async {
    final images = await ImageToPdfController.selectImages();
    if (mounted && images.isNotEmpty) {
      setState(() {
        _selectedImages = images;
        _statusMessage = '';
      });
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  /// 拖动重新排序（调用 Controller.reorderImages，符合分层约束）。
  /// 注意：onReorder 回调的 newIndex 已是「源列表移除后的目标位置」，
  /// 由 Controller.reorderImages 内部自行做 removeAt/insert，此处不再预减，
  /// 否则会造成双重偏移导致排序错乱。
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      _selectedImages = ImageToPdfController.reorderImages(
        _selectedImages,
        oldIndex,
        newIndex,
      );
    });
  }

  Future<void> _onConvertPressed() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isConverting = true;
      _statusMessage = '';
    });

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final pdfFileName = 'images_$timestamp.pdf';

    try {
      final result = await ImageToPdfController.convertToPdf(
        imagePaths: _selectedImages,
        pdfFileName: pdfFileName,
      );

      if (!mounted) return;
      setState(() {
        _isConverting = false;
        _statusMessage = result.message;
        if (result.success) {
          _selectedImages = [];
          _loadExportRecords();
        }
      });
    } catch (e, st) {
      debugPrint('转换异常: $e');
      await FilepickerDiagnostics.writeLog('ui _onConvertPressed 异常: $e\n$st');
      if (!mounted) return;
      setState(() {
        _isConverting = false;
        _statusMessage = '${LocalizationEngine.text('conv_convert_failed')}: $e';
      });
    }
  }

  Future<void> _onDeleteRecord(String recordId) async {
    final ok = await confirmConversionDelete(context);
    if (!ok) return;
    final success = await ImageToPdfController.deleteExportRecord(recordId);
    if (mounted && success) {
      setState(() => _exportRecords.removeWhere((r) => r.id == recordId));
    }
  }

  Future<void> _onAddToShelf(ExportRecord record) async {
    final result = await ImageToPdfController.addExportedPdfToShelf(
      record,
      (file) async {
        try {
          await BookshelfService().importPdf(file);
          return true;
        } catch (e) {
          debugPrint('添加到书架失败: $e');
          return false;
        }
      },
    );

    if (!mounted) return;
    setState(() {
      if (result) {
        final i = _exportRecords.indexWhere((r) => r.id == record.id);
        if (i >= 0) {
          _exportRecords[i] = record.copyWith(addedToShelf: true);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConversionScaffold(
      title: LocalizationEngine.text('tool_img_pdf_title'),
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
          text: LocalizationEngine.text('conv_tip_image'),
        ),
        const SizedBox(height: 16),
        ConversionPrimaryButton(
          label: LocalizationEngine.text('conv_select_images'),
          icon: CupertinoIcons.photo_on_rectangle,
          onPressed: _isConverting ? null : _onSelectImagesPressed,
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            LocalizationEngine.text('conv_selected_count')
                .replaceFirst('%d', '${_selectedImages.length}'),
            style: AppTextStyles.body(context)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 116,
            // ReorderableListView 是 Material 组件，纯 Cupertino 树中缺少
            // MaterialLocalizations 会断言崩溃（选图后直接闪退）。
            // 参考 daily_sentence_page 的修法：用 Localizations 仅包裹列表、
            // 提供其所需的 Material 文案环境（不引入 MaterialApp，避免嵌套导航冲突）。
            child: Localizations(
              locale: const Locale('en'),
              delegates: const [
                DefaultWidgetsLocalizations.delegate,
                DefaultMaterialLocalizations.delegate,
              ],
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                // 关闭默认拖拽手柄（默认手柄依赖 Material），改用自绘手柄
                buildDefaultDragHandles: false,
                proxyDecorator: (child, index, animation) => child,
                itemCount: _selectedImages.length,
                onReorder: _onReorder,
                itemBuilder: (context, index) => _buildImageThumb(
                  _selectedImages[index],
                  index,
                  key: ValueKey(_selectedImages[index]),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        ConversionPrimaryButton(
          label: LocalizationEngine.text('conv_start'),
          loadingLabel: LocalizationEngine.text('conv_converting'),
          icon: CupertinoIcons.arrow_right_circle,
          loading: _isConverting,
          onPressed: _selectedImages.isEmpty ? null : _onConvertPressed,
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

  /// 缩略图 + 序号 + 右上角删除角标。
  ///
  /// 整张卡片作为拖拽手柄（[ReorderableDragStartListener]），长按即可重新排序。
  Widget _buildImageThumb(String imagePath, int index, {required Key key}) {
    return ReorderableDragStartListener(
      key: key,
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: SizedBox(
          width: 88,
          child: Stack(
            children: [
              Container(
                width: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: CupertinoColors.systemGrey4.resolveFrom(context),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(9),
                      ),
                      child: Image(
                        image: ResizeImage(
                          FileImage(File(imagePath)),
                          width: 176,
                          height: 176,
                        ),
                        width: 88,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 88,
                          height: 80,
                          color: CupertinoColors.secondarySystemFill
                              .resolveFrom(context),
                          child: const Icon(CupertinoIcons.photo),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${index + 1}',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption(context),
                      ),
                    ),
                  ],
                ),
              ),
              // 右上角删除角标
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  onTap: () => _removeImage(index),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: CupertinoColors.systemRed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.clear,
                      size: 14,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ),
              // 左下角拖拽指示图标
              Positioned(
                left: 2,
                bottom: 18,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemFill
                        .resolveFrom(context)
                        .withOpacity(0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    CupertinoIcons.line_horizontal_3,
                    size: 14,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        final countText = LocalizationEngine.text('conv_image_count')
            .replaceFirst('%d', '${record.imageCount}');
        return ConversionRecordCard(
          title: record.fileName,
          subtitle:
              '$countText · ${ConversionFormat.fileSize(record.fileSize)}',
          time: ConversionFormat.dateTime(record.exportedAt),
          actions: [
            ConversionRecordActions.primary(
              context: context,
              label: LocalizationEngine.text('conv_view'),
              icon: CupertinoIcons.eye,
              onPressed: () => openConversionFile(
                context,
                record.filePath,
                onMessage: (m) => setState(() => _statusMessage = m),
              ),
            ),
            ConversionRecordActions.gap,
            if (record.addedToShelf)
              ConversionRecordActions.successBadge(
                context: context,
                label: LocalizationEngine.text('conv_added_shelf'),
              )
            else
              ConversionRecordActions.primary(
                context: context,
                label: LocalizationEngine.text('conv_add_shelf'),
                icon: CupertinoIcons.book,
                onPressed: () => _onAddToShelf(record),
              ),
            ConversionRecordActions.gap,
            ConversionRecordActions.danger(
              context: context,
              onPressed: () => _onDeleteRecord(record.id),
            ),
          ],
        );
      },
    );
  }
}
