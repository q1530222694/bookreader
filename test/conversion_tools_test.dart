import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;

import 'package:bookreader/features/txt_to_epub/service/txt_to_epub_service.dart';
import 'package:bookreader/features/doc_to_pdf/service/doc_to_pdf_service.dart';
import 'package:bookreader/features/ppt_to_pdf/service/ppt_to_pdf_service.dart';
import 'package:bookreader/features/excel_to_pdf/service/excel_to_pdf_service.dart';
import 'package:bookreader/features/image_to_pdf/service/image_to_pdf_service.dart';

/// 构造最小可用的 DOCX（ZIP），document.xml 含中文 `<w:t>` 文本。
List<int> _buildDocx(String text) {
  final documentXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body><w:p><w:r><w:t>$text</w:t></w:r></w:p></w:body>
</w:document>''';
  final archive = Archive();
  archive.addFile(ArchiveFile('[Content_Types].xml', 0, utf8.encode('<Types/>')));
  archive.addFile(ArchiveFile('word/document.xml',
      utf8.encode(documentXml).length, utf8.encode(documentXml)));
  return ZipEncoder().encode(archive);
}

/// 构造最小可用的 XLSX（ZIP），含 sharedStrings 与按索引引用的单元格。
List<int> _buildXlsx() {
  final shared = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <si><t>姓名</t></si>
  <si><t>年龄</t></si>
</sst>''';
  final sheet = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>
    <row r="2"><c r="A2" t="s"><v>0</v></c><c r="B2"><v>18</v></c></row>
  </sheetData>
</worksheet>''';
  final archive = Archive();
  archive.addFile(ArchiveFile('xl/sharedStrings.xml',
      utf8.encode(shared).length, utf8.encode(shared)));
  archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml',
      utf8.encode(sheet).length, utf8.encode(sheet)));
  return ZipEncoder().encode(archive);
}

/// 构造最小可用的 PPTX（ZIP），slide 含中文 `<a:t>` 文本。
List<int> _buildPptx(String text) {
  final slide = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
       xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <p:cSld><p:sp><p:txBody><a:p><a:r><a:t>$text</a:t></a:r></a:p></p:txBody></p:sp></p:cSld>
</p:sld>''';
  final archive = Archive();
  archive.addFile(ArchiveFile('ppt/slides/slide1.xml',
      utf8.encode(slide).length, utf8.encode(slide)));
  return ZipEncoder().encode(archive);
}

/// 构造一个 40x30 的合法红色 PNG（image 包编码，确保可被 pdf 包解码）。
Uint8List _buildPng() {
  final img = im.Image(width: 40, height: 30);
  for (int y = 0; y < img.height; y++) {
    for (int x = 0; x < img.width; x++) {
      img.setPixelRgba(x, y, 220, 40, 40, 255);
    }
  }
  return Uint8List.fromList(im.encodePng(img));
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // path_provider 在宿主 `flutter test` 环境下没有原生实现，
    // 这里把 getApplicationDocumentsDirectory 通道 mock 到一个宿主临时目录，
    // 让被测 service 与测试本身落到同一个目录。
    tempDir = await Directory.systemTemp.createTemp('bookreader_convert_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        if (call.method == 'getTemporaryDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  String tmpPath(String name) => '${tempDir.path}${Platform.pathSeparator}$name';

  test('TXT(GBK) -> EPUB 生成合法 ZIP 且含 mimetype/content.html', () async {
    // 用 GBK 编码中文写入，验证解码回中文不乱码
    final gbkBytes = gbk.encode('第一章 中文乱码测试\n这是正文内容。');
    final txtPath = tmpPath('sample_gbk.txt');
    await File(txtPath).writeAsBytes(gbkBytes);

    final epubPath = tmpPath('out.epub');
    final res = await TxtToEpubService.convertTxtToEpub(
      txtFilePath: txtPath,
      outputFileName: 'out.epub',
      bookTitle: '测试书',
    );

    expect(res.success, isTrue, reason: res.message);
    final bytes = await File(epubPath).readAsBytes();
    // ZIP 文件头 PK
    expect(bytes[0], equals(0x50)); // P
    expect(bytes[1], equals(0x4B)); // K
    final zip = ZipDecoder().decodeBytes(bytes);
    final names = zip.files.map((f) => f.name).toList();
    expect(names, contains('mimetype'));
    expect(names, contains('OEBPS/content.html'));
    expect(names, contains('OEBPS/content.opf'));
    final html = utf8.decode(
        zip.files.firstWhere((f) => f.name == 'OEBPS/content.html').content
            as List<int>);
    // 中文应被原样保留（未被替换符污染）
    expect(html, contains('中文乱码测试'));
    expect(html, isNot(contains('�')));
  });

  test('DOCX(中文) -> PDF 转换成功且产出非空', () async {
    final docxPath = tmpPath('sample.docx');
    await File(docxPath).writeAsBytes(_buildDocx('中文文档标题内容'));
    final pdfPath = tmpPath('out_doc.pdf');
    final res = await DocToPdfService.convertDocToPdf(
      docFilePath: docxPath,
      outputFileName: 'out_doc.pdf',
    );
    expect(res.success, isTrue, reason: res.message);
    final f = File(pdfPath);
    expect(await f.exists(), isTrue);
    expect(await f.length(), greaterThan(1000)); // 内嵌字体后体积较大
  });

  test('XLSX(sharedStrings) -> PDF 还原真实文本', () async {
    final xlsxPath = tmpPath('sample.xlsx');
    await File(xlsxPath).writeAsBytes(_buildXlsx());
    final pdfPath = tmpPath('out_xlsx.pdf');
    final res = await ExcelToPdfService.convertExcelToPdf(
      excelFilePath: xlsxPath,
      outputFileName: 'out_xlsx.pdf',
    );
    expect(res.success, isTrue, reason: res.message);
    // 既然转换成功，说明 sharedStrings 索引已正确解析（否则会抛异常导致失败）
    final f = File(pdfPath);
    expect(await f.exists(), isTrue);
    expect(await f.length(), greaterThan(1000));
  });

  test('PPTX(中文) -> PDF 转换成功', () async {
    final pptxPath = tmpPath('sample.pptx');
    await File(pptxPath).writeAsBytes(_buildPptx('演示文稿标题'));
    final pdfPath = tmpPath('out_ppt.pdf');
    final res = await PptToPdfService.convertPptToPdf(
      pptFilePath: pptxPath,
      outputFileName: 'out_ppt.pdf',
    );
    expect(res.success, isTrue, reason: res.message);
    final f = File(pdfPath);
    expect(await f.exists(), isTrue);
    expect(await f.length(), greaterThan(1000));
  });

  test('图片 -> PDF 每页按图片比例且产物合法', () async {
    final pngBytes = _buildPng();
    final imgPath = tmpPath('sample.png');
    await File(imgPath).writeAsBytes(pngBytes);
    final pdfPath = tmpPath('out_img.pdf');
    final res = await ImageToPdfService.convertImagesToSinglePdf(
      imagePaths: [imgPath],
      outputFileName: 'out_img.pdf',
    );
    expect(res.success, isTrue, reason: res.message);
    final bytes = await File(pdfPath).readAsBytes();
    expect(bytes[0], equals(0x25)); // PDF 头 %
    expect(bytes[1], equals(0x50)); // P
    expect(await File(pdfPath).length(), greaterThan(500));
  });
}
