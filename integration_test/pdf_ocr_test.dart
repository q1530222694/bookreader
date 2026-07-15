import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:bookreader/features/shell/service/pdf_ocr_service.dart';

/// 在真实 Windows 应用嵌入中运行（原生插件已注册），
/// 真正触发 onnxruntime 原生库（dart:ffi）的加载与推理，验证不会挂死/崩溃。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onnxruntime 原生库可在 Windows 加载并跑通推理（不挂死）', (
    WidgetTester tester,
  ) async {
    final ByteData data =
        await rootBundle.load('assets/models/addition_model.onnx');
    final out = await PdfOcrService.runInferenceFromBytes(
      data.buffer.asUint8List(),
    );
    expect(out, <double>[11.0, 22.0, 33.0]);
  });
}
