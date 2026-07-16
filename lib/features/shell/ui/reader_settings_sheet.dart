import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;

import 'dart:async';

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../controller/settings_controller.dart';
import '../service/reader_data_service.dart';
import 'package:pdfrx/pdfrx.dart';

void _noopBackgroundColorChanged(Color _) {}
void _noopInt(int _) {}
void _noopBool(bool _) {}
void _noopDouble(double _) {}
void _noop() {}

class ReaderSettingsSheet extends StatefulWidget {
  final int selectedThemeIndex;
  final double brightness;
  final int selectedFontIndex;
  final int selectedPageMode;
  final Color? selectedBackgroundColor;
  final ValueChanged<int> onThemeChanged;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<Color> onBackgroundColorChanged;
  final ValueChanged<int> onFontChanged;
  final ValueChanged<int> onPageModeChanged;

  // PDF 专属：布局模式（0 单页 / 1 双页 / 2 单页连续 / 3 双页连续）
  final int selectedLayoutMode;
  final ValueChanged<int> onLayoutModeChanged;
  // 翻页动画（0 无动画 / 1 仿真动画）
  final int selectedPageAnimation;
  final ValueChanged<int> onPageAnimationChanged;
  // PDF 专属：自动裁切
  final bool autoCrop;
  final ValueChanged<bool> onAutoCropChanged;
  // PDF 专属：背景调节（亮度外的对比度 / 饱和度 / 去色 / 去杂色）
  final double contrast;
  final ValueChanged<double> onContrastChanged;
  final double saturation;
  final ValueChanged<double> onSaturationChanged;
  final bool removeColor;
  final ValueChanged<bool> onRemoveColorChanged;
  final bool denoise;
  final ValueChanged<bool> onDenoiseChanged;
  // PDF 专属：色温（0.5 偏冷蓝 ~ 2.0 偏暖黄）
  final double colorTemperature;
  final ValueChanged<double> onColorTemperatureChanged;
  // PDF 专属：裁切模式（0=不裁切 / 1=智能自动裁边 / 2=手动裁边 / 3=框选裁边）
  final int cropMode;
  final ValueChanged<int> onCropModeChanged;
  // PDF 专属：手动裁切边距（归一化 0~1）
  final double manualCropLeft;
  final ValueChanged<double> onManualCropLeftChanged;
  final double manualCropRight;
  final ValueChanged<double> onManualCropRightChanged;
  final double manualCropTop;
  final ValueChanged<double> onManualCropTopChanged;
  final double manualCropBottom;
  final ValueChanged<double> onManualCropBottomChanged;
  // PDF 专属：框选裁边回调
  final VoidCallback? onSelectCrop;
  // PDF 专属：双屏模式
  final bool dualScreen;
  final ValueChanged<bool> onDualScreenChanged;
  // PDF 专属：奇偶页分开裁边（0=统一 / 1=仅奇数页 / 2=仅偶数页）
  final int cropOddEvenMode;
  final ValueChanged<int> onCropOddEvenModeChanged;

  // 进度 / 目录 / 笔记 / 搜索 所需上下文
  final String bookId;
  final PdfDocument? document;
  final int totalPages;
  final int currentPage;
  final ValueChanged<int> onJumpToPage;
  final ValueChanged<bool> onToggleLandscape;

  final bool isPdfReader;
  final VoidCallback onClose;
  final VoidCallback? onAddTag;
  // PDF 专属：重排（切换为单栏连续、页面撑满的阅读模式）
  final VoidCallback onReflow;
  // 是否处于重排模式：是则在面板中显示「重排排版」（字体大小 / 行距 / 字距 / 段距）调节
  final bool showReflow;

  const ReaderSettingsSheet({
    super.key,
    required this.selectedThemeIndex,
    required this.brightness,
    required this.selectedFontIndex,
    required this.selectedPageMode,
    this.selectedBackgroundColor,
    required this.onThemeChanged,
    required this.onBrightnessChanged,
    required this.onFontChanged,
    required this.onPageModeChanged,
    this.selectedLayoutMode = 0,
    this.onLayoutModeChanged = _noopInt,
    this.selectedPageAnimation = 1,
    this.onPageAnimationChanged = _noopInt,
    this.autoCrop = false,
    this.onAutoCropChanged = _noopBool,
    this.contrast = 1.0,
    this.onContrastChanged = _noopDouble,
    this.saturation = 1.0,
    this.onSaturationChanged = _noopDouble,
    this.removeColor = false,
    this.onRemoveColorChanged = _noopBool,
    this.denoise = false,
    this.onDenoiseChanged = _noopBool,
    this.colorTemperature = 1.0,
    this.onColorTemperatureChanged = _noopDouble,
    this.cropMode = 0,
    this.onCropModeChanged = _noopInt,
    this.manualCropLeft = 0.0,
    this.onManualCropLeftChanged = _noopDouble,
    this.manualCropRight = 0.0,
    this.onManualCropRightChanged = _noopDouble,
    this.manualCropTop = 0.0,
    this.onManualCropTopChanged = _noopDouble,
    this.manualCropBottom = 0.0,
    this.onManualCropBottomChanged = _noopDouble,
    this.onSelectCrop,
    this.dualScreen = false,
    this.onDualScreenChanged = _noopBool,
    this.cropOddEvenMode = 0,
    this.onCropOddEvenModeChanged = _noopInt,
    required this.bookId,
    this.document,
    required this.totalPages,
    required this.currentPage,
    required this.onJumpToPage,
    required this.onToggleLandscape,
    this.isPdfReader = false,
    this.onBackgroundColorChanged = _noopBackgroundColorChanged,
    required this.onClose,
    this.onAddTag,
    this.onReflow = _noop,
    this.showReflow = false,
  });

  @override
  State<ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<ReaderSettingsSheet> {
  // 底部导航选中项：0=目录 1=进度 2=笔记 3=外观 4=更多（默认外观，保持打开即见）。
  int _selectedNav = 3;
  // 电子书（非 PDF）分支沿用旧的两段式开关（更多面板），避免改动其外观常驻布局。
  bool _showMoreSettings = false;

  // ───── 目录（PDF 内置 outline）─────
  List<PdfOutlineNode>? _outline;
  bool _outlineLoading = false;

  // ───── 笔记 / 书签（按 bookId 持久化）─────
  List<NoteItem>? _notes;
  List<BookmarkItem>? _bookmarks;

  // ───── 搜索（PDF 全文）─────
  final TextEditingController _searchController = TextEditingController();
  List<int> _searchResults = const [];
  bool _searching = false;
  // 横屏模式开关的本地镜像（父级为 true 时由 onToggleLandscape 同步）。
  bool _landscapeOn = false;
  // 进度：滑块当前值（1-based 页码），用于进度条与微调按钮。
  double _progressValue = 1.0;
  // 进度：页码输入框控制器。
  final TextEditingController _pageInputController = TextEditingController();
  // 搜索防抖计时器。
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _progressValue = widget.currentPage
        .toDouble()
        .clamp(1, widget.totalPages <= 0 ? 1 : widget.totalPages)
        .toDouble();
    _loadOutline();
    _loadNotes();
    _loadBookmarks();
  }

  Future<void> _loadOutline() async {
    if (widget.document == null) return;
    if (mounted) setState(() => _outlineLoading = true);
    try {
      final list = await widget.document!.loadOutline();
      if (mounted) setState(() => _outline = list);
    } catch (e) {
      if (mounted) setState(() => _outline = const []);
    } finally {
      if (mounted) setState(() => _outlineLoading = false);
    }
  }

  Future<void> _loadNotes() async {
    final list = await ReaderDataStore.loadNotes(widget.bookId);
    if (mounted) setState(() => _notes = list);
  }

  Future<void> _loadBookmarks() async {
    final list = await ReaderDataStore.loadBookmarks(widget.bookId);
    if (mounted) setState(() => _bookmarks = list);
  }

  /// 全文搜索：逐页 loadText 匹配关键字，收集命中的 1-based 页码。
  Future<void> _runSearch(String q) async {
    q = q.trim();
    if (q.isEmpty || widget.document == null) {
      if (mounted) setState(() => _searchResults = const []);
      return;
    }
    if (mounted) setState(() {
      _searching = true;
      _searchResults = const [];
    });
    final results = <int>[];
    final pages = widget.document!.pages;
    final needle = q.toLowerCase();
    for (int i = 0; i < pages.length; i++) {
      if (!mounted) return;
      try {
        final text = await pages[i].loadText();
        if (text.fullText.toLowerCase().contains(needle)) results.add(i + 1);
      } catch (_) {
        // 个别页无文本层，跳过
      }
    }
    if (mounted) setState(() {
      _searchResults = results;
      _searching = false;
    });
  }

  /// 递归展平 outline 树为带缩进层级的列表，便于在目录面板渲染。
  List<_OutlineEntry> _flattenOutline(List<PdfOutlineNode> nodes, int depth) {
    final out = <_OutlineEntry>[];
    for (final n in nodes) {
      out.add(_OutlineEntry(node: n, depth: depth));
      if (n.children.isNotEmpty) {
        out.addAll(_flattenOutline(n.children, depth + 1));
      }
    }
    return out;
  }

  // ────────────────────────────────────────────────────────────────
  // 新增面板：目录 / 进度 / 笔记
  // ────────────────────────────────────────────────────────────────

  Widget _buildNotSupportedPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          LocalizationEngine.text('reader_catalog_empty'),
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPanel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  /// 目录面板：展示 PDF 内置 outline（书签）树，点击跳页。
  Widget _buildCatalogPanel(
    BuildContext context,
    Color primaryColor,
    Color labelColor,
    Color secondaryColor,
    Color borderColor,
  ) {
    if (!widget.isPdfReader || widget.document == null) {
      return _buildNotSupportedPanel();
    }
    if (_outlineLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    final entries =
        _outline == null ? const <_OutlineEntry>[] : _flattenOutline(_outline!, 0);
    if (entries.isEmpty) {
      return _buildEmptyPanel(LocalizationEngine.text('reader_catalog_empty'));
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, __) =>
          Container(height: 1, color: borderColor),
      itemBuilder: (context, i) {
        final e = entries[i];
        final page = e.node.dest?.pageNumber ?? 0;
        return GestureDetector(
          onTap: page > 0 ? () => widget.onJumpToPage(page) : null,
          child: Container(
            padding: EdgeInsets.only(
              left: 12.0 * e.depth,
              top: 11,
              bottom: 11,
              right: 12,
            ),
            color: page > 0
                ? null
                : CupertinoColors.systemGrey6.resolveFrom(context),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    e.node.title.isEmpty ? '(无标题)' : e.node.title,
                    style: TextStyle(color: labelColor, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (page > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$page',
                      style: TextStyle(color: primaryColor, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _jumpToInputPage() {
    final raw = int.tryParse(_pageInputController.text.trim());
    if (raw == null) return;
    final max = widget.totalPages <= 0 ? 1 : widget.totalPages;
    final target = raw.clamp(1, max);
    _pageInputController.text = '$target';
    setState(() => _progressValue = target.toDouble());
    widget.onJumpToPage(target);
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _runSearch(q);
    });
  }

  Future<void> _addBookmarkCurrent() async {
    final page = _progressValue.round();
    final list = await ReaderDataStore.addBookmark(
      widget.bookId,
      pageNumber: page,
    );
    if (mounted) setState(() => _bookmarks = list);
  }

  Future<void> _removeBookmark(int pageNumber) async {
    final list =
        await ReaderDataStore.deleteBookmark(widget.bookId, pageNumber);
    if (mounted) setState(() => _bookmarks = list);
  }

  /// 进度面板：页码输入 + 拖动条(微调按钮) + 搜索 + 书签。
  Widget _buildProgressPanel(
    BuildContext context,
    Color primaryColor,
    Color labelColor,
    Color secondaryColor,
    Color borderColor,
  ) {
    if (!widget.isPdfReader) return _buildNotSupportedPanel();
    final total = widget.totalPages <= 0 ? 1 : widget.totalPages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 页码输入 + 跳转
        Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: _pageInputController,
                keyboardType: TextInputType.number,
                placeholder:
                    '${LocalizationEngine.text('reader_nav_progress')} (1-$total)',
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                onSubmitted: (_) => _jumpToInputPage(),
              ),
            ),
            const SizedBox(width: 8),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: _jumpToInputPage,
              child: Text(LocalizationEngine.text('reader_go_to_page')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 进度条 + 微调（仿画面增强圆角卡片）
        _StyledCard(
          title: LocalizationEngine.text('reader_nav_progress'),
          children: [
            _FineTuneSliderRow(
              label: '',
              value: _progressValue,
              min: 1,
              max: total.toDouble(),
              step: 1,
              primaryColor: primaryColor,
              displayValue: '${_progressValue.round()} / $total',
              onChanged: (v) {
                setState(() => _progressValue = v);
                widget.onJumpToPage(v.round());
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 搜索
        _sectionTitle(context, 'reader_search_tab'),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: _searchController,
          placeholder: LocalizationEngine.text('reader_search_placeholder'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6.resolveFrom(context),
            borderRadius: BorderRadius.circular(10),
          ),
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: 8),
        if (_searching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CupertinoActivityIndicator()),
          )
        else if (_searchResults.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _searchResults.length,
            separatorBuilder: (_, __) =>
                Container(height: 1, color: borderColor),
            itemBuilder: (context, i) {
              final pg = _searchResults[i];
              return GestureDetector(
                onTap: () => widget.onJumpToPage(pg),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.search, size: 16, color: secondaryColor),
                      const SizedBox(width: 8),
                      Text(
                        '${LocalizationEngine.text('reader_nav_progress')} $pg',
                        style: TextStyle(color: labelColor, fontSize: 14),
                      ),
                      const Spacer(),
                      Icon(CupertinoIcons.chevron_right,
                          size: 16, color: secondaryColor),
                    ],
                  ),
                ),
              );
            },
          )
        else if (_searchController.text.trim().isNotEmpty)
          _buildEmptyPanel(LocalizationEngine.text('reader_search_empty')),
        const SizedBox(height: 16),
        // 书签
        Row(
          children: [
            Expanded(child: _sectionTitle(context, 'reader_bookmarks')),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _addBookmarkCurrent,
              child: Text(LocalizationEngine.text('reader_add_bookmark')),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_bookmarks == null)
          const Center(child: CupertinoActivityIndicator())
        else if (_bookmarks!.isEmpty)
          _buildEmptyPanel(LocalizationEngine.text('reader_bookmarks_empty'))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _bookmarks!.length,
            separatorBuilder: (_, __) =>
                Container(height: 1, color: borderColor),
            itemBuilder: (context, i) {
              final b = _bookmarks![i];
              return GestureDetector(
                onTap: () => widget.onJumpToPage(b.pageNumber),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.bookmark, size: 16, color: primaryColor),
                      const SizedBox(width: 8),
                      Text(
                          '${LocalizationEngine.text('reader_nav_progress')} ${b.pageNumber}',
                          style: TextStyle(color: labelColor, fontSize: 14)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _removeBookmark(b.pageNumber),
                        child: Icon(CupertinoIcons.delete,
                            size: 18,
                            color: CupertinoColors.systemRed.resolveFrom(context)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _showAddNoteDialog() async {
    final controller = TextEditingController();
    final page = _progressValue.round();
    if (!mounted) return;
    // 让对话框「返回文本」而非在 onPressed 内异步写盘：避免 Navigator.pop 与
    // controller.dispose() 竞态（pop 动画期间 TextField 仍持有 controller 会被 dispose
    // 触发崩溃），也避免未捕获的写盘异常冒泡到事件句柄导致整个 app 崩溃。
    final String? result = await showCupertinoDialog<String?>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(
          '${LocalizationEngine.text('reader_add_note')} · ${LocalizationEngine.text('reader_nav_progress')} $page',
          style: TextStyle(
            color: CupertinoColors.label.resolveFrom(context),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: LocalizationEngine.text('reader_note_hint'),
            placeholderStyle: TextStyle(
              color: CupertinoColors.systemGrey.resolveFrom(context),
            ),
            style: TextStyle(
              color: CupertinoColors.label.resolveFrom(context),
              fontSize: 15,
            ),
            cursorColor: CupertinoColors.activeBlue.resolveFrom(context),
            maxLines: null,
            minLines: 3,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6.resolveFrom(context),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(LocalizationEngine.text('cancel')),
            onPressed: () => Navigator.of(ctx).pop(null),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(LocalizationEngine.text('confirm')),
            onPressed: () {
              final text = controller.text.trim();
              Navigator.of(ctx).pop(text.isEmpty ? null : text);
            },
          ),
        ],
      ),
    );
    // 对话框已完全出栈后再 dispose，杜绝竞态。
    controller.dispose();
    if (result == null || !mounted) return;
    try {
      final list = await ReaderDataStore.addNote(
        widget.bookId,
        pageNumber: page,
        content: result,
      );
      if (mounted) setState(() => _notes = list);
    } catch (e) {
      debugPrint('添加笔记失败: $e');
      if (mounted) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(LocalizationEngine.text('reader_add_note')),
            content: Text('保存失败：$e'),
            actions: [
              CupertinoDialogAction(
                child: Text(LocalizationEngine.text('confirm')),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  /// 笔记面板：列出本书全部笔记（按页码），点击跳页；底部添加按钮。
  Widget _buildNotesPanel(
    BuildContext context,
    Color primaryColor,
    Color labelColor,
    Color secondaryColor,
    Color borderColor,
  ) {
    if (!widget.isPdfReader) return _buildNotSupportedPanel();
    if (_notes == null) {
      return const Center(child: CupertinoActivityIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_notes!.isEmpty)
          _buildEmptyPanel(LocalizationEngine.text('reader_notes_empty'))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _notes!.length,
            separatorBuilder: (_, __) =>
                Container(height: 1, color: borderColor),
            itemBuilder: (context, i) {
              final n = _notes![i];
              final time = DateTime.fromMillisecondsSinceEpoch(n.updatedAt);
              final timeStr =
                  '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
              return GestureDetector(
                onTap: () => widget.onJumpToPage(n.pageNumber),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${n.pageNumber}',
                            style: TextStyle(
                                color: primaryColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.summary,
                                style: TextStyle(color: labelColor, fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(timeStr,
                                style: TextStyle(
                                    color: secondaryColor, fontSize: 11)),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minSize: 0,
                        onPressed: () async {
                          final list = await ReaderDataStore.deleteNote(
                              widget.bookId, n.id);
                          if (mounted) setState(() => _notes = list);
                        },
                        child: Icon(CupertinoIcons.delete,
                            size: 18,
                            color: CupertinoColors.systemRed.resolveFrom(context)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton.filled(
            onPressed: _showAddNoteDialog,
            child: Text(LocalizationEngine.text('reader_add_note')),
          ),
        ),
      ],
    );
  }

  Color _resolveThemeColor(String themeColor) {
    switch (themeColor) {
      case SettingsEngine.themeColorGreen:
        return CupertinoColors.activeGreen;
      case SettingsEngine.themeColorPink:
        return CupertinoColors.systemPink;
      case SettingsEngine.themeColorOrange:
        return CupertinoColors.systemOrange;
      case SettingsEngine.themeColorPurple:
        return CupertinoColors.systemIndigo;
      case SettingsEngine.themeColorRed:
        return CupertinoColors.systemRed;
      case SettingsEngine.themeColorBlue:
      default:
        return CupertinoColors.activeBlue;
    }
  }

  Widget _buildPdfReaderSheet(
    BuildContext context,
    Color primaryColor,
    List<_ThemeOption> themeOptions,
    int selectedIndex,
    Color effectiveBackgroundColor,
  ) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final borderColor = CupertinoColors.systemGrey4.resolveFrom(context);

    // 设置面板最高占屏幕 3/4，内容超出时内部滚动
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.75;

    return ColoredBox(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.all(4),
                        minSize: 0,
                        onPressed: () => setState(() => _selectedNav = 1),
                        child: Icon(
                          CupertinoIcons.search,
                          size: 20,
                          color: primaryColor,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          LocalizationEngine.text('reader_settings'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.all(4),
                        minSize: 0,
                        onPressed: widget.onAddTag ?? widget.onClose,
                        child: Icon(
                          CupertinoIcons.add,
                          size: 20,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ── 目录 / 进度 / 笔记（新增功能）──
                  if (_selectedNav == 0)
                    _buildCatalogPanel(
                        context, primaryColor, labelColor, secondaryColor, borderColor),
                  if (_selectedNav == 1)
                    _buildProgressPanel(
                        context, primaryColor, labelColor, secondaryColor, borderColor),
                  if (_selectedNav == 2)
                    _buildNotesPanel(
                        context, primaryColor, labelColor, secondaryColor, borderColor),
                  if (_selectedNav == 3) ...[
                    const SizedBox(height: 12),
                    _sectionTitle(context, 'theme_color'),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: themeOptions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 3),
                        itemBuilder: (context, index) {
                          final isSelected = index == selectedIndex;
                          return GestureDetector(
                            onTap: () {
                              widget.onThemeChanged(index);
                              SettingsController.setThemeColor(
                                themeOptions[index].keyValue,
                              );
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: themeOptions[index].color,
                                    border: Border.all(
                                      color: isSelected
                                          ? primaryColor
                                          : borderColor,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check,
                                          size: 14,
                                          color: primaryColor,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 2),
                                SizedBox(
                                  width: 54,
                                  child: Text(
                                    themeOptions[index].label,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: secondaryColor,
                                      fontSize: 11,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    _sectionTitle(context, 'reader_background'),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _buildBackgroundOptions(
                          effectiveBackgroundColor,
                          primaryColor,
                          secondaryColor,
                          borderColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _sectionTitle(context, 'reader_brightness'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(CupertinoIcons.sun_max,
                            size: 18, color: primaryColor),
                        Expanded(
                          child: CupertinoSlider(
                            value: widget.brightness,
                            min: 0.3,
                            max: 1.5,
                            onChanged: widget.onBrightnessChanged,
                            activeColor: primaryColor,
                            thumbColor: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 翻页方式（单行 5 模式）+ 翻页动画（独立分区）
                    _buildPageTurnSection(context),
                    if (widget.showReflow) ...[
                      const SizedBox(height: 14),
                      _buildReflowTypographySection(context),
                    ],
                    const SizedBox(height: 12),
                    // 布局模式：与翻页方式风格一致
                    _sectionTitle(context, 'reader_layout'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _PageModeChip(
                          icon: Icons.filter_1,
                          label: LocalizationEngine.text('reader_layout_single'),
                          selected: widget.selectedLayoutMode == 0,
                          onPressed: () => widget.onLayoutModeChanged(0),
                        ),
                        const SizedBox(width: 8),
                        _PageModeChip(
                          icon: Icons.filter_2,
                          label: LocalizationEngine.text('reader_layout_double'),
                          selected: widget.selectedLayoutMode == 1,
                          onPressed: () => widget.onLayoutModeChanged(1),
                        ),
                        const SizedBox(width: 8),
                        _PageModeChip(
                          icon: Icons.view_stream,
                          label: LocalizationEngine.text(
                            'reader_layout_single_continuous',
                          ),
                          selected: widget.selectedLayoutMode == 2,
                          onPressed: () => widget.onLayoutModeChanged(2),
                        ),
                        const SizedBox(width: 8),
                        _PageModeChip(
                          icon: Icons.view_module,
                          label: LocalizationEngine.text(
                            'reader_layout_double_continuous',
                          ),
                          selected: widget.selectedLayoutMode == 3,
                          onPressed: () => widget.onLayoutModeChanged(3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_selectedNav == 4) ...[
                    const SizedBox(height: 12),
                    // 重排：开关式切换（能开能关），单栏连续、页面撑满，适合手机阅读
                    _SwitchRow(
                      label: LocalizationEngine.text('pdf_reflow'),
                      description: widget.showReflow
                          ? LocalizationEngine.text('pdf_reflow_on_desc')
                          : LocalizationEngine.text('pdf_reflow_desc'),
                      value: widget.showReflow,
                      onChanged: (_) => widget.onReflow(),
                    ),
                    const SizedBox(height: 12),
                    // ── 画面增强（圆角卡片：清晰度/对比度/亮度/饱和度/色温/去色）──
                    _buildEnhanceCard(context, primaryColor, labelColor,
                        secondaryColor, borderColor),
                    const SizedBox(height: 12),
                    // ── 页面裁切（圆角卡片：自动裁边/手动裁切/框选裁边）──
                    // 仅 PDF 读者显示：框选裁边依赖 widget.document（_pdfDocument!）。
                    if (widget.isPdfReader)
                      _buildCropCard(context, primaryColor, labelColor,
                          secondaryColor, borderColor),
                    if (widget.isPdfReader) const SizedBox(height: 12),
                    // ── 双屏模式 ──
                    _SwitchRow(
                      label: LocalizationEngine.text('pdf_dual_screen'),
                      description:
                          LocalizationEngine.text('pdf_dual_screen_desc'),
                      value: widget.dualScreen,
                      onChanged: widget.onDualScreenChanged,
                    ),
                    const SizedBox(height: 12),
                    // ── 横屏模式 ──
                    _SwitchRow(
                      icon: CupertinoIcons.rotate_right,
                      label: LocalizationEngine.text('reader_landscape'),
                      description:
                          LocalizationEngine.text('reader_landscape_desc'),
                      value: _landscapeOn,
                      onChanged: (v) {
                        setState(() => _landscapeOn = v);
                        widget.onToggleLandscape(v);
                      },
                    ),
                    const SizedBox(height: 4),
                  ],
                      ],
                    ),
                  ),
                ),
              ),
              // 固定底部导航：移出滚动区，切换「外观 / 更多」展开设置内容时始终可见，
              // 不再被设置内容顶出视口（此前作为滚动 Column 末子会被内容遮挡）。
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _BottomNavItem(
                      icon: CupertinoIcons.book,
                      label: LocalizationEngine.text('reader_nav_catalog'),
                      active: _selectedNav == 0,
                      onTap: () => setState(() => _selectedNav = 0),
                    ),
                    _BottomNavItem(
                      icon: CupertinoIcons.chart_bar_circle,
                      label: LocalizationEngine.text('reader_nav_progress'),
                      active: _selectedNav == 1,
                      onTap: () => setState(() => _selectedNav = 1),
                    ),
                    _BottomNavItem(
                      icon: CupertinoIcons.square_list,
                      label: LocalizationEngine.text('reader_nav_notes'),
                      active: _selectedNav == 2,
                      onTap: () => setState(() => _selectedNav = 2),
                    ),
                    _BottomNavItem(
                      icon: CupertinoIcons.paintbrush,
                      label: LocalizationEngine.text('appearance'),
                      active: _selectedNav == 3,
                      onTap: () => setState(() => _selectedNav = 3),
                    ),
                    _BottomNavItem(
                      icon: CupertinoIcons.ellipsis,
                      label: LocalizationEngine.text('reader_nav_more'),
                      active: _selectedNav == 4,
                      onTap: () => setState(() => _selectedNav = 4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 设置分区标题（统一字号 / 字重 / 主题色，无硬编码）。
  Widget _sectionTitle(BuildContext context, String key) {
    return Text(
      LocalizationEngine.text(key),
      style: TextStyle(
        color: CupertinoColors.label.resolveFrom(context),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// 翻页方式（单行 5 模式）+ 翻页动画（独立分区）。
  ///
  /// - 翻页方式：左右滑动(0) / 上下滑动(1) / 左右单击(2) / 上下单击(3) / 单击滚动(4)，
  ///   五个模式同处一行，点击即切换（[widget.onPageModeChanged]）。
  /// - 翻页动画：无动画(0) / 仿真动画(1)，独立成区（[widget.onPageAnimationChanged]）。
  Widget _buildPageTurnSection(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final borderColor = CupertinoColors.systemGrey4.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);

    final modes = <int, String>{
      0: 'reader_page_turn_swipe_h',
      1: 'reader_page_turn_swipe_v',
      2: 'reader_page_turn_tap_h',
      3: 'reader_page_turn_tap_v',
      4: 'reader_page_turn_tap_scroll',
    };
    final anims = <int, String>{
      0: 'reader_page_animation_none',
      1: 'reader_page_animation_simulation',
    };

    Widget chip(String label, bool selected, VoidCallback onPressed) {
      return Expanded(
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            height: 36,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: selected
                  ? primaryColor.withValues(alpha: 0.12)
                  : CupertinoColors.systemGrey6.resolveFrom(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? primaryColor : borderColor),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? primaryColor : labelColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'reader_page_turn'),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final e in modes.entries)
              chip(
                LocalizationEngine.text(e.value),
                widget.selectedPageMode == e.key,
                () => widget.onPageModeChanged(e.key),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _sectionTitle(context, 'reader_page_animation'),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final e in anims.entries)
              chip(
                LocalizationEngine.text(e.value),
                widget.selectedPageAnimation == e.key,
                () => widget.onPageAnimationChanged(e.key),
              ),
          ],
        ),
      ],
    );
  }

  /// 重排排版调节：字体大小 / 行距 / 字距 / 段距（仅重排模式下显示）。
  ///
  /// 全部经 [SettingsController] 实时落库并广播，[PdfReflowView] 监听后即时重排。
  Widget _buildReflowTypographySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'pdf_reflow'),
        const SizedBox(height: 8),
        _reflowSlider(
          context,
          'pdf_reflow_font_size',
          SettingsController.pdfReflowFontSize,
          12,
          32,
          (v) => SettingsController.setPdfReflowFontSize(v),
          (v) => v.toStringAsFixed(0),
        ),
        _reflowSlider(
          context,
          'pdf_reflow_line_spacing',
          SettingsController.pdfReflowLineSpacing,
          1.0,
          3.0,
          (v) => SettingsController.setPdfReflowLineSpacing(v),
          (v) => v.toStringAsFixed(1),
        ),
        _reflowSlider(
          context,
          'pdf_reflow_letter_spacing',
          SettingsController.pdfReflowLetterSpacing,
          0.0,
          4.0,
          (v) => SettingsController.setPdfReflowLetterSpacing(v),
          (v) => v.toStringAsFixed(1),
        ),
        _reflowSlider(
          context,
          'pdf_reflow_para_spacing',
          SettingsController.pdfReflowParaSpacing,
          0.0,
          24.0,
          (v) => SettingsController.setPdfReflowParaSpacing(v),
          (v) => v.toStringAsFixed(0),
        ),
      ],
    );
  }

  /// 单个重排排版滑块：左侧标签 + 中部滑块（实时跟随）+ 右侧数值。
  Widget _reflowSlider(
    BuildContext context,
    String key,
    ValueNotifier<double> notifier,
    double min,
    double max,
    ValueChanged<double> onChanged,
    String Function(double) format,
  ) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              LocalizationEngine.text(key),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<double>(
              valueListenable: notifier,
              builder: (context, value, _) => CupertinoSlider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
                activeColor: primaryColor,
                thumbColor: primaryColor,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: ValueListenableBuilder<double>(
              valueListenable: notifier,
              builder: (context, value, _) => Text(
                format(value),
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 画面增强卡片（圆角深色容器，每行带 [−] 滑块 [+] 微调按钮）
  // ────────────────────────────────────────────────────────────────

  /// 画面增强分区：清晰度(占位)/对比度/亮度/饱和度/色温 + 去除颜色开关。
  Widget _buildEnhanceCard(
    BuildContext context,
    Color primaryColor,
    Color labelColor,
    Color secondaryColor,
    Color borderColor,
  ) {
    final bgColor = CupertinoColors.systemGrey6.resolveFrom(context);
    return _StyledCard(
      title: LocalizationEngine.text('pdf_enhance'),
      children: [
        // 清晰度（UI 占位，暂不接入渲染管线）
        _FineTuneSliderRow(
          label: LocalizationEngine.text('pdf_enhance_sharpness'),
          value: 1.0,
          min: 0.5,
          max: 2.0,
          step: 0.1,
          onChanged: (_) {},
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 10),
        // 对比度
        _FineTuneSliderRow(
          label: LocalizationEngine.text('pdf_enhance_contrast'),
          value: widget.contrast,
          min: 0.5,
          max: 2.0,
          step: 0.01,
          onChanged: widget.onContrastChanged,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 10),
        // 亮度
        _FineTuneSliderRow(
          label: LocalizationEngine.text('pdf_enhance_brightness'),
          value: widget.brightness,
          min: 0.3,
          max: 1.5,
          step: 0.05,
          onChanged: widget.onBrightnessChanged,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 10),
        // 饱和度
        _FineTuneSliderRow(
          label: LocalizationEngine.text('pdf_enhance_saturation'),
          value: widget.saturation,
          min: 0.0,
          max: 2.0,
          step: 0.01,
          onChanged: widget.onSaturationChanged,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 10),
        // 色温
        _FineTuneSliderRow(
          label: LocalizationEngine.text('pdf_enhance_color_temp'),
          value: widget.colorTemperature,
          min: 0.5,
          max: 2.0,
          step: 0.01,
          onChanged: widget.onColorTemperatureChanged,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 10),
        // 去除颜色（开关）
        _SwitchRow(
          label: LocalizationEngine.text('pdf_enhance_remove_color'),
          description:
              LocalizationEngine.text('pdf_bg_remove_color_desc'),
          value: widget.removeColor,
          onChanged: widget.onRemoveColorChanged,
        ),
        const SizedBox(height: 4),
        // 去杂色（开关）
        _SwitchRow(
          label: LocalizationEngine.text('pdf_bg_denoise'),
          description: LocalizationEngine.text('pdf_bg_denoise_desc'),
          value: widget.denoise,
          onChanged: widget.onDenoiseChanged,
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 页面裁切卡片（自动裁边 / 手动裁切 / 框选裁边）
  // ────────────────────────────────────────────────────────────────

  /// 页面裁切分区：智能自动裁边开关 + 手动裁切滑块 + 框选裁边入口。
  Widget _buildCropCard(
    BuildContext context,
    Color primaryColor,
    Color labelColor,
    Color secondaryColor,
    Color borderColor,
  ) {
    return _StyledCard(
      title: LocalizationEngine.text('pdf_crop'),
      children: [
        // 智能自动裁边开关
        _SwitchRow(
          label: LocalizationEngine.text('pdf_crop_auto'),
          value: widget.cropMode == 1 || (widget.autoCrop && widget.cropMode == 0),
          onChanged: (v) {
            if (v) {
              widget.onCropModeChanged(1);
              widget.onAutoCropChanged(true);
            } else {
              widget.onCropModeChanged(0);
              widget.onAutoCropChanged(false);
            }
          },
        ),
        const SizedBox(height: 10),
        // 奇偶页分开裁边
        _CropOddEvenToggle(
          value: widget.cropOddEvenMode,
          onChanged: widget.onCropOddEvenModeChanged,
          primaryColor: CupertinoTheme.of(context).primaryColor,
        ),
        const SizedBox(height: 12),
        // 手动四边裁切（真实生效）：每条边独立滑块，滑动即时更新并落库
        _FineTuneSliderRow(
          label: LocalizationEngine.text('pdf_crop_left'),
          value: widget.manualCropLeft,
          min: 0.0,
          max: 0.4,
          step: 0.01,
          displayValue: '${(widget.manualCropLeft * 100).toStringAsFixed(0)}%',
          onChanged: widget.onManualCropLeftChanged,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 6),
        _FineTuneSliderRow(
          label: LocalizationEngine.text('pdf_crop_right'),
          value: widget.manualCropRight,
          min: 0.0,
          max: 0.4,
          step: 0.01,
          displayValue: '${(widget.manualCropRight * 100).toStringAsFixed(0)}%',
          onChanged: widget.onManualCropRightChanged,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 6),
        _FineTuneSliderRow(
          label: LocalizationEngine.text('pdf_crop_top'),
          value: widget.manualCropTop,
          min: 0.0,
          max: 0.4,
          step: 0.01,
          displayValue: '${(widget.manualCropTop * 100).toStringAsFixed(0)}%',
          onChanged: widget.onManualCropTopChanged,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 6),
        _FineTuneSliderRow(
          label: LocalizationEngine.text('pdf_crop_bottom'),
          value: widget.manualCropBottom,
          min: 0.0,
          max: 0.4,
          step: 0.01,
          displayValue: '${(widget.manualCropBottom * 100).toStringAsFixed(0)}%',
          onChanged: widget.onManualCropBottomChanged,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: 12),
        // 框选裁边按钮
        GestureDetector(
          onTap: widget.onSelectCrop ?? _noop,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6.resolveFrom(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.crop,
                    size: 16, color: primaryColor),
                const SizedBox(width: 6),
                Text(
                  LocalizationEngine.text('pdf_crop_select'),
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildBackgroundOptions(
    Color effectiveBackgroundColor,
    Color primaryColor,
    Color secondaryColor,
    Color borderColor,
  ) {
    final backgroundOptions = <_BackgroundColorOption>[
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_white'),
        color: const Color(0xFFFFFFFF),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_beige'),
        color: const Color(0xFFF3E5D6),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_gray'),
        color: const Color(0xFFF2F2F2),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_yellow'),
        color: const Color(0xFFF7F0C3),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_green'),
        color: const Color(0xFFE4F2E2),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_blue'),
        color: const Color(0xFFE7F1FC),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_dark'),
        color: const Color(0xFF2C2C2C),
      ),
    ];

    return backgroundOptions.asMap().entries.map((entry) {
      final index = entry.key;
      final option = entry.value;
      final isSelected = effectiveBackgroundColor == option.color;
      // 圆圈尺寸缩小（原 40→22），间距缩小（原 8→3），与「主题配色」保持一致：
      // 直径 22 / 标签宽 54 / 字号 11 / 间距 3，使两行紧凑对齐。
      return Padding(
        padding: const EdgeInsets.only(right: 3),
        child: GestureDetector(
          key: ValueKey('reader_background_color_$index'),
          onTap: () {
            widget.onBackgroundColorChanged(option.color);
            SettingsController.setReaderBackgroundColor(option.color);
          },
          child: SizedBox(
            width: 54,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: option.color,
                    border: Border.all(
                      color: isSelected ? primaryColor : borderColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  option.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final borderColor = CupertinoColors.systemGrey4.resolveFrom(context);
    final effectiveBackgroundColor =
        widget.selectedBackgroundColor ?? SettingsController.readerBackgroundColor.value;

    final themeOptions = <_ThemeOption>[
      _ThemeOption(
        label: LocalizationEngine.text('theme_color_blue'),
        color: _resolveThemeColor(SettingsEngine.themeColorBlue),
        keyValue: SettingsEngine.themeColorBlue,
      ),
      _ThemeOption(
        label: LocalizationEngine.text('theme_color_green'),
        color: _resolveThemeColor(SettingsEngine.themeColorGreen),
        keyValue: SettingsEngine.themeColorGreen,
      ),
      _ThemeOption(
        label: LocalizationEngine.text('theme_color_pink'),
        color: _resolveThemeColor(SettingsEngine.themeColorPink),
        keyValue: SettingsEngine.themeColorPink,
      ),
      _ThemeOption(
        label: LocalizationEngine.text('theme_color_orange'),
        color: _resolveThemeColor(SettingsEngine.themeColorOrange),
        keyValue: SettingsEngine.themeColorOrange,
      ),
      _ThemeOption(
        label: LocalizationEngine.text('theme_color_purple'),
        color: _resolveThemeColor(SettingsEngine.themeColorPurple),
        keyValue: SettingsEngine.themeColorPurple,
      ),
      _ThemeOption(
        label: LocalizationEngine.text('theme_color_red'),
        color: _resolveThemeColor(SettingsEngine.themeColorRed),
        keyValue: SettingsEngine.themeColorRed,
      ),
    ];

    final resolvedSelectedIndex = themeOptions.indexWhere(
      (option) => option.keyValue == SettingsController.themeColor.value,
    );
    final selectedIndex = resolvedSelectedIndex >= 0
        ? resolvedSelectedIndex
        : widget.selectedThemeIndex.clamp(0, themeOptions.length - 1);

    if (widget.isPdfReader) {
      return _buildPdfReaderSheet(
        context,
        primaryColor,
        themeOptions,
        selectedIndex,
        effectiveBackgroundColor,
      );
    }

    final backgroundOptions = <_BackgroundColorOption>[
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_white'),
        color: const Color(0xFFFFFFFF),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_beige'),
        color: const Color(0xFFF3E5D6),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_gray'),
        color: const Color(0xFFF2F2F2),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_yellow'),
        color: const Color(0xFFF7F0C3),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_green'),
        color: const Color(0xFFE4F2E2),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_blue'),
        color: const Color(0xFFE7F1FC),
      ),
      _BackgroundColorOption(
        label: LocalizationEngine.text('reader_background_dark'),
        color: const Color(0xFF2C2C2C),
      ),
    ];

    return ValueListenableBuilder<String>(
      valueListenable: SettingsController.themeColor,
      builder: (context, currentThemeColor, child) {
        final resolvedSelectedIndex = themeOptions.indexWhere(
          (option) => option.keyValue == currentThemeColor,
        );
        final selectedIndex = resolvedSelectedIndex >= 0
            ? resolvedSelectedIndex
            : widget.selectedThemeIndex.clamp(0, themeOptions.length - 1);

        return ValueListenableBuilder<Color>(
          valueListenable: SettingsController.readerBackgroundColor,
          builder: (context, currentBackgroundColor, child) {
            return ColoredBox(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.all(4),
                            minSize: 0,
                            onPressed: () {},
                            child: Icon(
                              CupertinoIcons.search,
                              size: 20,
                              color: primaryColor,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              LocalizationEngine.text('reader_settings'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: labelColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.all(4),
                            minSize: 0,
                            onPressed: widget.onAddTag ?? widget.onClose,
                            child: Icon(
                              CupertinoIcons.add,
                              size: 20,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        LocalizationEngine.text('theme_color'),
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 56,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: themeOptions.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 3),
                          itemBuilder: (context, index) {
                            final isSelected = index == selectedIndex;
                            return GestureDetector(
                              onTap: () {
                                widget.onThemeChanged(index);
                                SettingsController.setThemeColor(
                                  themeOptions[index].keyValue,
                                );
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: themeOptions[index].color,
                                      border: Border.all(
                                        color: isSelected ? primaryColor : borderColor,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check,
                                            size: 14,
                                            color: primaryColor,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 2),
                                  SizedBox(
                                    width: 54,
                                    child: Text(
                                      themeOptions[index].label,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: secondaryColor,
                                        fontSize: 11,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        LocalizationEngine.text('reader_background'),
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: backgroundOptions.asMap().entries.map((entry) {
                            final index = entry.key;
                            final option = entry.value;
                            final isSelected = effectiveBackgroundColor == option.color;
                            return Padding(
                              padding: const EdgeInsets.only(right: 3),
                              child: GestureDetector(
                                key: ValueKey('reader_background_color_$index'),
                                onTap: () {
                                  widget.onBackgroundColorChanged(option.color);
                                  SettingsController.setReaderBackgroundColor(option.color);
                                },
                                child: SizedBox(
                                  width: 54,
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: option.color,
                                          border: Border.all(
                                            color: isSelected ? primaryColor : borderColor,
                                            width: isSelected ? 2 : 1,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        option.label,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: secondaryColor,
                                          fontSize: 11,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        LocalizationEngine.text('reader_brightness'),
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(CupertinoIcons.sun_max, size: 18, color: primaryColor),
                          Expanded(
                            child: CupertinoSlider(
                              value: widget.brightness,
                              onChanged: widget.onBrightnessChanged,
                              activeColor: primaryColor,
                              thumbColor: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      if (_showMoreSettings) ...[
                        const SizedBox(height: 10),
                        if (!widget.isPdfReader) ...[
                          Text(
                            LocalizationEngine.text('reader_font'),
                            style: TextStyle(
                              color: labelColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _FontChip(
                                label: LocalizationEngine.text('reader_font_default'),
                                selected: widget.selectedFontIndex == 0,
                                onPressed: () => widget.onFontChanged(0),
                              ),
                              const SizedBox(width: 10),
                              _FontChip(
                                label: '100%',
                                selected: widget.selectedFontIndex == 1,
                                onPressed: () => widget.onFontChanged(1),
                              ),
                              const SizedBox(width: 10),
                              _FontChip(
                                label: LocalizationEngine.text('reader_font_large'),
                                selected: widget.selectedFontIndex == 2,
                                onPressed: () => widget.onFontChanged(2),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        _buildPageTurnSection(context),
                      ],
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _BottomNavItem(
                              icon: CupertinoIcons.book,
                              label: LocalizationEngine.text('reader_nav_catalog'),
                            ),
                            _BottomNavItem(
                              icon: CupertinoIcons.chart_bar_circle,
                              label: LocalizationEngine.text('reader_nav_progress'),
                            ),
                            _BottomNavItem(
                              icon: CupertinoIcons.square_list,
                              label: LocalizationEngine.text('reader_nav_notes'),
                            ),
                            _BottomNavItem(
                              icon: CupertinoIcons.paintbrush,
                              label: LocalizationEngine.text('appearance'),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _showMoreSettings = !_showMoreSettings),
                              child: _BottomNavItem(
                                icon: CupertinoIcons.ellipsis,
                                label: LocalizationEngine.text('reader_nav_more'),
                                active: _showMoreSettings,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _OutlineEntry {
  final PdfOutlineNode node;
  final int depth;

  const _OutlineEntry({required this.node, required this.depth});
}

class _ThemeOption {
  final String label;
  final Color color;
  final String keyValue;

  const _ThemeOption({
    required this.label,
    required this.color,
    required this.keyValue,
  });
}

class _BackgroundColorOption {
  final String label;
  final Color color;

  const _BackgroundColorOption({required this.label, required this.color});
}

class _FontChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _FontChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final borderColor = CupertinoColors.systemGrey4.resolveFrom(context);
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? primaryColor.withValues(alpha: 0.12)
                : CupertinoColors.systemGrey6.resolveFrom(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? primaryColor : borderColor),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? primaryColor
                  : CupertinoColors.label.resolveFrom(context),
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _PageModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const _PageModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final borderColor = CupertinoColors.systemGrey4.resolveFrom(context);
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? primaryColor.withValues(alpha: 0.12)
                : CupertinoColors.systemGrey6.resolveFrom(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? primaryColor : borderColor),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? primaryColor
                    : CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: selected
                      ? primaryColor
                      : CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final color =
        active ? primaryColor : CupertinoColors.secondaryLabel.resolveFrom(context);
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 9, color: color)),
      ],
    );
    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}

/// 带标题与描述的动作行（用于重排等一键操作）。
class _ActionRow extends StatelessWidget {
  final String label;
  final String? description;
  final VoidCallback onPressed;

  const _ActionRow({
    required this.label,
    this.description,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    return GestureDetector(
      onTap: onPressed,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description!,
                    style: TextStyle(color: secondaryColor, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          Icon(CupertinoIcons.chevron_right, size: 16, color: primaryColor),
        ],
      ),
    );
  }
}

/// 带标题与描述的开关行（用于自动裁切 / 去除颜色 / 智能去杂色）。
class _SwitchRow extends StatelessWidget {
  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  const _SwitchRow({
    required this.label,
    this.description,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: primaryColor),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 2),
                Text(
                  description!,
                  style: TextStyle(color: secondaryColor, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        CupertinoSwitch(
          value: value,
          onChanged: onChanged,
          activeColor: primaryColor,
        ),
      ],
    );
  }
}

/// 带数值显示的滑块行（用于对比度 / 饱和度）。
class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = CupertinoTheme.of(context).primaryColor;
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              displayValue,
              style: TextStyle(color: secondaryColor, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        CupertinoSlider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: primaryColor,
          thumbColor: primaryColor,
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────
// 新增：圆角卡片容器 + 带 [−]/[+] 微调按钮的滑块行
// ────────────────────────────────────────────────────────────────

/// 圆角深色卡片容器（画面增强 / 页面裁切共用）。
class _StyledCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _StyledCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final bgColor =
        CupertinoColors.systemGrey6.resolveFrom(context); // 暗色模式自适应

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 卡片标题
          Text(
            title,
            style: TextStyle(
              color: labelColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/// 带 [−] [滑块] [+] 微调按钮的滑块行。
///
/// 布局：标签 | [−] [═══●═══] [+]
/// 点击 [−]/[+] 以 [step] 为单位微调，拖动滑块连续调节。
class _FineTuneSliderRow extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final Color primaryColor;
  final String? displayValue;

  const _FineTuneSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.step = 0.01,
    required this.onChanged,
    required this.primaryColor,
    this.displayValue,
  });

  @override
  State<_FineTuneSliderRow> createState() => _FineTuneSliderRowState();
}

class _FineTuneSliderRowState extends State<_FineTuneSliderRow> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(_FineTuneSliderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_isDragging) {
      _value = widget.value;
    }
  }

  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    final btnBg =
        CupertinoColors.systemGrey5.resolveFrom(context);

    return Row(
      children: [
        // 标签
        SizedBox(
          width: 56,
          child: Text(
            widget.label,
            style: TextStyle(color: labelColor, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // [−] 按钮
        GestureDetector(
          onTap: () => _adjust(-1),
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: btnBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '−',
              style: TextStyle(
                  color: secondaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // 滑块
        Expanded(
          child: CupertinoSlider(
            value: _value.clamp(widget.min, widget.max),
            min: widget.min,
            max: widget.max,
            onChangeStart: (_) => _isDragging = true,
            onChangeEnd: (_) {
              _isDragging = false;
            },
            onChanged: (v) {
              setState(() => _value = v);
              widget.onChanged(v);
            },
            activeColor: widget.primaryColor,
            thumbColor: widget.primaryColor,
          ),
        ),
        const SizedBox(width: 6),
        // [+] 按钮
        GestureDetector(
          onTap: () => _adjust(1),
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: btnBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+',
              style: TextStyle(
                  color: secondaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (widget.displayValue != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(
              widget.displayValue!,
              style:
                  TextStyle(color: secondaryColor, fontSize: 11),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  void _adjust(int direction) {
    setState(() {
      _value = (_value + direction * widget.step)
          .clamp(widget.min, widget.max);
    });
    widget.onChanged(_value);
  }
}

/// 奇偶页分开裁边切换器：三段选项（统一 / 仅奇数页 / 仅偶数页）。
///
/// 布局：三个等宽按钮水平排列，选中态高亮。用户可快速切换当前裁边的生效范围。
class _CropOddEvenToggle extends StatelessWidget {
  final int value; // 0=统一 / 1=仅奇数页 / 2=仅偶数页
  final ValueChanged<int> onChanged;
  final Color primaryColor;

  const _CropOddEvenToggle({
    required this.value,
    required this.onChanged,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final borderColor = CupertinoColors.systemGrey4.resolveFrom(context);

    final options = <int, String>{
      0: LocalizationEngine.text('pdf_crop_odd_even_all'),
      1: LocalizationEngine.text('pdf_crop_odd_even_odd'),
      2: LocalizationEngine.text('pdf_crop_odd_even_even'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocalizationEngine.text('pdf_crop_odd_even_title'),
          style: TextStyle(
            color: labelColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: options.entries.map((e) {
            final isSelected = e.key == value;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor.withValues(alpha: 0.12)
                        : CupertinoColors.systemGrey6.resolveFrom(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? primaryColor : borderColor,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    e.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? primaryColor : secondaryColor,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
