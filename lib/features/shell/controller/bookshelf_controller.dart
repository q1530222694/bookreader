import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:file_picker/file_picker.dart';

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../model/book_model.dart';
import '../model/folder_candidate_model.dart';
import '../model/scan_candidate_model.dart';
import '../service/bookshelf_service.dart';
import '../service/storage_permission_service.dart';

/// 导入进度快照，供 UI 展示「正在导入第 X / Y 本：书名」及百分比、预估剩余时间。
class ImportProgress {
  const ImportProgress({
    required this.current,
    required this.total,
    required this.currentTitle,
    this.estimatedRemainingSeconds,
  });

  /// 当前正在导入第几本（从 1 开始）。
  final int current;

  /// 本次导入的书籍总数。
  final int total;

  /// 当前正在导入的书籍标题（用于进度浮层展示）。
  final String currentTitle;

  /// 预估剩余秒数（基于已用时间与已导入本数推算）；尚无法推算时为 null。
  final int? estimatedRemainingSeconds;
}

/// BookshelfController manages imported books and coordinates file import logic.
class BookshelfController {
  final BookshelfService _service = BookshelfService();

  final ValueNotifier<List<BookModel>> books = BookshelfService.booksNotifier;
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<String?> errorText = ValueNotifier<String?>(null);
  final ValueNotifier<String?> toastMessage = ValueNotifier<String?>(null);

  /// 导入进度快照（当前第几本 / 总数 / 当前书名），供 UI 展示进度浮层。
  final ValueNotifier<ImportProgress?> importProgress = ValueNotifier<ImportProgress?>(null);

  /// 扫描导入进度：已扫描的文件数（节流上报），供 UI 实时展示「已扫描 N 个文件」。
  final ValueNotifier<int> scanProgress = ValueNotifier<int>(0);

  /// 扫描导入候选实时列表（随扫描进度边扫边增），供候选弹层虚拟列表展示。
  final ValueNotifier<List<ScanCandidateModel>> scanCandidates =
      ValueNotifier<List<ScanCandidateModel>>(const []);

  /// 本次扫描是否直接命中缓存（UI 据此跳过进度态、直接展示候选并秒开）。
  final ValueNotifier<bool> scanServedFromCache = ValueNotifier<bool>(false);

  /// 是否正在扫描导入书籍（驱动「扫描中」进度态与候选列表只读态）。
  final ValueNotifier<bool> isScanning = ValueNotifier<bool>(false);

  /// 文件夹访问被操作系统权限限制标记；UI 监听后弹出「前往设置」引导。
  final ValueNotifier<bool> folderPermissionBlocked = ValueNotifier<bool>(false);

  /// 扫描取消标志：UI 点「取消」后置位，扫描循环检测到即停止并返回已收集候选。
  bool _scanCancelled = false;

  Timer? _toastTimer;

  Future<void> importPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'txt', 'mobi', 'cbz', 'cbr', 'cb7', 'cbt'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        errorText.value = '未获取到文件路径';
        return;
      }

      final file = File(filePath);
      if (_service.isBookAlreadyImported(file)) {
        _showToast(LocalizationEngine.text('bookshelf_import_duplicate'));
        return;
      }

      // 单本导入也走统一进度链路，便于大文件时展示「正在导入哪一本」。
      await _importFilesWithProgress([file]);
    } catch (e) {
      errorText.value = '导入书籍失败：$e';
    }
  }

  Future<void> importMultiplePdfs() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'epub', 'txt', 'mobi', 'cbz', 'cbr', 'cb7', 'cbt'],
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final files = result.files
          .where((file) => file.path != null)
          .map((file) => File(file.path!))
          .toList();
      await _importFilesWithProgress(files);
    } catch (e) {
      errorText.value = '批量导入失败：$e';
    }
  }

  /// 启动扫描导入：权限闸门 → 缓存命中即秒开 → 否则并发扫描并实时推送候选 → 落盘缓存。
  ///
  /// 全程通过 [scanProgress]/[scanCandidates]/[isScanning]/[scanServedFromCache]
  /// 驱动 UI，无需等待整轮扫描结束即可看到候选列表边扫边增长（见「边扫边插 + 虚拟列表」优化）。
  /// 被拒绝权限时置位 [folderPermissionBlocked]；用户可调用 [cancelScan] 中途取消，
  /// 取消后返回已收集到的候选。
  Future<void> runScanForImport() async {
    // ① 重置扫描状态。
    _scanCancelled = false;
    scanCandidates.value = const [];
    scanServedFromCache.value = false;
    scanProgress.value = 0;
    isScanning.value = true;

    // ② 权限闸门：扫描导入前主动申请文件夹读取权限，避免无权限导致静默扫不全。
    final granted = await StoragePermissionService.ensureFolderReadAccess();
    if (!granted) {
      folderPermissionBlocked.value = true;
      isScanning.value = false;
      return;
    }

    // ③ 缓存命中则秒开（service 内部按根目录+修改时间查缓存）；否则并发扫描并实时推送。
    try {
      final result = await _service.scanForSupportedBooks(
        extraRoots: SettingsEngine.scanRoots,
        onScanned: (count) => scanProgress.value = count,
        onCandidates: (list) => scanCandidates.value = list,
        isCancelled: () => _scanCancelled,
      );
      scanCandidates.value = result;
      scanServedFromCache.value = _service.lastScanFromCache;
    } finally {
      isScanning.value = false;
    }
  }

  /// 用户追加的扫描根目录（来自 SettingsEngine 持久化）。
  List<String> get scanRoots => SettingsEngine.scanRoots;

  /// 追加一个扫描根目录并持久化（去重）。返回 true 表示本次确实新增了目录。
  bool addScanRoot(String dirPath) {
    if (dirPath.isEmpty) return false;
    final roots = SettingsEngine.scanRoots.toSet();
    if (!roots.add(dirPath)) return false;
    SettingsEngine.scanRoots = roots.toList();
    return true;
  }

  /// 取消正在进行的扫描导入。
  void cancelScan() => _scanCancelled = true;

  /// 是否因用户取消而提前结束扫描。
  bool get isScanCancelled => _scanCancelled;

  /// 通用导入（带进度上报）：遍历文件，逐个去重后导入，并通过 [importProgress] 上报
  /// 当前序号 / 总数 / 当前书名，供 UI 展示「正在导入第 X / Y 本：书名」。
  Future<void> _importFilesWithProgress(List<File> files) async {
    final importable = files.where((file) => !_service.isBookAlreadyImported(file)).toList();
    final skipped = files.length - importable.length;

    if (importable.isEmpty) {
      if (skipped > 0) _showToast(LocalizationEngine.text('bookshelf_import_duplicate_skipped'));
      importProgress.value = null;
      return;
    }

    isLoading.value = true;
    errorText.value = null;
    importProgress.value = ImportProgress(current: 0, total: importable.length, currentTitle: '');
    final stopwatch = Stopwatch()..start();
    var imported = 0;
    try {
      for (var i = 0; i < importable.length; i++) {
        final file = importable[i];
        importProgress.value = ImportProgress(
          current: i + 1,
          total: importable.length,
          currentTitle: _titleOfFile(file.path),
          estimatedRemainingSeconds: _estimateRemainingSeconds(stopwatch, i + 1, importable.length),
        );
        await _service.importPdf(file);
        imported++;
      }
      if (skipped > 0) {
        _showToast(LocalizationEngine.text('bookshelf_import_duplicate_skipped'));
      } else if (imported > 0) {
        _showToast(_importedToast(imported));
      }
    } catch (e) {
      errorText.value = '导入书籍失败：$e';
    } finally {
      importProgress.value = null;
      isLoading.value = false;
    }
  }

  /// 取文件名（去扩展名）作为导入进度展示标题。
  String _titleOfFile(String path) {
    final name = path.split(Platform.pathSeparator).last;
    return name.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
  }

  /// 生成「已成功导入 N 本书」的本地化提示。
  String _importedToast(int count) {
    return LocalizationEngine.text('bookshelf_import_done').replaceAll('%d', count.toString());
  }

  /// 基于已用时间与已导入本数，推算剩余秒数（每本平均耗时 × 剩余本数）。
  int? _estimateRemainingSeconds(Stopwatch stopwatch, int current, int total) {
    if (current <= 0 || total <= current) return null;
    final avgMillisPerBook = stopwatch.elapsedMilliseconds / current;
    final remainingMillis = avgMillisPerBook * (total - current);
    return (remainingMillis / 1000).ceil();
  }

  Future<void> importScanCandidates(List<ScanCandidateModel> candidates) async {
    if (candidates.isEmpty) return;
    final files = <File>[];
    for (final candidate in candidates) {
      final file = File(candidate.path);
      if (await file.exists()) files.add(file);
    }
    // 统一进度链路：逐个去重后导入，并上报当前/总数/书名。
    await _importFilesWithProgress(files);
  }

  /// 扫描文件夹流程：先主动申请操作系统权限，再让用户选择根目录，
  /// 返回其直接子文件夹列表（含递归书籍数）。
  ///
  /// 返回 null 表示用户取消或被权限限制（此时 [folderPermissionBlocked] 会被置位，
  /// UI 据此弹出「前往设置」引导）。
  Future<List<FolderCandidateModel>?> pickFolderAndListSubfolders() async {
    // ① 主动申请文件夹访问权限（满足「被限制要主动请求权限」需求）。
    final granted = await StoragePermissionService.ensureFolderReadAccess();
    if (!granted) {
      folderPermissionBlocked.value = true;
      return null;
    }

    // ② 让用户选择根目录（各平台原生目录选择器）。
    final dirPath = await FilePicker.getDirectoryPath();
    if (dirPath == null || dirPath.isEmpty) {
      return null; // 用户取消
    }

    // ③ 列出子文件夹；若目录本身受限则上抛引导授权。
    try {
      return await _service.listSubfolders(dirPath);
    } on FolderAccessDeniedException {
      folderPermissionBlocked.value = true;
      return null;
    } catch (e) {
      errorText.value = '读取文件夹失败：$e';
      return null;
    }
  }

  /// 递归扫描某个文件夹下的所有受支持书籍，返回候选列表供确认导入。
  Future<List<ScanCandidateModel>> scanBooksInFolder(String folderPath) async {
    try {
      return await _service.scanDirectoryForBooks(folderPath);
    } on FolderAccessDeniedException {
      folderPermissionBlocked.value = true;
      return const <ScanCandidateModel>[];
    } catch (e) {
      errorText.value = '扫描文件夹书籍失败：$e';
      return const <ScanCandidateModel>[];
    }
  }

  BookModel? pickRandomBook() {
    final availableBooks = books.value;
    if (availableBooks.isEmpty) {
      return null;
    }
    final randomIndex = Random().nextInt(availableBooks.length);
    return availableBooks[randomIndex];
  }

  void setError(String? message) {
    errorText.value = message;
  }

  void _showToast(String message) {
    toastMessage.value = message;
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 2), () {
      toastMessage.value = null;
    });
  }

  /// 暴露给 UI 的轻量提示（如「已添加扫描目录」），2 秒后自动消失。
  void showInfoToast(String message) => _showToast(message);

  void updateBookProgress(String bookId, double progress) {
    _service.updateBookProgress(bookId, progress);
  }

  void updateBookReadingDuration(String bookId, int additionalSeconds) {
    _service.updateBookReadingDuration(bookId, additionalSeconds);
  }

  void updateBookFavorite(String bookId, bool isFavorite) {
    _service.updateBookFavorite(bookId, isFavorite);
  }

  void updateBookReadingState(String bookId, double progress) {
    _service.updateBookReadingState(bookId, progress);
  }

  void updateBookLastRead(String bookId, DateTime lastReadAt) {
    _service.updateBookLastRead(bookId, lastReadAt);
  }

  void updateBookTags(String bookId, List<String> tags) {
    _service.updateBookTags(bookId, tags);
  }

  BookModel? getBook(String bookId) {
    return _service.getBookById(bookId);
  }

  void removeBook(String bookId) {
    _service.removeBook(bookId);
  }

  void dispose() {
    isLoading.dispose();
    errorText.dispose();
    toastMessage.dispose();
    importProgress.dispose();
    scanProgress.dispose();
    scanCandidates.dispose();
    scanServedFromCache.dispose();
    isScanning.dispose();
    folderPermissionBlocked.dispose();
    _toastTimer?.cancel();
  }
}
