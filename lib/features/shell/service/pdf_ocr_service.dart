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
/// 版面分析输出的单个版面框（已映射回原图坐标）。
///
/// 由 [PdfOcrService.runLayoutAnalysis] 产出：模型把整页分成若干区域，每个区域带
/// 类别标签（'Text'/'Title'/'Figure'/'Table'/'Header'/'Footer'）、置信度与
/// 原图坐标系下的包围盒。组装器据此做「模型分类 + 路由分发」，替换旧版硬编码规则。
class LayoutBox {
  /// 类别标签。
  final String label;

  /// 置信度（0~1）。
  final double score;

  /// 原图坐标系下的轴对齐包围盒（单位=原图像素）。
  final double left;
  final double top;
  final double right;
  final double bottom;

  const LayoutBox({
    required this.label,
    required this.score,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;

  /// 中心点（用于与图表/表格框做「文本是否落在图内」的重叠判定）。
  ({double x, double y}) get center =>
      (x: (left + right) / 2, y: (top + bottom) / 2);
}

class PdfOcrService {
  PdfOcrService._();

  // ── 检测阶段超参（对应 PaddleOCR 默认） ──
  static const double _detThresh = 0.3; // 概率图二值化阈值
  static const double _boxThresh = 0.5; // 文本框平均得分阈值
  static const int _detMinArea = 10; // 连通域最小像素面积（缩放后空间）
  static const int _detLongSide = 960; // 检测输入长边尺寸
  static const double _detUnclipRatio = 1.6; // DB 文本框向外扩张比例（还原收缩的文字核心）
  // ── 识别阶段超参 ──
  static const int _recHeight = 48; // 识别输入高度（PP-OCRv5 rec=48）
  static const int _recMaxWidth = 320; // 识别输入最大宽度
  // ── 检测阶段图像归一化（ImageNet 均值 / 标准差，通道顺序 BGR，仅 det 使用） ──
  static const List<double> _mean = [0.485, 0.456, 0.406];
  static const List<double> _std = [0.229, 0.224, 0.225];
  // ── 识别阶段图像归一化（PaddleOCR rec 专用：(x/255-0.5)/0.5，与检测不同） ──
  static const double _recNormMean = 0.5;
  static const double _recNormStd = 0.5;

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

  /// 把单页 [PdfPage] 渲染为 PNG 字节（白底，宽 [effW]），供重排层做底图与图片内联。
  /// 与 [recognizePage] 内部渲染同源（decodeImageFromList → rawRgba）。
  static Future<Uint8List?> renderPageToPng(
    dynamic page,
    double effW,
  ) async {
    try {
      final pw = (page.width as num).toDouble();
      final ph = (page.height as num).toDouble();
      if (pw <= 0 || ph <= 0) return null;
      final fullH = effW * ph / pw;
      // page.render 为 pdfrx 的 PdfPage 方法；这里以 dynamic 接收避免强耦合导入。
      final img = await page.render(
        fullWidth: effW,
        fullHeight: fullH,
        backgroundColor: const Color(0xFFFFFFFF),
      );
      if (img == null) return null;
      final ui.Image uiImg = await img.createImage();
      img.dispose();
      final png = await uiImg.toByteData(format: ui.ImageByteFormat.png);
      uiImg.dispose();
      return png?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// 阶段 3 原子能力：仅做 DB 文本检测，返回缩放后空间的**概率图**（已 sigmoid）
  /// 与对应尺寸，供上层（文档组装 / 图片区检测）自行分析，而不直接出框。
  ///
  /// [rgba] 为原图 RGBA 字节，[w]/[h] 为原图宽高；返回
  /// `(scores, newW, newH)`，scores 长度 = newW*newH，值∈[0,1]。
  static Future<(Float32List, int, int)> detectPage(
    Uint8List rgba,
    int w,
    int h,
  ) async {
    final det = await _ensureDetSession();
    final (detInput, newW, newH) = _preprocessDet(rgba, w, h);
    final scores = await _runDet(det, detInput, newW, newH);
    return (scores, newW, newH);
  }

  /// 阶段 3 原子能力（公开透传）：供文档组装器裁剪文本框。
  /// 返回裁剪后的 RGBA 字节与尺寸（详见私有 [_cropAxisAligned]）。
  static ({Uint8List bytes, int width, int height})? cropAxisAlignedPublic(
    Uint8List rgba,
    int w,
    int h,
    List<ui.Offset> poly,
  ) =>
      _cropAxisAligned(rgba, w, h, poly, _recHeight);

  /// 阶段 3 原子能力：对裁剪出的文本框（[bytes] 为 RGBA，[cw]×[ch]）做 CRNN 识别。
  /// 返回该行文本与平均置信度（CTC 贪心解码 + 字典映射）。
  static Future<({String text, double score})> recognizeCrop(
    Uint8List bytes,
    int cw,
    int ch,
  ) async {
    final rec = await _ensureRecSession();
    final (recInput, recW) = _preprocessRec(bytes, cw, ch);
    final logits = await _runRec(rec, recInput, recW, (await _ensureDict()).length);
    return _ctcDecode(logits, await _ensureDict());
  }

  /// 阶段 3：检测 / 识别模型与字典是否齐备（三者缺一不可）。
  ///
  /// 依次探测 [assets/models/] 下的 [det.onnx] / [rec.onnx] / [ppocr_dict.txt]，
  /// 任一缺失即视为不可用（由上层提示用户放入完整模型包）。
  /// 真正加载会话由 [recognizePage] 在首次调用时完成。
  static Future<bool> isModelAvailable() async {
    try {
      await rootBundle.load(_detAsset);
      await rootBundle.load(_recAsset);
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

    final lines = <OcrTextLine>[];
    for (final poly in polys) {
      final crop = _cropAxisAligned(rgba, w, h, poly, _recHeight);
      if (crop == null) continue;
      final decoded = await recognizeCrop(crop.bytes, crop.width, crop.height);
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
    // 字典每行一个字符，且必须与识别模型输出通道数（C）严格一致：
    // PP-OCRv4 rec 输出 [1,T,6625]，即 blank(索引0) + 6623 个常用字 + 末尾空格字符。
    // 因此这里不能 trim/过滤空行——否则末尾的空格字符会被丢弃，导致 C 少 1、
    // CTC 解码时步长错位，整段识别结果乱码。
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    // 仅去掉文件结尾换行造成的最后一个空元素（不影响字符表内容）。
    if (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    _dict = lines;
    // 若字典未显式包含索引 0 的 CTC blank（空串），则补一个空串。
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
    // DB 检测网络内部有多次 2× 下采样再上采样拼接，输入宽高必须是 32 的整数倍，
    // 否则 onnxruntime 会在特征图拼接（Add/Concat）处因维度错位而报错崩溃。
    final newW = math.max(32, ((w * scale) / 32).round() * 32);
    final newH = math.max(32, ((h * scale) / 32).round() * 32);
    // 对齐到 32 后宽高比可能与原图略有出入，故采样使用逐轴独立比例。
    final scaleX = newW / w;
    final scaleY = newH / h;
    // ⚠️ 必须用 NCHW 平面布局：三通道各占一整块 plane，索引 c*plane + y*newW + x。
    // 绝不能用 HWC 交错布局（(y*W+x)*3+c）——那样与 [1,3,H,W] 的张量声明不符，
    // onnxruntime 会把交错像素误当成分离通道读取，导致输入被彻底打乱、
    // 检测框与后续识别全部乱码（这是「一个字都不准」的根因）。
    // 最近邻缩放（检测对轻微插值不敏感，且避免引入复杂采样）。
    final plane = newW * newH;
    final resized = Float32List(plane * 3);
    for (var y = 0; y < newH; y++) {
      final sy = (y / scaleY).floor().clamp(0, h - 1);
      for (var x = 0; x < newW; x++) {
        final sx = (x / scaleX).floor().clamp(0, w - 1);
        final si = (sy * w + sx) * 4; // 源 RGBA：[R,G,B,A]
        final pi = y * newW + x; // 目标平面内的像素偏移
        // 通道顺序 BGR（与 PaddleOCR/cv2 训练时一致）：ch0=B, ch1=G, ch2=R。
        final b = rgba[si + 2];
        final g = rgba[si + 1];
        final r = rgba[si];
        resized[pi] = (b / 255.0 - _mean[0]) / _std[0]; // 通道 0 = B
        resized[plane + pi] = (g / 255.0 - _mean[1]) / _std[1]; // 通道 1 = G
        resized[2 * plane + pi] = (r / 255.0 - _mean[2]) / _std[2]; // 通道 2 = R
      }
    }
    return (resized, newW, newH);
  }

  /// 识别预处理：把裁剪出的文本框（[bytes] 为 RGBA，[cw]×[ch]）等比缩放到高度 [_recHeight]、
  /// 宽度不超过 [_recMaxWidth]，输出 NCHW(BGR) 归一化浮点。
  /// 返回元组 `(data, recW)`，其中 `recW` 是实际缩放后的宽度，供 [_runRec] 构造形状。
  ///
  /// 归一化用 PaddleOCR rec 专用的 (x/255-0.5)/0.5（不是检测的 ImageNet 均值方差），
  /// 且与检测一致必须用 NCHW 平面布局（详见 [_preprocessDet] 的说明）。
  static (Float32List, int) _preprocessRec(Uint8List bytes, int cw, int ch) {
    final scale = _recHeight / ch;
    var rw = (cw * scale).round();
    rw = rw.clamp(1, _recMaxWidth);
    final plane = _recHeight * rw;
    final out = Float32List(plane * 3);
    for (var y = 0; y < _recHeight; y++) {
      final sy = (y / scale).floor().clamp(0, ch - 1);
      for (var x = 0; x < rw; x++) {
        final sx = (x / scale).floor().clamp(0, cw - 1);
        final si = (sy * cw + sx) * 4; // 源 RGBA：[R,G,B,A]
        final pi = y * rw + x; // 目标平面内的像素偏移
        final b = bytes[si + 2];
        final g = bytes[si + 1];
        final r = bytes[si];
        out[pi] = (b / 255.0 - _recNormMean) / _recNormStd; // 通道 0 = B
        out[plane + pi] = (g / 255.0 - _recNormMean) / _recNormStd; // 通道 1 = G
        out[2 * plane + pi] = (r / 255.0 - _recNormMean) / _recNormStd; // 通道 2 = R
      }
    }
    return (out, rw);
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
    // 注意：多 rank 输出用 asList() 会返回嵌套 List<List<...>>，导致 (e as num) 抛
    // "List<dynamic> is not a subtype of num"；本处需要展平概率，故用 asFlattenedList。
    final raw = await outputs[session.outputNames.first]!.asFlattenedList();
    ortInput.dispose();
    for (final t in outputs.values) {
      t.dispose();
    }
    return Float32List.fromList(raw.map((e) => (e as num).toDouble()).toList());
  }

  /// 识别推理：输入 [1,3,recH,rw]，输出展平概率 [T*C]。
  /// PP-OCRv4 rec 实际输出布局为 [1,T,C]（时间步在前、类别在后），C=字典长度；
  /// 展平后按 logits[t*C + k] 访问，正好对应 [_ctcDecode] 的取值方式。
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
    // 同上：asFlattenedList 直接得到展平概率，避免嵌套列表 cast 失败。
    final raw = await outputs[session.outputNames.first]!.asFlattenedList();
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
      // DB 分割图输出的是收缩后的文字核心，需按 unclip 比例向外扩张，还原到完整
      // 文字区域，否则裁剪出的条带过窄（只含字形中段），识别结果会整段乱码。
      final bw = (maxX - minX + 1).toDouble();
      final bh = (maxY - minY + 1).toDouble();
      final dist = bw * bh * _detUnclipRatio / (2 * (bw + bh));
      final exMinX = (minX - dist).clamp(0.0, (newW - 1).toDouble());
      final exMinY = (minY - dist).clamp(0.0, (newH - 1).toDouble());
      final exMaxX = (maxX + 1 + dist).clamp(1.0, newW.toDouble());
      final exMaxY = (maxY + 1 + dist).clamp(1.0, newH.toDouble());
      // 用（扩张后的）包围盒按缩放比映射回原图。文本框以 4 顶点表示。
      final x0 = exMinX * scaleX;
      final y0 = exMinY * scaleY;
      final x1 = exMaxX * scaleX;
      final y1 = exMaxY * scaleY;
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

  /// 识别输出展平概率 [T*C]（布局 [1,T,C]，t*C+k 访问），逐时间步 argmax，
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
    double cyOf(OcrTextLine l) =>
        (l.polygon[0].dy + l.polygon[1].dy + l.polygon[2].dy + l.polygon[3].dy) /
            4;
    double cxOf(OcrTextLine l) =>
        (l.polygon[0].dx + l.polygon[1].dx + l.polygon[2].dx + l.polygon[3].dx) /
            4;

    final sorted = [...lines]..sort((a, b) => cyOf(a).compareTo(cyOf(b)));
    final rows = <List<OcrTextLine>>[];
    for (final line in sorted) {
      var placed = false;
      for (final row in rows) {
        final rowCy = cyOf(row.first);
        if ((cyOf(line) - rowCy).abs() < 20) {
          row.add(line);
          placed = true;
          break;
        }
      }
      if (!placed) rows.add([line]);
    }
    final result = <OcrTextLine>[];
    for (final row in rows) {
      row.sort((a, b) => cxOf(a).compareTo(cxOf(b)));
      result.addAll(row);
    }
    lines
      ..clear()
      ..addAll(result);
  }

  // ───────────────────── 图片区检测（跳过 OCR） ─────────────────────

  /// 由检测概率图（缩放后空间）用**行带（row-band）**法找出真正的图表 / 插图 / 公式区。
  ///
  /// 设计目标（对应用户反馈「一堆截图、字没几个、看不清」）：
  /// - 只把**整块图表 / 插图 / 公式**裁成**一张**图，正文文字页绝不被拆成满屏截图；
  /// - 正文交给 OCR 走 ePub 式段落重排，图表整块截图内联到对应文字下方。
  ///
  /// 为何弃用旧的「像素连通域」：一幅图表内部有大量白缝，像素连通域会把它碎成
  /// 几十个小块（就是「一堆截图」的根因），且 DB 检测漏检的正文行也会被误判成图块。
  ///
  /// 新算法分三步：
  /// 1) **逐行分类**：统计每行的墨点占比与文本像素占比，得到「图形行」——
  ///    有足量墨点，但文本检测覆盖占墨点比例低（说明这行不是被识别为文字的正文），
  ///    且不是明显的正文行；
  /// 2) **聚成图形带**：把连续（允许少量空白行间隙）的图形行合并为一个纵向带；
  /// 3) **整块裁剪**：仅保留高度 ≥ 页高 6%、宽度 ≥ 页宽 12% 的带，按带内墨点的
  ///    横向范围（略外扩）生成**一个**图片块。
  /// 这样一幅图 = 一张截图；纯文字页得到 0 个图块，全部走 OCR 重排。
  static List<({double left, double top, double right, double bottom})>
      detectImageBlocks(
    Float32List scores,
    int newW,
    int newH,
    Uint8List rgba,
    int w,
    int h,
  ) {
    const detTextThresh = 0.30; // 概率 ≥ 视为「文本像素」
    const whiteThresh = 245; // 灰度 > 视为白（无墨）
    // —— 行级判定阈值 ——
    const inkRowMin = 0.015; // 行内墨点占比下限：低于视为空白行
    const figureTextRatioMax = 0.25; // 行内「文本像素/墨点」上限：低于才算图形行
    const textRowMin = 0.010; // 行内文本像素占比：高于视为正文行（排除）
    // —— 带级判定阈值（相对页高/页宽比例，确保只裁大块图表/插图/公式） ——
    const minBandHeightFrac = 0.06; // 图形带最小高度（占页高比例）
    const minBandWidthFrac = 0.12; // 图形带最小宽度（占页宽比例）
    const rowGapTol = 3; // 图形行之间允许的空白行间隙（缩放行数）
    const padXFrac = 0.01; // 横向外扩比例（避免裁掉图表边缘）
    const padYFrac = 0.005; // 纵向外扩比例

    final scaleX = w / newW;
    final scaleY = h / newH;

    // 1) 逐行统计墨点 / 文本像素，做「图形行」判定。
    final isFigureRow = List<bool>.filled(newH, false);
    for (var y = 0; y < newH; y++) {
      final sy = ((y + 0.5) * scaleY).floor().clamp(0, h - 1);
      var ink = 0;
      var txt = 0;
      for (var x = 0; x < newW; x++) {
        final idx = y * newW + x;
        final sx = ((x + 0.5) * scaleX).floor().clamp(0, w - 1);
        final si = (sy * w + sx) * 4;
        final lum = (rgba[si] + rgba[si + 1] + rgba[si + 2]) ~/ 3;
        if (lum < whiteThresh) ink++;
        if (scores[idx] >= detTextThresh) txt++;
      }
      final inkFrac = ink / newW;
      final textFrac = txt / newW;
      // 图形行：墨点够多、文本覆盖占墨点比例低、且非明显正文行。
      isFigureRow[y] = inkFrac >= inkRowMin &&
          (ink == 0 || txt / ink <= figureTextRatioMax) &&
          textFrac < textRowMin;
    }

    // 2) 把连续（允许 rowGapTol 空白行间隙）的图形行聚成图形带。
    final bands = <({int y0, int y1})>[];
    var y = 0;
    while (y < newH) {
      if (!isFigureRow[y]) {
        y++;
        continue;
      }
      var end = y;
      var gap = 0;
      var probe = y + 1;
      while (probe < newH) {
        if (isFigureRow[probe]) {
          end = probe;
          gap = 0;
        } else {
          gap++;
          if (gap > rowGapTol) break;
        }
        probe++;
      }
      bands.add((y0: y, y1: end));
      y = probe;
    }

    // 3) 每个图形带：按带内墨点横向范围裁成一个图片块（整块）。
    final minBandH = newH * minBandHeightFrac;
    final minBandW = newW * minBandWidthFrac;
    final blocks = <({double left, double top, double right, double bottom})>[];
    for (final band in bands) {
      final bh = (band.y1 - band.y0 + 1).toDouble();
      if (bh < minBandH) continue;
      // 横向墨点范围
      var minX = newW;
      var maxX = -1;
      for (var yy = band.y0; yy <= band.y1; yy++) {
        final sy = ((yy + 0.5) * scaleY).floor().clamp(0, h - 1);
        for (var x = 0; x < newW; x++) {
          final sx = ((x + 0.5) * scaleX).floor().clamp(0, w - 1);
          final si = (sy * w + sx) * 4;
          final lum = (rgba[si] + rgba[si + 1] + rgba[si + 2]) ~/ 3;
          if (lum < whiteThresh) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
          }
        }
      }
      if (maxX < minX) continue;
      final bw = (maxX - minX + 1).toDouble();
      if (bw < minBandW) continue;
      // 略微外扩，避免裁掉图表边缘。
      final padX = newW * padXFrac;
      final padY = newH * padYFrac;
      final left = (minX - padX).clamp(0.0, (newW - 1).toDouble()) * scaleX;
      final right = (maxX + 1 + padX).clamp(1.0, newW.toDouble()) * scaleX;
      final top = (band.y0 - padY).clamp(0.0, (newH - 1).toDouble()) * scaleY;
      final bottom = (band.y1 + 1 + padY).clamp(1.0, newH.toDouble()) * scaleY;
      blocks.add((left: left, top: top, right: right, bottom: bottom));
    }
    return blocks;
  }

  // ───────────────────── 版面分析（Layout Analysis） ─────────────────────

  static const String _layoutAsset = 'assets/models/layout.onnx';
  static OrtSession? _layoutSession;

  /// 版面模型输入尺寸（DocLayout-YOLO 系列固定为正方形 imgsz，本模型为 1024）。
  /// 必须与原训练 imgsz 一致，否则坐标与置信度都会失真。
  static const int _layoutInputSize = 1024;

  /// 版面模型原始 10 类（**务必与导出的 layout.onnx 训练类别顺序严格一致**）。
  /// 来源：DocStructBench 预训练权重（imgsz1024），经验证顺序为：
  /// 0 title / 1 plain text / 2 abandon / 3 figure / 4 figure_caption /
  /// 5 table / 6 table_caption / 7 table_footnote / 8 isolate_formula / 9 formula_caption。
  static const List<String> _layoutRawLabels = [
    'title',
    'plain text',
    'abandon',
    'figure',
    'figure_caption',
    'table',
    'table_caption',
    'table_footnote',
    'isolate_formula',
    'formula_caption',
  ];

  /// 原始类别 → 路由标签映射。
  /// 路由标签沿用旧版语义：'Title'/'Text' 走文本（整页检测），'Figure'/'Table'
  /// 走图片块；'Drop' 为「抑制区」（页眉/页脚/页码），其内文字在组装阶段丢弃；
  /// 未登记类别返回 null 直接丢弃。
  /// 说明：figure_caption/table_caption/table_footnote/formula_caption 均为文字，
  /// 并入 'Text'；isolate_formula 作为图片保留（'Figure'）以免 OCR 扭曲公式。
  /// 注意：'abandon' 改为 'Drop' 而非丢弃——组装器需要用它的框来抑制页眉页脚文字，
  /// 否则整页 DB 检测会把页码也识别成正文。
  static const Map<String, String?> _layoutRouteMap = {
    'title': 'Title',
    'plain text': 'Text',
    'abandon': 'Drop',
    'figure': 'Figure',
    'figure_caption': 'Text',
    'table': 'Table',
    'table_caption': 'Text',
    'table_footnote': 'Text',
    'isolate_formula': 'Figure',
    'formula_caption': 'Text',
  };

  /// 版面框置信度阈值（低于直接丢弃）。DocLayout-YOLO 默认 conf=0.2，
  /// 这里取 0.25 兼顾召回与精度，避免漏掉真实版面块。
  static const double _layoutScoreThresh = 0.25;

  /// NMS 的 IoU 阈值（去除同一目标的重复框）。
  static const double _layoutNmsIou = 0.5;

  /// 版面分析原子能力：输入整页 RGBA，输出 N 个版面框（含 label/score/rect）。
  ///
  /// 预处理为 YOLO 标准：letterbox 缩放到 [_layoutInputSize] 正方形、灰边填充、
  /// RGB 且 /255（与训练一致）；输出为已含 NMS 的 `[1, N, 6]`，每行
  /// `[x1, y1, x2, y2, conf, cls]`（坐标在输入像素空间），解析后按 letterbox
  /// 逆变换映射回原图绝对坐标，再经 NMS 去重，并按 [_layoutRouteMap] 路由。
  /// 模型文件需放入 `assets/models/layout.onnx`；缺失或推理失败会抛错，
  /// 由上层（[PdfOcrDocumentBuilder]）回退到旧版「行带整块裁剪」流程。
  static Future<List<LayoutBox>> runLayoutAnalysis(
    Uint8List rgba,
    int w,
    int h,
  ) async {
    final session = await _ensureLayoutSession();
    final pre = _preprocessLayout(rgba, w, h);
    final raw = await _runLayout(session, pre.input, pre.inSize);
    final boxes = _parseLayout(raw, w, h, pre.scale, pre.padL, pre.padT);
    return _layoutNms(boxes);
  }

  /// 版面模型可用性（供组装器决定走模型路由还是旧版行带回退）。
  static Future<bool> isLayoutModelAvailable() async {
    try {
      await rootBundle.load(_layoutAsset);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<OrtSession> _ensureLayoutSession() async {
    if (_layoutSession != null) return _layoutSession!;
    _layoutSession = await OnnxRuntime().createSessionFromAsset(_layoutAsset);
    return _layoutSession!;
  }

  /// 版面预处理：YOLO 标准 letterbox —— 保持纵横比缩放到 [_layoutInputSize]
  /// 正方形，不足部分用灰边 114 填充（YOLO 惯例，灰色与通道无关），输出
  /// NCHW(RGB) 且 /255（与 DocLayout-YOLO 训练预处理一致）。返回输入张量及
  /// 逆变换所需的 scale / 左/上填充，供 [_parseLayout] 把框映射回原图坐标。
  static ({Float32List input, double scale, int padL, int padT, int inSize})
      _preprocessLayout(Uint8List rgba, int w, int h) {
    final inSize = _layoutInputSize;
    final scale = inSize / math.max(w, h);
    final nw = (w * scale).round();
    final nh = (h * scale).round();
    final padL = ((inSize - nw) / 2).floor();
    final padT = ((inSize - nh) / 2).floor();
    final plane = inSize * inSize;
    final input = Float32List(plane * 3);
    const padVal = 114.0 / 255.0; // 灰边
    for (var y = 0; y < inSize; y++) {
      for (var x = 0; x < inSize; x++) {
        final pi = y * inSize + x;
        final inBox = x >= padL && x < padL + nw && y >= padT && y < padT + nh;
        double r, g, b;
        if (inBox) {
          final sx = ((x - padL) / scale).floor().clamp(0, w - 1);
          final sy = ((y - padT) / scale).floor().clamp(0, h - 1);
          final si = (sy * w + sx) * 4; // 源 RGBA：[R,G,B,A]
          r = rgba[si] / 255.0; // 通道 0 = R
          g = rgba[si + 1] / 255.0; // 通道 1 = G
          b = rgba[si + 2] / 255.0; // 通道 2 = B
        } else {
          r = g = b = padVal;
        }
        input[pi] = r;
        input[plane + pi] = g;
        input[2 * plane + pi] = b;
      }
    }
    return (input: input, scale: scale, padL: padL, padT: padT, inSize: inSize);
  }

  static Future<Float32List> _runLayout(
    OrtSession session,
    Float32List input,
    int inSize,
  ) async {
    final ortInput = await OrtValue.fromList(input, <int>[1, 3, inSize, inSize]);
    final outputs = await session.run(<String, OrtValue>{
      session.inputNames.first: ortInput,
    });
    // 展平输出（rank>1 用 asFlattenedList 避免嵌套 List cast 失败，见 [_runDet]）。
    final raw = await outputs[session.outputNames.first]!.asFlattenedList();
    // ⚠️ FFI 安全：输入与所有输出张量必须显式释放，否则原生内存泄漏。
    ortInput.dispose();
    for (final t in outputs.values) {
      t.dispose();
    }
    return Float32List.fromList(raw.map((e) => (e as num).toDouble()).toList());
  }

  /// 解析版面模型输出：支持标准 YOLOv8 输出 [1, 14, N] 及 NMS 输出 [1, N, 6]。
  static List<LayoutBox> _parseLayout(
    Float32List raw,
    int origW,
    int origH,
    double scale,
    int padL,
    int padT,
  ) {
    final boxes = <LayoutBox>[];
    final numClasses = _layoutRawLabels.length; // 10
    final channels = 4 + numClasses; // 14

    // 策略 1：标准 YOLOv8 / YOLOv11 输出（如 DocLayout-YOLO 默认导出）
    // 形状 [1, 14, 8400] -> 展平后长度通常大于 10000 且能被 channels 整除
    if (raw.length > 10000 && raw.length % channels == 0) {
      final numAnchors = raw.length ~/ channels;

      for (var i = 0; i < numAnchors; i++) {
        // 1. 提取最大类别得分
        double maxConf = -1.0;
        int classIdx = -1;
        for (var c = 0; c < numClasses; c++) {
          final conf = raw[(4 + c) * numAnchors + i];
          if (conf > maxConf) {
            maxConf = conf;
            classIdx = c;
          }
        }

        if (maxConf < _layoutScoreThresh) continue;

        final rawLabel = _layoutRawLabels[classIdx];
        final route = _layoutRouteMap[rawLabel];
        if (route == null) continue;

        // 2. 提取并转换 YOLO 坐标：[cx, cy, w, h] -> [left, top, right, bottom]
        final cx = raw[0 * numAnchors + i];
        final cy = raw[1 * numAnchors + i];
        final w = raw[2 * numAnchors + i];
        final h = raw[3 * numAnchors + i];

        var left = (cx - w / 2 - padL) / scale;
        var top = (cy - h / 2 - padT) / scale;
        var right = (cx + w / 2 - padL) / scale;
        var bottom = (cy + h / 2 - padT) / scale;

        boxes.add(LayoutBox(
          label: route,
          score: maxConf,
          left: left.clamp(0.0, origW.toDouble()),
          top: top.clamp(0.0, origH.toDouble()),
          right: right.clamp(0.0, origW.toDouble()),
          bottom: bottom.clamp(0.0, origH.toDouble()),
        ));
      }
    }
    // 策略 2：已内置 NMS 的输出（[1, N, 6] 格式）
    else if (raw.length % 6 == 0) {
      final n = raw.length ~/ 6;
      for (var i = 0; i < n; i++) {
        final base = i * 6;
        final conf = raw[base + 4];
        if (conf < _layoutScoreThresh) continue;

        final classIdx = raw[base + 5].round().clamp(0, _layoutRawLabels.length - 1);
        final rawLabel = _layoutRawLabels[classIdx];
        final route = _layoutRouteMap[rawLabel];
        if (route == null) continue;

        var left = (raw[base] - padL) / scale;
        var top = (raw[base + 1] - padT) / scale;
        var right = (raw[base + 2] - padL) / scale;
        var bottom = (raw[base + 3] - padT) / scale;

        if (left > right) {
          final t = left;
          left = right;
          right = t;
        }
        if (top > bottom) {
          final t = top;
          top = bottom;
          bottom = t;
        }

        boxes.add(LayoutBox(
          label: route,
          score: conf,
          left: left.clamp(0.0, origW.toDouble()),
          top: top.clamp(0.0, origH.toDouble()),
          right: right.clamp(0.0, origW.toDouble()),
          bottom: bottom.clamp(0.0, origH.toDouble()),
        ));
      }
    }
    return boxes;
  }

  /// 版面框 NMS：按类别分组，IoU 超过 [_layoutNmsIou] 的保留分数最高者，
  /// 去除同一目标的重复预测（检测模型常见输出）。
  static List<LayoutBox> _layoutNms(List<LayoutBox> boxes) {
    final byLabel = <String, List<LayoutBox>>{};
    for (final b in boxes) {
      (byLabel[b.label] ??= []).add(b);
    }
    final result = <LayoutBox>[];
    for (final list in byLabel.values) {
      list.sort((a, b) => b.score.compareTo(a.score));
      final keep = <LayoutBox>[];
      for (final cand in list) {
        var suppressed = false;
        for (final kept in keep) {
          if (_iou(cand, kept) > _layoutNmsIou) {
            suppressed = true;
            break;
          }
        }
        if (!suppressed) keep.add(cand);
      }
      result.addAll(keep);
    }
    return result;
  }

  static double _iou(LayoutBox a, LayoutBox b) {
    final ix0 = math.max(a.left, b.left);
    final iy0 = math.max(a.top, b.top);
    final ix1 = math.min(a.right, b.right);
    final iy1 = math.min(a.bottom, b.bottom);
    final iw = (ix1 - ix0).clamp(0.0, double.infinity);
    final ih = (iy1 - iy0).clamp(0.0, double.infinity);
    final inter = iw * ih;
    if (inter <= 0) return 0;
    final union = a.width * a.height + b.width * b.height - inter;
    return union <= 0 ? 0 : inter / union;
  }

  /// 区域 OCR 原子能力：仅对 Layout 划分出的 'Text'/'Title' 区域图像跑
  /// DB 文本检测 + CRNN 识别（不再整页跑检测，命中率与速度更好）。
  ///
  /// [regionBytes] 为从整页原图抠出的区域 RGBA；[rw]/[rh] 为区域宽高。
  /// 返回该区域**相对坐标**的文本行（[OcrTextLine.polygon] 落在区域坐标系内）；
  /// 调用方需叠加区域在原图的偏移，映射回整页绝对坐标。
  static Future<List<OcrTextLine>> recognizeRegion(
    Uint8List regionBytes,
    int rw,
    int rh,
  ) async {
    // 复用整页检测原子能力得到区域概率图（缩放后空间）。
    final (scores, newW, newH) = await detectPage(regionBytes, rw, rh);
    // 连通域取文本行轴对齐框（origW/origH 传入区域宽高 → 框落在区域坐标系）。
    final polys = _detectBoxes(scores, newW, newH, rw, rh);
    final lines = <OcrTextLine>[];
    for (final poly in polys) {
      final crop = _cropAxisAligned(regionBytes, rw, rh, poly, _recHeight);
      if (crop == null) continue;
      final decoded = await recognizeCrop(crop.bytes, crop.width, crop.height);
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
}
