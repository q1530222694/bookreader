import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../model/txt_to_epub_model.dart';

/// TxtToEpubService 处理 TXT 文件到 EPUB 的转换逻辑。
///
/// 关键点修复（此前生成的 .epub 实为裸 XHTML 文本，并非合法 EPUB，任何阅读器都打不开）：
/// 1. 用 [archive] 包拼出标准 EPUB（ZIP：mimetype / META-INF/container.xml /
///    OEBPS/content.opf / OEBPS/toc.ncx / OEBPS/content.html），可被阅读器正常打开；
/// 2. 编码自动探测：先按 UTF-8（不允许乱码字节），失败或含替换符则回退 GBK，
///    解决中文 TXT（常见 GBK）导入后乱码的问题；
/// 3. 正文做 XML 转义并按空行切片为段落，避免 `< & >` 破坏 XML 导致无法解析。
class TxtToEpubService {
  TxtToEpubService._();

  /// 将 TXT 文件转换为 EPUB 格式。
  ///
  /// 参数：
  /// - [txtFilePath] TXT 文件的完整路径
  /// - [outputFileName] 输出 EPUB 文件名（不包含路径）
  /// - [bookTitle] EPUB 书籍标题（可选，默认为文件名）
  ///
  /// 返回转换结果，包含成功状态和 EPUB 路径。
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

      final title =
          bookTitle ?? outputFileName.replaceAll(RegExp(r'\.epub$'), '');

      // 在后台 isolate 中生成 EPUB，避免阻塞主线程
      final args = {
        'txtFilePath': txtFilePath,
        'outputPath': outputPath,
        'bookTitle': title,
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

  /// 后台 isolate 执行的 EPUB 生成函数。
  ///
  /// 参数 args 包含：
  /// - txtFilePath: TXT 文件路径
  /// - outputPath: EPUB 输出路径
  /// - bookTitle: 书籍标题
  static Future<Map<String, dynamic>> _generateEpubAndSave(
      Map<String, dynamic> args) async {
    try {
      final txtFilePath = args['txtFilePath'] as String;
      final outputPath = args['outputPath'] as String;
      final bookTitle = args['bookTitle'] as String;

      // 读取 TXT 原始字节并按编码探测解码（UTF-8 → GBK）
      final txtFile = File(txtFilePath);
      final rawBytes = await txtFile.readAsBytes();
      final content = _decodeText(rawBytes);

      // 组装合法 EPUB 并写入
      final epubBytes = _buildEpubBytes(bookTitle, content);

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(epubBytes, flush: true);

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

  /// 编码探测：优先 UTF-8（严格，遇到非法字节会失败），否则回退 GBK。
  /// 这样无论是 UTF-8 还是中文常见的 GBK 编码 TXT 都不会乱码。
  static String _decodeText(List<int> bytes) {
    try {
      final utf8Str = utf8.decode(bytes, allowMalformed: false);
      // 若含替换符，视为编码识别失败，回退 GBK
      if (!utf8Str.contains('\u{FFFD}')) {
        return utf8Str;
      }
    } catch (_) {
      // UTF-8 解码失败，继续尝试 GBK
    }
    try {
      return gbk.decode(bytes);
    } catch (_) {
      // 极端情况下兜底：忽略非法字节按 UTF-8 读取
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  /// 将字符串转义为合法的 XML 文本（防止 `< & >` 破坏文档结构）。
  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  /// 将 TXT 正文按空行切分为段落，段内换行用 <br/> 连接。
  static String _buildParagraphs(String content) {
    final buffer = StringBuffer();
    // 按一个或多个空行分段
    final blocks = content.split(RegExp(r'\n\s*\n'));
    for (final block in blocks) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) continue;
      final lines = trimmed
          .split('\n')
          .map((l) => _escapeXml(l.trim()))
          .where((l) => l.isNotEmpty)
          .join('<br/>');
      buffer.writeln('    <p>$lines</p>');
    }
    final result = buffer.toString().trim();
    return result.isEmpty ? '    <p>（内容为空）</p>' : result;
  }

  /// 生成标准 EPUB（ZIP）字节流。
  static List<int> _buildEpubBytes(String title, String content) {
    final safeTitle = _escapeXml(title);
    final uid = 'bookreader-${DateTime.now().microsecondsSinceEpoch}-'
        '${Random().nextInt(999999)}';
    final paragraphs = _buildParagraphs(content);

    // 1) mimetype：必须为第一个文件且存储（不压缩，compressionLevel=0）
    final mimeBytes = utf8.encode('application/epub+zip');
    final mimeFile = ArchiveFile('mimetype', mimeBytes.length, mimeBytes)
      ..compressionLevel = 0;

    // 2) META-INF/container.xml
    const containerXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';

    // 3) OEBPS/content.opf
    final contentOpf = '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>$safeTitle</dc:title>
    <dc:language>zh</dc:language>
    <dc:identifier id="bookid">urn:uuid:$uid</dc:identifier>
    <dc:creator>BookReader</dc:creator>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="content" href="content.html" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="content"/>
  </spine>
</package>''';

    // 4) OEBPS/toc.ncx
    final tocNcx = '''
<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="urn:uuid:$uid"/>
    <meta name="dtb:depth" content="1"/>
  </head>
  <docTitle><text>$safeTitle</text></docTitle>
  <navMap>
    <navPoint id="np1" playOrder="1">
      <navLabel><text>$safeTitle</text></navLabel>
      <content src="content.html"/>
    </navPoint>
  </navMap>
</ncx>''';

    // 5) OEBPS/content.html
    final contentHtml = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <meta charset="UTF-8"/>
  <title>$safeTitle</title>
  <style>
    body { font-family: sans-serif; line-height: 1.8; padding: 0 1em; }
    h1 { font-size: 1.4em; text-align: center; }
    p { text-indent: 2em; margin: 0.6em 0; }
  </style>
</head>
<body>
  <h1>$safeTitle</h1>
$paragraphs
</body>
</html>''';

    final archive = Archive();
    archive.addFile(mimeFile);
    archive.addFile(ArchiveFile(
      'META-INF/container.xml',
      utf8.encode(containerXml).length,
      utf8.encode(containerXml),
    ));
    archive.addFile(ArchiveFile(
      'OEBPS/content.opf',
      utf8.encode(contentOpf).length,
      utf8.encode(contentOpf),
    ));
    archive.addFile(ArchiveFile(
      'OEBPS/toc.ncx',
      utf8.encode(tocNcx).length,
      utf8.encode(tocNcx),
    ));
    archive.addFile(ArchiveFile(
      'OEBPS/content.html',
      utf8.encode(contentHtml).length,
      utf8.encode(contentHtml),
    ));

    return ZipEncoder().encode(archive);
  }

  /// 获取 EPUB 输出目录
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

  /// 删除转换记录及其对应的 EPUB 文件（按时间戳唯一标识）
  static Future<bool> deleteExportRecord(int timestamp) async {
    try {
      final recordsFile = await _getExportRecordsFile();
      if (!await recordsFile.exists()) return false;

      final content = await recordsFile.readAsString();
      final jsonList = json.decode(content) as List;
      final records = jsonList
          .map((item) => ExportRecord.fromJson(item as Map<String, dynamic>))
          .toList();

      // 删除对应的物理文件（若存在）
      for (final r in records.where((r) => r.timestamp == timestamp)) {
        final f = File(r.filePath);
        if (await f.exists()) {
          await f.delete();
        }
      }

      records.removeWhere((r) => r.timestamp == timestamp);
      await recordsFile.writeAsString(
        json.encode(records.map((r) => r.toJson()).toList()),
      );
      return true;
    } catch (e) {
      debugPrint('删除转换记录失败: $e');
      return false;
    }
  }
}
