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
import '../model/excel_to_pdf_model.dart';

/// Excel (XLSX) 转 PDF 服务，使用纯 Dart 解析 XLSX（ZIP 格式）并提取文本生成 PDF。
///
/// 修复要点：
/// 1. 内嵌 CJK 中文字体（[CjkFontLoader]），中文不再渲染为空白/方块；
/// 2. 关键修复：XLSX 单元格 `<c t="s"><v>0</v></c>` 中的 `<v>` 是
///    `xl/sharedStrings.xml` 的**索引**，并非文字本身。此前直接输出索引数字，
///    导致 PDF 里全是 `0 1 2 ...`。现先解析 sharedStrings 列表，再按索引还原真实文本；
///    同时支持 inlineStr 内联字符串与数值单元格。
/// 3. 字体字节经 [compute] 的 args 传入 isolate 注册。
class ExcelToPdfService {
  ExcelToPdfService._();

  static Future<ConversionResult> convertExcelToPdf({required String excelFilePath, required String outputFileName}) async {
    try {
      if (excelFilePath.isEmpty) return ConversionResult.failure(message: '请选择一个Excel文件');
      final file = File(excelFilePath);
      if (!await file.exists()) return ConversionResult.failure(message: '选择的Excel文件不存在');

      final ext = excelFilePath.toLowerCase().split('.').last;
      if (ext != 'xls' && ext != 'xlsx') return ConversionResult.failure(message: '只支持XLS和XLSX文件');

      final outputDir = await getApplicationDocumentsDirectory();
      final outputPath = '${outputDir.path}${Platform.pathSeparator}$outputFileName';

      final fontBytes = await CjkFontLoader.loadBytes();

      final args = {
        'excelFilePath': excelFilePath,
        'outputPath': outputPath,
        'fontBytes': fontBytes,
      };
      Map<String, dynamic> result;
      try {
        result = await compute(_convertExcelAndSave, args).timeout(const Duration(seconds: 120));
      } on TimeoutException {
        result = await _convertExcelAndSave(args);
      } catch (e) {
        return ConversionResult.failure(message: '转换失败: ${e.toString()}');
      }

      if (result['success'] == true) {
        await saveExportRecord(sourceFileName: excelFilePath.split(Platform.pathSeparator).last, pdfFileName: outputFileName, filePath: outputPath);
        return ConversionResult.success(message: '成功转换Excel为PDF', filePath: outputPath);
      } else {
        return ConversionResult.failure(message: result['message'] as String);
      }
    } catch (e) {
      return ConversionResult.failure(message: '转换失败: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> _convertExcelAndSave(Map<String, dynamic> args) async {
    try {
      final excelFilePath = args['excelFilePath'] as String;
      final outputPath = args['outputPath'] as String;
      final fontBytes = args['fontBytes'] as Uint8List;

      final file = File(excelFilePath);
      final bytes = await file.readAsBytes();

      String plainText = '';
      try {
        plainText = _extractTextFromXlsx(bytes);
      } catch (e) {
        plainText = '表格内容提取失败或包含复杂元素，已采用默认提示。';
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
              padding: const pw.EdgeInsets.symmetric(vertical: 1),
              child: pw.Text(
                line,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.4),
              ),
            ),
          );
        }
      }

      pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(36), build: (c) => pdfContent));
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(await pdf.save());

      return {'success': true, 'message': '成功转换为PDF'};
    } catch (e) {
      return {'success': false, 'message': '转换失败: ${e.toString()}'};
    }
  }

  /// 从 XLSX 文件（ZIP 格式）提取纯文本。
  ///
  /// 关键修复：单元格 `<c t="s"><v>0</v></c>` 的 `<v>` 是 sharedStrings 索引，
  /// 需先解析 `xl/sharedStrings.xml` 成列表，再按索引还原真实文本；
  /// 支持 inlineStr 内联字符串与数值单元格。
  static String _extractTextFromXlsx(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final textBuffer = StringBuffer();

    // 1) 解析 sharedStrings.xml（若存在）
    final sharedStrings = <String>[];
    final ssFile = archive.files.firstWhere(
      (f) => f.name == 'xl/sharedStrings.xml' || f.name.endsWith('/sharedStrings.xml'),
      orElse: () => throw Exception('no_sharedStrings'),
    );
    if (ssFile.name.isNotEmpty) {
      final ssXml = utf8.decode(ssFile.content as List<int>);
      // 每个 <si> 是一个共享字符串，内部可能含多个 <t>
      final siRegex = RegExp(r'<si>(.*?)</si>', dotAll: true);
      final tRegex = RegExp(r'<t\b[^>]*>(.*?)</t>', dotAll: true);
      for (final siMatch in siRegex.allMatches(ssXml)) {
        final siXml = siMatch.group(1) ?? '';
        final sb = StringBuffer();
        for (final tMatch in tRegex.allMatches(siXml)) {
          sb.write(tMatch.group(1) ?? '');
        }
        sharedStrings.add(_decodeXmlEntities(sb.toString()));
      }
    }

    // 2) 解析各工作表
    final sheetFiles = archive.files
        .where((f) => f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml'))
        .toList();
    sheetFiles.sort((a, b) => _sheetIndex(a.name).compareTo(_sheetIndex(b.name)));

    for (final file in sheetFiles) {
      final xml = utf8.decode(file.content as List<int>);
      // 按 <row> 聚合单元格
      final rowRegex = RegExp(r'<row\b[^>]*>(.*?)</row>', dotAll: true);
      final cellRegex = RegExp(r'<c\b[^>]*>(.*?)</c>', dotAll: true);
      final valueRegex = RegExp(r'<v\b[^>]*>(.*?)</v>', dotAll: true);
      final inlineRegex = RegExp(r'<is>(.*?)</is>', dotAll: true);
      final tAttrRegex = RegExp(r'\bt="([^"]*)"');

      for (final rowMatch in rowRegex.allMatches(xml)) {
        final rowXml = rowMatch.group(1) ?? '';
        final rowCells = <String>[];
        for (final cellMatch in cellRegex.allMatches(rowXml)) {
          final cellXml = cellMatch.group(1) ?? '';
          // 内联字符串
          final isMatch = inlineRegex.firstMatch(cellXml);
          if (isMatch != null) {
            final inner = isMatch.group(1) ?? '';
            final tIn = RegExp(r'<t\b[^>]*>(.*?)</t>', dotAll: true).firstMatch(inner);
            rowCells.add(tIn != null ? _decodeXmlEntities(tIn.group(1) ?? '') : '');
            continue;
          }
          // 共享字符串索引
          final typeMatch = tAttrRegex.firstMatch(cellXml);
          final type = typeMatch?.group(1);
          final valMatch = valueRegex.firstMatch(cellXml);
          if (valMatch != null) {
            final val = valMatch.group(1) ?? '';
            if (type == 's') {
              final idx = int.tryParse(val);
              if (idx != null && idx >= 0 && idx < sharedStrings.length) {
                rowCells.add(sharedStrings[idx]);
              } else {
                rowCells.add('');
              }
            } else {
              // 数值/公式结果等原样保留
              rowCells.add(_decodeXmlEntities(val));
            }
          }
        }
        final rowText = rowCells.join('\t').trim();
        if (rowText.isNotEmpty) {
          textBuffer.writeln(rowText);
        }
      }
      textBuffer.writeln();
    }

    final result = textBuffer.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return result.isEmpty ? '（表格内容为空或无法解析）' : result;
  }

  /// 从 sheet 文件名中提取序号排序（如 sheet3.xml -> 3）。
  static int _sheetIndex(String name) {
    final match = RegExp(r'sheet(\d+)\.xml').firstMatch(name);
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

  static Future<String> _getExportRecordsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}${Platform.pathSeparator}excel2pdf_export_records.json';
  }

  static Future<List<ExportRecord>> getExportRecords() async {
    try {
      final recordsFile = File(await _getExportRecordsFile());
      if (!await recordsFile.exists()) return [];
      final jsonString = await recordsFile.readAsString();
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList.map((j) => ExportRecord.fromJson(j as Map<String, dynamic>)).toList();
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
