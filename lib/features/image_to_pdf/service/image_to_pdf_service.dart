import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import '../service/filepicker_diagnostics.dart';

import '../model/export_record_model.dart';
import '../model/image_to_pdf_model.dart';

/// ImageToPdfService 处理图片到PDF的转换逻辑
class ImageToPdfService {
  ImageToPdfService._();

  /// 将多张图片按顺序转换为单个PDF文件
  ///
  /// 参数：
  /// - [imagePaths] 图片文件路径列表，按转换顺序排列
  /// - [outputFileName] 输出PDF文件名（不包含路径）
  ///
  /// 返回转换结果，包含成功状态和PDF路径
  static Future<ConversionResult> convertImagesToSinglePdf({
    required List<String> imagePaths,
    required String outputFileName,
  }) async {
    try {
      // 验证输入
      if (imagePaths.isEmpty) {
        return ConversionResult.failure(message: '请选择至少一张图片');
      }

      // 获取输出目录（应用文档目录）
      final outputDir = await getApplicationDocumentsDirectory();
      final outputPath =
          '${outputDir.path}${Platform.pathSeparator}$outputFileName';

      // 在后台 isolate 中生成并写入 PDF，避免主线程阻塞
      await FilepickerDiagnostics.writeLog('convertImagesToSinglePdf(): 开始在 isolate 中生成PDF');

      final args = {
        'imagePaths': imagePaths,
        'outputPath': outputPath,
      };

      Map<String, dynamic> result;
      try {
        result = await compute(generatePdfAndSave, args)
            .timeout(const Duration(seconds: 30));
      } on TimeoutException catch (e) {
        await FilepickerDiagnostics.writeLog('compute 超时: $e，改为主线程执行 PDF 生成');
        result = await generatePdfAndSave(args);
      } catch (e) {
        await FilepickerDiagnostics.writeLog('compute 调用失败: $e');
        return ConversionResult.failure(message: '转换失败: ${e.toString()}');
      }

      if (result['success'] == true) {
        await FilepickerDiagnostics.writeLog('convertImagesToSinglePdf(): isolate 生成成功 $outputPath');
        return ConversionResult.success(
          message: '成功转换 ${imagePaths.length} 张图片为PDF',
          filePath: outputPath,
        );
      } else {
        await FilepickerDiagnostics.writeLog('convertImagesToSinglePdf(): isolate 生成失败: ${result['message']}');
        return ConversionResult.failure(message: '转换失败: ${result['message']}');
      }
    } catch (e) {
      return ConversionResult.failure(
        message: '转换失败: ${e.toString()}',
      );
    }
  }

  /// 根据图片原始尺寸计算 PDF 页面尺寸，使每页与图片同比例、铺满且不变形。
  ///
  /// [imageBytes] 图片二进制；支持 PNG / JPEG 解析宽高，其它格式按 A4 兜底。
  static pdf.PdfPageFormat _getPageFormatFromImage(Uint8List imageBytes) {
    final size = _imageSize(imageBytes);
    if (size == null) return pdf.PdfPageFormat.a4;

    final double w = size.$1.toDouble();
    final double h = size.$2.toDouble();
    if (w <= 0 || h <= 0) return pdf.PdfPageFormat.a4;

    // 限制最大边为 2000pt，避免超大像素导致 PDF 页面尺寸离谱
    final double maxSide = w >= h ? w : h;
    final double scale = maxSide > 2000 ? 2000 / maxSide : 1.0;
    return pdf.PdfPageFormat(w * scale, h * scale);
  }

  /// 读取图片像素尺寸（PNG / JPEG），失败返回 null。
  static (int, int)? _imageSize(Uint8List bytes) {
    try {
      if (bytes.length > 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        // PNG：IHDR 在偏移 16 起，宽 4 字节、高 4 字节（大端）
        final w = _readUint32BE(bytes, 16);
        final h = _readUint32BE(bytes, 20);
        return (w, h);
      }
      if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
        // JPEG：扫描 SOF 标记获取尺寸
        int i = 2;
        while (i < bytes.length - 9) {
          if (bytes[i] != 0xFF) {
            i++;
            continue;
          }
          final marker = bytes[i + 1];
          // SOF0..SOF15（排除 C4/C8/CC 等保留标记）
          if (marker >= 0xC0 &&
              marker <= 0xCF &&
              marker != 0xC4 &&
              marker != 0xC8 &&
              marker != 0xCC) {
            final h = _readUint16BE(bytes, i + 5);
            final w = _readUint16BE(bytes, i + 7);
            return (w, h);
          }
          // 段长度
          final len = _readUint16BE(bytes, i + 2);
          if (len <= 0) break;
          i += 2 + len;
        }
      }
    } catch (_) {
      // 解析失败忽略，返回 null 由调用方兜底
    }
    return null;
  }

  /// 大端读取 32 位无符号整数。
  static int _readUint32BE(Uint8List b, int offset) {
    return (b[offset] << 24) |
        (b[offset + 1] << 16) |
        (b[offset + 2] << 8) |
        b[offset + 3];
  }

  /// 大端读取 16 位无符号整数。
  static int _readUint16BE(Uint8List b, int offset) {
    return (b[offset] << 8) | b[offset + 1];
  }

  /// 获取PDF输出目录路径
  static Future<Directory> getPdfOutputDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${docDir.path}${Platform.pathSeparator}exported_pdfs');
    
    // 如果目录不存在，创建它
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    
    return pdfDir;
  }

  /// 获取导出记录文件路径
  static Future<File> _getExportRecordsFile() async {
    final docDir = await getApplicationDocumentsDirectory();
    return File('${docDir.path}${Platform.pathSeparator}export_records.json');
  }

  /// 保存导出记录
  static Future<void> saveExportRecord(ExportRecord record) async {
    try {
      final recordFile = await _getExportRecordsFile();
      
      // 读取现有记录
      List<ExportRecord> records = [];
      if (await recordFile.exists()) {
        final content = await recordFile.readAsString();
        final jsonList = jsonDecode(content) as List<dynamic>;
        records = jsonList
            .map((item) => ExportRecord.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      
      // 添加新记录（去重：同ID的记录只保留最新的）
      records.removeWhere((r) => r.id == record.id);
      records.insert(0, record);
      
      // 保存更新后的记录列表
      final jsonData = records.map((r) => r.toJson()).toList();
      await recordFile.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      // 记录保存失败，但不中断导出流程
      debugPrint('保存导出记录失败: $e');
    }
  }

  /// 获取所有导出记录（按导出时间倒序）
  static Future<List<ExportRecord>> getExportRecords() async {
    try {
      final recordFile = await _getExportRecordsFile();
      
      if (!await recordFile.exists()) {
        return [];
      }
      
      final content = await recordFile.readAsString();
      final jsonList = jsonDecode(content) as List<dynamic>;
      
      return jsonList
          .map((item) => ExportRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('读取导出记录失败: $e');
      return [];
    }
  }

  /// 删除导出记录及其对应的PDF文件
  static Future<bool> deleteExportRecord(String recordId) async {
    try {
      final recordFile = await _getExportRecordsFile();
      
      // 读取所有记录
      List<ExportRecord> records = [];
      if (await recordFile.exists()) {
        final content = await recordFile.readAsString();
        final jsonList = jsonDecode(content) as List<dynamic>;
        records = jsonList
            .map((item) => ExportRecord.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      
      // 查找要删除的记录
      final targetRecord = records.firstWhere(
        (r) => r.id == recordId,
        orElse: () => throw Exception('记录不存在'),
      );
      
      // 删除PDF文件
      final pdfFile = File(targetRecord.filePath);
      if (await pdfFile.exists()) {
        await pdfFile.delete();
      }
      
      // 删除记录
      records.removeWhere((r) => r.id == recordId);
      
      // 保存更新的记录列表
      final jsonData = records.map((r) => r.toJson()).toList();
      await recordFile.writeAsString(jsonEncode(jsonData));
      
      return true;
    } catch (e) {
      debugPrint('删除导出记录失败: $e');
      return false;
    }
  }

  /// 更新导出记录的状态
  static Future<bool> updateExportRecord(ExportRecord record) async {
    try {
      final recordFile = await _getExportRecordsFile();
      
      // 读取所有记录
      List<ExportRecord> records = [];
      if (await recordFile.exists()) {
        final content = await recordFile.readAsString();
        final jsonList = jsonDecode(content) as List<dynamic>;
        records = jsonList
            .map((item) => ExportRecord.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      
      // 更新记录
      final index = records.indexWhere((r) => r.id == record.id);
      if (index >= 0) {
        records[index] = record;
      } else {
        return false;
      }
      
      // 保存更新的记录列表
      final jsonData = records.map((r) => r.toJson()).toList();
      await recordFile.writeAsString(jsonEncode(jsonData));
      
      return true;
    } catch (e) {
      debugPrint('更新导出记录失败: $e');
      return false;
    }
  }
}

/// 在 isolate 中生成 PDF 并写入到指定路径的辅助函数
/// 参数为 Map 包含 'imagePaths' (List<String>) 和 'outputPath' (String)
Future<Map<String, dynamic>> generatePdfAndSave(Map<String, dynamic> args) async {
  try {
    await FilepickerDiagnostics.writeLog('generatePdfAndSave(): isolate 开始');
    final List<dynamic> pathsDyn = args['imagePaths'] as List<dynamic>;
    final List<String> imagePaths = pathsDyn.map((e) => e as String).toList();
    final String outputPath = args['outputPath'] as String;

    final pw.Document pdfDoc = pw.Document();

    for (int i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        return {'success': false, 'message': '图片不存在: $imagePath'};
      }

      final imageBytes = await imageFile.readAsBytes();
      final image = pw.MemoryImage(imageBytes);

      // 页面尺寸与图片同比例，图片铺满且不变形
      final pageFormat = ImageToPdfService._getPageFormatFromImage(imageBytes);
      pdfDoc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) {
            return pw.Image(image, fit: pw.BoxFit.fill);
          },
        ),
      );
    }

    final outputFile = File(outputPath);
    final pdfBytes = await pdfDoc.save();
    await outputFile.writeAsBytes(pdfBytes);

    await FilepickerDiagnostics.writeLog('generatePdfAndSave(): isolate 写入完成: $outputPath');
    return {'success': true, 'message': 'ok'};
  } catch (e) {
    await FilepickerDiagnostics.writeLog('generatePdfAndSave(): isolate 异常: $e');
    return {'success': false, 'message': e.toString()};
  }
}
