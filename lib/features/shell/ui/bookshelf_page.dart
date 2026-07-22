import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// compute 需在独立 isolate 执行顶层函数，本文件用到它做书架筛选的隔离计算。
import 'package:flutter/foundation.dart';

import '../../../engine/localization_engine.dart';
import '../controller/bookshelf_controller.dart';
import '../model/book_model.dart';
import '../model/folder_candidate_model.dart';
import '../model/scan_candidate_model.dart';
import '../service/baidu_image_search_service.dart';
import '../service/storage_permission_service.dart';
import 'package:file_picker/file_picker.dart';
import 'book_viewer_page.dart';
import 'epub_viewer_page.dart';
import 'txt_viewer_page.dart';
import 'widgets/book_cover_image.dart';
import 'comic_viewer_page.dart';
import 'package:open_filex/open_filex.dart';

/// 书架筛选的可序列化输入：仅携带可跨隔离传递的字符串字段，避免把笨重的 BookModel
/// （含 Uint8List 封面、DateTime 等）直接丢进 compute 隔离导致拷贝开销或不可发送错误。
class _BookFilterInput {
  const _BookFilterInput({
    required this.titles,
    required this.paths,
    required this.types,
    required this.category,
    required this.keyword,
  });

  // 从书籍列表提取与搜索相关的可序列化字段（转小写，统一过滤口径）。
  factory _BookFilterInput.fromBooks(
    List<BookModel> books,
    String category,
    String keyword,
  ) {
    final titles = <String>[];
    final paths = <String>[];
    final types = <String>[];
    for (final b in books) {
      titles.add(b.title.toLowerCase());
      paths.add(b.path.toLowerCase());
      types.add(b.normalizedType.toLowerCase());
    }
    return _BookFilterInput(
      titles: titles,
      paths: paths,
      types: types,
      category: category.trim().toLowerCase(),
      keyword: keyword.trim().toLowerCase(),
    );
  }

  final List<String> titles;
  final List<String> paths;
  final List<String> types;
  final String category;
  final String keyword;

  // 转为可跨隔离发送的消息：compute 不接受自定义类实例，需拆为基础可发送结构（List<dynamic>）。
  List<dynamic> toMessage() => <dynamic>[titles, paths, types, category, keyword];
}

/// 纯函数：根据筛选输入返回命中的索引列表。
/// 设计为顶层函数以便 compute 在独立 isolate 执行；主线程同步路径也复用它，保证结果一致。
List<int> _filterBookIndices(List<dynamic> message) {
  final List<String> titles = message[0] as List<String>;
  final List<String> paths = message[1] as List<String>;
  final List<String> types = message[2] as List<String>;
  final String category = message[3] as String;
  final String keyword = message[4] as String;
  final result = <int>[];
  for (var i = 0; i < titles.length; i++) {
    // 先按分类过滤（all/pdf/epub/txt/other）。
    if (category.isNotEmpty && category != 'all') {
      final t = types[i];
      if (category == 'other') {
        if (t == 'pdf' || t == 'epub' || t == 'txt') continue;
      } else if (t != category) {
        continue;
      }
    }
    // 再按关键词过滤（命中标题或路径任一即可）。
    if (keyword.isNotEmpty) {
      if (!titles[i].contains(keyword) && !paths[i].contains(keyword)) {
        continue;
      }
    }
    result.add(i);
  }
  return result;
}

/// 过滤扫描候选：按标题或路径命中关键词；无关键词返回原列表。
/// 用于扫描导入弹层内的搜索框，仅主线程执行（候选规模可控，输入即筛）。
List<ScanCandidateModel> _filterScanCandidates(
  List<ScanCandidateModel> candidates,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return candidates;
  return candidates.where((c) {
    return c.title.toLowerCase().contains(q) || c.path.toLowerCase().contains(q);
  }).toList();
}

/// 过滤扫描候选（搜索 + 分类）：在 [_filterScanCandidates] 基础上叠加类别筛选。
///
/// [category] 为 'all' 时不做类别限制；其余按候选 [ScanCandidateModel.type]
/// （pdf/epub/txt/mobi/comic）精确匹配，用于扫描导入弹层顶部的类别胶囊筛选。
List<ScanCandidateModel> _filterScanCandidatesBy(
  List<ScanCandidateModel> candidates,
  String query,
  String category,
) {
  final byKeyword = _filterScanCandidates(candidates, query);
  if (category.isEmpty || category == 'all') return byKeyword;
  return byKeyword.where((c) => c.type.toLowerCase() == category.toLowerCase()).toList();
}

/// 扫描导入弹层支持的类别胶囊定义（键 + 本地化 key），顺序即展示顺序。
const List<Map<String, String>> _scanCategoryChips = [
  {'k': 'all', 't': 'bookshelf_scan_filter_all'},
  {'k': 'pdf', 't': 'file_type_pdf'},
  {'k': 'epub', 't': 'file_type_epub'},
  {'k': 'txt', 't': 'file_type_txt'},
  {'k': 'mobi', 't': 'bookshelf_scan_filter_mobi'},
  {'k': 'comic', 't': 'bookshelf_scan_filter_comic'},
];

/// BookshelfPage provides the bookshelf UI and import actions.
class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key, this.controller});

  final BookshelfController? controller;

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  late final BookshelfController _controller;
  late final bool _ownsController;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool _showCoverMode = true; // true=封面网格；false=书籍列表
  String _selectedCategory = 'all';
  // 批量管理模式标记：开启后书架进入「勾选」态，点击卡片=切换选择而非打开书籍。
  bool _selectionMode = false;
  // 批量管理已选中的书籍 id 集合（Set 保证去重与 O(1) 切换）。
  final Set<String> _selectedIds = {};
  // 过滤后的展示列表（单一数据源）：数据/分类变化即时同步重算，搜索输入走防抖+compute 隔离更新。
  List<BookModel> _displayBooks = const [];
  // 搜索输入防抖定时器：避免每次击键都重算过滤，集中到停顿 200ms 后在隔离线程执行。
  Timer? _filterDebounceTimer;

  /// 切换某本书的批量选中状态。
  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  /// 全选 / 取消全选当前过滤后的可见书籍。
  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _displayBooks.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_displayBooks.map((book) => book.id));
      }
    });
  }

  /// 退出批量管理模式并清空选择。
  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? BookshelfController();
    // 初始化展示列表为全部书籍（默认分类 all、无关键词）。
    _displayBooks = _controller.books.value;
    // 监听书架数据变化（导入/收藏/进度等），数据变动即时同步重算过滤结果。
    _controller.books.addListener(_onBooksChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filterDebounceTimer?.cancel();
    _controller.books.removeListener(_onBooksChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  // 书架数据变化时：同步即时重算过滤（用户期望新导入的书立刻可见，故不走防抖）。
  void _onBooksChanged() {
    _applyFilterImmediate(_controller.books.value);
    if (mounted) setState(() {});
  }

  // 同步即时过滤：直接在主线程序列化并过滤，用于数据/分类变化等低频、需即时响应的场景。
  void _applyFilterImmediate(List<BookModel> source) {
    final input = _BookFilterInput.fromBooks(source, _selectedCategory, _searchText);
    final indices = _filterBookIndices(input.toMessage());
    _displayBooks = [for (final i in indices) source[i]];
  }

  // 防抖过滤：搜索输入高频变化，先取消上一次计时，停顿 200ms 后在 compute 隔离线程过滤，
  // 避免主线程因逐字过滤大书架而卡顿。
  void _scheduleFilter(List<BookModel> source) {
    _filterDebounceTimer?.cancel();
    _filterDebounceTimer = Timer(const Duration(milliseconds: 200), () async {
      final input = _BookFilterInput.fromBooks(source, _selectedCategory, _searchText);
      final indices = await compute(_filterBookIndices, input.toMessage());
      if (!mounted) return;
      setState(() {
        _displayBooks = [for (final i in indices) source[i]];
      });
    });
  }

  Offset _resolveAnchorPosition(BuildContext context) {
    final renderBox = context.findRenderObject();
    if (renderBox is RenderBox) {
      final offset = renderBox.localToGlobal(Offset.zero);
      return offset + Offset(renderBox.size.width / 2, renderBox.size.height);
    }
    return const Offset(0, 0);
  }

  double _calculateMenuWidth(BuildContext context, List<String> labels,
      {double minWidth = 120.0, double horizontalPadding = 32.0, double maxWidth = double.infinity}) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontSize: 17);
    final textDirection = Directionality.of(context);
    var maxTextWidth = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: textDirection,
        maxLines: 1,
      )..layout();
      maxTextWidth = math.max(maxTextWidth, painter.width);
    }
    return maxTextWidth + horizontalPadding
        .clamp(minWidth, maxWidth.isFinite ? maxWidth : double.infinity);
  }

  void _showMoreOptions(BuildContext context, {Offset? anchorPosition}) {
    final overlayState = Overlay.of(context, rootOverlay: true);

    late final OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final targetPosition = anchorPosition ?? _resolveAnchorPosition(context);
        final mediaQuery = MediaQuery.of(overlayContext);
        final screenWidth = mediaQuery.size.width;
        final screenHeight = mediaQuery.size.height;
        final labels = [
          LocalizationEngine.text('bookshelf_import_single'),
          LocalizationEngine.text('bookshelf_import_multiple'),
          LocalizationEngine.text('bookshelf_scan_import'),
          LocalizationEngine.text('bookshelf_scan_folder'),
          LocalizationEngine.text('bookshelf_batch_manage'),
          LocalizationEngine.text('bookshelf_random_read'),
        ];
        final menuWidth = _calculateMenuWidth(
          overlayContext,
          labels,
          minWidth: 120.0,
          maxWidth: screenWidth - 24.0,
        );
        final menuHeight = labels.length * 46.0 + (labels.length - 1) * 1.0;
        final safeLeft = (targetPosition.dx - menuWidth / 2).clamp(12.0, screenWidth - menuWidth - 12.0);
        final safeTop = (targetPosition.dy + 8.0).clamp(12.0, screenHeight - menuHeight - 12.0);

        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => overlayEntry.remove(),
              child: Container(color: CupertinoColors.transparent),
            ),
            Positioned(
              left: safeLeft,
              top: safeTop,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: menuWidth,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground.resolveFrom(overlayContext),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: CupertinoColors.systemGrey4.resolveFrom(overlayContext)),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        onPressed: () {
                          overlayEntry.remove();
                          _controller.importPdf();
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(LocalizationEngine.text('bookshelf_import_single')),
                        ),
                      ),
                      Container(height: 1, color: CupertinoColors.systemGrey4.resolveFrom(overlayContext)),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        onPressed: () {
                          overlayEntry.remove();
                          _controller.importMultiplePdfs();
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(LocalizationEngine.text('bookshelf_import_multiple')),
                        ),
                      ),
                      Container(height: 1, color: CupertinoColors.systemGrey4.resolveFrom(overlayContext)),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        onPressed: () {
                          overlayEntry.remove();
                          _showScanImportPicker(context);
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(LocalizationEngine.text('bookshelf_scan_import')),
                        ),
                      ),
                      Container(height: 1, color: CupertinoColors.systemGrey4.resolveFrom(overlayContext)),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        onPressed: () {
                          overlayEntry.remove();
                          _showScanFolderFlow(context);
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(LocalizationEngine.text('bookshelf_scan_folder')),
                        ),
                      ),
                      Container(height: 1, color: CupertinoColors.systemGrey4.resolveFrom(overlayContext)),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        onPressed: () {
                          overlayEntry.remove();
                          setState(() {
                            _selectionMode = true;
                          });
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(LocalizationEngine.text('bookshelf_batch_manage')),
                        ),
                      ),
                      Container(height: 1, color: CupertinoColors.systemGrey4.resolveFrom(overlayContext)),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        onPressed: () {
                          overlayEntry.remove();
                          final randomBook = _controller.pickRandomBook();
                          if (randomBook == null) {
                            _controller.setError(LocalizationEngine.text('bookshelf_empty_error'));
                            return;
                          }
                          _openBook(randomBook);
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(LocalizationEngine.text('bookshelf_random_read')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlayState.insert(overlayEntry);
  }

  Future<void> _showScanImportPicker(BuildContext context, [List<ScanCandidateModel>? candidatesParam]) async {
    // 已有候选（如文件夹流程传入）：直接弹选择层，不再重复扫描。
    if (candidatesParam != null) {
      await _presentScanImportDialog(context, candidatesParam);
      return;
    }

    // 扫描导入：后台启动扫描（权限闸门 → 缓存秒开 → 并发扫描实时推送候选 → 落盘），
    // 同时展示「边扫边插 + 虚拟列表」实时弹层（无需等待整轮扫描结束即可见候选增长）。
    await _showLiveScanImportDialog(context);
  }

  /// 展示「扫描导入」实时弹层：边扫描边插入候选、虚拟列表渲染，首屏即时可见。
  ///
  /// 顶部随 [isScanning] 在「扫描进度」与「已找到 N 本」间切换；扫描中列表只读并支持取消，
  /// 扫描完成（或命中缓存秒开）后激活底部「添加扫描目录 / 已选 / 导入」。
  Future<void> _showLiveScanImportDialog(BuildContext context) async {
    final selectedPaths = <String>{};
    // 扫描弹层内的搜索框状态（常驻显示）与类别筛选状态。
    final scanSearchController = TextEditingController();
    var scanCategory = 'all';
    // 触发后台扫描（实时推送候选到 [BookshelfController.scanCandidates]）。
    _controller.runScanForImport();
    var closed = false;

    Future<void> closeAnd(Function() action) {
      if (closed) return Future<void>.value();
      closed = true;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      action();
      return Future<void>.value();
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '导入书籍',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim1, anim2) {
        return SafeArea(
          child: GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            behavior: HitTestBehavior.opaque,
            child: Material(
              color: Colors.transparent,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () {},
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _controller.isScanning,
                    builder: (_, scanning, __) {
                      return ValueListenableBuilder<List<ScanCandidateModel>>(
                        valueListenable: _controller.scanCandidates,
                        builder: (_, candidates, __) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: _controller.folderPermissionBlocked,
                            builder: (_, blocked, ___) {
                              // 权限被拒（且非扫描中）：收起弹层并弹「前往设置」引导。
                              if (blocked && !scanning && !closed) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  closeAnd(() {
                                    _controller.folderPermissionBlocked.value = false;
                                    if (mounted) _showFolderPermissionDialog(context);
                                  });
                                });
                              }
                              // 扫描完成且无候选、无权限限制：收起弹层并提示空结果。
                              if (!scanning && candidates.isEmpty && !blocked && !closed) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  closeAnd(() {
                                    if (mounted) _controller.setError(LocalizationEngine.text('bookshelf_scan_import_empty'));
                                  });
                                });
                              }
                              return StatefulBuilder(
                                builder: (modalCtx, setModalState) => _buildLiveScanCard(
                                  context,
                                  modalCtx,
                                  setModalState,
                                  candidates,
                                  scanning,
                                  selectedPaths,
                                  scanSearchController,
                                  scanCategory,
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, a1, a2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: a1, child: child),
        );
      },
    );
    // 弹层关闭后释放搜索框控制器，避免内存泄漏。
    scanSearchController.dispose();
  }

  /// 构建「扫描导入」实时弹层卡片（头部进度/已找到数量 + 类别筛选 + 搜索 + 虚拟候选列表 + 底部操作）。
  /// [scanSearchController] / [scanCategory] 控制弹层内的搜索关键词与类别筛选，用于过滤扫描到的书籍。
  Widget _buildLiveScanCard(
    BuildContext context,
    BuildContext modalCtx,
    void Function(VoidCallback) setModalState,
    List<ScanCandidateModel> candidates,
    bool scanning,
    Set<String> selectedPaths,
    TextEditingController scanSearchController,
    String scanCategory,
  ) {
    // 按搜索关键词 + 类别筛选候选（标题或路径命中关键词，类别精确匹配）。
    final visibleCandidates = _filterScanCandidatesBy(candidates, scanSearchController.text, scanCategory);
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 12, right: 12, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationEngine.text('bookshelf_scan_import_dialog_title'),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: CupertinoColors.label.resolveFrom(context)),
                      ),
                      const SizedBox(height: 4),
                      // 头部副标题：扫描中显示进度，完成后显示已找到数量（含缓存秒开）。
                      // 计数使用过滤后的可见候选数，与下方列表一致。
                      if (scanning)
                        Text(
                          '${LocalizationEngine.text('bookshelf_scanning_title')} · ${LocalizationEngine.text('bookshelf_scanning_count').replaceAll('%d', _controller.scanProgress.value.toString())} · ${LocalizationEngine.text('bookshelf_scan_found_count').replaceAll('%d', visibleCandidates.length.toString())}',
                          style: TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                        )
                      else
                        Text(
                          LocalizationEngine.text('bookshelf_scan_found_count').replaceAll('%d', visibleCandidates.length.toString()),
                          style: TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                        ),
                    ],
                  ),
                ),
                // 关闭按钮（扫描中点击 = 取消扫描并保留已收集候选）。
                GestureDetector(
                  onTap: () {
                    if (scanning) _controller.cancelScan();
                    Navigator.of(modalCtx).pop();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey5.resolveFrom(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 18, color: CupertinoColors.label.resolveFrom(context)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // 类别筛选胶囊：全部 / PDF / EPUB / TXT / MOBI / 漫画，点击即时过滤候选列表。
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _scanCategoryChips.map((chip) {
                  final key = chip['k']!;
                  final selected = scanCategory == key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setModalState(() {
                        scanCategory = key;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected
                              ? CupertinoTheme.of(context).primaryColor
                              : CupertinoColors.systemGrey6.resolveFrom(context),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          LocalizationEngine.text(chip['t']!),
                          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                                fontSize: 13,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                color: selected
                                    ? CupertinoColors.white
                                    : CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 搜索框（常驻）：实时过滤扫描到的书籍。
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: CupertinoSearchTextField(
              controller: scanSearchController,
              placeholder: LocalizationEngine.text('bookshelf_scan_search_placeholder'),
              onChanged: (_) => setModalState(() {}),
            ),
          ),

          // 候选列表：虚拟列表（ListView.builder）边扫边插，仅构建可视项，千本也不卡。
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: visibleCandidates.isEmpty
                  ? Center(
                      child: (candidates.isEmpty && scanning)
                          ? const CupertinoActivityIndicator(radius: 14)
                          : (candidates.isEmpty && !scanning)
                              ? Text(
                                  LocalizationEngine.text('bookshelf_scan_import_empty'),
                                  style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                                )
                              : Text(
                                  // 有候选但被搜索关键词过滤掉。
                                  LocalizationEngine.text('bookshelf_no_match_books'),
                                  style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                                ),
                    )
                  : ListView.builder(
                      addAutomaticKeepAlives: false,
                      itemCount: visibleCandidates.length,
                      itemBuilder: (ctx2, index) {
                        final candidate = visibleCandidates[index];
                        final isSelected = selectedPaths.contains(candidate.path);

                        Color iconBg;
                        IconData iconData = Icons.book;
                        final type = candidate.type.toLowerCase();
                        if (type.contains('pdf')) {
                          iconBg = Colors.red[400]!;
                          iconData = Icons.picture_as_pdf;
                        } else if (type.contains('epub')) {
                          iconBg = Colors.blue[400]!;
                          iconData = Icons.book;
                        } else if (type.contains('mobi')) {
                          iconBg = Colors.green[400]!;
                          iconData = Icons.menu_book;
                        } else if (type.contains('txt')) {
                          iconBg = Colors.grey[400]!;
                          iconData = Icons.description;
                        } else {
                          iconBg = Colors.purple[400]!;
                          iconData = Icons.book;
                        }

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            // 扫描中也可点选：边扫边选，扫描完成后一并导入，无需等待扫描结束。
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  selectedPaths.remove(candidate.path);
                                } else {
                                  selectedPaths.add(candidate.path);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: iconBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(iconData, color: Colors.white, size: 18),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(candidate.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 1),
                                        Text('${_localizedFileType(candidate.type)} · ${_formatFileSize(candidate.fileSizeBytes)}', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.blue[600] : Colors.transparent,
                                      border: Border.all(color: isSelected ? Colors.blue[600]! : Colors.grey[400]!),
                                      shape: BoxShape.circle,
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, color: Colors.white, size: 12)
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          const Divider(height: 1),

          // 底部操作：添加扫描目录 / 已选数量 / 确认导入。
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  // 扫描中禁用「添加目录」，避免与进行中的扫描竞争。
                  onPressed: scanning
                      ? null
                      : () async {
                          final dir = await FilePicker.getDirectoryPath();
                          if (dir == null || dir.isEmpty) return;
                          final added = _controller.addScanRoot(dir);
                          if (!mounted) return;
                          Navigator.of(modalCtx).pop();
                          if (added) {
                            _controller.showInfoToast(LocalizationEngine.text('bookshelf_scan_root_added'));
                          }
                          // 带新根重新扫描并重列（复用实时弹层）。
                          await _showScanImportPicker(context);
                        },
                  child: Text(
                    '+ ${LocalizationEngine.text('bookshelf_scan_add_dir')}',
                    style: TextStyle(fontSize: 14, color: CupertinoColors.systemBlue.resolveFrom(context)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  LocalizationEngine.text('bookshelf_selected_count').replaceAll('%d', selectedPaths.length.toString()),
                  style: TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                ),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CupertinoColors.systemBlue.resolveFrom(context),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  // 已选即可导入；扫描中亦允许，导入前先取消后台扫描以释放资源。
                  onPressed: (selectedPaths.isEmpty)
                      ? null
                      : () async {
                          if (scanning) _controller.cancelScan();
                          Navigator.of(modalCtx).pop();
                          final selectedCandidates = candidates.where((c) => selectedPaths.contains(c.path)).toList();
                          if (selectedCandidates.isEmpty) {
                            _controller.setError(LocalizationEngine.text('bookshelf_scan_import_empty'));
                            return;
                          }
                          _showImportProgressOverlay(context);
                          await _controller.importScanCandidates(selectedCandidates);
                        },
                  child: Text(
                    LocalizationEngine.text('bookshelf_confirm_import').replaceAll('%d', selectedPaths.length.toString()),
                    style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 展示「扫描导入」候选选择弹层（书名列表 + 选择 + 导入）。
  ///
  /// 含「添加扫描目录」按钮：选中目录后追加到扫描根并重新扫描重列。
  Future<void> _presentScanImportDialog(BuildContext context, List<ScanCandidateModel> candidates) async {
    final selectedPaths = <String>{};

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '导入书籍',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim1, anim2) {
        return SafeArea(
          child: GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            behavior: HitTestBehavior.opaque,
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  // blurred, dimmed background
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                    child: Container(color: Colors.transparent),
                  ),

                  // bottom card
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      onTap: () {},
                      child: StatefulBuilder(
                        builder: (modalCtx, setModalState) {
                          return Container(
                            height: MediaQuery.of(context).size.height * 0.75,
                            margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemBackground.resolveFrom(context),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6)),
                              ],
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 12, left: 12, right: 12, bottom: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              LocalizationEngine.text('bookshelf_scan_import_dialog_title'),
                                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: CupertinoColors.label.resolveFrom(context)),
                                            ),
                                            const SizedBox(height: 10),
                                          ],
                                        ),
                                      ),
                                      // close button
                                      GestureDetector(
                                        onTap: () => Navigator.of(ctx).pop(),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: CupertinoColors.systemGrey5.resolveFrom(context),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.close, size: 18, color: CupertinoColors.label.resolveFrom(context)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 8),

                                const Divider(height: 1),

                                // list
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    child: ListView.separated(
                                      itemCount: candidates.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                                      itemBuilder: (ctx2, index) {
                                        final candidate = candidates[index];
                                        final isSelected = selectedPaths.contains(candidate.path);

                                        // leading icon color by type
                                        Color iconBg;
                                        IconData iconData = Icons.book;
                                        final type = candidate.type.toLowerCase();
                                        if (type.contains('pdf')) {
                                          iconBg = Colors.red[400]!;
                                          iconData = Icons.picture_as_pdf;
                                        } else if (type.contains('epub')) {
                                          iconBg = Colors.blue[400]!;
                                          iconData = Icons.book;
                                        } else if (type.contains('mobi')) {
                                          iconBg = Colors.green[400]!;
                                          iconData = Icons.menu_book;
                                        } else if (type.contains('txt')) {
                                          iconBg = Colors.grey[400]!;
                                          iconData = Icons.description;
                                        } else {
                                          iconBg = Colors.purple[400]!;
                                          iconData = Icons.book;
                                        }

                                        return Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(10),
                                            onTap: () {
                                              setModalState(() {
                                                if (isSelected) {
                                                  selectedPaths.remove(candidate.path);
                                                } else {
                                                  selectedPaths.add(candidate.path);
                                                }
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 32,
                                                    height: 38,
                                                    decoration: BoxDecoration(
                                                      color: iconBg,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Icon(iconData, color: Colors.white, size: 18),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(candidate.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                                        const SizedBox(height: 1),
                                                        Text('${_localizedFileType(candidate.type)} · ${_formatFileSize(candidate.fileSizeBytes)}', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // custom selector
                                                  Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? Colors.blue[600] : Colors.transparent,
                                                      border: Border.all(color: isSelected ? Colors.blue[600]! : Colors.grey[400]!),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: isSelected
                                                        ? const Icon(Icons.check, color: Colors.white, size: 12)
                                                        : const SizedBox.shrink(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                const Divider(height: 1),

                                // bottom actions
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      // 添加扫描目录：选中的目录会追加为扫描根并重新扫描重列。
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () async {
                                          final dir = await FilePicker.getDirectoryPath();
                                          if (dir == null || dir.isEmpty) return;
                                          final added = _controller.addScanRoot(dir);
                                          if (!mounted) return;
                                          // 收起当前选择层，带新根重新扫描并展示。
                                          Navigator.of(ctx).pop();
                                          if (added) {
                                            _controller.showInfoToast(LocalizationEngine.text('bookshelf_scan_root_added'));
                                          }
                                          await _showScanImportPicker(context);
                                        },
                                        child: Text(
                                          '+ ${LocalizationEngine.text('bookshelf_scan_add_dir')}',
                                          style: TextStyle(fontSize: 14, color: CupertinoColors.systemBlue.resolveFrom(context)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        LocalizationEngine.text('bookshelf_selected_count').replaceAll('%d', selectedPaths.length.toString()),
                                        style: TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                                      ),
                                      const Spacer(),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: CupertinoColors.systemBlue.resolveFrom(context),
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: selectedPaths.isEmpty
                                            ? null
                                            : () async {
                                                Navigator.of(ctx).pop();
                                                final selectedCandidates = candidates.where((c) => selectedPaths.contains(c.path)).toList();
                                                if (selectedCandidates.isEmpty) {
                                                  _controller.setError(LocalizationEngine.text('bookshelf_scan_import_empty'));
                                                  return;
                                                }
                                                // 展示导入进度浮层（正在导入第 X / Y 本：书名）。
                                                _showImportProgressOverlay(context);
                                                await _controller.importScanCandidates(selectedCandidates);
                                              },
                                        child: Text(
                                          LocalizationEngine.text('bookshelf_confirm_import').replaceAll('%d', selectedPaths.length.toString()),
                                          style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, a1, a2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: a1, child: child),
        );
      },
    );
  }

  /// 扫描文件夹主流程：选择根目录 → 列出子文件夹 → 用户点选 → 扫描该文件夹书籍 → 确认导入。
  Future<void> _showScanFolderFlow(BuildContext context) async {
    final folders = await _controller.pickFolderAndListSubfolders();
    if (!mounted) return;

    // 用户取消：folders 为 null 但未被权限限制。
    if (folders == null) {
      if (_controller.folderPermissionBlocked.value) {
        _controller.folderPermissionBlocked.value = false;
        _showFolderPermissionDialog(context);
      }
      return;
    }

    if (folders.isEmpty) {
      _controller.setError(LocalizationEngine.text('bookshelf_scan_folder_empty'));
      return;
    }

    await _presentFolderSheet(context, folders);
  }

  /// 展示「扫描文件夹」的文件夹选择底部弹层（UI 与扫描书籍一致，但列表项为文件夹）。
  Future<void> _presentFolderSheet(BuildContext context, List<FolderCandidateModel> folders) async {
    // 多选状态：用户勾选的文件夹路径集合（勾选后直接扫描并导入其中全部书籍）。
    final selectedFolderPaths = <String>{};
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: LocalizationEngine.text('bookshelf_folder_title'),
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, anim1, anim2) {
        return SafeArea(
          child: GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            behavior: HitTestBehavior.opaque,
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                    child: Container(color: Colors.transparent),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      onTap: () {},
                      child: StatefulBuilder(
                        builder: (modalCtx, setModalState) {
                          return Container(
                            height: MediaQuery.of(context).size.height * 0.75,
                            margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemBackground.resolveFrom(context),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6)),
                              ],
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 12, left: 12, right: 12, bottom: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              LocalizationEngine.text('bookshelf_folder_title'),
                                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: CupertinoColors.label.resolveFrom(context)),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              LocalizationEngine.text('bookshelf_scan_folder_multi_hint'),
                                              style: TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => Navigator.of(ctx).pop(),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: CupertinoColors.systemGrey5.resolveFrom(context),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.close, size: 18, color: CupertinoColors.label.resolveFrom(context)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    child: ListView.separated(
                                      itemCount: folders.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                                      itemBuilder: (ctx2, index) {
                                        final folder = folders[index];
                                        final isSelected = selectedFolderPaths.contains(folder.path);
                                        return Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(10),
                                            onTap: () => setModalState(() {
                                              if (isSelected) {
                                                selectedFolderPaths.remove(folder.path);
                                              } else {
                                                selectedFolderPaths.add(folder.path);
                                              }
                                            }),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                                              decoration: BoxDecoration(
                                                border: isSelected
                                                    ? Border.all(color: CupertinoColors.systemBlue.resolveFrom(context), width: 1.5)
                                                    : null,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 38,
                                                    height: 38,
                                                    decoration: BoxDecoration(
                                                      color: CupertinoColors.systemBlue.resolveFrom(context),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Icon(Icons.folder, color: CupertinoColors.white, size: 20),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          folder.name,
                                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CupertinoColors.label.resolveFrom(context)),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          '${folder.bookCount} 本',
                                                          style: TextStyle(fontSize: 11, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  // 勾选态复选框（替代原来的右箭头）。
                                                  Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? CupertinoColors.systemBlue.resolveFrom(context) : Colors.transparent,
                                                      border: Border.all(
                                                        color: isSelected
                                                            ? CupertinoColors.systemBlue.resolveFrom(context)
                                                            : CupertinoColors.systemGrey.resolveFrom(context),
                                                      ),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: isSelected
                                                        ? const Icon(Icons.check, color: CupertinoColors.white, size: 14)
                                                        : null,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const Divider(height: 1),
                                // 底部操作：全选 / 导入选中文件夹的全部书籍（直接导入，不再逐本选择）。
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () => setModalState(() {
                                          if (selectedFolderPaths.length == folders.length) {
                                            selectedFolderPaths.clear();
                                          } else {
                                            selectedFolderPaths.addAll(folders.map((f) => f.path));
                                          }
                                        }),
                                        child: Text(
                                          LocalizationEngine.text('bookshelf_batch_select_all'),
                                          style: TextStyle(fontSize: 14, color: CupertinoColors.systemBlue.resolveFrom(context)),
                                        ),
                                      ),
                                      const Spacer(),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: CupertinoColors.systemBlue.resolveFrom(context),
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: selectedFolderPaths.isEmpty
                                            ? null
                                            : () async {
                                                final selected = selectedFolderPaths.toList();
                                                Navigator.of(ctx).pop();
                                                _showImportProgressOverlay(context);
                                                await _controller.scanAndImportFolders(selected);
                                              },
                                        child: Text(
                                          LocalizationEngine.text('bookshelf_scan_folder_import_count').replaceAll('%d', selectedFolderPaths.length.toString()),
                                          style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, a1, a2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: a1, child: child),
        );
      },
    );
  }

  /// 展示导入进度浮层，监听 [BookshelfController.importProgress]，导入结束自动移除。
  void _showImportProgressOverlay(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    var removed = false;
    entry = OverlayEntry(
      builder: (_) {
        return ValueListenableBuilder<ImportProgress?>(
          valueListenable: _controller.importProgress,
          builder: (ctx, progress, __) {
            if (progress == null) {
              if (!removed) {
                removed = true;
                WidgetsBinding.instance.addPostFrameCallback((_) => entry.remove());
              }
              return const SizedBox.shrink();
            }
            return _buildImportProgressCard(ctx, progress);
          },
        );
      },
    );
    overlay.insert(entry);
  }

  /// 构建导入进度卡片：转圈指示 + 当前书名 + 进度计数 + 百分比进度条 + 预估剩余时间。
  Widget _buildImportProgressCard(BuildContext context, ImportProgress progress) {
    // 总进度百分比（0–100）。
    final percent = progress.total > 0 ? (progress.current / progress.total * 100).round() : 0;
    // 预估剩余时间文案（无法推算时为 null，不展示）。
    final etaText = progress.estimatedRemainingSeconds == null
        ? null
        : LocalizationEngine.text('bookshelf_import_progress_eta')
            .replaceAll('%d', progress.estimatedRemainingSeconds.toString());

    return Stack(
      children: [
        Container(color: Colors.black.withOpacity(0.35)),
        Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CupertinoActivityIndicator(radius: 14),
                const SizedBox(height: 14),
                Text(
                  LocalizationEngine.text('bookshelf_import_progress_title'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CupertinoColors.label.resolveFrom(context)),
                ),
                const SizedBox(height: 8),
                Text(
                  LocalizationEngine.text('bookshelf_import_progress_current')
                      .replaceAll('%s', progress.currentTitle)
                      .replaceAll('%cur%', '${progress.current}')
                      .replaceAll('%tot%', '${progress.total}'),
                  style: TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                // 总进度条：直观展示 current/total 百分比。
                LinearProgressIndicator(
                  value: progress.total > 0 ? progress.current / progress.total : null,
                  backgroundColor: CupertinoColors.systemFill.resolveFrom(context),
                  color: CupertinoColors.systemBlue.resolveFrom(context),
                  minHeight: 6,
                ),
                const SizedBox(height: 6),
                Text(
                  LocalizationEngine.text('bookshelf_import_progress_percent').replaceAll('%d', '$percent'),
                  style: TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                ),
                if (etaText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    etaText,
                    style: TextStyle(fontSize: 12, color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 文件夹访问被拒时弹窗，引导用户前往系统设置开启权限。
  void _showFolderPermissionDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(LocalizationEngine.text('bookshelf_permission_folder_title')),
        content: Text(LocalizationEngine.text('bookshelf_permission_folder_message')),
        actions: [
          CupertinoDialogAction(
            child: Text(LocalizationEngine.text('cancel')),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(LocalizationEngine.text('bookshelf_permission_open_settings')),
            onPressed: () {
              Navigator.of(context).pop();
              StoragePermissionService.openSystemSettings();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openBook(BookModel book) async {
    _controller.updateBookLastRead(book.id, DateTime.now());
    final path = book.path.toLowerCase();
    if (path.endsWith('.pdf')) {
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => BookViewerPage(
            title: book.title,
            filePath: book.path,
            bookId: book.id,
            controller: _controller,
          ),
        ),
      );
      return;
    }

    // EPUB
    if (path.endsWith('.epub')) {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (context) => EpubViewerPage(title: book.title, filePath: book.path, bookId: book.id, controller: _controller)),
      );
      return;
    }

    // TXT
    if (path.endsWith('.txt')) {
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => TxtViewerPage(
            title: book.title,
            filePath: book.path,
            bookId: book.id,
            controller: _controller,
          ),
        ),
      );
      return;
    }

    // Comic archive formats (CBZ/CBR/CB7/CBT)
    if (path.endsWith('.cbz') || path.endsWith('.cbr') || path.endsWith('.cb7') || path.endsWith('.cbt') || path.endsWith('.zip')) {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (context) => ComicViewerPage(title: book.title, filePath: book.path, bookId: book.id, controller: _controller)),
      );
      return;
    }

    // Fallback: try system open
    try {
      final result = await OpenFilex.open(book.path);
      if (result.type != ResultType.done) {
        _controller.setError('无法打开文件：${result.message}');
      }
    } catch (e) {
      _controller.setError('打开文件失败：$e');
    }
  }

  Future<void> _deleteBook(BookModel book) async {
    _controller.removeBook(book.id);
  }

  void _showBookActions(BuildContext context, BookModel book, {Offset? anchorPosition}) {
    final overlayState = Overlay.of(context, rootOverlay: true);

    late final OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final targetPosition = anchorPosition ?? _resolveAnchorPosition(context);
        final mediaQuery = MediaQuery.of(overlayContext);
        final screenWidth = mediaQuery.size.width;
        final screenHeight = mediaQuery.size.height;
        final actions = <Map<String, dynamic>>[
          {
            'label': LocalizationEngine.text('bookshelf_change_cover'),
            'isDestructive': false,
            'onTap': () => _showCoverSourceSheet(context, book),
          },
          {
            'label': book.isFavorite
                ? LocalizationEngine.text('bookshelf_remove_favorite')
                : LocalizationEngine.text('bookshelf_add_favorite'),
            'isDestructive': false,
            'onTap': () => _controller.updateBookFavorite(book.id, !book.isFavorite),
          },
          {
            'label': LocalizationEngine.text('bookshelf_mark_reading'),
            'isDestructive': false,
            'onTap': () => _controller.updateBookReadingState(book.id, 0.5),
          },
          {
            'label': LocalizationEngine.text('bookshelf_mark_finished'),
            'isDestructive': false,
            'onTap': () => _controller.updateBookReadingState(book.id, 1.0),
          },
          {
            'label': LocalizationEngine.text('bookshelf_mark_unread'),
            'isDestructive': false,
            'onTap': () => _controller.updateBookReadingState(book.id, 0.0),
          },
          {
            'label': LocalizationEngine.text('bookshelf_delete'),
            'isDestructive': true,
            'onTap': () => _deleteBook(book),
          },
        ];
        final labels = actions.map((action) => action['label'] as String).toList();
        final menuWidth = _calculateMenuWidth(
          overlayContext,
          labels,
          minWidth: 128.0,
          maxWidth: screenWidth - 24.0,
        );
        final menuHeight = labels.length * 46.0 + (labels.length - 1) * 1.0;
        final safeLeft = (targetPosition.dx - menuWidth / 2).clamp(12.0, screenWidth - menuWidth - 12.0);
        final safeTop = (targetPosition.dy + 8.0).clamp(12.0, screenHeight - menuHeight - 12.0);

        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => overlayEntry.remove(),
              child: Container(color: CupertinoColors.transparent),
            ),
            Positioned(
              left: safeLeft,
              top: safeTop,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: menuWidth,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground.resolveFrom(overlayContext),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: CupertinoColors.systemGrey4.resolveFrom(overlayContext)),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withOpacity(0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(actions.length, (index) {
                      final action = actions[index];
                      final isDestructive = action['isDestructive'] as bool;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            onPressed: () {
                              overlayEntry.remove();
                              (action['onTap'] as VoidCallback).call();
                            },
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                action['label'] as String,
                                style: isDestructive
                                    ? const TextStyle(color: CupertinoColors.destructiveRed)
                                    : null,
                              ),
                            ),
                          ),
                          if (index < actions.length - 1)
                            Container(height: 1, color: CupertinoColors.systemGrey4.resolveFrom(overlayContext)),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlayState.insert(overlayEntry);
  }

  /// 从下向上滑出的「封面来源」抽屉：提供「百度图片搜索」与「从本地相册选择」两种方式。
  ///
  /// 选择本地图片：用 [FilePicker] 选图后读取字节，经 [BookshelfController.updateBookCover]
  /// 统一转码落盘；选择百度图片：打开 [ _showBaiduCoverSearch ] 搜索结果网格。
  Future<void> _showCoverSourceSheet(BuildContext context, BookModel book) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) {
        return CupertinoPopupSurface(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Text(
                    LocalizationEngine.text('bookshelf_cover_source_title'),
                    style: CupertinoTheme.of(popupContext).textTheme.textStyle.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: CupertinoColors.label.resolveFrom(popupContext),
                        ),
                  ),
                ),
                _buildCoverSourceRow(
                  popupContext,
                  icon: CupertinoIcons.search,
                  label: LocalizationEngine.text('bookshelf_cover_from_baidu'),
                  onTap: () {
                    Navigator.of(popupContext).pop();
                    _showBaiduCoverSearch(context, book);
                  },
                ),
                const SizedBox(height: 8),
                _buildCoverSourceRow(
                  popupContext,
                  icon: CupertinoIcons.photo,
                  label: LocalizationEngine.text('bookshelf_cover_from_local'),
                  onTap: () async {
                    Navigator.of(popupContext).pop();
                    final result = await FilePicker.pickFiles(
                      type: FileType.image,
                      allowMultiple: false,
                    );
                    if (!mounted) return;
                    if (result == null || result.files.isEmpty) return;
                    final filePath = result.files.first.path;
                    if (filePath == null) return;
                    final bytes = await File(filePath).readAsBytes();
                    if (!mounted) return;
                    await _controller.updateBookCover(book.id, bytes);
                    _controller.showInfoToast(LocalizationEngine.text('bookshelf_cover_set_success'));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建抽屉内的单行来源项（图标 + 文案 + 右箭头）。
  Widget _buildCoverSourceRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: CupertinoTheme.of(context).primaryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: CupertinoTheme.of(context).primaryColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
              ),
            ),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 18,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 百度图片搜索选封面：底部上滑抽屉，含「引擎选择器 + 搜索框 + 结果网格」，
  /// 点选即下载并替换封面。
  ///
  /// - 引擎：百度移动端接口（中文书籍匹配度最高）/ Bing 兜底 / Google 不可用提示。
  /// - 搜索：调用 [BaiduImageSearchService.search] 拉取缩略图地址（后缀处理由服务按引擎自动适配）；
  /// - 选图：调用 [BaiduImageSearchService.downloadImage] 下载字节，经
  ///   [BookshelfController.updateBookCover] 落盘；失败给出友好提示，不崩溃。
  Future<void> _showBaiduCoverSearch(BuildContext context, BookModel book) async {
    // 抽屉内独立状态（引擎 / 关键词 / 结果 / 加载中 / 正在下载某张）。
    var currentEngine = ImageSearchEngine.baidu;
    final searchController = TextEditingController(text: _bookTitle(book));
    var query = _bookTitle(book);
    var results = <String>[];
    var loading = false;
    var downloadingUrl = '';
    var searchedOnce = false;

    // 按当前引擎搜索一次。
    Future<void> runSearch(StateSetter setInner) async {
      final kw = query.trim();
      if (kw.isEmpty) return;
      setInner(() {
        loading = true;
        searchedOnce = true;
      });
      final list = await BaiduImageSearchService.search(kw, engine: currentEngine);
      if (!mounted) return;
      setInner(() {
        results = list;
        loading = false;
      });
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: LocalizationEngine.text('bookshelf_cover_from_baidu'),
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return SafeArea(
          child: GestureDetector(
            onTap: () => Navigator.of(dialogCtx).pop(),
            behavior: HitTestBehavior.opaque,
            child: Material(
              color: Colors.transparent,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onTap: () {},
                  child: StatefulBuilder(
                    builder: (modalCtx, setInner) {
                      // 进入时预搜一次（仅一次）。
                      if (!searchedOnce && !loading) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          runSearch(setInner);
                        });
                      }
                      return Container(
                        height: MediaQuery.of(context).size.height * 0.82,
                        margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground.resolveFrom(context),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      LocalizationEngine.text('bookshelf_cover_from_baidu'),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: CupertinoColors.label.resolveFrom(context),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.of(dialogCtx).pop(),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.systemGrey5.resolveFrom(context),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.close, size: 18, color: CupertinoColors.label.resolveFrom(context)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            // 搜索引擎选择器：百度匹配度最高（默认），Bing 兜底，Google 不可用。
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                              child: SizedBox(
                                width: double.infinity,
                                child: CupertinoSlidingSegmentedControl<ImageSearchEngine>(
                                  groupValue: currentEngine,
                                  onValueChanged: (v) {
                                    if (v == null) return;
                                    if (v == ImageSearchEngine.google) {
                                      // Google 不可用：弹轻提示，不切换。
                                      _controller.setError(LocalizationEngine.text('bookshelf_cover_engine_google_unavailable'));
                                      return;
                                    }
                                    setInner(() => currentEngine = v);
                                    // 切引擎后自动重搜一次。
                                    runSearch(setInner);
                                  },
                                  children: {
                                    ImageSearchEngine.baidu: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Text(LocalizationEngine.text('bookshelf_cover_engine_baidu'),
                                          style: const TextStyle(fontSize: 13)),
                                    ),
                                    ImageSearchEngine.bing: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Text(LocalizationEngine.text('bookshelf_cover_engine_bing'),
                                          style: const TextStyle(fontSize: 13)),
                                    ),
                                    ImageSearchEngine.google: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Text(LocalizationEngine.text('bookshelf_cover_engine_google'),
                                          style: const TextStyle(fontSize: 13)),
                                    ),
                                  },
                                ),
                              ),
                            ),
                            // 搜索框 + 搜索按钮。
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: CupertinoSearchTextField(
                                      controller: searchController,
                                      placeholder: LocalizationEngine.text('bookshelf_cover_baidu_search_hint'),
                                      onChanged: (value) => query = value,
                                      onSubmitted: (_) => runSearch(setInner),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: loading ? null : () => runSearch(setInner),
                                    child: Text(
                                      LocalizationEngine.text('search'),
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: CupertinoColors.systemBlue.resolveFrom(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            // 结果网格。
                            Expanded(
                              child: _buildBaiduResultGrid(
                                context,
                                loading: loading,
                                results: results,
                                searchedOnce: searchedOnce,
                                downloadingUrl: downloadingUrl,
                                onTapImage: (url) async {
                                  if (downloadingUrl.isNotEmpty) return;
                                  setInner(() => downloadingUrl = url);
                                  final bytes = await BaiduImageSearchService.downloadImage(url);
                                  if (!mounted) return;
                                  if (bytes == null) {
                                    setInner(() => downloadingUrl = '');
                                    _controller.setError(LocalizationEngine.text('bookshelf_cover_pick_failed'));
                                    return;
                                  }
                                  await _controller.updateBookCover(book.id, bytes);
                                  if (!mounted) return;
                                  setInner(() => downloadingUrl = '');
                                  Navigator.of(dialogCtx).pop();
                                  _controller.showInfoToast(LocalizationEngine.text('bookshelf_cover_set_success'));
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, a1, a2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a1, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: a1, child: child),
        );
      },
    );
    searchController.dispose();
  }

  /// 构建百度图片搜索结果网格（加载中 / 空 / 失败 / 网格四态）。
  Widget _buildBaiduResultGrid(
    BuildContext context, {
    required bool loading,
    required List<String> results,
    required bool searchedOnce,
    required String downloadingUrl,
    required void Function(String url) onTapImage,
  }) {
    if (loading) {
      return const Center(child: CupertinoActivityIndicator(radius: 16));
    }
    if (searchedOnce && results.isEmpty) {
      return Center(
        child: Text(
          LocalizationEngine.text('bookshelf_cover_baidu_empty'),
          style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(10),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.72,
        ),
        itemCount: results.length,
        itemBuilder: (ctx, index) {
          final url = results[index];
          final isDownloading = downloadingUrl == url;
          return GestureDetector(
            onTap: () => onTapImage(url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (c, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: CupertinoColors.systemGrey6.resolveFrom(context),
                        child: const Center(child: CupertinoActivityIndicator(radius: 10)),
                      );
                    },
                    errorBuilder: (c, error, stack) => Container(
                      color: CupertinoColors.systemGrey6.resolveFrom(context),
                      child: Icon(CupertinoIcons.photo, color: CupertinoColors.systemGrey.resolveFrom(context)),
                    ),
                  ),
                  if (isDownloading)
                    Container(
                      color: CupertinoColors.black.withOpacity(0.45),
                      child: const Center(child: CupertinoActivityIndicator(radius: 12)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGeneratedCover(BookModel book) {
    final seed = book.title.hashCode % 7;
    final colors = <Color>[
      CupertinoColors.systemBlue,
      CupertinoColors.systemGreen,
      CupertinoColors.systemIndigo,
      CupertinoColors.systemOrange,
      CupertinoColors.systemPink,
      CupertinoColors.systemPurple,
      CupertinoColors.systemTeal,
    ];

    // ★ 不设 width/height，靠父布局（SizedBox(w:70)+AspectRatio(3:4)）的约束自动撑满。
    // 显式 double.infinity 在某些约束链中（如 AspectRatio→Container→fallback 无
    // RepaintBoundary 包裹）可能导致尺寸计算偏差，表现为「只显示一部分」。
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors[seed], colors[(seed + 2) % colors.length]],
        ),
      ),
      child: const Center(
        child: Icon(
          CupertinoIcons.book_fill,
          size: 44,
          color: CupertinoColors.white,
        ),
      ),
    );
  }

  String _bookTitle(BookModel book) {
    final title = book.title.trim();
    if (title.isNotEmpty) {
      return title;
    }
    return book.path.split(Platform.pathSeparator).last;
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return '-';
    }
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var index = 0;
    while (size >= 1024 && index < units.length - 1) {
      size /= 1024;
      index += 1;
    }
    final precision = size >= 100 || index == 0 ? 0 : 1;
    return '${size.toStringAsFixed(precision)} ${units[index]}';
  }

  Widget _buildBookListItem(
    BookModel book, {
    bool selectionMode = false,
    bool isSelected = false,
    VoidCallback? onToggle,
  }) {
    // 选择态：整行点击=切换选中；普通态：点击打开、长按出操作菜单。
    final VoidCallback? rowOnTap = selectionMode ? onToggle : () => _openBook(book);
    final void Function(LongPressStartDetails)? rowOnLongPress = selectionMode
        ? null
        : (details) => _showBookActions(context, book, anchorPosition: details.globalPosition);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: rowOnTap,
        onLongPressStart: rowOnLongPress,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? CupertinoTheme.of(context).primaryColor
                  : CupertinoColors.systemGrey5,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openBook(book),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 88,
                    height: 120,
                    child: _buildBookThumbnail(book),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _bookTitle(book),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: CupertinoColors.label.resolveFrom(context),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${(book.progress * 100).toStringAsFixed(0)}% · ${book.normalizedType.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Builder(
                builder: (buttonContext) {
                  if (selectionMode) {
                    return GestureDetector(
                      onTap: onToggle,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? CupertinoColors.systemBlue.resolveFrom(context)
                              : CupertinoColors.systemBackground.resolveFrom(context),
                          border: Border.all(
                            color: isSelected
                                ? CupertinoColors.systemBlue.resolveFrom(context)
                                : CupertinoColors.systemGrey.resolveFrom(context),
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: isSelected
                            ? const Icon(CupertinoIcons.check_mark, size: 16, color: CupertinoColors.white)
                            : null,
                      ),
                    );
                  }
                  return CupertinoButton(
                    padding: const EdgeInsets.all(6),
                    minSize: 0,
                    borderRadius: BorderRadius.circular(999),
                    color: CupertinoColors.systemGrey6.withOpacity(0.95),
                    onPressed: () => _showBookActions(buttonContext, book),
                    child: const Icon(CupertinoIcons.ellipsis, size: 16),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookThumbnail(BookModel book) {
    // 封面改为磁盘懒加载（见 [BookCoverImage] / [CoverStore]）：内存仅持 hasCover 布尔，
    // 显示时由 Image.file 按需解码。组件内部已用 RepaintBoundary 隔离重绘、
    // cacheWidth 限制解码尺寸，并显式铺满父容器（与 _buildGeneratedCover 一致）。
    final thumbnail = BookCoverImage(
      book: book,
      // 整张封面完整可见：用 contain 等比缩放居中，避免 cover 放大裁掉封面边缘。
      fit: BoxFit.contain,
      fallback: (_) => _buildGeneratedCover(book),
    );

    return Container(
      // ★ 强制填满父布局（AspectRatio 提供的 70×93 紧约束），保证 Web 图片和
      // 生成封面都完整填充封面预留位，不会缩到 Icon(44pt) 大小。
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: CupertinoColors.systemGrey4.withOpacity(0.9),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: thumbnail,
    );
  }

  Widget _buildGridCard(
    BookModel book, {
    bool selectionMode = false,
    bool isSelected = false,
    VoidCallback? onToggle,
  }) {
    // calculate thumbnail and card heights so card is thumbnail height + 2px
    const double thumbWidth = 70.0;
    const double thumbAspect = 3.0 / 4.0;
    final double thumbHeight = thumbWidth / thumbAspect;
    final double cardHeight = thumbHeight + 2.0;

    final theme = CupertinoTheme.of(context);
    // 选择态：点击=切换选中，禁用打开/长按菜单；普通态：点击打开、长按出操作菜单。
    final VoidCallback? cardOnTap = selectionMode ? onToggle : () => _openBook(book);
    final void Function(LongPressStartDetails)? cardOnLongPress = selectionMode
        ? null
        : (details) => _showBookActions(context, book, anchorPosition: details.globalPosition);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: cardOnTap,
      onLongPressStart: cardOnLongPress,
      child: Container(
        height: cardHeight,
        padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: isSelected
              ? Border.all(color: CupertinoTheme.of(context).primaryColor, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 4,
              right: 4,
              child: selectionMode
                  ? GestureDetector(
                      onTap: onToggle,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? CupertinoColors.systemBlue.resolveFrom(context)
                              : CupertinoColors.systemBackground.resolveFrom(context).withOpacity(0.9),
                          border: Border.all(
                            color: isSelected
                                ? CupertinoColors.systemBlue.resolveFrom(context)
                                : CupertinoColors.systemGrey.resolveFrom(context),
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: isSelected
                            ? const Icon(CupertinoIcons.check_mark, size: 14, color: CupertinoColors.white)
                            : null,
                      ),
                    )
                  : Builder(
                      builder: (buttonContext) {
                        return GestureDetector(
                          onTap: () => _showBookActions(buttonContext, book),
                          child: const Padding(
                            padding: EdgeInsets.only(top: 0, right: 0),
                            child: Icon(CupertinoIcons.ellipsis, size: 16, color: CupertinoColors.inactiveGray),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openBook(book),
                    child: SizedBox(
                      width: 70,
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildBookThumbnail(book),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _bookTitle(book),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: CupertinoColors.label.resolveFrom(context),
                                height: 1.25,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatMeta(book),
                          style: const TextStyle(
                            color: CupertinoColors.inactiveGray,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '已读 ${(book.progress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: CupertinoColors.systemBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMeta(BookModel book) {
    return '${_localizedFileType(book.normalizedType)} · ${_formatFileSize(book.fileSizeBytes)}';
  }

  String _localizedFileType(String type) {
    final normalizedType = type.toLowerCase();
    final key = 'file_type_$normalizedType';
    final val = LocalizationEngine.text(key);
    if (val == key) {
      return normalizedType.toUpperCase();
    }
    return val;
  }

  Widget _buildStatsCards(BuildContext context, List<BookModel> books) {
    final allCount = books.length;
    final favCount = books.where((book) => book.isFavorite).length;
    final readingCount = books.where((book) => book.progress > 0 && book.progress < 1).length;
    final finishedCount = books.where((book) => book.progress >= 1.0).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          // 背景改用次要系统背景，与回忆页阅读统计卡片一致，无需硬边框即可与页面底色形成柔和对比
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            // 阴影调淡，仅留极轻的主题主色投影，整体线框更柔和
            BoxShadow(
              color: CupertinoTheme.of(context).primaryColor.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildStatCell(
                context,
                CupertinoIcons.book,
                const Color(0xFF5DA5FF),
                allCount.toString(),
                LocalizationEngine.text('bookshelf_all_label'),
              ),
            ),
            Expanded(
              child: _buildStatCell(
                context,
                CupertinoIcons.star_fill,
                const Color(0xFFFFC857),
                favCount.toString(),
                LocalizationEngine.text('bookshelf_favorites_label'),
              ),
            ),
            Expanded(
              child: _buildStatCell(
                context,
                CupertinoIcons.clock,
                const Color(0xFF43C17C),
                readingCount.toString(),
                LocalizationEngine.text('bookshelf_reading_label'),
              ),
            ),
            Expanded(
              child: _buildStatCell(
                context,
                CupertinoIcons.check_mark,
                const Color(0xFF9B7BFF),
                finishedCount.toString(),
                LocalizationEngine.text('bookshelf_finished_label'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCell(BuildContext context, IconData icon, Color bgColor, String value, String label) {
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;
    final labelFontSize = 12.5;
    final iconSize = labelFontSize * 0.9;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: textStyle.copyWith(
                  color: CupertinoColors.label.resolveFrom(context),
                  fontWeight: FontWeight.w600,
                  fontSize: labelFontSize,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 4),
              Container(
                width: labelFontSize + 8,
                height: labelFontSize + 8,
                decoration: BoxDecoration(
                  color: bgColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular((labelFontSize + 8) / 2),
                  boxShadow: [
                    BoxShadow(
                      color: bgColor.withOpacity(0.24),
                      blurRadius: 6,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(icon, color: bgColor, size: iconSize),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: textStyle.copyWith(
              color: CupertinoColors.label.resolveFrom(context),
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }

  /// 批量管理底部操作栏（现代设计：毛玻璃卡片 + 图标按钮）。
  ///
  /// 左侧显示已选数量，右侧 4 个动作：批量收藏 / 批量已读 / 批量未读 / 批量删除。
  /// 删除需二次确认；其余动作处理后清空当前选择但保持选择模式，方便连续操作。
  Widget _buildBatchActionBar() {
    final count = _selectedIds.length;
    final disabled = count == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context).withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CupertinoColors.systemGrey4.resolveFrom(context)),
        boxShadow: [
          BoxShadow(color: CupertinoColors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              LocalizationEngine.text('bookshelf_batch_selected_count').replaceAll('%d', count.toString()),
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
            ),
          ),
          _buildBatchAction(
            CupertinoIcons.star_fill,
            LocalizationEngine.text('bookshelf_batch_favorite'),
            CupertinoColors.systemOrange.resolveFrom(context),
            disabled: disabled,
            onPressed: disabled
                ? null
                : () {
                    _controller.batchUpdateFavorite(_selectedIds.toList(), true);
                    _controller.showInfoToast(
                      LocalizationEngine.text('bookshelf_batch_done').replaceAll('%d', count.toString()),
                    );
                    setState(() => _selectedIds.clear());
                  },
          ),
          _buildBatchAction(
            CupertinoIcons.check_mark_circled_solid,
            LocalizationEngine.text('bookshelf_batch_mark_read'),
            CupertinoColors.systemGreen.resolveFrom(context),
            disabled: disabled,
            onPressed: disabled
                ? null
                : () {
                    _controller.batchSetReadingState(_selectedIds.toList(), 1.0);
                    _controller.showInfoToast(
                      LocalizationEngine.text('bookshelf_batch_done').replaceAll('%d', count.toString()),
                    );
                    setState(() => _selectedIds.clear());
                  },
          ),
          _buildBatchAction(
            CupertinoIcons.circle,
            LocalizationEngine.text('bookshelf_batch_mark_unread'),
            CupertinoColors.systemGrey.resolveFrom(context),
            disabled: disabled,
            onPressed: disabled
                ? null
                : () {
                    _controller.batchSetReadingState(_selectedIds.toList(), 0.0);
                    _controller.showInfoToast(
                      LocalizationEngine.text('bookshelf_batch_done').replaceAll('%d', count.toString()),
                    );
                    setState(() => _selectedIds.clear());
                  },
          ),
          _buildBatchAction(
            CupertinoIcons.delete_solid,
            LocalizationEngine.text('bookshelf_batch_delete'),
            CupertinoColors.destructiveRed,
            disabled: disabled,
            onPressed: disabled
                ? null
                : () async {
                    final confirmed = await showCupertinoDialog<bool>(
                      context: context,
                      builder: (_) => CupertinoAlertDialog(
                        title: Text(LocalizationEngine.text('bookshelf_batch_delete')),
                        content: Text(
                          LocalizationEngine.text('bookshelf_batch_delete_confirm').replaceAll('%d', count.toString()),
                        ),
                        actions: [
                          CupertinoDialogAction(
                            child: Text(LocalizationEngine.text('cancel')),
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            child: Text(LocalizationEngine.text('confirm')),
                            onPressed: () => Navigator.of(context).pop(true),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      _controller.batchRemove(_selectedIds.toList());
                      setState(() => _selectedIds.clear());
                    }
                  },
          ),
        ],
      ),
    );
  }

  /// 构建操作栏中的单个图标动作（图标在上、文案在下），禁用时置灰。
  Widget _buildBatchAction(
    IconData icon,
    String label,
    Color color, {
    required VoidCallback? onPressed,
    bool disabled = false,
  }) {
    final activeColor = disabled ? CupertinoColors.systemGrey3.resolveFrom(context) : color;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minSize: 0,
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: activeColor),
          const SizedBox(height: 3),
          Text(
            label,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: activeColor,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final headerColor = CupertinoColors.label.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: Text(
          LocalizationEngine.text('bookshelf'),
          style: theme.textTheme.textStyle.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: headerColor,
          ),
        ),
        middle: const SizedBox.shrink(),
        trailing: _selectionMode
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _toggleSelectAll,
                    child: Text(
                      LocalizationEngine.text('bookshelf_batch_select_all'),
                      style: theme.textTheme.textStyle.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _exitSelectionMode,
                    child: Text(
                      LocalizationEngine.text('bookshelf_batch_cancel'),
                      style: theme.textTheme.textStyle.copyWith(fontSize: 15, color: headerColor),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      showCupertinoModalPopup<void>(
                        context: context,
                        builder: (context) {
                          return CupertinoPopupSurface(
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CupertinoTextField(
                                          controller: _searchController,
                                          placeholder: LocalizationEngine.text('bookshelf_search_placeholder'),
                                          prefix: const Padding(
                                            padding: EdgeInsets.only(left: 8),
                                            child: Icon(CupertinoIcons.search),
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              _searchText = value;
                                            });
                                            // 搜索输入高频变化：交由防抖+compute 隔离线程过滤，主线程不被逐字拖慢。
                                            _scheduleFilter(_controller.books.value);
                                          },
                                          clearButtonMode: OverlayVisibilityMode.editing,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: Text(LocalizationEngine.text('done')),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    child: Icon(CupertinoIcons.search, size: 20, color: headerColor),
                  ),
                  const SizedBox(width: 16),
                  Builder(
                    builder: (buttonContext) {
                      return GestureDetector(
                        onTap: () => _showMoreOptions(buttonContext),
                        child: Icon(CupertinoIcons.ellipsis, size: 20, color: headerColor),
                      );
                    },
                  ),
                ],
              ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                ValueListenableBuilder<List<BookModel>>(
                  valueListenable: _controller.books,
                  builder: (context, books, child) {
                    // 使用已缓存的过滤结果（搜索输入经防抖+compute 更新，数据/分类变化即时同步更新）。
                    final filteredBooks = _displayBooks;
                    return Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatsCards(context, books),
                            const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        ...<Map<String, String>>[
                                          {'k': 'all', 't': LocalizationEngine.text('bookshelf_tab_all')},
                                          {'k': 'pdf', 't': LocalizationEngine.text('file_type_pdf')},
                                          {'k': 'epub', 't': LocalizationEngine.text('file_type_epub')},
                                          {'k': 'txt', 't': LocalizationEngine.text('file_type_txt')},
                                          {'k': 'other', 't': LocalizationEngine.text('bookshelf_tab_other')},
                                        ].map((item) {
                                          final key = item['k']!;
                                          final label = item['t']!;
                                          final selected = _selectedCategory == key;
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() => _selectedCategory = key);
                                                // 分类切换：低频且需即时响应，直接同步重算过滤。
                                                _applyFilterImmediate(_controller.books.value);
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: selected ? CupertinoTheme.of(context).primaryColor.withOpacity(0.12) : CupertinoColors.transparent,
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  label,
                                                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                                                    fontSize: 14,
                                                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                                    color: selected ? CupertinoTheme.of(context).primaryColor : CupertinoColors.inactiveGray,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showCoverMode = !_showCoverMode;
                                  });
                                },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    child: Icon(
                                      CupertinoIcons.slider_horizontal_3,
                                      color: _showCoverMode
                                          ? CupertinoColors.inactiveGray
                                              .resolveFrom(context)
                                          : CupertinoTheme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          books.isEmpty
                                ? Center(
                                    child: CupertinoButton.filled(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 14,
                                      ),
                                      onPressed: _controller.importPdf,
                                      child: Text(LocalizationEngine.text('bookshelf_import_button')),
                                    ),
                                  )
                                : filteredBooks.isEmpty
                                    ? Center(
                                        child: Text(
                                          LocalizationEngine.text('bookshelf_no_match_books'),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: CupertinoColors.inactiveGray,
                                          ),
                                        ),
                                      )
                                    : _showCoverMode
                                        ? LayoutBuilder(
                                            builder: (context, constraints) {
                                              const crossAxisCount = 2;
                                              const crossAxisSpacing = 12.0;
                                              const mainAxisSpacing = 12.0;
                                              const hPadding = 12.0;
                                              final cardW = (constraints.maxWidth - hPadding * 2 - crossAxisSpacing * (crossAxisCount - 1)) / crossAxisCount;
                                              // childAspectRatio 1.72 + 文本区域约 56pt
                                              final cardH = cardW / 1.72 + 56;
                                              final rowCount = (filteredBooks.length / crossAxisCount).ceil();
                                              final gridH = hPadding * 2 + rowCount * (cardH + mainAxisSpacing) - mainAxisSpacing;
                                              return SizedBox(
                                                height: gridH.clamp(0.0, double.infinity),
                                                child: GridView.builder(
                                                  // ★ 懒加载：用计算高度替代 shrinkWrap，不再一次性布局全部卡片
                                                  shrinkWrap: false,
                                                  padding: const EdgeInsets.symmetric(horizontal: hPadding, vertical: 6),
                                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: crossAxisCount,
                                                    childAspectRatio: 1.72,
                                                    crossAxisSpacing: crossAxisSpacing,
                                                    mainAxisSpacing: mainAxisSpacing,
                                                  ),
                                                  addRepaintBoundaries: true,
                                                  itemCount: filteredBooks.length,
                                                  itemBuilder: (context, index) {
                                                    final book = filteredBooks[index];
                                                    return RepaintBoundary(
                                                      child: _buildGridCard(
                                                        book,
                                                        selectionMode: _selectionMode,
                                                        isSelected: _selectedIds.contains(book.id),
                                                        onToggle: () => _toggleSelect(book.id),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              );
                                            },
                                          )
                                        : LayoutBuilder(
                                            builder: (context, constraints) {
                                              // 列表每项约 100pt（封面~70 + 内边距~20 + 文字~10），
                                              // 稍高估保证不截断，误差仅底部留少许空白。
                                              const double estimatedItemH = 100.0;
                                              final listH = filteredBooks.length * estimatedItemH + 8;
                                              return SizedBox(
                                                height: listH.clamp(0.0, double.infinity),
                                                child: ListView.builder(
                                                  shrinkWrap: false,
                                                  physics: const NeverScrollableScrollPhysics(),
                                                  addRepaintBoundaries: true,
                                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                                  itemCount: filteredBooks.length,
                                                  itemBuilder: (context, index) {
                                                    final book = filteredBooks[index];
                                                    return RepaintBoundary(
                                                      child: _buildBookListItem(
                                                        book,
                                                        selectionMode: _selectionMode,
                                                        isSelected: _selectedIds.contains(book.id),
                                                        onToggle: () => _toggleSelect(book.id),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                        ],
                      ),
                      ),
                    );
                  },
                ),
              ],
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _controller.isLoading,
              builder: (context, loading, child) {
                if (loading) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: CupertinoActivityIndicator(),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            ValueListenableBuilder<String?>(
              valueListenable: _controller.errorText,
              builder: (context, errorText, child) {
                if (errorText == null) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    errorText,
                    style: const TextStyle(
                      color: Color.fromARGB(255, 163, 65, 60),
                    ),
                  ),
                );
              },
            ),
            ValueListenableBuilder<String?>(
              valueListenable: _controller.toastMessage,
              builder: (context, toast, child) {
                if (toast == null) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  bottom: 20,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.78),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        toast,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          if (_selectionMode)
            Positioned(
              left: 12,
              right: 12,
              bottom: 14,
              child: _buildBatchActionBar(),
            ),
          ],
        ),
      ),
    );
  }
}
