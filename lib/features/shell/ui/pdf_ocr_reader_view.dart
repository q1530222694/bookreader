import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../model/pdf_ocr_document.dart';

/// 逐页图文混排阅读视图（扫描件 OCR 结果呈现）。
///
/// 两种呈现模式（顶栏「重排 / 原图」切换）：
/// - **重排（默认）**：把每页 OCR 文本行按阅读顺序**聚成段落**，流式排列成纯文本列；
///   检测到的图表 / 照片 / 公式从原图**裁剪**出来，按阅读顺序**内联**到对应段落下方。
///   这才是真正的 ePub 式重排——不再把整页扫描图当底图铺满，也不会把文字行误当图片框。
/// - **原图**：保留整页原扫描图，方便对照 / 核对识别结果。
///
/// 编辑：支持长段文字整段编辑（写回 [onEdit] 并落盘）。
class PdfOcrReaderView extends StatefulWidget {
  /// 结构化 OCR 文档（可能后台仍在补全，[onPageUpdated] 会持续触发）。
  final PdfOcrDocument document;

  /// 退出 OCR 阅读、返回原 PDF 版式。
  final VoidCallback onExit;

  /// 后台是否仍在识别（用于显示轻量「后台识别中」与停止按钮）。
  final bool backgroundActive;

  /// 停止后台识别。
  final VoidCallback onStop;

  /// 后台已识别 / 总页数（backgroundActive 时显示）。
  final int donePages;
  final int totalPages;

  /// 编辑文字回调：key = 段内某个 segment 索引，value = 新文本（可批量替换）。
  final void Function(int pageIndex, Map<int, String> replacements) onEdit;

  const PdfOcrReaderView({
    super.key,
    required this.document,
    required this.onExit,
    this.backgroundActive = false,
    this.onStop = _noop,
    this.donePages = 0,
    this.totalPages = 0,
    required this.onEdit,
  });

  static void _noop() {}

  @override
  State<PdfOcrReaderView> createState() => _PdfOcrReaderViewState();
}

class _PdfOcrReaderViewState extends State<PdfOcrReaderView> {
  /// 是否重排模式（false = 原图对照模式）。
  bool _reflow = true;

  @override
  Widget build(BuildContext context) {
    final primary = CupertinoTheme.of(context).primaryColor;
    final label = CupertinoColors.label.resolveFrom(context);
    return Container(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              color: CupertinoColors.systemBackground.resolveFrom(context),
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: widget.onExit,
                    child: Icon(CupertinoIcons.clear, color: primary),
                  ),
                  Expanded(
                    child: Text(
                      LocalizationEngine.text('pdf_ocr_reader_exit'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: label,
                      ),
                    ),
                  ),
                  // 重排 / 原图 切换：让用户直观对比「重排后」与「原扫描」。
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => setState(() => _reflow = !_reflow),
                    child: Text(
                      _reflow
                          ? LocalizationEngine.text('pdf_ocr_view_original')
                          : LocalizationEngine.text('pdf_ocr_view_reflow'),
                      style: TextStyle(color: primary, fontSize: 15),
                    ),
                  ),
                  if (widget.backgroundActive)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: widget.onStop,
                      child: Icon(CupertinoIcons.stop_circle, color: primary),
                    )
                  else
                    const SizedBox(width: 28),
                ],
              ),
            ),
          ),
          if (widget.backgroundActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                LocalizationEngine.text('pdf_ocr_reader_background')
                    .replaceFirst('%d', '${widget.donePages}')
                    .replaceFirst('%d', '${widget.totalPages}'),
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ),
          Expanded(
            child: widget.document.pages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        LocalizationEngine.text('pdf_ocr_no_content'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: widget.document.pages.length,
                    itemBuilder: (ctx, i) {
                      final page = widget.document.pages[i];
                      if (_reflow) {
                        return _ReflowPageTile(
                          page: page,
                          onEdit: (replacements) =>
                              widget.onEdit(page.pageIndex, replacements),
                        );
                      }
                      return _OriginalPageTile(page: page);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 重排单页瓦片：文字按阅读顺序聚成段落并流式排列，图表 / 图片从原图裁剪后**内联**到段落之间。
class _ReflowPageTile extends StatefulWidget {
  final PdfOcrPageData page;
  final void Function(Map<int, String> replacements) onEdit;

  const _ReflowPageTile({
    required this.page,
    required this.onEdit,
  });

  @override
  State<_ReflowPageTile> createState() => _ReflowPageTileState();
}

/// 重排所需的已解码数据：原图（用于裁剪）+ 各图片块的裁剪结果。
class _ReflowData {
  final ui.Image? base;
  final List<ui.Image?> crops;
  _ReflowData(this.base, this.crops);
}

class _ReflowPageTileState extends State<_ReflowPageTile> {
  late final Future<_ReflowData> _future;

  // 持有当前已解码数据，便于在切换页面 / 销毁时释放原生图片句柄（ui.Image 为
  // GPU 原生资源，必须显式 dispose，否则造成显存泄漏）。
  _ReflowData? _data;

  @override
  void initState() {
    super.initState();
    _future = _load(widget.page);
  }

  @override
  void didUpdateWidget(covariant _ReflowPageTile old) {
    super.didUpdateWidget(old);
    if (old.page != widget.page) {
      _disposeData();
      _future = _load(widget.page);
    }
  }

  /// 释放已解码的原图与所有裁剪子图（均为原生 GPU 句柄）。
  void _disposeData() {
    final d = _data;
    _data = null;
    d?.base?.dispose();
    for (final c in d?.crops ?? const <ui.Image?>[]) {
      c?.dispose();
    }
  }

  @override
  void dispose() {
    _disposeData();
    super.dispose();
  }

  /// 解码原图，并把它内部被判定为图片 / 图表 / 公式的区块裁剪出来。
  Future<_ReflowData> _load(PdfOcrPageData page) async {
    ui.Image? base;
    if (page.pageImageBase64 != null) {
      try {
        final bytes = base64Decode(page.pageImageBase64!);
        base = await decodeImageFromList(bytes);
      } catch (_) {
        base = null;
      }
    }
    final crops = <ui.Image?>[];
    for (final b in page.images) {
      if (base == null) {
        crops.add(null);
        continue;
      }
      crops.add(await _crop(base, b.left, b.top, b.right, b.bottom));
    }
    return _ReflowData(base, crops);
  }

  /// 从原图按包围盒裁剪出一个子图（用于图表 / 图片内联）。
  static Future<ui.Image?> _crop(
    ui.Image src,
    double l,
    double t,
    double r,
    double b,
  ) async {
    final w = (r - l).round();
    final h = (b - t).round();
    if (w <= 0 || h <= 0) return null;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        src,
        Rect.fromLTRB(l, t, r, b),
        Rect.fromLTRB(0, 0, w.toDouble(), h.toDouble()),
        Paint(),
      );
      final picture = recorder.endRecording();
      return await picture.toImage(w, h);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final bodyStyle = theme.textTheme.textStyle.copyWith(height: 1.6);
    final grey = CupertinoColors.systemGrey.resolveFrom(context);
    final grey6 = CupertinoColors.systemGrey6.resolveFrom(context);

    return FutureBuilder<_ReflowData>(
      future: _future,
      builder: (ctx, snap) {
        final data = snap.data;
        if (data != null) _data = data; // 持有引用，供 dispose 释放原生句柄
        if (data == null) {
          return _textOnly(ctx, _paragraphsOf(widget.page), bodyStyle);
        }
        final page = widget.page;
        final paragraphs = _paragraphsOf(page);
        final items = _mergeFlow(paragraphs, page.images);
        final children = <Widget>[];

        for (var i = 0; i < items.length; i++) {
          final item = items[i];
          if (item.isImage) {
            final crop = data.crops[item.imgIndex];
            if (crop != null) {
              children.add(
                LayoutBuilder(
                  builder: (c, constraints) {
                    final w = constraints.maxWidth;
                    final h = crop.height > 0
                        ? w * crop.height / crop.width
                        : 200.0;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: CupertinoColors.systemGrey5.resolveFrom(c),
                          width: 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: RawImage(
                        image: crop,
                        width: w,
                        height: h,
                        fit: BoxFit.fill,
                      ),
                    );
                  },
                ),
              );
            } else {
              children.add(
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: grey6,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    LocalizationEngine.text('pdf_ocr_image_failed'),
                    style: TextStyle(color: grey, fontSize: 13),
                  ),
                ),
              );
            }
          } else {
            final para = item.paragraph!;
            final isTitle = para.isTitle;
            // 标题：大字号 + 加粗 + 独立段距，还原真实标题格式
            //（isTitle 由 Layout 模型标注，layoutType == 'title'）。
            final baseFontSize = bodyStyle.fontSize ?? 18.0;
            final paraStyle = isTitle
                ? bodyStyle.copyWith(
                    fontSize: baseFontSize * 1.5,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  )
                : bodyStyle;
            children.add(
              GestureDetector(
                onLongPress: () => _editParagraph(ctx, para),
                child: Container(
                  // 标题上下的额外留白（相对字号派生，避免硬编码数值）。
                  margin: isTitle
                      ? EdgeInsets.only(
                          top: baseFontSize * 0.5,
                          bottom: baseFontSize * 0.25,
                        )
                      : null,
                  child: Text(
                    para.text,
                    style: paraStyle,
                    textAlign: isTitle ? TextAlign.left : TextAlign.justify,
                    softWrap: true,
                  ),
                ),
              ),
            );
          }
          // 段落 / 图片之间插入留白，模拟 ePub 阅读节奏。
          if (i < items.length - 1) {
            children.add(const SizedBox(height: 12));
          }
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemBackground.resolveFrom(ctx),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );
      },
    );
  }

  /// 把 OCR 文本行按阅读顺序聚成段落。
  ///
  /// **关键点**：完全信任 [PdfOcrTextSegment] 列表的既有顺序（该顺序由 Builder 的
  /// XY-Cut 块级算法给出，已是真实阅读顺序）。这里**不再做全局 Y 轴排序**——否则多栏
  /// 论文会被切成「先上栏全部、再下栏全部」的错误顺序。
  ///
  /// 仅在「相邻两行之间」判断是否需要换段，启发式（按优先级）：
  /// 1. 版面类型变化（标题↔正文）→ 必换段；
  /// 2. 纵向大间隔（>0.8 行高）→ 段落间空行，换段；
  /// 3. 首行缩进 / 明显左移（>1.5 行高且同行）→ 新段起始，换段；
  /// 4. 同行且横向未跨栏（<3 行高偏移）→ 合并为同一段；否则换段。
  List<_Paragraph> _paragraphsOf(PdfOcrPageData page) {
    final segs = page.segments;
    if (segs.isEmpty) return const [];

    // 直接沿 Builder 给出的阅读顺序遍历，不做任何重排。
    final paragraphs = <_Paragraph>[];
    var current = _Paragraph(segIndex: 0, segment: segs[0]);
    for (var i = 1; i < segs.length; i++) {
      final cur = segs[i];
      final prev = current.segments.last;

      // 1) 版面类型变化（标题↔正文）单独成段
      if (cur.isTitle != prev.isTitle) {
        paragraphs.add(current);
        current = _Paragraph(segIndex: i, segment: cur);
        continue;
      }

      final lineH = math.max(cur.height, prev.height);

      // 2) 纵向大间隔（段落间空行）
      final gap = cur.top - prev.bottom;
      if (gap > lineH * 0.8) {
        paragraphs.add(current);
        current = _Paragraph(segIndex: i, segment: cur);
        continue;
      }

      // 3) 首行缩进 / 明显左移（同行、但横向偏离过大）→ 新段起始
      final indent = cur.left - prev.left;
      if (indent > lineH * 1.5 && (cur.top - prev.top).abs() < lineH * 0.5) {
        paragraphs.add(current);
        current = _Paragraph(segIndex: i, segment: cur);
        continue;
      }

      // 4) 同行且横向未跨栏 → 合并；否则换段
      final sameLine = (cur.top - prev.bottom) < lineH * 0.75;
      final withinColumn = (cur.left - prev.left).abs() < lineH * 3.0;
      if (sameLine && withinColumn) {
        current.add(i, cur);
      } else {
        paragraphs.add(current);
        current = _Paragraph(segIndex: i, segment: cur);
      }
    }
    paragraphs.add(current);
    return paragraphs;
  }

  /// 把段落与图片块合并为阅读流（统一 XY-Cut 混排）。
  ///
  /// 与早期「图片吸附到上一个段落之下」的做法不同，这里把段落与图片视为同级元素，
  /// 一起做 XY-Cut 排序：纵向重叠 >30%（同一行/栏）按左边界排序，否则按上边界排序。
  /// 这样图片会落在它真实出现的阅读流位置（右侧栏的图就插在右侧栏对应位置），
  /// 而不是永远夹在两个段落之间，也不会插进某一行文字中间。
  List<_FlowItem> _mergeFlow(List<_Paragraph> paragraphs, List<PdfOcrImageBlock> images) {
    final items = <_FlowItem>[];
    for (final p in paragraphs) {
      items.add(_FlowItem.paragraph(p));
    }
    for (var i = 0; i < images.length; i++) {
      items.add(_FlowItem.image(i, images[i]));
    }

    // 段落与图片统一 XY-Cut：同栏（纵向重叠>30%）按左，否则按上。
    items.sort((a, b) {
      final yOverlap = math.min(a.bottom, b.bottom) - math.max(a.top, b.top);
      final minH = math.min(a.bottom - a.top, b.bottom - b.top);
      if (minH > 0 && yOverlap / minH > 0.3) {
        return a.left.compareTo(b.left);
      }
      return a.top.compareTo(b.top);
    });
    return items;
  }

  /// 解码原图前的纯文本降级显示（段落已聚合，但图片尚未裁剪）。
  Widget _textOnly(BuildContext ctx, List<_Paragraph> paragraphs, TextStyle bodyStyle) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(ctx),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: paragraphs
            .map((p) => Text(
                  p.text,
                  style: bodyStyle,
                  textAlign: TextAlign.justify,
                  softWrap: true,
                ))
            .toList(),
      ),
    );
  }

  /// 整段编辑：弹出输入框，保存时把整段文字写回第一个 segment，其余 segment 清空。
  Future<void> _editParagraph(BuildContext context, _Paragraph para) async {
    final controller = TextEditingController(text: para.text);
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: Text(LocalizationEngine.text('pdf_ocr_edit_title')),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            maxLines: 4,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(c).pop(),
            child: Text(LocalizationEngine.text('cancel')),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(c).pop(controller.text),
            child: Text(LocalizationEngine.text('confirm')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    final replacements = <int, String>{
      para.segIndices.first: result,
    };
    for (var i = 1; i < para.segIndices.length; i++) {
      replacements[para.segIndices[i]] = '';
    }
    widget.onEdit(replacements);
  }
}

/// 一个段落：由若干相邻的 OCR 文本行合并而来，用于真正流式重排。
class _Paragraph {
  final List<int> segIndices = <int>[];
  final List<PdfOcrTextSegment> _segments = <PdfOcrTextSegment>[];

  double top = double.infinity;
  double left = double.infinity;
  double bottom = 0;
  double right = 0;

  _Paragraph({required int segIndex, required PdfOcrTextSegment segment}) {
    add(segIndex, segment);
  }

  void add(int segIndex, PdfOcrTextSegment segment) {
    segIndices.add(segIndex);
    _segments.add(segment);
    if (segment.top < top) top = segment.top;
    if (segment.left < left) left = segment.left;
    if (segment.bottom > bottom) bottom = segment.bottom;
    if (segment.right > right) right = segment.right;
  }

  List<PdfOcrTextSegment> get segments => _segments;

  /// 是否为标题段落：当且仅当段内所有文本行都被 Layout 模型标注为标题
  /// （[PdfOcrTextSegment.isTitle]）。供渲染层做差异化样式。
  bool get isTitle =>
      _segments.isNotEmpty && _segments.every((s) => s.isTitle);

  /// 合并段内文字。中文行之间不加空格；英文 / 数字之间必要时加空格。
  String get text {
    final sb = StringBuffer();
    for (var i = 0; i < _segments.length; i++) {
      final t = _segments[i].text.trim();
      if (t.isEmpty) continue;
      if (i > 0) {
        final prev = _segments[i - 1].text;
        if (_needsSpace(prev, t)) sb.write(' ');
      }
      sb.write(t);
    }
    return sb.toString();
  }

  static bool _needsSpace(String prev, String next) {
    final a = prev.trim();
    final b = next.trim();
    if (a.isEmpty || b.isEmpty) return false;
    // 如果上一行结尾或下一行开头是字母/数字，则补空格，否则不补（中文场景）。
    final endAlphanum = RegExp(r'[a-zA-Z0-9]$').hasMatch(a);
    final startAlphanum = RegExp(r'^[a-zA-Z0-9]').hasMatch(b);
    return endAlphanum || startAlphanum;
  }
}

/// 阅读流中的一个元素：要么是一段文字，要么是一个图片块。
class _FlowItem {
  final bool isImage;
  final _Paragraph? paragraph;
  final int imgIndex;

  double get top => paragraph!.top;
  double get left => paragraph!.left;
  double get bottom => paragraph!.bottom;
  double get right => paragraph!.right;

  _FlowItem.paragraph(this.paragraph)
      : isImage = false,
        imgIndex = -1;

  _FlowItem.image(this.imgIndex, PdfOcrImageBlock block)
      : isImage = true,
        paragraph = _Paragraph(
          segIndex: -1,
          segment: PdfOcrTextSegment(
            text: '',
            left: block.left,
            top: block.top,
            right: block.right,
            bottom: block.bottom,
            score: 0,
          ),
        );
}

/// 原图对照瓦片：直接整页渲染原扫描图（不做文字叠加），用于与重排模式对比 / 核对。
class _OriginalPageTile extends StatelessWidget {
  final PdfOcrPageData page;
  const _OriginalPageTile({required this.page});

  @override
  Widget build(BuildContext context) {
    final future = _decode(page.pageImageBase64);
    return FutureBuilder<ui.Image?>(
      future: future,
      builder: (ctx, snap) {
        final img = snap.data;
        if (img == null) {
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                LocalizationEngine.text('pdf_ocr_no_content'),
                style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ),
          );
        }
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x11000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: img.width / img.height,
            child: RawImage(image: img, fit: BoxFit.contain),
          ),
        );
      },
    );
  }

  Future<ui.Image?> _decode(String? b64) async {
    if (b64 == null) return null;
    try {
      final bytes = base64Decode(b64);
      return await decodeImageFromList(bytes);
    } catch (_) {
      return null;
    }
  }
}
