import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:archive/archive.dart';

import '../model/ppt_to_pdf_model.dart';

/// PPTX 转 PDF 服务，使用纯 Dart 解析 PPTX（ZIP 格式）并提取文本生成 PDF
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

      final args = {'pptFilePath': pptFilePath, 'outputPath': outputPath};

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

      final file = File(pptFilePath);
      final bytes = await file.readAsBytes();

      String plainText = '';
      try {
        plainText = await _extractTextFromPptx(bytes);
      } catch (e) {
        plainText = '幻灯片内容提取失败或包含复杂元素，已采用默认提示。';
      }

      final pdf = pw.Document();

      final lines = plainText.split('\n');
      List<pw.Widget> pdfContent = [];

      for (final line in lines) {
        if (line.isEmpty) {
          pdfContent.add(pw.SizedBox(height: 10));
        } else {
          pdfContent.add(
            pw.Text(
              line,
              style: pw.TextStyle(fontSize: 12, font: pw.Font.helvetica()),
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

  static Future<String> _extractTextFromPptx(List<int> bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final textBuffer = StringBuffer();

    // PPTX 的 slide 内容通常位于 ppt/slides/slideX.xml
    final slideFiles = archive.files.where((f) => f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'));

    for (final file in slideFiles) {
      final xml = utf8.decode(file.content as List<int>);
      bool inTag = false;
      for (int i = 0; i < xml.length; i++) {
        final ch = xml[i];
        if (ch == '<') {
          inTag = true;
          if (xml.substring(i).startsWith('<p:') || xml.substring(i).startsWith('<a:') || xml.substring(i).startsWith('<p>')) {
            if (textBuffer.isNotEmpty && !textBuffer.toString().endsWith('\n')) textBuffer.write('\n');
          }
        } else if (ch == '>') {
          inTag = false;
        } else if (!inTag) {
          if (ch != '\n' && ch != '\r' && ch != '\t') textBuffer.write(ch);
        }
      }
      textBuffer.write('\n\n');
    }

    final result = textBuffer.toString().replaceAll(RegExp(r'\n\n+'), '\n').trim();
    return result.isEmpty ? '（幻灯片内容为空或无法解析）' : result;
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
}
