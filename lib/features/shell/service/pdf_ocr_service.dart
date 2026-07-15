import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// PDF OCR 服务（扫描件重排的数据来源）。
///
/// 基于 [flutter_onnxruntime] 通用 ONNX 绑定，自行实现 PaddleOCR 检测/识别流水线，
/// 以满足 Windows / iOS / Android / macOS 全平台离线 OCR 的需求。
///
/// 阶段 0（本次）：仅验证 onnxruntime 原生库在 Windows 等全平台可正常加载并跑通推理
/// （[runAdditionSmokeTest] / [runInferenceFromBytes]），以排除上次 PDFium 那种
/// 「进程未响应」挂死风险。
///
/// 阶段 3：补齐 DB 文本检测 + CRNN 识别 + CTC 字典解码 + 阅读顺序排序的完整流水线，
/// 由 [recognizePage] 对扫描页位图输出按阅读顺序排列的文本块。
class PdfOcrService {
  PdfOcrService._();

  /// 阶段 0 冒烟测试（App 用）：从 assets 加载极简「加法」模型并推理，
  /// 验证 onnxruntime 原生库（dart:ffi）可正常加载与运行，不挂死。
  ///
  /// 输入 A=[1,2,3]、B=[10,20,30]，期望输出 [11,22,33]。
  static Future<List<double>> runAdditionSmokeTest() async {
    final ort = OnnxRuntime();
    final session =
        await ort.createSessionFromAsset('assets/models/addition_model.onnx');
    try {
      return await _runAddition(session);
    } finally {
      await session.close();
    }
  }

  /// 阶段 0 冒烟测试（Test 用，绕过 path_provider）：
  /// 直接以模型字节创建会话并推理，避免 `flutter test` 环境未注册 path_provider 的问题。
  static Future<List<double>> runInferenceFromBytes(Uint8List modelBytes) async {
    final file =
        File('${Directory.systemTemp.path}/ort_smoke_${modelBytes.hashCode}.onnx');
    await file.writeAsBytes(modelBytes, flush: true);
    final ort = OnnxRuntime();
    final session = await ort.createSession(file.path);
    try {
      return await _runAddition(session);
    } finally {
      await session.close();
      try {
        await file.delete();
      } catch (_) {
        // 临时文件清理失败不影响结果
      }
    }
  }

  /// 通用加法推理核心：A+B，返回结果列表。
  static Future<List<double>> _runAddition(OrtSession session) async {
    final a = await OrtValue.fromList(<double>[1.0, 2.0, 3.0], <int>[3]);
    final b = await OrtValue.fromList(<double>[10.0, 20.0, 30.0], <int>[3]);
    final outputs = await session.run(<String, OrtValue>{'A': a, 'B': b});
    final outName = session.outputNames.first;
    final result = await outputs[outName]!.asList();
    // 释放张量，避免原生内存泄漏
    a.dispose();
    b.dispose();
    for (final tensor in outputs.values) {
      tensor.dispose();
    }
    return List<double>.from(result);
  }

  /// 对单页位图（PNG/JPEG 字节）做 OCR，输出按阅读顺序排列的文本行。
  ///
  /// 阶段 3 实现：加载 `assets/models/det.onnx`（DB 检测）、
  /// `assets/models/rec.onnx`（CRNN 识别）、`assets/models/ppocr_dict.txt`
  /// （字符字典），经检测→透视裁剪→识别→CTC 解码→顺序排序。
  ///
  /// [imageBytes] 为单页渲染出的位图字节。
  static Future<List<String>> recognizePage(Uint8List imageBytes) async {
    // TODO(阶段3): 实现完整 PaddleOCR 流水线。阶段 0 暂未内置模型，返回空列表。
    // 调用前由 book_viewer_page 判断 PDF 是否含文本层，扫描件才走此路径。
    return <String>[];
  }
}
