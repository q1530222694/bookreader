import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:archive/archive.dart';

import '../../../shared/util/cjk_font_loader.dart';
import '../model/doc_to_pdf_model.dart';

/// DocToPdfService 处理 DOC/DOCX 文件到 PDF 的转换逻辑。
///
/// 修复要点：
/// 1. 内嵌 CJK 中文字体（[CjkFontLoader]）—— [pdf] 包默认 Helvetica 不含中文字形，
///    此前中文会渲染成空白/方块；字体字节经 [compute] 的 args 传入 isolate 注册。
/// 2. DOCX 文本提取改为按 `<w:p>` 分段、段内只收集 `<w:t>` 文本节点，
///    得到干净的段落文本，避免把样式名/域代码等噪声当正文。
/// 3. 保留对旧版二进制 .doc 的优雅降级提示。
class DocToPdfService {
  DocToPdfService._();

  /// 将 DOC/DOCX 文件转换为 PDF 格式。
  ///
  /// 参数：
  /// - [docFilePath] DOC/DOCX 文件的完整路径
  /// - [outputFileName] 输出 PDF 文件名（不包含路径）
  ///
  /// 返回转换结果，包含成功状态和 PDF 路径。
  static Future<ConversionResult> convertDocToPdf({
    required String docFilePath,
    required String outputFileName,
  }) async {
    try {
      // 验证输入
      if (docFilePath.isEmpty) {
        return ConversionResult.failure(message: '请选择一个DOC/DOCX文件');
      }

      // 检查文件是否存在
      final docFile = File(docFilePath);
      if (!await docFile.exists()) {
        return ConversionResult.failure(message: '选择的DOC文件不存在');
      }

      // 检查文件扩展名
      final ext = docFilePath.toLowerCase().split('.').last;
      if (ext != 'doc' && ext != 'docx') {
        return ConversionResult.failure(message: '只支持DOC和DOCX文件');
      }

      // 获取输出目录
      final outputDir = await getApplicationDocumentsDirectory();
      final outputPath =
          '${outputDir.path}${Platform.pathSeparator}$outputFileName';

      // 主线程加载 CJK 字体字节（isolate 无法访问 rootBundle）
      final fontBytes = await CjkFontLoader.loadBytes();

      // 在后台 isolate 中转换，避免阻塞主线程
      final args = {
        'docFilePath': docFilePath,
        'outputPath': outputPath,
        'fontBytes': fontBytes,
      };

      Map<String, dynamic> result;
      try {
        result = await compute(_convertDocAndSave, args)
            .timeout(const Duration(seconds: 120));
      } on TimeoutException {
        // 如果超时，回退到主线程执行
        result = await _convertDocAndSave(args);
      } catch (e) {
        return ConversionResult.failure(message: '转换失败: ${e.toString()}');
      }

      if (result['success'] == true) {
        // 保存转换记录
        await saveExportRecord(
          sourceFileName: docFilePath.split(Platform.pathSeparator).last,
          pdfFileName: outputFileName,
          filePath: outputPath,
        );

        return ConversionResult.success(
          message: '成功转换DOC为PDF',
          filePath: outputPath,
        );
      } else {
        return ConversionResult.failure(
            message: result['message'] as String);
      }
    } catch (e) {
      return ConversionResult.failure(message: '转换失败: ${e.toString()}');
    }
  }

  /// 后台 isolate 执行的转换函数。
  static Future<Map<String, dynamic>> _convertDocAndSave(
      Map<String, dynamic> args) async {
    try {
      final docFilePath = args['docFilePath'] as String;
      final outputPath = args['outputPath'] as String;
      final fontBytes = args['fontBytes'] as Uint8List;

      // 读取 DOC/DOCX 文件
      final docFile = File(docFilePath);
      final bytes = await docFile.readAsBytes();

      // 使用纯 Dart 方式提取文本（DOCX 为 ZIP；旧版 .doc 为 OLE 二进制，解析失败则降级）
      String plainText = '';
      try {
        plainText = _extractTextFromDocx(bytes);
      } catch (e) {
        plainText = '该文档为旧版 .doc 二进制格式或包含复杂格式，'
            '当前版本暂不支持提取其文字内容。';
      }

      // 中文必须内嵌 CJK 字体，否则渲染为空白/方块
      final cjkFont = pw.Font.ttf(
        fontBytes.buffer.asByteData(
          fontBytes.offsetInBytes,
          fontBytes.lengthInBytes,
        ),
      );

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: cjkFont, bold: cjkFont),
      );

      // 分页处理大文本（按段落）
      final paragraphs = plainText.split('\n');
      final pdfContent = <pw.Widget>[];
      for (final line in paragraphs) {
        if (line.isEmpty) {
          pdfContent.add(pw.SizedBox(height: 6));
        } else {
          pdfContent.add(
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Text(
                line,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.6),
              ),
            ),
          );
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => pdfContent,
        ),
      );

      // 保存 PDF 到文件
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(await pdf.save());

      return {
        'success': true,
        'message': '成功转换为PDF',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '转换失败: ${e.toString()}',
      };
    }
  }

  /// 从 DOCX 文件（ZIP 格式）提取纯文本。
  ///
  /// 按 `<w:p>` 分段，段内只收集 `<w:t>` 文本节点，得到干净的正文段落。
  static String _extractTextFromDocx(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    // 查找 document.xml
    ArchiveFile? documentFile;
    for (final file in archive.files) {
      if (file.name == 'word/document.xml' ||
          file.name.endsWith('/document.xml')) {
        documentFile = file;
        break;
      }
    }

    if (documentFile == null) {
      throw Exception('找不到 document.xml');
    }

    final xml = utf8.decode(documentFile.content as List<int>);

    // 按段落 <w:p> 切分，段内收集 <w:t> 文本
    final buffer = StringBuffer();
    // 通过正则匹配每个 <w:p>...</w:p> 段落块
    final paragraphRegex = RegExp(r'<w:p\b[^>]*>(.*?)</w:p>', dotAll: true);
    final textRegex = RegExp(r'<w:t\b[^>]*>(.*?)</w:t>', dotAll: true);

    for (final pMatch in paragraphRegex.allMatches(xml)) {
      final paragraphXml = pMatch.group(1) ?? '';
      final textBuffer = StringBuffer();
      for (final tMatch in textRegex.allMatches(paragraphXml)) {
        textBuffer.write(tMatch.group(1) ?? '');
      }
      final text = textBuffer.toString();
      if (text.isNotEmpty) {
        buffer.writeln(_decodeXmlEntities(text));
      } else {
        buffer.writeln();
      }
    }

    String result = buffer.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return result.isEmpty ? '（文档内容为空或无法解析）' : result;
  }

  /// 还原 XML 实体（&amp; &lt; &gt; &quot; &apos;）。
  static String _decodeXmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  /// 获取 PDF 输出目录路径
  static Future<Directory> getPdfOutputDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final pdfDir =
        Directory('${docDir.path}${Platform.pathSeparator}exported_pdfs');

    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }

    return pdfDir;
  }

  /// 获取转换记录文件路径
  static Future<String> _getExportRecordsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}${Platform.pathSeparator}doc2pdf_export_records.json';
  }

  /// 获取所有导出记录
  static Future<List<ExportRecord>> getExportRecords() async {
    try {
      final recordsFile = File(await _getExportRecordsFile());

      if (!await recordsFile.exists()) {
        return [];
      }

      final jsonString = await recordsFile.readAsString();
      final jsonList = jsonDecode(jsonString) as List<dynamic>;

      return jsonList
          .map((json) => ExportRecord.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 保存单条导出记录
  static Future<void> saveExportRecord({
    required String sourceFileName,
    required String pdfFileName,
    required String filePath,
  }) async {
    try {
      final records = await getExportRecords();

      // 添加新记录
      records.add(
        ExportRecord(
          sourceFileName: sourceFileName,
          pdfFileName: pdfFileName,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          filePath: filePath,
        ),
      );

      // 保存回文件
      final recordsFile = File(await _getExportRecordsFile());
      final jsonString =
          jsonEncode(records.map((r) => r.toJson()).toList());

      await recordsFile.writeAsString(jsonString);
    } catch (e) {
      // 静默失败，不影响主功能
    }
  }

  /// 删除导出记录及其对应的 PDF 文件（按时间戳唯一标识）
  static Future<bool> deleteExportRecord(int timestamp) async {
    try {
      final recordsFile = File(await _getExportRecordsFile());
      if (!await recordsFile.exists()) return false;

      final records = await getExportRecords();

      // 删除对应的物理文件（若存在）
      for (final r in records.where((r) => r.timestamp == timestamp)) {
        final f = File(r.filePath);
        if (await f.exists()) {
          await f.delete();
        }
      }

      records.removeWhere((r) => r.timestamp == timestamp);
      await recordsFile.writeAsString(
        jsonEncode(records.map((r) => r.toJson()).toList()),
      );
      return true;
    } catch (e) {
      debugPrint('删除导出记录失败: $e');
      return false;
    }
  }
}
