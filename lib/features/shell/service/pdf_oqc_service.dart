import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:pdfrx/pdfrx.dart';

import '../model/pdf_oqc_result.dart';
import 'pdf_render_service.dart';

/// 扫描件质检（OQC）服务：对整本 PDF 逐页渲染并做像素统计，
/// 检测空白页 / 模糊 / 黑边 / 倾斜 / 重影等常见问题。纯 Dart，无模型。
///
/// 复用 [PdfRenderService.renderPageImage] 渲染（与阅读视图同源，避免重复实现），
/// 在较低分辨率（renderWidth≈700）下做统计，兼顾速度与精度。
class PdfOqcService {
  PdfOqcService._();

  /// 对 [document] 逐页质检，[onProgress] 上报已检页数 / 总页数。
  static Future<PdfOqcReport> run(
    PdfDocument document, {
    void Function(int current, int total)? onProgress,
  }) async {
    final total = document.pages.length;
    final results = <PdfOqcPageResult>[];
    for (var i = 0; i < total; i++) {
      final pageNumber = i + 1;
      try {
        final img = await PdfRenderService.renderPageImage(
          document,
          pageNumber,
          renderWidth: 700,
          denoise: false,
          sharpness: 1.0,
        );
        results.add(img == null
            ? PdfOqcPageResult(pageNumber: pageNumber)
            : await _analyze(img, pageNumber));
      } catch (_) {
        results.add(PdfOqcPageResult(pageNumber: pageNumber));
      }
      onProgress?.call(pageNumber, total);
    }
    return PdfOqcReport(pages: results);
  }

  /// 对单页渲染图做像素统计，得出 [PdfOqcPageResult]。
  static Future<PdfOqcPageResult> _analyze(ui.Image src, int pageNumber) async {
    final bytes = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) return PdfOqcPageResult(pageNumber: pageNumber);
    final rgba = bytes.buffer.asUint8List();
    final w = src.width;
    final h = src.height;
    final n = w * h;

    int ink = 0;
    double edgeEnergy = 0;
    // 倾斜估计：仅统计强边缘像素的梯度方向（双角），取主导方向。
    double sinSum = 0;
    double cosSum = 0;
    int edgeCount = 0;

    // 黑边检测：分别统计四周边框带与内部的暗点占比。
    int borderInk = 0;
    int borderN = 0;
    int interiorInk = 0;
    int interiorN = 0;
    final bandX = (w * 0.04).round();
    final bandY = (h * 0.04).round();

    // 第一遍：基础统计 + 边缘能量 + 黑边带归属 + 倾斜梯度方向。
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = (y * w + x) * 4;
        final lum =
            0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2];
        if (lum < 140) ink++;
        // 边缘能量（与左、上邻域亮度差）。
        final j = (y * w + (x - 1)) * 4;
        final k = ((y - 1) * w + x) * 4;
        final l2 = 0.299 * rgba[j] + 0.587 * rgba[j + 1] + 0.114 * rgba[j + 2];
        final l3 = 0.299 * rgba[k] + 0.587 * rgba[k + 1] + 0.114 * rgba[k + 2];
        final e = (lum - l2).abs() + (lum - l3).abs();
        edgeEnergy += e;
        // 强边缘才参与倾斜估计（弱边缘噪声会污染方向）。
        if (e > 30) {
          final dx = (rgba[j] - rgba[i]).toDouble();
          final dy = (rgba[k] - rgba[i]).toDouble();
          final ang = math.atan2(dy, dx);
          sinSum += math.sin(2 * ang);
          cosSum += math.cos(2 * ang);
          edgeCount++;
        }
        // 黑边带归属（边框 4% 带 / 内部）。
        final inBorder =
            x < bandX || x >= w - bandX || y < bandY || y >= h - bandY;
        if (inBorder) {
          borderN++;
          if (lum < 90) borderInk++;
        } else {
          interiorN++;
          if (lum < 90) interiorInk++;
        }
      }
    }

    // 第二遍（降采样）：水平滞后自相关，用于重影/双影启发式。
    final step = w > 400 ? 2 : 1;
    int acN = 0;
    double mean = 0;
    double autocorr = 0;
    double varianceAcc = 0;
    for (var y = bandY; y < h - bandY; y += step) {
      for (var x = bandX; x < w - bandX - 5; x += step) {
        final i = (y * w + x) * 4;
        final lx = 0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2];
        final i3 = (y * w + (x + 5)) * 4;
        final lx5 =
            0.299 * rgba[i3] + 0.587 * rgba[i3 + 1] + 0.114 * rgba[i3 + 2];
        mean += lx;
        autocorr += lx * lx5;
        varianceAcc += lx * lx;
        acN++;
      }
    }
    if (acN > 0) mean /= acN;
    final variance = (varianceAcc / acN) - mean * mean;
    final ghostCoef =
        variance > 1 ? (autocorr / acN - mean * mean) / variance : 0.0;

    final inkRatio = ink / n;
    final isBlank = inkRatio < 0.005;
    final avgEdge = edgeEnergy / ((w - 2) * (h - 2));
    final blurScore = (avgEdge / 60 * 100).clamp(0, 100).round();
    final isBlurry = avgEdge < 12;

    final borderRatio = borderN > 0 ? borderInk / borderN : 0.0;
    final interiorRatio = interiorN > 0 ? interiorInk / interiorN : 0.0;
    final hasBlackMargin =
        borderRatio > 0.4 && borderRatio - interiorRatio > 0.2;

    double skewAngle = 0.0;
    if (edgeCount > 0) {
      final dom = 0.5 * math.atan2(sinSum, cosSum);
      var deg = dom * 180 / math.pi;
      while (deg > 45) {
        deg -= 90;
      }
      while (deg < -45) {
        deg += 90;
      }
      skewAngle = deg;
    }

    final hasGhost = ghostCoef > 0.6 && !isBlank && inkRatio > 0.005;

    return PdfOqcPageResult(
      pageNumber: pageNumber,
      isBlank: isBlank,
      blurScore: blurScore,
      isBlurry: isBlurry,
      hasBlackMargin: hasBlackMargin,
      skewAngle: skewAngle,
      hasGhost: hasGhost,
    );
  }
}
