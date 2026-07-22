import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:pdfrx/pdfrx.dart';

import '../model/book_model.dart';
import '../model/folder_candidate_model.dart';
import '../model/scan_candidate_model.dart';
import 'cover_store.dart';
import 'scan_import_cache_service.dart';

/// BookshelfService handles local book import and simple book metadata extraction.
class BookshelfService {
  BookshelfService({List<Directory>? scanRoots}) : _scanRoots = scanRoots;

  static final List<BookModel> _books = [];
  static final ValueNotifier<List<BookModel>> booksNotifier =
      ValueNotifier<List<BookModel>>(List<BookModel>.unmodifiable(_books));
  static bool _isUpdateScheduled = false;
  final List<Directory>? _scanRoots;

  /// 最近一次扫描是否直接命中缓存（供 UI 判断是否需要展示「扫描中」进度态）。
  bool lastScanFromCache = false;

  /// Returns true when the bookshelf contains at least one book.
  static bool get hasBooks => _books.isNotEmpty;

  /// Import a PDF file and return a book model for the local bookshelf.
  /// If the file path has already been imported, returns the existing book.
  ///
  /// [backgroundCover]：是否把封面生成放入后台工作者池（默认 true，不阻塞导入主流程）。
  /// 批量导入时前几本会传 false，改为由调用方同步生成封面，使书架首屏立即可见封面、
  /// 其余仍走后台，整体保持「导入很快」的体感（见 [importScanCandidates]）。
  Future<BookModel> importPdf(File file, {bool backgroundCover = true}) async {
    if (!await file.exists()) {
      throw FileSystemException('文件不存在', file.path);
    }

    final normalizedPath = _normalizePath(file.path);
    final existingBook = _findBookByNormalizedPath(normalizedPath);
    if (existingBook != null) {
      return existingBook;
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final rawName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : file.path.split(Platform.pathSeparator).last;
    final title = rawName.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
    final type = _detectBookType(file.path.toLowerCase());
    final normalizedTitle = title.isEmpty ? '未命名 ${type.toUpperCase()}' : title;
    final fileSizeBytes = await file.length();

    // 封面不再在导入主流程中同步生成（大 PDF 渲染会阻塞进度浮层），
    // 改为导入完成后后台异步补齐（见 [warmUpCover]）。
    // 此处不再常驻封面字节：hasCover 默认 false，封面由 [_attachCover] 落盘后标记。
    final book = BookModel(
      id: id,
      title: normalizedTitle,
      path: file.path,
      type: BookModel.normalizeBookType(path: file.path, rawType: type),
      progress: 0.0,
      isFavorite: false,
      fileSizeBytes: fileSizeBytes,
      tags: const [],
    );

    _books.add(book);
    _notifyBooksChanged();
    // PDF 封面默认在导入完成后异步生成（后台工作者池），避免阻塞导入主流程与进度展示。
    // 批量导入的前几本会由 [importScanCandidates] 传 backgroundCover=false 同步生成，
    // 使书架首屏立即可见封面；此处不重复后台预热（避免重复渲染）。
    if (type == 'pdf' && backgroundCover) {
      warmUpCover(book, file.path);
    }
    return book;
  }

  /// 扫描导入：递归扫描多个根目录（下载/文档/桌面 + 用户追加目录）下的受支持书籍。
  ///
  /// - [extraRoots] 用户通过 UI 显式追加的扫描根（来自 SettingsEngine 持久化）。
  /// - [onScanned] 每扫描（节流后）一定数量的文件回调一次，供 UI 展示「已扫描 N 个文件」。
  /// - [onCandidates] 扫描过程中按批次实时回传「当前已找到的候选列表」，供 UI 边扫边插。
  /// - [isCancelled] 取消检查；返回 true 时立即停止扫描并返回已收集到的候选。
  /// 各根目录独立遍历（见 [_scanOneRootIncremental]），单个根不可访问不会中断其它根，
  /// 扫描更全面也更健壮（修复「扫不全」问题）。
  ///
  /// 性能优化（断点增量）：扫描前按「根目录路径」查增量缓存（见 [ScanImportCacheService]）。
  /// 命中缓存时，仅对**修改时间发生变化的子目录**重新枚举文件，未变化的子树直接复用
  /// 缓存候选、不再下探，既修复了 Linux/macOS 上深层新增书籍被漏扫的问题，又显著减少
  /// 二次扫描的磁盘枚举量；全量命中缓存时跳过实时扫描、秒级返回（[lastScanFromCache]=true）。
  Future<List<ScanCandidateModel>> scanForSupportedBooks({
    List<String> extraRoots = const [],
    void Function(int scanned)? onScanned,
    void Function(List<ScanCandidateModel> candidates)? onCandidates,
    bool Function()? isCancelled,
  }) async {
    final defaultRoots = _resolveScanDirectories();
    // 合并默认根与追加根，按路径去重（同一目录不要重复扫描）。
    final allPaths = <String>{
      for (final d in defaultRoots) d.path,
      for (final r in extraRoots) r,
    }.toList();

    if (allPaths.isEmpty) {
      return const <ScanCandidateModel>[];
    }

    final allCandidates = <ScanCandidateModel>[];
    final seenPaths = <String>{};
    var totalScanned = 0;
    var reusedTotal = 0;
    var lastPushed = 0;

    // 阈值化实时推送：首条即推（lastPushed==0），之后每累积 64 本推一次，避免整列表重建。
    void pushCandidates() {
      if (lastPushed == 0 || allCandidates.length - lastPushed >= 64) {
        lastPushed = allCandidates.length;
        onCandidates?.call(List<ScanCandidateModel>.of(allCandidates));
      }
    }

    for (final root in allPaths) {
      if (isCancelled?.call() == true) break;

      // ① 取该根的增量缓存（null 表示首次扫描，需整根全量）。
      final cached = await ScanImportCacheService.loadRoot(root);
      final outCursors = <String, int>{};
      final outByDir = <String, List<ScanCandidateModel>>{};
      final reusedCounter = [0];

      // ② 增量扫描：复用未变化子树、仅重扫变化子树。
      await _scanOneRootIncremental(
        root,
        cached?.dirCursors,
        cached?.candidatesByDir,
        outCursors,
        outByDir,
        allCandidates,
        reusedCounter,
        seenPaths,
        (delta) {
          totalScanned += delta;
          // 节流上报：每累积 50 个文件回调一次，避免高频刷新 UI。
          if (totalScanned % 50 == 0) onScanned?.call(totalScanned);
        },
        (_) => pushCandidates(),
        isCancelled,
      );

      reusedTotal += reusedCounter[0];

      // ③ 落盘该根的完整快照（复用 + 新扫），供下次增量复用。
      await ScanImportCacheService.saveRoot(
        root,
        ScanImportCacheEntry(dirCursors: outCursors, candidatesByDir: outByDir),
      );

      // 每个根结束后推送一次完整列表，保证 UI 与实际一致。
      lastPushed = allCandidates.length;
      onCandidates?.call(List<ScanCandidateModel>.of(allCandidates));
    }

    onScanned?.call(totalScanned);
    allCandidates.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    // 全量复用缓存、无任何真实文件扫描 → 视为「命中缓存秒开」（如首次扫为空则不算）。
    lastScanFromCache = reusedTotal > 0 && reusedTotal == allCandidates.length;
    return allCandidates;
  }

  /// 增量扫描单个根目录（含子目录）到 [outByDir]/[outCursors]，累计已扫描文件数到 [onScanned]，
  /// 每新增/复用一本回调一次 [onFound]（传入当前总数，供调用方节流实时推送）。
  ///
  /// 增量逻辑：
  /// - [cachedCursors]/[cachedByDir] 为上次扫描的游标与候选（null 表示首次整根全量扫描）。
  /// - 遇到子目录时先 stat 其 mtime 并与缓存游标比对：
  ///   * 未变化 → 整棵子树（含全部后代）直接复用缓存候选与游标，**不再下探**，
  ///     省去该子树所有文件的磁盘枚举；
  ///   * 变化或新增 → 递归下探，重新枚举其文件并按父目录归入 [outByDir]。
  /// - 文件按扩展名判定是否为受支持书籍，计入 [outByDir][父目录]。
  /// 目录不可访问（沙箱/权限）时静默跳过该根，不影响其它根。
  Future<void> _scanOneRootIncremental(
    String dirPath,
    Map<String, int>? cachedCursors,
    Map<String, List<ScanCandidateModel>>? cachedByDir,
    Map<String, int> outCursors,
    Map<String, List<ScanCandidateModel>> outByDir,
    List<ScanCandidateModel> allCandidates,
    List<int> reusedCounter,
    Set<String> seenPaths,
    void Function(int delta) onScanned,
    void Function(int totalFound) onFound,
    bool Function()? isCancelled,
  ) async {
    final directory = Directory(dirPath);
    if (!await directory.exists()) return;

    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (isCancelled?.call() == true) return; // 用户取消：停止后续扫描。

        if (entity is Directory) {
          final stat = await entity.stat();
          final mtime = stat.modified.millisecondsSinceEpoch;
          outCursors[entity.path] = mtime; // 记录当前游标（无论复用与否）。

          final cachedMtime = cachedCursors?[entity.path];
          if (cachedMtime != null && cachedMtime == mtime) {
            // 子目录未变化：整棵子树直接复用缓存，不再下探枚举（修复深层漏扫关键路径）。
            final sep = Platform.pathSeparator;
            final prefix = '${entity.path}$sep';
            // 复用游标（含全部后代目录）。
            if (cachedCursors != null) {
              cachedCursors.forEach((k, v) {
                if (k == entity.path || k.startsWith(prefix)) outCursors[k] = v;
              });
            }
            // 复用候选（含全部后代目录），仅计入未见过者。
            if (cachedByDir != null) {
              cachedByDir.forEach((k, list) {
                if (k == entity.path || k.startsWith(prefix)) {
                  outByDir[k] = List<ScanCandidateModel>.of(list); // 拷贝，避免共享可变缓存列表。
                  for (final c in list) {
                    if (seenPaths.add(c.path)) {
                      allCandidates.add(c);
                      reusedCounter[0]++;
                      onFound(allCandidates.length);
                    }
                  }
                }
              });
            }
            continue; // 不下探，省去整棵子树的磁盘枚举。
          }

          // 变化或新增：递归下探重新扫描。
          await _scanOneRootIncremental(
            entity.path,
            cachedCursors,
            cachedByDir,
            outCursors,
            outByDir,
            allCandidates,
            reusedCounter,
            seenPaths,
            onScanned,
            onFound,
            isCancelled,
          );
        } else if (entity is File) {
          onScanned(1); // 每检查一个文件计数 +1（供 UI「已扫描 N」）。

          final lowerPath = entity.path.toLowerCase();
          final extension = _safeExtension(lowerPath);
          if (!_supportedExtensions.contains(extension)) continue;
          if (seenPaths.contains(entity.path)) continue; // 多根重叠时去重。

          final title = entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments.last.replaceAll(RegExp(r'\.[^.]+$'), '').trim()
              : entity.path.split(Platform.pathSeparator).last.replaceAll(RegExp(r'\.[^.]+$'), '').trim();

          final candidate = ScanCandidateModel(
            path: entity.path,
            title: title.isEmpty ? '未命名文件' : title,
            type: _detectBookType(lowerPath),
            fileSizeBytes: await entity.length(),
          );
          outByDir.putIfAbsent(dirPath, () => []).add(candidate);
          seenPaths.add(entity.path);
          allCandidates.add(candidate);
          onFound(allCandidates.length); // 通知调用方累计已找到数量（节流在调用方）。
        }
      }
    } on FileSystemException {
      // 沙箱/操作系统权限限制导致无法列举：跳过该根，继续其它根。
    }
  }

  /// 批量导入扫描候选书籍。
  ///
  /// [firstCoversSync]：前若干本 PDF 在导入时**同步**生成封面（导入完成后书架立即可见，
  /// 显得很快），其余入后台工作者池异步渲染（[warmUpCover]），维持导入速度体感。
  /// 默认 4 本——既让首屏「有封面」显得快，又不至于因同步渲染拖慢整体导入。
  Future<void> importScanCandidates(
    List<ScanCandidateModel> candidates, {
    int firstCoversSync = 4,
  }) async {
    var synced = 0;
    for (final candidate in candidates) {
      final file = File(candidate.path);
      if (!await file.exists()) {
        continue;
      }
      // 前 firstCoversSync 本同步生成封面（bookgroundCover=false），其余走后台。
      final syncThis = synced < firstCoversSync;
      final book = await importPdf(file, backgroundCover: !syncThis);
      if (syncThis) {
        synced++;
        // 仅 PDF 有首页封面；其它类型无需同步（后台也不会为其生成）。
        if (book.type == 'pdf') {
          final cover = await _generatePdfCover(file.path);
          if (cover != null) await _attachCover(book.id, cover);
        }
      }
    }
  }

  /// 递归扫描指定目录下的受支持书籍，返回候选列表（供「扫描文件夹」功能使用）。
  ///
  /// 与 [scanForSupportedBooks] 不同，本方法只扫描用户显式选定的单个目录（含子目录）。
  /// 若目录因沙箱/操作系统权限无法访问，抛出 [FolderAccessDeniedException]
  /// 由上层主动请求授权，而不是静默跳过。
  Future<List<ScanCandidateModel>> scanDirectoryForBooks(String dirPath) async {
    final directory = Directory(dirPath);
    if (!await directory.exists()) {
      return const <ScanCandidateModel>[];
    }

    final candidates = <ScanCandidateModel>[];
    final seenPaths = <String>{};

    try {
      await for (final entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;

        final lowerPath = entity.path.toLowerCase();
        final extension = _safeExtension(lowerPath);
        if (!_supportedExtensions.contains(extension)) continue;
        if (seenPaths.contains(entity.path)) continue;

        final title = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last.replaceAll(RegExp(r'\.[^.]+$'), '').trim()
            : entity.path.split(Platform.pathSeparator).last.replaceAll(RegExp(r'\.[^.]+$'), '').trim();

        candidates.add(
          ScanCandidateModel(
            path: entity.path,
            title: title.isEmpty ? '未命名文件' : title,
            type: _detectBookType(lowerPath),
            fileSizeBytes: await entity.length(),
          ),
        );
        seenPaths.add(entity.path);
      }
    } on FileSystemException {
      // 沙箱或操作系统权限限制导致无法列举，上抛供 UI 主动请求授权。
      throw const FolderAccessDeniedException();
    }

    candidates.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return candidates;
  }

  /// 列出指定目录下的直接子文件夹，并统计每个子文件夹递归包含的受支持书籍数量。
  ///
  /// 列表首项为目录自身（便于「直接扫描所选整个文件夹」），其余为各直接子文件夹。
  /// 根目录与所有子目录的书籍计数采用分批并发统计（见 [_countBookCountsConcurrently]），
  /// 深目录场景下显著降低卡顿。访问受限时抛出 [FolderAccessDeniedException]。
  Future<List<FolderCandidateModel>> listSubfolders(String dirPath) async {
    final directory = Directory(dirPath);
    if (!await directory.exists()) {
      return const <FolderCandidateModel>[];
    }

    try {
      final entries = await directory.list().toList();
      final subDirs = entries
          .whereType<Directory>()
          .map((entry) => entry.path)
          .toList();

      // 根目录与所有直接子目录并发统计书籍数，分批避免一次性开启过多并发。
      final allDirs = <String>[dirPath, ...subDirs];
      final counts = await _countBookCountsConcurrently(allDirs);

      final result = <FolderCandidateModel>[
        FolderCandidateModel(
          path: dirPath,
          name: _basename(dirPath),
          bookCount: counts.first,
        ),
      ];
      for (var i = 0; i < subDirs.length; i++) {
        result.add(
          FolderCandidateModel(
            path: subDirs[i],
            name: _basename(subDirs[i]),
            bookCount: counts[i + 1],
          ),
        );
      }
      return result;
    } on FileSystemException {
      throw const FolderAccessDeniedException();
    }
  }

  /// 并发（分批）统计多个目录的书籍数量。
  ///
  /// 目录遍历属于 I/O 密集，在事件循环中天然可并行；分批（每批 8 个）可在
  /// 子文件夹极多的深目录场景下显著提速，同时避免一次性发起过量并发。
  Future<List<int>> _countBookCountsConcurrently(List<String> dirPaths) async {
    const batchSize = 8;
    final results = List<int>.filled(dirPaths.length, 0);
    for (var i = 0; i < dirPaths.length; i += batchSize) {
      final end = (i + batchSize < dirPaths.length) ? i + batchSize : dirPaths.length;
      final batch = dirPaths.sublist(i, end);
      final counts = await Future.wait(batch.map((p) => _countBooksRecursively(p)));
      for (var j = 0; j < counts.length; j++) {
        results[i + j] = counts[j];
      }
    }
    return results;
  }

  /// 递归统计目录（含子目录）下受支持书籍的数量。
  Future<int> _countBooksRecursively(String dirPath) async {
    var count = 0;
    try {
      await for (final entity in Directory(dirPath).list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final lowerPath = entity.path.toLowerCase();
        final extension = _safeExtension(lowerPath);
        if (_supportedExtensions.contains(extension)) count++;
      }
    } on FileSystemException {
      // 忽略无权限访问的子树，避免整列中断。
    }
    return count;
  }

  /// 取路径最后一段作为展示名称（去除结尾分隔符）。
  String _basename(String path) {
    final cleaned = path.replaceAll(RegExp(r'[/\\]$'), '');
    final segments = cleaned.split(Platform.pathSeparator);
    return segments.isNotEmpty ? segments.last : cleaned;
  }

  /// 安全地从路径中提取扩展名（含前导点，如 `.pdf`），全部小写。
  ///
  /// 相比 `path.substring(path.lastIndexOf('.'))`：当文件名**没有点**、**以点点文件**（如 `.gitignore`）
  /// 或**以点在末尾**（如 `file.`）时，旧写法会抛 [RangeError] 或给出错误扩展名，
  /// 导致整目录被静默跳过（「扫不全」的根因）。本方法统一返回 `''`（视为不支持），由调用方跳过。
  static String _safeExtension(String lowerPath) {
    final dot = lowerPath.lastIndexOf('.');
    // dot<=0：无点或隐藏文件（.bashrc）无有效扩展名；dot==末位：结尾点（file.）无效。
    if (dot <= 0 || dot == lowerPath.length - 1) return '';
    return lowerPath.substring(dot);
  }

  /// 受支持导入的书籍扩展名集合（扫描书籍/文件夹共用）。
  ///
  /// 注意：**不含 `.zip`**——普通 zip 压缩包并非漫画/书籍，纳入会导致「扫到一堆非书籍文件」。
  /// 漫画仅认真正的漫画归档（cbz/cbr/cb7/cbt）。
  static const Set<String> _supportedExtensions = {
    '.pdf',
    '.epub',
    '.txt',
    '.mobi',
    '.cbz',
    '.cbr',
    '.cb7',
    '.cbt',
  };

  List<Directory> _resolveScanDirectories() {
    if (_scanRoots != null && _scanRoots.isNotEmpty) {
      return _scanRoots;
    }

    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final directories = <Directory>[];

    String? actualHome = home;
    if (Platform.isMacOS && actualHome != null && actualHome.contains('/Library/Containers/')) {
      final userName = Platform.environment['USER'] ?? Platform.environment['LOGNAME'];
      if (userName != null && userName.isNotEmpty) {
        actualHome = '/Users/$userName';
      }
    }

    if (actualHome != null && actualHome.isNotEmpty) {
      final commonRoots = <String>[
        '$actualHome/Downloads',
        '$actualHome/Documents',
        '$actualHome/Desktop',
      ];
      for (final root in commonRoots) {
        directories.add(Directory(root));
      }
    }

    // 注意：不再硬编码任何具体用户名（如旧版的 /Users/wzh/...）。扫描根完全由
    // 当前登录用户的 HOME/USER 环境变量推导，避免在非开发者机器上扫描到错误/越权目录。

    // Ensure unique directory paths (Directory equality is not guaranteed to dedupe by path)
    final uniqueDirs = directories.map((d) => d.path).toSet().map((p) => Directory(p)).toList();
    return uniqueDirs;
  }

  String _detectBookType(String pathLower) {
    if (pathLower.endsWith('.pdf')) return 'pdf';
    if (pathLower.endsWith('.epub')) return 'epub';
    if (pathLower.endsWith('.txt')) return 'txt';
    if (pathLower.endsWith('.mobi')) return 'mobi';
    if (pathLower.endsWith('.cbz') || pathLower.endsWith('.cbr') || pathLower.endsWith('.cb7') || pathLower.endsWith('.cbt') || pathLower.endsWith('.zip')) {
      return 'comic';
    }
    return 'file';
  }

  /// Returns whether the file has already been imported into the bookshelf.
  bool isBookAlreadyImported(File file) {
    final normalizedPath = _normalizePath(file.path);
    return _findBookByNormalizedPath(normalizedPath) != null;
  }

  BookModel? _findBookByNormalizedPath(String normalizedPath) {
    for (final book in _books) {
      if (_normalizePath(book.path) == normalizedPath) {
        return book;
      }
    }
    return null;
  }

  String _normalizePath(String path) {
    try {
      return File(path).absolute.path.toLowerCase();
    } catch (_) {
      return path.toLowerCase();
    }
  }

  /// Get all imported books.
  List<BookModel> listBooks() {
    return List<BookModel>.unmodifiable(_books);
  }

  /// 从备份恢复书籍：按 [BookModel.id] 合并到现有书架。
  ///
  /// - 已存在相同 id：用导入数据覆盖（保留导入的进度/收藏等最新值）；
  /// - 不存在：追加为新书。
  /// 合并后统一通知书架刷新。供「数据管理 - 导入阅读数据」调用。
  void importBooks(List<BookModel> incoming) {
    for (final book in incoming) {
      final index = _books.indexWhere((b) => b.id == book.id);
      if (index < 0) {
        _books.add(book);
      } else {
        _books[index] = book;
      }
    }
    _notifyBooksChanged();
  }

  /// Get a book by its id.
  BookModel? getBookById(String bookId) {
    for (final book in _books) {
      if (book.id == bookId) {
        return book;
      }
    }
    return null;
  }

  /// Update the reading progress of a book by its id.
  void updateBookProgress(String bookId, double progress) {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index < 0) {
      return;
    }

    final nextProgress = progress.clamp(0.0, 1.0);
    final updatedBook = _books[index].copyWith(progress: nextProgress);
    _books[index] = updatedBook;
    _notifyBooksChanged();
  }

  void updateBookReadingDuration(String bookId, int additionalSeconds) {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index < 0 || additionalSeconds <= 0) {
      return;
    }

    final currentSeconds = _books[index].readingDurationSeconds;
    final updatedBook = _books[index].copyWith(
      readingDurationSeconds: currentSeconds + additionalSeconds,
    );
    _books[index] = updatedBook;
    _notifyBooksChanged();
  }

  void updateBookFavorite(String bookId, bool isFavorite) {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index < 0) {
      return;
    }

    final updatedBook = _books[index].copyWith(isFavorite: isFavorite);
    _books[index] = updatedBook;
    _notifyBooksChanged();
  }

  void updateBookReadingState(String bookId, double progress) {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index < 0) {
      return;
    }

    final nextProgress = progress.clamp(0.0, 1.0);
    final updatedBook = _books[index].copyWith(progress: nextProgress);
    _books[index] = updatedBook;
    _notifyBooksChanged();
  }

  void updateBookLastRead(String bookId, DateTime lastReadAt) {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index < 0) {
      return;
    }

    final updatedBook = _books[index].copyWith(lastReadAt: lastReadAt);
    _books[index] = updatedBook;
    _notifyBooksChanged();
  }

  void updateBookTags(String bookId, List<String> tags) {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index < 0) {
      return;
    }

    final updatedBook = _books[index].copyWith(tags: List<String>.unmodifiable(tags));
    _books[index] = updatedBook;
    _notifyBooksChanged();
  }

  /// 替换某本书的封面：把原始图片字节（可能来自本地相册或网络）统一转码为 PNG 后
  /// 落盘到 [CoverStore]，并置 `hasCover=true`。
  ///
  /// 统一转码的原因：选中的本地/网络图片可能是 jpg/heic 等格式，而 [CoverStore] 固定以
  /// `.png` 扩展名存储；若不转码，部分平台会因「内容与实际扩展名不符」解码失败。
  /// 转码失败则退化为直接保存原始字节（尽力展示）。落盘或解码异常仅忽略，不影响调用方。
  Future<void> updateBookCover(String bookId, Uint8List rawBytes) async {
    final index = _books.indexWhere((book) => book.id == bookId);
    if (index < 0) return;

    Uint8List bytes = rawBytes;
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded != null) {
        bytes = Uint8List.fromList(img.encodePng(decoded));
      }
    } catch (_) {
      bytes = rawBytes; // 转码失败：保留原始字节，交由 Image.file 按内容嗅探解码
    }

    try {
      await CoverStore.save(bookId, bytes);
    } catch (_) {
      return; // 写盘失败：放弃标记，UI 回退到生成式占位封面
    }
    _books[index] = _books[index].copyWith(hasCover: true);
    _notifyBooksChanged();
  }

  /// 批量收藏 / 取消收藏：对 [ids] 内书籍统一设置收藏状态。
  void batchUpdateFavorite(List<String> ids, bool favorite) {
    if (ids.isEmpty) return;
    final idSet = ids.toSet();
    for (var i = 0; i < _books.length; i++) {
      if (idSet.contains(_books[i].id)) {
        _books[i] = _books[i].copyWith(isFavorite: favorite);
      }
    }
    _notifyBooksChanged();
  }

  /// 批量设置阅读进度：对 [ids] 内书籍统一设置为 [progress]（0=未读，1=已读）。
  void batchSetReadingState(List<String> ids, double progress) {
    if (ids.isEmpty) return;
    final idSet = ids.toSet();
    final next = progress.clamp(0.0, 1.0);
    for (var i = 0; i < _books.length; i++) {
      if (idSet.contains(_books[i].id)) {
        _books[i] = _books[i].copyWith(progress: next);
      }
    }
    _notifyBooksChanged();
  }

  /// 批量删除书籍：移除 [ids] 内书籍并同步清理各自的磁盘封面（避免孤儿文件）。
  void batchRemove(List<String> ids) {
    if (ids.isEmpty) return;
    final idSet = ids.toSet();
    _books.removeWhere((book) => idSet.contains(book.id));
    for (final id in ids) {
      CoverStore.delete(id);
    }
    _notifyBooksChanged();
  }

  /// Generate cover bytes from the first page of the imported PDF.
  Future<Uint8List?> _generatePdfCover(String filePath) async {
    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(filePath);
      // pdfrx：通过 document.pages 取页（0-based），无需 getPage/close。
      final page = document.pages[0];
      // 限制封面渲染尺寸：以「最长边 ≤ 400px」为上限等比缩放，避免对大尺寸 PDF 首页
      // 做超大解码（如 2000×2800 直接 *2 会生成 4000×5600 的位图，极为耗内存且拖慢导入）。
      // 封面实际显示仅约 70~140px，400px 上限已足够清晰，内存与导入速度显著改善。
      final double longest = page.width > page.height ? page.width : page.height;
      final double scale = longest > 400 ? 400 / longest : 2.0;
      final int renderW = (page.width * scale).round();
      final int renderH = (page.height * scale).round();
      final pageImage = await page.render(
        width: renderW,
        height: renderH,
        backgroundColor: Colors.white,
      );
      Uint8List? bytes;
      if (pageImage != null) {
        // pdfrx 的 PdfImage 不含原始字节字段，需经 createImage → ui.Image → PNG 字节。
        final uiImage = await pageImage.createImage();
        final data = await uiImage.toByteData(format: ui.ImageByteFormat.png);
        bytes = data?.buffer.asUint8List();
        uiImage.dispose();
        pageImage.dispose();
      }
      await document.dispose();
      return bytes;
    } catch (e) {
      if (document != null) {
        try {
          await document.dispose();
        } catch (_) {}
      }
      return null;
    }
  }

  /// 封面预热的最大并发数：同时最多渲染 [kCoverWarmConcurrency] 本 PDF 封面。
  ///
  /// 旧实现为严格串行：导入上百本 PDF 时封面依次渲染、线性堆积，导入完成很久才「长齐」。
  /// 限制并发可在不抢占主线程的前提下，将「长封面」整体耗时压缩到约 1/并发数，
  /// 导入完即可快速出图。
  static const int kCoverWarmConcurrency = 4;

  /// 封面预热待处理队列（导入时按本入队，工作者池按并发上限消费）。
  final List<_CoverWarmJob> _coverWarmQueue = [];

  /// 当前正在生成的封面任务数（并发上限控制）。
  int _coverWarmActive = 0;

  /// 导入完成后后台异步生成 PDF 封面，避免阻塞导入主流程与进度浮层。
  ///
  /// 通过固定大小为 [kCoverWarmConcurrency] 的工作者池并发执行：入队后由 [_pumpCoverWarm]
  /// 拉起至多 N 个并发渲染任务，每个完成后自动补充队列中的下一个，既显著快于串行，
  /// 又避免无限制并发抢占主线程。生成失败仅忽略，不影响已完成的导入。
  void warmUpCover(BookModel book, String filePath) {
    _coverWarmQueue.add(_CoverWarmJob(book, filePath));
    _pumpCoverWarm();
  }

  /// 按并发上限拉起封面预热任务（工作者池调度）。
  void _pumpCoverWarm() {
    while (_coverWarmActive < kCoverWarmConcurrency && _coverWarmQueue.isNotEmpty) {
      final job = _coverWarmQueue.removeAt(0);
      _coverWarmActive++;
      _generateCoverAndAttach(job.book, job.filePath).whenComplete(() {
        _coverWarmActive--;
        _pumpCoverWarm(); // 一个完成，补充下一个，维持并发上限。
      });
    }
  }

  /// 生成封面并回写至书籍模型（失败忽略，不阻塞导入）。
  Future<void> _generateCoverAndAttach(BookModel book, String filePath) async {
    try {
      final cover = await _generatePdfCover(filePath);
      if (cover != null) await _attachCover(book.id, cover);
    } catch (_) {
      // 封面生成失败不应影响已完成的导入。
    } finally {
      // 让出一帧，避免连续渲染独占主线程。
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// 将封面字节落盘（[CoverStore]）并标记 hasCover，再通知书架更新。
  ///
  /// 改为「磁盘持久化 + 布尔标记」后，内存中不再常驻封面 [Uint8List]；
  /// UI 通过 `BookCoverImage` 按需从磁盘懒加载。落盘失败仅忽略，不影响已完成的导入。
  Future<void> _attachCover(String bookId, Uint8List cover) async {
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index < 0) return;
    try {
      await CoverStore.save(bookId, cover);
    } catch (_) {
      // 封面写盘失败：放弃标记，UI 会回退到生成式占位封面。
      return;
    }
    _books[index] = _books[index].copyWith(hasCover: true);
    _notifyBooksChanged();
  }

  BookModel? pickRandomBook() {
    if (_books.isEmpty) {
      return null;
    }

    final randomIndex = Random().nextInt(_books.length);
    return _books[randomIndex];
  }

  void removeBook(String bookId) {
    _books.removeWhere((book) => book.id == bookId);
    // 同步清理磁盘封面，避免孤儿文件随书籍移除而残留。
    CoverStore.delete(bookId);
    _notifyBooksChanged();
  }

  void _notifyBooksChanged() {
    if (_isUpdateScheduled) {
      return;
    }
    _isUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      booksNotifier.value = List<BookModel>.unmodifiable(_books);
      _isUpdateScheduled = false;
    });
  }
}

/// 封面预热任务（书籍 + 文件路径），供工作者池队列使用。
class _CoverWarmJob {
  final BookModel book;
  final String filePath;
  const _CoverWarmJob(this.book, this.filePath);
}

/// 文件夹访问被操作系统权限/沙箱限制时抛出的异常，提示上层主动请求授权。
class FolderAccessDeniedException implements Exception {
  const FolderAccessDeniedException();
}
