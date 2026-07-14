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
import '../model/ppt_to_pdf_model.dart';

/// PPTX 转 PDF 服务，使用纯 Dart 解析 PPTX（ZIP 格式）并提取文本生成 PDF。
///
/// 修复要点：
/// 1. 内嵌 CJK 中文字体（[CjkFontLoader]），中文不再渲染为空白/方块；
/// 2. 文本提取改为解析 `<a:t>` 文本节点，按幻灯片/段落聚合，去掉逐字符去标签的噪声；
/// 3. 字体字节经 [compute] 的 args 传入 isolate 注册。
class PptToPdfService {
  PptToPdfService._();

  static Future<ConversionResult> convertPptToPdf({
    required String pptFilePath,
    required String outputFileName,
  }) async {
    try {
      if (pptFilePath.isEmpty) {
        return ConversionResult.failure(message: '请选择一个PPT/PPTX文件');
      }

      final file = File(pptFilePath);
      if (!await file.exists()) {
        return ConversionResult.failure(message: '选择的PPT文件不存在');
      }

      final ext = pptFilePath.toLowerCase().split('.').last;
      if (ext != 'ppt' && ext != 'pptx') {
        return ConversionResult.failure(message: '只支持PPT和PPTX文件');
      }

      final outputDir = await getApplicationDocumentsDirectory();
      final outputPath = '${outputDir.path}${Platform.pathSeparator}$outputFileName';

      final fontBytes = await CjkFontLoader.loadBytes();

      final args = {
        'pptFilePath': pptFilePath,
        'outputPath': outputPath,
        'fontBytes': fontBytes,
      };

      Map<String, dynamic> result;
      try {
        result = await compute(_convertPptAndSave, args).timeout(const Duration(seconds: 120));
      } on TimeoutException {
        result = await _convertPptAndSave(args);
      } catch (e) {
        return ConversionResult.failure(message: '转换失败: ${e.toString()}');
      }

      if (result['success'] == true) {
        await saveExportRecord(
          sourceFileName: pptFilePath.split(Platform.pathSeparator).last,
          pdfFileName: outputFileName,
          filePath: outputPath,
        );

        return ConversionResult.success(message: '成功转换PPT为PDF', filePath: outputPath);
      } else {
        return ConversionResult.failure(message: result['message'] as String);
      }
    } catch (e) {
      return ConversionResult.failure(message: '转换失败: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> _convertPptAndSave(Map<String, dynamic> args) async {
    try {
      final pptFilePath = args['pptFilePath'] as String;
      final outputPath = args['outputPath'] as String;
      final fontBytes = args['fontBytes'] as Uint8List;

      final file = File(pptFilePath);
      final bytes = await file.readAsBytes();

      String plainText = '';
      try {
        plainText = _extractTextFromPptx(bytes);
      } catch (e) {
        plainText = '幻灯片内容提取失败或包含复杂元素，已采用默认提示。';
      }

      final cjkFont = pw.Font.ttf(
        fontBytes.buffer.asByteData(
          fontBytes.offsetInBytes,
          fontBytes.lengthInBytes,
        ),
      );

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: cjkFont, bold: cjkFont),
      );

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
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
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

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(await pdf.save());

      return {'success': true, 'message': '成功转换为PDF'};
    } catch (e) {
      return {'success': false, 'message': '转换失败: ${e.toString()}'};
    }
  }

  /// 从 PPTX 文件（ZIP 格式）提取纯文本。
  ///
  /// 逐张幻灯片解析，收集每张幻灯片中 `<a:t>` 文本节点，
  /// 段落（`<a:p>`）之间换行，幻灯片之间空行分隔。
  static String _extractTextFromPptx(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final textBuffer = StringBuffer();

    // PPTX 的 slide 内容位于 ppt/slides/slideX.xml
    final slideFiles = archive.files
        .where((f) =>
            f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'))
        .toList();

    // 按幻灯片序号排序，保证顺序正确
    slideFiles.sort((a, b) {
      final na = _slideIndex(a.name);
      final nb = _slideIndex(b.name);
      return na.compareTo(nb);
    });

    for (final file in slideFiles) {
      final xml = utf8.decode(file.content as List<int>);
      // 按 <a:p> 段落聚合 <a:t> 文本
      final paraRegex = RegExp(r'<a:p\b[^>]*>(.*?)</a:p>', dotAll: true);
      final textRegex = RegExp(r'<a:t\b[^>]*>(.*?)</a:t>', dotAll: true);
      for (final pMatch in paraRegex.allMatches(xml)) {
        final paraXml = pMatch.group(1) ?? '';
        final sb = StringBuffer();
        for (final tMatch in textRegex.allMatches(paraXml)) {
          sb.write(tMatch.group(1) ?? '');
        }
        textBuffer.writeln(_decodeXmlEntities(sb.toString()));
      }
      textBuffer.writeln();
    }

    final result =
        textBuffer.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return result.isEmpty ? '（幻灯片内容为空或无法解析）' : result;
  }

  /// 从 slide 文件名中提取序号，用于排序（如 slide12.xml -> 12）。
  static int _slideIndex(String name) {
    final match = RegExp(r'slide(\d+)\.xml').firstMatch(name);
    return match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
  }

  /// 还原 XML 实体。
  static String _decodeXmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  static Future<Directory> getPdfOutputDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${docDir.path}${Platform.pathSeparator}exported_pdfs');
    if (!await pdfDir.exists()) await pdfDir.create(recursive: true);
    return pdfDir;
  }

  static Future<String> _getExportRecordsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}${Platform.pathSeparator}ppt2pdf_export_records.json';
  }

  static Future<List<ExportRecord>> getExportRecords() async {
    try {
      final recordsFile = File(await _getExportRecordsFile());
      if (!await recordsFile.exists()) return [];
      final jsonString = await recordsFile.readAsString();
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList.map((json) => ExportRecord.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveExportRecord({required String sourceFileName, required String pdfFileName, required String filePath}) async {
    try {
      final records = await getExportRecords();
      records.add(ExportRecord(sourceFileName: sourceFileName, pdfFileName: pdfFileName, timestamp: DateTime.now().millisecondsSinceEpoch, filePath: filePath));
      final recordsFile = File(await _getExportRecordsFile());
      final jsonString = jsonEncode(records.map((r) => r.toJson()).toList());
      await recordsFile.writeAsString(jsonString);
    } catch (e) {
      // ignore
    }
  }

  /// 删除导出记录及其对应的 PDF 文件（按时间戳唯一标识）
  static Future<bool> deleteExportRecord(int timestamp) async {
    try {
      final recordsFile = File(await _getExportRecordsFile());
      if (!await recordsFile.exists()) return false;

      final records = await getExportRecords();
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
