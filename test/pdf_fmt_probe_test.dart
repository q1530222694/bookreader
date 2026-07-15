import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' as pdfpkg;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

Future<void> _writeSamplePdf(String path) async {
  final doc = pw.Document();
  for (var i = 0; i < 5; i++) {
    doc.addPage(pw.Page(build: (c) => pw.Center(child: pw.Text('Hello PDF page $i'))));
  }
  await File(path).writeAsBytes(await doc.save());
}

void main() {
  testWidgets('png vs jpeg render on windows', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final path = '${Directory.systemTemp.path}/pdfdbg_sample.pdf';
    await _writeSamplePdf(path);
    final document = await pdfx.PdfDocument.openFile(path);
    final page = await document.getPage(1);
    // Pattern A: PNG (our old/crashing path)
    try {
      final imgPng = await page.render(
        width: 1200,
        height: 1697,
        format: pdfx.PdfPageImageFormat.png,
      );
      print('PROBE_PNG bytes=${imgPng?.bytes?.length}');
    } catch (e) {
      print('PROBE_PNG_ERROR $e');
    }
    // Pattern B: JPEG + white bg (pdfx proven path)
    try {
      final imgJpg = await page.render(
        width: 1200,
        height: 1697,
        format: pdfx.PdfPageImageFormat.jpeg,
        backgroundColor: '#ffffff',
      );
      print('PROBE_JPEG bytes=${imgJpg?.bytes?.length}');
    } catch (e) {
      print('PROBE_JPEG_ERROR $e');
    }
    await page.close();
    await document.close();
    print('PROBE_DONE');
  });
}
