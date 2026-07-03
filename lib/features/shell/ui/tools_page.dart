import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../image_to_pdf/ui/image_to_pdf_page.dart';
import '../../txt_to_epub/ui/txt_to_epub_page.dart';
import '../../doc_to_pdf/ui/doc_to_pdf_page.dart';
import '../../ppt_to_pdf/ui/ppt_to_pdf_page.dart';
import '../../excel_to_pdf/ui/excel_to_pdf_page.dart';

/// ToolsPage 工具页面，展示各种实用工具
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  void _openImageToPdfPage(BuildContext context) {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => const ImageToPdfPage(),
    ));
  }

  void _openTxtToEpubPage(BuildContext context) {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => const TxtToEpubPage(),
    ));
  }

  void _openDocToPdfPage(BuildContext context) {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => const DocToPdfPage(),
    ));
  }

  void _openPptToPdfPage(BuildContext context) {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => const PptToPdfPage(),
    ));
  }

  void _openExcelToPdfPage(BuildContext context) {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => const ExcelToPdfPage(),
    ));
  }

  Widget _buildToolCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = CupertinoTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CupertinoColors.systemGrey5,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: theme.primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(LocalizationEngine.text('tools')),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildToolCard(
                context: context,
                icon: CupertinoIcons.book,
                title: 'TXT转EPUB',
                subtitle: '将TXT文本文件转换为EPUB电子书格式',
                onTap: () => _openTxtToEpubPage(context),
              ),
              const SizedBox(height: 12),

              _buildToolCard(
                context: context,
                icon: CupertinoIcons.doc_text,
                title: 'DOC转PDF',
                subtitle: '将Word文档转换为PDF格式',
                onTap: () => _openDocToPdfPage(context),
              ),
              const SizedBox(height: 12),

              _buildToolCard(
                context: context,
                icon: CupertinoIcons.doc,
                title: 'PPT转PDF',
                subtitle: '将PPT或PPTX幻灯片转换为PDF文档（提取文本）',
                onTap: () => _openPptToPdfPage(context),
              ),
              const SizedBox(height: 12),

              _buildToolCard(
                context: context,
                icon: CupertinoIcons.table,
                title: 'Excel转PDF',
                subtitle: '将Excel表格（XLS/XLSX）导出为PDF（提取文本）',
                onTap: () => _openExcelToPdfPage(context),
              ),
              const SizedBox(height: 12),

              _buildToolCard(
                context: context,
                icon: CupertinoIcons.photo_on_rectangle,
                title: '图片转PDF',
                subtitle: '将图片合并并导出为PDF',
                onTap: () => _openImageToPdfPage(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

