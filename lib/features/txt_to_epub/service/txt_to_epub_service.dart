import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../model/txt_to_epub_model.dart';

/// TxtToEpubService 处理TXT文件到EPUB的转换逻辑
class TxtToEpubService {
  TxtToEpubService._();

  /// 将TXT文件转换为EPUB格式
  ///
  /// 参数：
  /// - [txtFilePath] TXT文件的完整路径
  /// - [outputFileName] 输出EPUB文件名（不包含路径）
  /// - [bookTitle] EPUB书籍标题（可选，默认为文件名）
  ///
  /// 返回转换结果，包含成功状态和EPUB路径
  static Future<ConversionResult> convertTxtToEpub({
    required String txtFilePath,
    required String outputFileName,
    String? bookTitle,
  }) async {
    try {
      // 验证输入
      if (txtFilePath.isEmpty) {
        return ConversionResult.failure(message: '请选择一个TXT文件');
      }

      // 检查文件是否存在
      final txtFile = File(txtFilePath);
      if (!await txtFile.exists()) {
        return ConversionResult.failure(message: '选择的TXT文件不存在');
      }

      // 获取输出目录
      final outputDir = await getApplicationDocumentsDirectory();
      final outputPath =
          '${outputDir.path}${Platform.pathSeparator}$outputFileName';

      // 在后台isolate中生成EPUB，避免阻塞主线程
      final args = {
        'txtFilePath': txtFilePath,
        'outputPath': outputPath,
        'bookTitle': bookTitle ?? outputFileName.replaceAll('.epub', ''),
      };

      Map<String, dynamic> result;
      try {
        result = await compute(_generateEpubAndSave, args)
            .timeout(const Duration(seconds: 60));
      } on TimeoutException {
        // 如果超时，回退到主线程执行
        result = await _generateEpubAndSave(args);
      } catch (e) {
        return ConversionResult.failure(message: '转换失败: ${e.toString()}');
      }

      if (result['success'] == true) {
        return ConversionResult.success(
          message: '成功转换TXT为EPUB',
          filePath: outputPath,
        );
      } else {
        return ConversionResult.failure(
            message: '转换失败: ${result['message']}');
      }
    } catch (e) {
      return ConversionResult.failure(message: '转换失败: ${e.toString()}');
    }
  }

  /// 后台isolate执行的EPUB生成函数
  ///
  /// 参数args包含：
  /// - txtFilePath: TXT文件路径
  /// - outputPath: EPUB输出路径
  /// - bookTitle: 书籍标题
  static Future<Map<String, dynamic>> _generateEpubAndSave(
      Map<String, dynamic> args) async {
    try {
      final txtFilePath = args['txtFilePath'] as String;
      final outputPath = args['outputPath'] as String;
      final bookTitle = args['bookTitle'] as String;

      // 读取TXT文件内容
      final txtFile = File(txtFilePath);
      final content = await txtFile.readAsString();

      // 简单的EPUB框架（完整的EPUB格式）
      // 将内容写入EPUB文件（实际上是ZIP格式）
      // 这里使用简化版本，仅写入主要内容文件

      // 生成EPUB容器
      final epub = _createEpubStructure(bookTitle, content);

      // 写入文件
      final outputFile = File(outputPath);
      await outputFile.writeAsString(epub);

      return {
        'success': true,
        'message': '转换成功',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '后台转换失败: ${e.toString()}',
      };
    }
  }

  /// 创建基础EPUB结构
  ///
  /// 返回EPUB格式的XML内容（简化版本）
  static String _createEpubStructure(String title, String content) {
    // 这是一个简化版本，完整的EPUB需要压缩多个XML文件
    // 实际项目可使用 epub_writer 包来创建完整的EPUB格式
    return '''<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <title>$title</title>
  <meta charset="UTF-8"/>
  <style>
    body { font-family: 'Noto Sans', sans-serif; line-height: 1.6; }
    p { margin: 1em 0; text-indent: 2em; }
  </style>
</head>
<body>
  <h1>$title</h1>
  <div>
    ${content.replaceAll('\n', '</p><p>')}
  </div>
</body>
</html>''';
  }

  /// 获取EPUB输出目录
  static Future<Directory> getEpubOutputDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final epubDir =
        Directory('${docDir.path}${Platform.pathSeparator}exported_epubs');

    // 如果目录不存在，创建它
    if (!await epubDir.exists()) {
      await epubDir.create(recursive: true);
    }

    return epubDir;
  }

  /// 获取转换记录文件路径
  static Future<File> _getExportRecordsFile() async {
    final docDir = await getApplicationDocumentsDirectory();
    return File(
        '${docDir.path}${Platform.pathSeparator}txt2epub_export_records.json');
  }

  /// 保存转换记录到本地
  static Future<void> saveExportRecord(ExportRecord record) async {
    try {
      final recordsFile = await _getExportRecordsFile();
      List<ExportRecord> records = [];

      // 读取已有的记录
      if (await recordsFile.exists()) {
        final content = await recordsFile.readAsString();
        final jsonList = json.decode(content) as List;
        records = jsonList
            .map((item) => ExportRecord.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      // 添加新记录
      records.add(record);

      // 保存回文件
      await recordsFile.writeAsString(
        json.encode(records.map((r) => r.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('保存转换记录失败: $e');
    }
  }

  /// 获取所有转换记录
  static Future<List<ExportRecord>> getExportRecords() async {
    try {
      final recordsFile = await _getExportRecordsFile();

      if (!await recordsFile.exists()) {
        return [];
      }

      final content = await recordsFile.readAsString();
      final jsonList = json.decode(content) as List;
      return jsonList
          .map((item) => ExportRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('获取转换记录失败: $e');
      return [];
    }
  }
}
