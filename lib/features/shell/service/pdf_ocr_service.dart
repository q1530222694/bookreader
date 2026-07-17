import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// 单条 OCR 识别结果：文本、置信度、在原图中的四边形顶点（4 个 [Offset]）。
class OcrTextLine {
  final String text;
  final double score;
  final List<Offset> polygon;

  const OcrTextLine({
    required this.text,
    required this.score,
    required this.polygon,
  });
}

/// PDF OCR 服务（扫描件重排的数据来源）。
///
/// 基于 [flutter_onnxruntime] 通用 ONNX 绑定，自行实现 PaddleOCR 检测 / 识别流水线，
/// 满足 Windows / iOS / Android / macOS / Web 全平台离线 OCR 的需求（模型以 assets 内置）。
///
/// 阶段 0（冒烟测试）：[runAdditionSmokeTest] / [runInferenceFromBytes] 仅用极简「加法」
/// 模型验证 onnxruntime 原生库（dart:ffi）可正常加载与运行，排除上次 PDFium 那种挂死风险。
///
/// 阶段 3（完整流水线）：[recognizePage] 对单页位图依次执行
/// - DB 文本检测（det.onnx）：输出像素级文本概率图，经阈值 + 连通域得到文本框四边形；
/// - CRNN 文本识别（rec.onnx）：对每个文本框裁剪 + 归一化后识别；
/// - CTC 贪心解码 + 字典映射（ppocr_dict.txt）：把识别概率转成字符序列；
/// - 阅读顺序排序：按文本框位置（自顶向下、同行自左向右）排成文本行。
///
/// 模型文件需由调用方放入 `assets/models/`：`det.onnx`、`rec.onnx`、`ppocr_dict.txt`
/// （与 [addition_model.onnx] 同目录）。缺模型时 [recognizePage] 会抛错，由上层提示。
class PdfOcrService {
  PdfOcrService._();

  // ── 检测阶段超参（对应 PaddleOCR 默认） ──
  static const double _detThresh = 0.3; // 概率图二值化阈值
  static const double _boxThresh = 0.5; // 文本框平均得分阈值
  static const int _detMinArea = 10; // 连通域最小像素面积（缩放后空间）
  static const int _detLongSide = 960; // 检测输入长边尺寸
  // ── 识别阶段超参 ──
  static const int _recHeight = 48; // 识别输入高度（PP-OCRv5 rec=48）
  static const int _recMaxWidth = 320; // 识别输入最大宽度
  // ── 图像归一化（ImageNet 均值 / 标准差，BGR 顺序） ──
  static const List<double> _mean = [0.485, 0.456, 0.406];
  static const List<double> _std = [0.229, 0.224, 0.225];

  static const String _detAsset = 'assets/models/det.onnx';
  static const String _recAsset = 'assets/models/rec.onnx';
  static const String _dictAsset = 'assets/models/ppocr_dict.txt';

  // 会话与字典缓存（整进程只加载一次，避免重复读盘与重建原生会话）。
  static OrtSession? _detSession;
  static OrtSession? _recSession;
  static List<String>? _dict;

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
  /// 直接以模型字节创建会话并推理。
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
    a.dispose();
    b.dispose();
    for (final tensor in outputs.values) {
      tensor.dispose();
    }
    return List<double>.from(result);
  }

  /// 阶段 3：检测 / 识别模型与字典是否齐备。
  ///
  /// 仅做轻量 asset 存在性探测（读取体积最小的字典文件为代理），
  /// 真正加载由 [recognizePage] 在首次调用时完成。三个模型需一起放入。
  static Future<bool> isModelAvailable() async {
    try {
      await rootBundle.load(_dictAsset);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 对单页位图（PNG/JPEG 字节）做 OCR，输出按阅读顺序排列的文本行。
  ///
  /// [imageBytes] 为单页渲染出的位图字节。会按页懒加载并缓存 det/rec 会话与字典。
  /// 模型缺失或推理失败时抛出异常，由上层（[PdfTextReflowService] / [book_viewer_page]）
  /// 捕获并提示用户放入模型或改用其他方式。
  static Future<List<OcrTextLine>> recognizePage(Uint8List imageBytes) async {
    final image = await decodeImageFromList(imageBytes);
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))
        ?.buffer
        .asUint8List();
    if (rgba == null) return const [];
    final w = image.width;
    final h = image.height;

    final det = await _ensureDetSession();
    final (detInput, newW, newH) = _preprocessDet(rgba, w, h);
    final scores = await _runDet(det, detInput, newW, newH);
    final polys = _detectBoxes(scores, newW, newH, w, h);

    final rec = await _ensureRecSession();
    final dict = await _ensureDict();
    final lines = <OcrTextLine>[];
    for (final poly in polys) {
      final crop = _cropAxisAligned(rgba, w, h, poly, _recHeight);
      if (crop == null) continue;
      final recInput = _preprocessRec(crop.bytes, crop.width, crop.height);
      final logits = await _runRec(rec, recInput, crop.width, dict.length);
      final decoded = _ctcDecode(logits, dict);
      if (decoded.text.trim().isNotEmpty) {
        lines.add(OcrTextLine(
          text: decoded.text,
          score: decoded.score,
          polygon: poly,
        ));
      }
    }
    _sortReadingOrder(lines);
    return lines;
  }

  /// 阶段 3 便捷方法：直接返回按阅读顺序排列的文本行字符串列表。
  static Future<List<String>> recognizePageText(Uint8List imageBytes) async {
    final lines = await recognizePage(imageBytes);
    return lines.map((l) => l.text).toList();
  }

  // ───────────────────── 会话 / 字典加载（懒加载 + 缓存） ─────────────────────

  static Future<OrtSession> _ensureDetSession() async {
    if (_detSession != null) return _detSession!;
    _detSession = await OnnxRuntime().createSessionFromAsset(_detAsset);
    return _detSession!;
  }

  static Future<OrtSession> _ensureRecSession() async {
    if (_recSession != null) return _recSession!;
    _recSession = await OnnxRuntime().createSessionFromAsset(_recAsset);
    return _recSession!;
  }

  static Future<List<String>> _ensureDict() async {
    if (_dict != null) return _dict!;
    final raw = await rootBundle.loadString(_dictAsset);
    // 字典每行一个字符；首行常为空白符（索引 0 = CTC blank）。
    _dict = raw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    // 若字典未显式包含首行空白符，则补一个空串作为 CTC blank（索引 0）。
    if (_dict!.isNotEmpty && _dict!.first != '') {
      _dict!.insert(0, '');
    }
    return _dict!;
  }

  // ───────────────────── 预处理 ─────────────────────

  /// 检测预处理：保持纵横比缩放到长边 [_detLongSide]，输出 NCHW(BGR) 归一化浮点。
  static (Float32List, int, int) _preprocessDet(
    Uint8List rgba,
    int w,
    int h,
  ) {
    final scale = _detLongSide / math.max(w, h);
    final newW = (w * scale).round();
    final newH = (h * scale).round();
    // 最近邻缩放（检测对轻微插值不敏感，且避免引入复杂采样）。
    final resized = Float32List(newW * newH * 3);
    for (var y = 0; y < newH; y++) {
      final sy = (y / scale).floor().clamp(0, h - 1);
      for (var x = 0; x < newW; x++) {
        final sx = (x / scale).floor().clamp(0, w - 1);
        final si = (sy * w + sx) * 4;
        final di = (y * newW + x) * 3;
        // BGR 顺序，逐通道归一化。
        resized[di] = (rgba[si] / 255.0 - _mean[0]) / _std[0]; // B
        resized[di + 1] = (rgba[si + 1] / 255.0 - _mean[1]) / _std[1]; // G
        resized[di + 2] = (rgba[si + 2] / 255.0 - _mean[2]) / _std[2]; // R
      }
    }
    return (resized, newW, newH);
  }

  /// 识别预处理：把裁剪出的文本框（[bytes] 为 RGBA，[cw]×[ch]）等比缩放到高度 [_recHeight]、
  /// 宽度不超过 [_recMaxWidth]，灰边填充，输出 NCHW(BGR) 归一化浮点。
  static Float32List _preprocessRec(Uint8List bytes, int cw, int ch) {
    final scale = _recHeight / ch;
    var rw = (cw * scale).round();
    rw = rw.clamp(1, _recMaxWidth);
    final out = Float32List(_recHeight * rw * 3);
    for (var y = 0; y < _recHeight; y++) {
      final sy = (y / scale).floor().clamp(0, ch - 1);
      for (var x = 0; x < rw; x++) {
        final sx = (x / scale).floor().clamp(0, cw - 1);
        final si = (sy * cw + sx) * 4;
        final di = (y * rw + x) * 3;
        out[di] = (bytes[si] / 255.0 - _mean[0]) / _std[0];
        out[di + 1] = (bytes[si + 1] / 255.0 - _mean[1]) / _std[1];
        out[di + 2] = (bytes[si + 2] / 255.0 - _mean[2]) / _std[2];
      }
    }
    return out;
  }

  // ───────────────────── 推理 ─────────────────────

  static Future<Float32List> _runDet(
    OrtSession session,
    Float32List input,
    int newW,
    int newH,
  ) async {
    final ortInput = await OrtValue.fromList(input, <int>[1, 3, newH, newW]);
    final outputs = await session.run(<String, OrtValue>{
      session.inputNames.first: ortInput,
    });
    final raw = await outputs[session.outputNames.first]!.asList();
    ortInput.dispose();
    for (final t in outputs.values) {
      t.dispose();
    }
    return Float32List.fromList(raw.map((e) => (e as num).toDouble()).toList());
  }

  /// 识别推理：输入 [1,3,recH,rw]，输出展平概率 [C*T]。
  /// 约定输出布局为 NCHW([1,C,T])，故 C=字典长度、T=长度/C（若模型为 [1,T,C] 需在此交换）。
  static Future<Float32List> _runRec(
    OrtSession session,
    Float32List input,
    int rw,
    int classCount,
  ) async {
    final ortInput = await OrtValue.fromList(input, <int>[1, 3, _recHeight, rw]);
    final outputs = await session.run(<String, OrtValue>{
      session.inputNames.first: ortInput,
    });
    final raw = await outputs[session.outputNames.first]!.asList();
    ortInput.dispose();
    for (final t in outputs.values) {
      t.dispose();
    }
    return Float32List.fromList(raw.map((e) => (e as num).toDouble()).toList());
  }

  // ───────────────────── 检测后处理：概率图 → 文本框 ─────────────────────

  /// 由检测概率图（缩放后空间，长度 newH*newW）经阈值 + 4 连通域得到文本框四边形，
  /// 再按缩放比映射回原图坐标。返回的每个列表是 4 个 [Offset]（四边形顶点）。
  static List<List<Offset>> _detectBoxes(
    Float32List scores,
    int newW,
    int newH,
    int origW,
    int origH,
  ) {
    final scaleX = origW / newW;
    final scaleY = origH / newH;
    final binary = Uint8List(newW * newH);
    for (var i = 0; i < scores.length; i++) {
      binary[i] = scores[i] >= _detThresh ? 1 : 0;
    }

    final visited = Uint8List(newW * newH);
    final boxes = <List<Offset>>[];
    // 4 邻接 BFS 找连通域。
    final queue = <int>[];
    for (var start = 0; start < binary.length; start++) {
      if (binary[start] == 0 || visited[start] == 1) continue;
      queue.clear();
      queue.add(start);
      visited[start] = 1;
      double sumScore = 0;
      int area = 0;
      int minX = newW, minY = newH, maxX = 0, maxY = 0;
      while (queue.isNotEmpty) {
        final p = queue.removeLast();
        final px = p % newW;
        final py = p ~/ newW;
        area++;
        sumScore += scores[p];
        if (px < minX) minX = px;
        if (px > maxX) maxX = px;
        if (py < minY) minY = py;
        if (py > maxY) maxY = py;
        // 邻居
        if (px > 0) _tryEnqueue(p - 1, binary, visited, queue);
        if (px < newW - 1) _tryEnqueue(p + 1, binary, visited, queue);
        if (py > 0) _tryEnqueue(p - newW, binary, visited, queue);
        if (py < newH - 1) _tryEnqueue(p + newW, binary, visited, queue);
      }
      if (area < _detMinArea) continue;
      if (sumScore / area < _boxThresh) continue;
      // 用包围盒（按缩放比映射回原图）。文本框以 4 顶点表示。
      final x0 = minX * scaleX;
      final y0 = minY * scaleY;
      final x1 = (maxX + 1) * scaleX;
      final y1 = (maxY + 1) * scaleY;
      boxes.add([
        Offset(x0, y0),
        Offset(x1, y0),
        Offset(x1, y1),
        Offset(x0, y1),
      ]);
    }
    return boxes;
  }

  static void _tryEnqueue(
    int p,
    Uint8List binary,
    Uint8List visited,
    List<int> queue,
  ) {
    if (binary[p] == 1 && visited[p] == 0) {
      visited[p] = 1;
      queue.add(p);
    }
  }

  /// 按文本框四边形（原图坐标）的轴对齐包围盒从 RGBA 图中裁剪出子图（含灰边），
  /// 返回裁剪后的 RGBA 字节与尺寸。文本接近水平时包围盒即可，旋转文本会被略微包含。
  static ({Uint8List bytes, int width, int height})? _cropAxisAligned(
    Uint8List rgba,
    int w,
    int h,
    List<Offset> poly,
    int recH,
  ) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final p in poly) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    final x0 = minX.floor().clamp(0, w - 1);
    final y0 = minY.floor().clamp(0, h - 1);
    final x1 = maxX.ceil().clamp(0, w);
    final y1 = maxY.ceil().clamp(0, h);
    final cw = (x1 - x0).clamp(1, w);
    final ch = (y1 - y0).clamp(1, h);
    final out = Uint8List(cw * ch * 4);
    for (var y = 0; y < ch; y++) {
      final sy = y0 + y;
      for (var x = 0; x < cw; x++) {
        final sx = x0 + x;
        final si = (sy * w + sx) * 4;
        final di = (y * cw + x) * 4;
        out[di] = rgba[si];
        out[di + 1] = rgba[si + 1];
        out[di + 2] = rgba[si + 2];
        out[di + 3] = rgba[si + 3];
      }
    }
    return (bytes: out, width: cw, height: ch);
  }

  // ───────────────────── CTC 解码 + 字典映射 ─────────────────────

  /// 识别输出展平概率 [C*T]（布局 NCHW=[1,C,T]），逐时间步 argmax，
  /// 合并连续重复并去除 blank(索引 0)，映射为字典字符。返回文本与平均置信度。
  static ({String text, double score}) _ctcDecode(
    Float32List logits,
    List<String> dict,
  ) {
    final c = dict.length;
    final t = logits.length ~/ c;
    if (t <= 0) return (text: '', score: 0);
    final chars = <int>[];
    final scores = <double>[];
    int prev = -1;
    for (var ts = 0; ts < t; ts++) {
      var best = 0;
      var bestVal = -double.infinity;
      for (var k = 0; k < c; k++) {
        final v = logits[ts * c + k];
        if (v > bestVal) {
          bestVal = v;
          best = k;
        }
      }
      if (best != 0 && best != prev) {
        // 索引 0 为 CTC blank；blank 之外的字符才计入（已隐含合并相邻重复）。
        chars.add(best);
        scores.add(bestVal);
      }
      prev = best;
    }
    final text = chars.map((i) => dict[i]).join();
    final avg = scores.isEmpty
        ? 0.0
        : scores.reduce((a, b) => a + b) / scores.length;
    return (text: text, score: avg);
  }

  // ───────────────────── 阅读顺序排序 ─────────────────────

  /// 按文本框中心点做行聚类：同一行的框按 y 重叠归组，组内按 x 升序，行按 y 升序。
  static void _sortReadingOrder(List<OcrTextLine> lines) {
    if (lines.isEmpty) return;
    double _cy(OcrTextLine l) =>
        (l.polygon[0].dy + l.polygon[1].dy + l.polygon[2].dy + l.polygon[3].dy) /
            4;
    double _cx(OcrTextLine l) =>
        (l.polygon[0].dx + l.polygon[1].dx + l.polygon[2].dx + l.polygon[3].dx) /
            4;

    final sorted = [...lines]..sort((a, b) => _cy(a).compareTo(_cy(b)));
    final rows = <List<OcrTextLine>>[];
    for (final line in sorted) {
      var placed = false;
      for (final row in rows) {
        final rowCy = _cy(row.first);
        if ((_cy(line) - rowCy).abs() < 20) {
          row.add(line);
          placed = true;
          break;
        }
      }
      if (!placed) rows.add([line]);
    }
    final result = <OcrTextLine>[];
    for (final row in rows) {
      row.sort((a, b) => _cx(a).compareTo(_cx(b)));
      result.addAll(row);
    }
    lines
      ..clear()
      ..addAll(result);
  }
}
