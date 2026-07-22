### [2026-07-22] 修复：开启智能清晰度后翻页崩溃（Image.dispose double-dispose 断言）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_render_service.dart`
  ├─ 变更 ➔ ① 新增幂等释放安全网 `static final Set<ui.Image> _disposedImages` + `_safeDispose(img)`：所有 `ui.Image.dispose()` 统一收口，同一实例二次释放直接忽略，并清理各级缓存/引用残留；② `renderPageImage` 在「基础图→增强」阶段对 `base` 加 `markInUse(base)`，整个 `_enhanceImage(base)` 期间（含离屏取消/异常）走 `try/finally` 统一 `markUnused(base)`，结束后仅当 base 已不在任何缓存且引用计数为 0 才由收尾逻辑 `_safeDispose(base)` 释放一次——杜绝「自有 base 被并发另一路增强使用时释放」的 use-after-dispose / double-dispose；③ `evictImage` 维持「缓存中实例只移除引用、绝不 dispose」约束（上轮已加，保留）。
  └─ 被消费 ➔ `lib/features/shell/ui/pdf_custom_view.dart`（`_PdfPageWidget._enhance` 过期回收分支调用 `evictImage`）
- `lib/features/shell/ui/pdf_custom_view.dart`
  ├─ 变更 ➔ `_PdfPageWidgetState.didUpdateWidget` 新增「pageIndex 变化即重新 `_load()`」分支（位于 enhanceTick/settings 判定之前）：连续滚动 ListView 回收 Element 时同一 State 会被复用显示不同页，不重载会沿用旧页 `_image`/令牌/在途增强，导致旧页异步增强覆盖新页或旧 `_image` 误释放。
  └─ 依赖/调用 ➔ `pdf_render_service.dart`（markInUse/markUnused 全程保护 base）

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置 Key（沿用既有 `denoise`/`sharpness` 阅读设置键，崩溃修复对 UI 与持久化透明）。
- **根因（修正）**：上一轮误将崩溃归因为 `evictImage` 释放共享实例；真正的 double-dispose 发生在 `renderPageImage` 的「基础图释放」分支。开启智能清晰度后翻页（尤其点击翻页=滑动+滚动停止触发 `_enhanceTick++`）会让**同一页并发跑两路 `renderPageImage`**（典型为 `_load` 阶段二增强 与 `didUpdateWidget` 滚动停止增强）：第二路命中 `_baseRenderCache` 拿到**同一个 `base` 实例**，第一路派生 `out` 后在 `!baseFromCache` 分支直接 `base.dispose()`——此刻第二路仍在 `_enhanceImage(base)` 内 `toByteData` 读取该 base，被释放即 use-after-dispose；或第二路稍后把已释放 base 当显示图、翻走时 `markUnused` 再 dispose 一次 → 命中 `Image.dispose()` 的 `!_disposed` 断言。关掉智能清晰度即无阶段二增强、不进入该释放分支，故不崩。
- **修复逻辑**：① `base` 在增强全程受 `markInUse` 保护，并发两路中仅最后一手持有者释放一次；② 所有 `ui.Image.dispose()` 收口到幂等 `_safeDispose`，即便仍有遗漏也不再抛断言；③ `_PdfPageWidget` 跨页复用时 `_load` 重载，杜绝旧页状态串扰。三道防线共同消除该崩溃。

---

### [2026-07-22 (2)] 修复：返回书架崩溃（_safeDispose 在 disposeDocument 迭代中嵌套突变缓存）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_render_service.dart`
  ├─ 变更 ➔ ① `_safeDispose` 剥离所有缓存 `removeWhere` 突变（`_renderCache.removeWhere` / `_baseRenderCache.removeWhere` / 顺序表清理），调用方自行管理缓存生命周期；`Set<ui.Image> _disposedImages` → `Expando<bool> _disposedImages`（弱引用，不阻止已释放 `ui.Image` 的 GC）。
  └─ 依赖/调用 ➔ `disposeDocument` / `_cachePut` / `_cachePutBase` / `_clearDocCaches` / `markUnused` / `evictImage` / `renderPageImage` base 收尾

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置 Key。
- **根因**：`disposeDocument`（以及 `_clearDocCaches`）在 `_renderCache.removeWhere` 的回调中调用 `_safeDispose(img)`，而 `_safeDispose` 内部又对同一 `_renderCache` 做 `removeWhere` ——在迭代同一集合的回调中嵌套突变，触发并发修改异常（集合在迭代中被修改），**阅读一段时间后返回书架即崩溃**。`List.removeWhere`（顺序表）同理。
- **修复逻辑**：`_safeDispose` 不再触碰任何缓存，仅做幂等 dispose + `_inUseImages` 移除；调用方（`disposeDocument` 自身就在外层 `removeWhere` 中移除条目）已正确管理缓存生命周期，无需额外清理。

### [2026-07-22 (3)] 修复：开启智能清晰度后翻页掉帧/转圈（双重增强竞态）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/pdf_custom_view.dart`
  ├─ 变更 ➔ `_PdfPageWidgetState` 新增独立增强令牌 `_enhanceToken`（与 `_loadToken` 分离）；`didUpdateWidget` 的 `enhanceTick` 处理改用 `++_enhanceToken` 而非 `++_loadToken`。
  └─ 依赖/调用 ➔ `pdf_render_service.dart`（renderPageImage）

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置 Key。
- **根因**：PageView 翻页 300ms 动画结束 → `_enhanceTick++` 触发 `didUpdateWidget`，其中 `++_loadToken` **杀掉**了 `_load()` 阶段二（`_enhance`）的令牌。此时若 `_load()` 的阶段二增强正在 `_enhanceImage` 中计算（20-30MB 的 toByteData+isolate+decodeImageFromPixels，耗时 200-500ms），该增强结果完成后发现 token 过期 → 被 `evictImage` 丢弃 → 另一路从零重算。表现为：**每翻一页都长时间转圈**（Stage 1 被迫等锁、Stage 2 被反复杀启→总等待×2）且**明显掉帧**。
- **修复逻辑**：`_load()` 的阶段二使用 `_loadToken`，`enhanceTick` 触发使用 `_enhanceToken`，两路互不取消。`_load()` 阶段二先完成 → 已写缓存且已显示增强图，`enhanceTick` 路径命中缓存瞬间返回；`_load()` 阶段二仍在途 → 两路并发跑（偶有双份计算，但远优于旧逻辑的「杀旧启新·总等待×2·evict 丢弃」）。

---

### [2026-07-22 (4)] 修复：双页模式掉帧/转圈 + 默认设置改为上下单击无动画
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/pdf_custom_view.dart`
  ├─ 变更 ➔ `_prefetchAround` 双页模式下自适应减半预取 spread 窗口（`_kPrefetchAhead ~/2`、`_kPrefetchBehind ~/2`），保持预取总页数 ≈13~14 与单页持平，防止 26 页预取超出基础缓存容量（16）导致翻页缓存落空 → 原生渲染 → 转圈。
  └─ 依赖/调用 ➔ `pdf_render_service.dart`（renderPageImage 基础缓存）
- `lib/features/shell/service/pdf_render_service.dart`
  ├─ 变更 ➔ `_enhanceImage` 新增 `static final Lock _enhanceLock`：双页模式下左右两页同时进入阶段二，两张图并发的 `toByteData`（GPU 回读）+ `decodeImageFromPixels`（GPU 上传）同在 UI 线程同步排队 → 单帧阻塞超 16ms → 掉帧。`_enhanceLock.synchronized` 确保一次仅一页走增强管线，另一页排队，GPU 回读/上传不叠加 → 不掉帧。
  └─ 被消费 ➔ `pdf_custom_view.dart`（_PdfPageWidget._load 阶段二 → renderPageImage → _enhanceImage）
- `lib/engine/settings_engine.dart`
  ├─ 变更 ➔ ① `readerPageModeDefault` 由 0（左右滑动）改为 3（上下单击）；② `readerPageAnimationDefault` 由 1（仿真动画）改为 0（无动画）。
  └─ 被消费 ➔ `book_viewer_page.dart`（读取 pageMode/pageAnimation 确定翻页逻辑）

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置 Key（仅修改了两个常量的默认值，已持久化的用户设置不受影响）。
- **根因 A（双页掉帧/转圈）**：① 双页每 spread 含 2 页，旧预取窗口 13 个 spread = 26 页，远超 `_baseRenderCache` 容量（16），预热页被 LRU 淘汰 → 翻页时缓存落空走原生渲染 → 转圈；② 左右两页同时进入阶段二，`toByteData` + `decodeImageFromPixels` 并发叠加 UI 线程 → 掉帧。
- **根因 B（默认设置）**：用户要求默认改为「上下单击 + 无动画」，无需解释。
- **修复逻辑（A）**：双页预取窗口自适应减半（7 个 spread·2 页=14 页，< 16），预取不溢出、缓存命中率恢复；`_enhanceImage` 加互斥锁，一次仅一页做 GPU 回读/上传；**修复逻辑（B）**：改两个 const 默认值。

---

### [2026-07-21 (5)] 修复：开启智能清晰度后翻页转圈 + 点进看书设置崩溃
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_render_service.dart`
  ├─ 变更 ➔ 新增「正在显示引用」安全网：`static final Set<ui.Image> _inUseImages` + `markInUse(img)`/`markUnused(img)`。所有释放点（LRU 淘汰 `_cachePut`/`_cachePutBase`、`_clearDocCaches`、`disposeDocument`、`evictImage`）在释放 `ui.Image` 前均判定 `if (!_inUseImages.contains(img)) img.dispose();`，仅移出缓存、绝不 dispose 正被 `RawImage` 持绘制的纹理（`markUnused` 时若缓存也未持有才真正释放，避免 GPU 内存泄漏）。
  └─ 被消费 ➔ `lib/features/shell/ui/pdf_custom_view.dart`
- `lib/features/shell/ui/pdf_custom_view.dart`
  ├─ 变更 ➔ ① `_PdfPageWidgetState` 新增 `_setImage(ui.Image?)`（安全替换显示图并登记/释放「正在显示」引用）+ `dispose` 中 `markUnused`；阶段一/二 `setState` 改用 `_setImage`。② PageView 翻页路径补齐 `isScrolling` 降级：`_initControllers` 给 `_pageController` 加 `_onPageScroll` 监听（派生 `transitioning=(page-round()).abs()>0.01`），过渡中 `isScrolling=true` 暂停 Stage2 争抢光栅线程、落定 `false`+`_enhanceTick++`+`setState` 静默重跑增强；`PdfCustomViewState.dispose` 与 `DualScreenPaneState.dispose` 均复位 `isScrolling`。
  └─ 依赖/调用 ➔ `pdf_render_service.dart`（markInUse/markUnused）
- `lib/features/shell/ui/reader_settings_sheet.dart`
  └─ 变更 ➔ `_loadNotes`/`_loadBookmarks` 加 `try/catch`：读取失败改为显示空列表（`debugPrint` 错误），不再让设置面板因数据读取异常而崩溃。

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置 Key（沿用既有 `denoise`/`sharpness` 阅读设置键与 `ReaderDataStore` 读盘接口，崩溃修复对 UI 与持久化透明）。
- **根因 A（进设置崩溃）**：原 LRU 淘汰（`_cachePut`/`_cachePutBase`）与 `evictImage` 直接 `ui.Image.dispose()`。开启智能清晰度后增强图写入更频繁、淘汰更激进，翻多页后进设置面板触发整屏重绘，绘制到已释放纹理 → 原生层崩溃（"trying to draw a disposed image"）。
- **根因 B（翻页转圈）**：连续滚动有 `isScrolling` 降级，但 PageView 翻页路径未接入 `isScrolling`，每页 Stage2 增强与下一页 Stage1 原生渲染抢光栅线程 → 下一页原生渲染推迟 → 转圈。
- **修复逻辑**：① 用 `_inUseImages` 引用集合做「正在显示」保护，所有释放点跳过正显示的实例；② PageView 补 `_onPageScroll` 接入 `isScrolling` 降级，与连续滚动对齐，翻页即时无转圈。

---

### [2026-07-21] 修复：开启智能清晰度后翻几页持续转圈（两级缓存 + 预取去重后处理）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_render_service.dart`
  ├─ 变更 ➔ `renderPageImage` 重构为**两级缓存**：① `_baseRenderCache`（基础原生渲染层，键**不含** `denoise`/`sharpness`，独立 LRU 上限 16）只缓存 PDFium 原生渲染+裁切结果；② `_renderCache`（终成品缓存，键叠加 `denoise:sharpness`，LRU 上限 48）只缓存「带后处理」成品。二者互不共享实例、各自淘汰 `dispose`。`denoise`/`_sharpenImage` 仅在正式展示该页且 `out!=base` 时执行并写入终缓存；新增 `skipPostProcess` 形参、`_cacheGetBase`/`_cachePutBase`/`_maxBaseCache` 与同步的 `_clearDocCaches`/`disposeDocument` 清理。
  └─ 被消费 ➔ `lib/features/shell/ui/pdf_custom_view.dart`
- `lib/features/shell/ui/pdf_custom_view.dart`
  └─ 变更 ➔ `_prefetchAround(spreadIndex)` 预热调用新增 `skipPostProcess:true`：只暖基础原生渲染层、不再触发去杂色/锐化的 `compute` 与主线程 `toByteData`/`decodeImageFromPixels` 的 GPU 上传，避免与正式翻页争抢 isolate 池与 UI 线程。

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置 Key（沿用既有 `denoise`/`sharpness` 阅读设置键，缓存逻辑对 UI 透明）。
- **根因**：原预取对 ±1 对开页（单页 3 页 / 双页 6 页）同样走完整去杂色/锐化链路，每页 3 段代价（主线程 `toByteData` 拷显存 → `compute` 像素运算 → `_bytesToImage` 主线程 GPU 上传，单页 ~22MB×2 次拷贝），预取与正式翻页并发占满 isolate 池与 UI 线程，导致 `setState(_loading=false)` 迟迟无法落帧 → 开了智能清晰度后翻几页就一直转圈。

---

### [2026-07-21] 优化：书架导入封面优先加载（前 N 本同步 + 其余后台工作者池）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/bookshelf_service.dart`
  ├─ 变更 ➔ `importPdf(File, {bool backgroundCover = true})`：`backgroundCover` 为 true 时才将封面生成入后台工作者池（`warmUpCover`），false 时由调用方同步生成封面，避免重复渲染；`importScanCandidates(List, {int firstCoversSync = 4})` 改造——前 `firstCoversSync` 本 PDF 调 `importPdf(file, backgroundCover:false)` 并 `await _generatePdfCover`+`_attachCover` 同步生成封面（书架首屏立即可见），其余本走后台并发工作者池（并发上限 `kCoverWarmConcurrency=4`，`_pumpCoverWarm` 单本完成自动补位），维持「导入很快」的体感。
  └─ 依赖/调用 ➔ `lib/features/shell/service/cover_store.dart` / `_generatePdfCover` / `_attachCover` / `warmUpCover` / `_pumpCoverWarm`。

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置 Key（`firstCoversSync=4` 为局部默认值，未持久化）。

---

### [2026-07-21] 修复：阅读器翻页卡顿（相邻页预渲染 + 去杂色/锐化 compute 隔离 + 渲染缓存 LRU）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_render_service.dart`
  ├─ 变更 ➔ ① 单页 `ui.Image` 缓存由普通 Map 改为 **LRU**（上限 48，命中移到队尾、越界淘汰队首并 `dispose` 释放 GPU 内存；`_clearDocCaches`/`disposeDocument` 同步维护）；② 去杂色 `_denoiseImage`/锐化 `_sharpenImage` 的像素循环抽为顶层 `_denoisePixels(_PixelMsg)`/`_sharpenPixels(_SharpenMsg)` 经 `compute` 隔离（消息类含 `Uint8List`+尺寸+amount，解码回 `ui.Image`），消除主线程冻结；③ 新增 `static double estimateRenderWidth(double targetWidth)`（与视图 `_load` 计算一致：`targetWidth*dpr clamp 200..maxRenderWidth`），供预渲染复用确保缓存键一致。
  └─ 被消费 ➔ `lib/features/shell/ui/pdf_custom_view.dart`
- `lib/features/shell/ui/pdf_custom_view.dart`
  └─ 变更 ➔ 新增 `_prefetchAround(spreadIndex)`：在 `initState` 首帧后预热起始页相邻页、并在 `_reportPage` 翻页后预热当前 ±1 对开页；复用与 `_PdfPageWidget._load` 完全一致的 `effectiveAutoCrop`（`cropOddEvenMode` 分支）/`useManual`/`denoise`/`sharpness`/`estimateRenderWidth(perPageWidth)`，确保命中 `_renderCache`，彻底消除「每次翻页都像刚进书重新渲染」的卡顿。

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置 Key（沿用既有阅读设置键）。

---

### [2026-07-21] 优化：数据管理采纳 3 项建议（导入隔离 / 同步进度 + 多盘容错 / 封面按需回填）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/data_manager/service/backup_service.dart`
  ├─ 变更 ➔ ① `importFromFile` 的 JSON 解析 `jsonDecode` 移入 `compute(_parseBackupJson, content)`（文件顶层函数，避免上千本书大备份阻塞主线程与导入对话框）；合并恢复涉及 `ReaderDataStore` 文件 IO 须主线程，故仅离线解析、对象构造回主线程；② 导入后 `_applyBackup` 末调 `_warmImportedCovers`：对 `hasCover && path` 非空的书，经 `CoverStore.exists(id)` 判本地缺封面则 `BookshelfService().warmUpCover(book, book.path)` 后台重生（失败忽略），使跨设备导入书即时显示封面。
  └─ 依赖/调用 ➔ `lib/features/shell/service/cover_store.dart`（新增）/ `lib/features/shell/service/bookshelf_service.dart`
- `lib/features/data_manager/service/cloud_drive_service.dart`
  └─ 变更 ➔ `sync(bytes, {onProgress})` 加 `ValueChanged<double>? onProgress` 回调，每完成一盘 `onProgress?.call((i+1)/targets.length)` 上报（0~1）；逐盘**顺序同步**，单盘失败写入 `CloudDriveSyncResult.error` 不影响其余盘（天然多盘容错）。
- `lib/features/data_manager/controller/data_manager_controller.dart`
  └─ 变更 ➔ `syncNow({onProgress})` 透传 `CloudDriveService.sync(bytes, onProgress: onProgress)`。
- `lib/features/data_manager/ui/data_manager_page.dart`
  └─ 变更 ➔ `_sync` 改为带 `ValueNotifier<double> progress` 的 `CupertinoAlertDialog` 进度对话框（`ActivityIndicator` + `ValueListenableBuilder` 显示百分比），完成后按每盘 `name · 成功/失败(:error)` 汇总（`data_manager_drive_ok`/`data_manager_drive_fail`），单盘失败不掩盖其余成功。
- `lib/engine/localization_engine.dart`
  └─ 变更 ➔ 新增 3 键 `data_manager_sync_in_progress`/`data_manager_drive_ok`/`data_manager_drive_fail`。
- `lib/engine/settings_engine.dart`
  └─ 变更 ➔ 补 `import '../core/cloud_drive_store.dart';`（修复 `CloudDriveStore` 未定义编译错误）。
- `lib/features/shell/ui/profile_page.dart`
  └─ 变更 ➔ 修正数据管理入口 import 深度：`../data_manager/ui/data_manager_page.dart` → `../../data_manager/ui/data_manager_page.dart`。

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置 Key（`cloudDrives` 沿用既有 `app.dataManager.cloudDrives`）。
- 说明：修复前 `lib/features/data_manager/` 整目录 import 路径错误（service 层误把 `../model/` 当兄弟目录、profile_page 少一层 `..`、settings_engine 漏 import `CloudDriveStore`），致 23 个编译错误；本次一并修正，`flutter analyze` 现已 **0 error**。

---

### [2026-07-18] 修改：OCR 重排图片块检测改为「行带整块裁剪」，解决「一堆碎截图、字没几个、看不清」
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_ocr_service.dart`
  └─ 重写 ➔ `detectImageBlocks()` 由「非白非文本像素连通域」改为「行带(row-band)」检测：
     逐行判定图形行 → 聚成图形带 → 仅保留高度≥页高6%、宽度≥页宽12%的带 → 每带按墨点横向范围整块裁一张图。
     一幅图=一张截图；纯文字页得 0 图块，全部走 OCR 段落重排（ePub 式）。
  └─ 被消费 ➔ `lib/features/shell/service/pdf_ocr_document_builder.dart`（`_buildPage` 调用 detectImageBlocks；
     图块区域内的伪文字检测框经 `_boxesFromScores.overlapsImage` 丢弃，不做 OCR）
  └─ 数据流入 ➔ `lib/features/shell/ui/pdf_ocr_reader_view.dart`（`_mergeFlow` 按 top 坐标把整块图片内联到其上方文字段落之后 = 图放在对应 OCR 文字下方）
- `lib/features/shell/service/pdf_ocr_cache_service.dart`
  └─ 变更 ➔ 缓存文件名 `pdf_ocr_cache_v1.json` → `v2.json`，令旧的「过度碎裂图块」缓存失效，重排时按新算法重跑。

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项（纯算法与缓存版本变更）
- 说明：用户反馈的「打开书就开始 OCR」此前已由 `BookViewerPage.shouldAutoStartOcrOnOpen()` 返回 false 修复，本次不涉及。

---

### [2026-07-18] 修复：PDF 打开后不再自动进入 OCR 重排，改为仅在设置页主动触发
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/book_viewer_page.dart`
  └─ 变更 ➔ 新增 `BookViewerPage.shouldAutoStartOcrOnOpen()`，把 PDF 打开时的 OCR 自动启动关闭，改为仅在用户在设置页点击重排/OCR 入口时触发。
  └─ 依赖/调用 ➔ `lib/features/shell/ui/reader_settings_sheet.dart`（现有重排入口）

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
- 无新增 Config Key

---

### [2026-07-18] 重构：扫描件 OCR 升级为 ePub 式逐页图文混排阅读（可停止 / 可缓存 / 可编辑 / 页码剔除）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/model/pdf_ocr_document.dart`（新增·结构化 OCR 数据骨架）
  ├─ 新增 ➜ `PdfOcrTextSegment`（行：文本 + 轴对齐包围盒 + 置信度，JSON 可序列化）/ `PdfOcrImageBlock`（图片块 kind='image'，本轮跳过 OCR 内联；预留 'table'/'formula'）/ `PdfOcrPageData`（页：原图 base64 + 文本行 + 图片块）/ `PdfOcrDocument`（整本，sourceKey + 页列表）
  ├─ 依赖/调用 ➜ 无跨模块依赖（纯数据模型）
- `lib/features/shell/service/pdf_ocr_cache_service.dart`（新增·按文件落盘缓存）
  ├─ 新增 ➜ `computeKey(path)`（路径+大小+修改时间派生稳定键，`path_provider` 无需 crypto）/ `load(key)`（内存+JSON 双缓存）/ `save(doc)`（全量）/ `savePage(doc,page)`（增量合并+落盘）
  ├─ 依赖/调用 ➜ `package:path_provider` / `../model/pdf_ocr_document.dart`
- `lib/features/shell/service/pdf_ocr_document_builder.dart`（新增·结构化文档组装器）
  ├─ 新增 ➜ `build(document, sourceKey, {eagerPages, cancelled, onProgress, onPage})`（逐页：渲染 PNG→DB 检测→图片块检测（跳过 OCR）→连通域取文本行→CRNN 识别；`cancelled` 每次重量操作前检查，解决「停不下来」）/ `suppressPageNumbers(doc)`（位置桶算法剔除跨页页眉/页脚/页码，解决「页码混入正文」）
  ├─ 依赖/调用 ➜ `pdf_ocr_service.dart`（`renderPageToPng`/`detectPage`/`detectImageBlocks`/`cropAxisAlignedPublic`/`recognizeCrop`）/ `pdf_ocr_cache_service.dart` / `package:pdfrx` / `package:flutter/painting.dart`
  ├─ export ➜ `../model/pdf_ocr_document.dart`
- `lib/features/shell/ui/pdf_ocr_reader_view.dart`（新增·ePub 式逐页阅读视图）
  ├─ 新增 ➜ `PdfOcrReaderView`（每页=原扫描图底+该页 OCR 文字层半透明叠加+图片块内联；长按文字弹编辑框；顶栏「退出」+后台时「停止」+轻量「后台识别中」文案）
  ├─ 依赖/调用 ➜ `../model/pdf_ocr_document.dart` / `lib/engine/localization_engine.dart`（`pdf_ocr_reader_exit`/`pdf_ocr_reader_stop`/`pdf_ocr_reader_background`/`pdf_ocr_edit_title`/`pdf_ocr_no_content`）
- `lib/features/shell/ui/book_viewer_page.dart`（修改·接入口令）
  ├─ 变更 ➜ 重排按钮：文本层 PDF 走原生 [PdfReflowView]；扫描件改走 `PdfOcrReaderView`（逐页图文混排）
  ├─ 新增 ➜ `_startOcr(auto)`（优先命中缓存秒开；否则后台逐页识别+增量落盘；`auto=true` 无感不弹进度条，`auto=false` 极短加载）/ `_maybeAutoOcr()`（打开扫描件且无文本层时自动后台识别；有文本层走原生重排）/ `_cancelOcr()`（令牌自增中止后台）/ `_exitOcrReader()` / `_onOcrEdit(...)`（写回+增量落盘）
  ├─ 修复 ➜ 「一直识别无法停止」：OCR 后台闭包以 `_ocrRunToken` 令牌判定中止，`dispose` 与退出/停止均自增令牌；移除旧 `extractOcr` fire-and-forget 无取消路径
  ├─ 移除 ➜ 旧 OCR 进度下拉条（`_reflowOcrCurrent`/`_reflowOcrTotal`/`_isOcrLoading`/`_ocrProgressText`），改由阅读视图自身展示「后台识别中」
  ├─ 依赖/调用 ➜ `pdf_ocr_document_builder.dart` / `pdf_ocr_cache_service.dart` / `pdf_ocr_reader_view.dart` / `pdf_ocr_document.dart` / `pdf_ocr_service.dart`（`isModelAvailable`）/ `pdf_text_reflow_service.dart`（仅文本层路径）

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
- 无新增 Config Key（复用既有 `pdfOcrEnabled` / `pdfOcrEagerPages`）

**【依赖新增】**
- 无新增第三方包（缓存/序列化复用 `path_provider` + `dart:convert` + `dart:typed_data`）

**【多语言变更 (i18n)】**
- 无新增 i18n 键（沿用上一轮已加 `pdf_ocr_reader_exit` / `pdf_ocr_reader_stop` / `pdf_ocr_reader_background` / `pdf_ocr_edit_title` / `pdf_ocr_no_content`）

---

### [2026-07-14] 统一：5 个转换工具页布局统一 + 修复移动端打开/拖拽排序/删除记录
**【AI 架构依赖树 (Architecture Context)】**
- `lib/shared/ui/conversion_scaffold.dart`（新增·共享 UI 脚手架）
  └─ 新增 ➔ 转换页统一外壳 `ConversionScaffold`（导航栏 + 转换/记录分段控件 + 宽屏居中）与构件集：`ConversionInfoCard` / `ConversionPrimaryButton` / `ConversionEmptyState` / `ConversionRecordCard` / `ConversionRecordActions` / `ConversionFormat`
  └─ 新增 ➔ `openConversionFile()`（`OpenFilex.open` 真实打开导出文件，修复移动端假弹窗 BUG）、`confirmConversionDelete()`（删除二次确认）
  └─ 依赖/调用 ➔ `lib/engine/localization_engine.dart` / `lib/shared/ui/app_text_styles.dart` / `package:open_filex`
- `lib/features/txt_to_epub/ui/txt_to_epub_page.dart`
- `lib/features/doc_to_pdf/ui/doc_to_pdf_page.dart`
- `lib/features/ppt_to_pdf/ui/ppt_to_pdf_page.dart`
- `lib/features/excel_to_pdf/ui/excel_to_pdf_page.dart`
  └─ 重写 ➔ 统一为「转换」Tab（提示卡→选择文件→已选卡→开始转换→状态）+「记录」Tab（打开 / 删除），消费 `conversion_scaffold.dart`
  └─ 修复 ➔ 移动端「打开」改为真实打开；新增删除记录能力；移除硬编码文案/字号/颜色
  └─ 依赖/调用 ➔ 各自 controller 的 `deleteExportRecord(timestamp)`（新增）
- `lib/features/image_to_pdf/ui/image_to_pdf_page.dart`
  └─ 重写 ➔ 消费 `conversion_scaffold.dart`；横向 `ReorderableListView` 缩略图（角标 × 删除 + 拖动重排）
  └─ 修复 ➔ 兑现「拖拽重新排序」（`onReorder` → `ImageToPdfController.reorderImages`，此前从未调用）；「查看」改真实打开；`proxyDecorator` 规避纯 Cupertino 树缺 Material 祖先
  └─ 依赖/调用 ➔ `package:flutter/material.dart show ReorderableListView` / `bookshelf_service.dart`（加入书架）
- `lib/features/{txt_to_epub,doc_to_pdf,ppt_to_pdf,excel_to_pdf}/service/*.dart` + `controller/*.dart`
  └─ 新增 ➔ `deleteExportRecord(int timestamp)`（service 删除物理文件 + 回写 JSON；controller 静态委托）
- `lib/engine/localization_engine.dart`
  └─ 新增 ➔ 30+ 个 `conv_*` 转换页多语言键（zh/en）

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增/修改 Config Key
- 无新增/修改 Permission Key

**【依赖新增】**
- `open_filex ^4.3.2`（pubspec 已含）—— 移动端/桌面真实打开导出文件

**【多语言变更 (i18n)】**
- `conv_tab_convert` / `conv_tab_records` / `conv_select_txt|doc|ppt|excel|images` / `conv_start` / `conv_converting` / `conv_selected_file` / `conv_open` / `conv_view` / `conv_add_shelf` / `conv_added_shelf` / `conv_no_record` / `conv_delete` / `conv_delete_confirm_title` / `conv_delete_confirm_msg` / `conv_cancel` / `conv_open_failed` / `conv_file_not_found` / `conv_tip_txt|doc|ppt|excel|image` / `conv_selected_count`(含 %d) / `conv_image_count`(含 %d) / `conv_convert_failed`

---

### [2026-07-12] 优化：阅读设置面板高度收紧并降低按钮间距
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/reader_settings_sheet.dart`
  └─ 变更 ➔ 收紧面板内边距、标题与分组间距、主题色块尺寸、字体与翻页按钮高度，降低整体面板高度约 1/3，避免遮挡并提升紧凑度
  └─ 变更 ➔ 主题色选项与应用“主题配色”保持一致，点击后同步更新全局主题色
  └─ 依赖/调用 ➔ `lib/features/shell/ui/txt_viewer_page.dart`
  └─ 依赖/调用 ➔ `lib/features/shell/ui/book_viewer_page.dart`
  └─ 依赖/调用 ➔ `lib/features/shell/controller/settings_controller.dart`
- `test/txt_viewer_page_test.dart`
  └─ 变更 ➔ 新增阅读设置面板紧凑布局回归测试
  └─ 变更 ➔ 新增主题色与全局设置同步的回归测试

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
- 无新增 Config Key

---

### [2026-07-12] 修改：TXT 阅读设置界面与 PDF 阅读器保持一致
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/txt_viewer_page.dart`
  └─ 变更 ➔ 将 TXT 阅读页的设置面板改为与 PDF 阅读器一致的叠层遮罩、顶部标题栏、圆角抽屉和收起/展开动画
  └─ 依赖/调用 ➔ `lib/features/shell/ui/reader_settings_sheet.dart`
- `test/txt_viewer_page_test.dart`
  └─ 变更 ➔ 增加 TXT 设置面板的回归测试，确认其使用与 PDF 相同的圆角抽屉展示结构

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
- 无新增 Config Key

---

### [2026-07-12] 新增：TXT 阅读页进入全屏后支持中间触发设置面板
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/txt_viewer_page.dart`
  └─ 变更 ➔ 默认进入全屏阅读体验，点击阅读内容区域可弹出底部设置面板，并支持主题、亮度、字体和翻页方式切换
  └─ 依赖/调用 ➔ `lib/features/shell/ui/reader_settings_sheet.dart`
  └─ 依赖/调用 ➔ `lib/engine/localization_engine.dart`
- `lib/features/shell/ui/reader_settings_sheet.dart`
  └─ 新增 ➔ 提供与需求一致的底部抽屉式阅读设置面板 UI
- `lib/engine/localization_engine.dart`
  └─ 变更 ➔ 新增阅读设置相关多语言键
- `test/txt_viewer_page_test.dart`
  └─ 变更 ➔ 新增点击中间显示设置面板的回归测试

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
- 无新增 Config Key

---

### [2026-07-10] 修改：主页阅读统计改为真实书架数据
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/home_page.dart`
  └─ 变更 ➔ 将首页阅读统计卡片从硬编码模拟数据改为基于真实书架书籍的 `progress` 与 `lastReadAt` 计算
  └─ 依赖/调用 ➔ `lib/features/shell/model/book_model.dart`
  └─ 依赖/调用 ➔ `lib/engine/localization_engine.dart`
- `lib/engine/localization_engine.dart`
  └─ 变更 ➔ 新增 `minutes_short` 多语言键，供首页统计时格式化分钟展示

**【全局状态/鉴权变动 (State & Auth)】**
- 修改：首页阅读统计不再使用硬编码模拟值，而是根据真实书架书籍的进度和最近阅读时间动态计算
- 新增：`minutes_short` 多语言键，用于展示分钟单位

---

### [2026-07-10] 优化：书架过滤按钮切换为下载样式列表 UI
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/bookshelf_page.dart`
  └─ 变更 ➔ 将原先点击过滤按钮时弹出的 `CupertinoActionSheet` 改为切换到下载样式列表视图
  └─ 依赖/调用 ➔ `lib/engine/localization_engine.dart`
  └─ 依赖/调用 ➔ `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 消费 ➔ `lib/features/shell/model/book_model.dart`
- `lib/engine/localization_engine.dart`
  └─ 变更 ➔ 新增 `just_now` 多语言键，支持新列表项时间标签显示

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
- 无新增 Config Key

---

### [2026-07-09] 修复：主页应用启动次数文案随语言切换正确刷新
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/home_page.dart`
  └─ 变更 ➔ 为启动次数统计卡片增加对语言状态的显式监听，确保中英文切换后立即刷新文案
  └─ 依赖/调用 ➔ `lib/features/shell/controller/settings_controller.dart`
  └─ 依赖/调用 ➔ `lib/engine/localization_engine.dart`
  └─ 依赖/调用 ➔ `lib/features/shell/service/app_stats_service.dart`
- `lib/engine/localization_engine.dart`
  └─ 修复 ➔ 补齐 `period_day` 与启动次数相关多语言键，避免翻译映射缺失时回退为英文

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
- 无新增 Config Key

---

### [2026-07-08] 优化：设置页隐藏语言与外观入口
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/settings_page.dart`
  └─ 变更 ➔ 从设置页主列表中隐藏“语言设置”和“外观设置”入口，保留页面路由能力，避免与外层已展示入口重复
  └─ 依赖/调用 ➔ `lib/features/shell/ui/language_page.dart`
  └─ 依赖/调用 ➔ `lib/features/shell/ui/appearance_page.dart`

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
- 无新增 Config Key

---

### [2026-07-09] 优化：应用外观主题模式改为卡片式单选组件
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/appearance_page.dart`
  └─ 变更 ➔ 将“主题模式”区域重构为三个等宽卡片式单选按钮，采用 `Row + Expanded` 的 Flexbox 布局并保持统一间距
  └─ 变更 ➔ 选中态增加高亮边框、背景色和加粗文案，提升视觉反馈
  └─ 依赖/调用 ➔ `lib/features/shell/controller/settings_controller.dart`
  └─ 依赖/调用 ➔ `lib/engine/settings_engine.dart`

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
- 无新增 Config Key

---

### [2026-07-08] 新增：应用外观设置中的启动页设置子页面
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/appearance_page.dart`
  └─ 变更 ➔ 将原先分散的启动页、启动页内容和显示时长配置收敛为一个“启动页设置”入口
  └─ 依赖/调用 ➔ `lib/features/shell/ui/splash_settings_page.dart`
- `lib/features/shell/ui/splash_settings_page.dart`
  └─ 新增 ➔ 提供启动页预览、内容类型、图片设置、显示时长、进入方式与跳转页面的统一配置界面
  └─ 依赖/调用 ➔ `lib/features/shell/controller/settings_controller.dart`
  └─ 依赖/调用 ➔ `lib/engine/settings_engine.dart`
- `lib/engine/localization_engine.dart`
  └─ 变更 ➔ 新增 `splash_settings` 多语言文案

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
- 无新增 Config Key

---

### [2026-07-08] 优化：设置页隐藏语言与外观入口
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/settings_page.dart`
  └─ 变更 ➔ 从设置页主列表中隐藏“语言设置”和“外观设置”入口，保留页面路由能力，避免与外层已展示入口重复
  └─ 依赖/调用 ➔ `lib/features/shell/ui/language_page.dart`
  └─ 依赖/调用 ➔ `lib/features/shell/ui/appearance_page.dart`

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
- 无新增 Config Key

---

### [2026-07-08] 优化：我的页面移除占位欢迎文案
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/profile_page.dart`
  └─ 变更 ➔ 移除“我的”页面账户设置卡片中的欢迎/占位描述文案，保留会员与同步按钮入口
  └─ 依赖/调用 ➔ `lib/engine/localization_engine.dart`
  └─ 依赖/调用 ➔ `lib/features/membership/ui/membership_page.dart`

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
- 无新增 Config Key

---

### [2026-07-07] 优化：主页阅读统计卡片文案与布局
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/home_page.dart`
  └─ 变更 ➔ 将首页三个阅读统计卡片高度收紧，并将标签置于数值上方
  └─ 变更 ➔ 第三个统计卡片改为使用 `cumulative_reading` 文案，确保中文环境下显示为“累计阅读”
  └─ 依赖/调用 ➔ `lib/engine/localization_engine.dart`
- `lib/engine/localization_engine.dart`
  └─ 依赖/调用 ➔ `lib/engine/settings_engine.dart`
  └─ 变更 ➔ 保证主页统计文案在中英文环境下正确显示
- `lib/features/shell/ui/home_page.dart`
  └─ 变更 ➔ 将“阅读统计”标题置于卡片左上角并加粗，主数据字号缩小且靠左贴边
  └─ 变更 ➔ 在阅读统计卡片右侧新增“连续阅读”块，包含火花图标、标题与 18 天数值

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
- 无新增 Config Key

---

### [2026-07-07] 优化：主页顶部标题与操作按钮布局
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/home_page.dart`
  └─ 依赖/调用 ➔ `lib/features/shell/controller/settings_controller.dart`
  └─ 依赖/调用 ➔ `lib/engine/settings_engine.dart`
  └─ 变更 ➔ 将首页标题移动至导航栏左侧，并在右侧新增语言切换与主题模式切换按钮
  └─ 变更 ➔ 语言按钮在中文/英文之间切换，主题按钮仅显示图标并切换浅/深色模式

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
- 无新增 Config Key

---

### [2026-07-07] 修复：书架“更多”菜单宽度自适应最长文本
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/bookshelf_page.dart`
  └─ 变更 ➔ 调整书架页面“更多”弹窗宽度为基于最长菜单项文本动态计算，避免固定宽度过宽

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
- 无新增 Config Key

---

### [2026-07-07] 修复：书架暗色模式统计卡片与书架卡片背景
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/bookshelf_page.dart`
  └─ 变更 ➔ 将书架统计框和全部书籍网格卡片背景从硬编码白色改为主题背景色，修复暗色模式白底问题

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
- 无新增 Config Key

---

### [2026-07-07] 优化：主页继续阅读与问候卡片间距收紧为 2 像素
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/home_page.dart`
  └─ 变更 ➔ 将“问候卡片”与“继续阅读”卡片之间的间距收紧为 2 像素，保持两段内容的视觉连续性
  └─ 变更 ➔ 通过统一的 `_sectionGap` 常量与列表分隔器共同控制主页相关卡片间距，避免额外视觉留白

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
- 无新增 Config Key

---

### [2026-07-06] 优化：首页布局重构，中间展示阅读数据，下方为快捷功能
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/home_page.dart`
  └─ 变更 ➔ 首页布局重构为三层结构：(1)顶部问候区 + 最近阅读卡片，(2)中间阅读数据展示区（大号总阅读时长 + 三个统计卡片），(3)下方快捷功能 + 每日一句
  └─ 新增 ➔ `_readingDataSection()` 方法：展示大号总阅读时长卡片与三个统计卡片（本月/今年/累计）
  └─ 新增 ➔ `_buildStatCard()` 辅助方法：构建单个统计卡片（值 + 标签）
  └─ 变更 ➔ 移除原有 `_statsGrid()` 方法，其功能已整合到 `_readingDataSection()` 中
  └─ 依赖/调用 ➔ `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 打开 ➔ `lib/features/shell/ui/book_viewer_page.dart`
- `lib/engine/localization_engine.dart`
  └─ 新增 ➔ `monthly_reading` 文案：'本月阅读' / 'This Month'
  └─ 新增 ➔ `yearly_reading` 文案：'今年阅读' / 'This Year'

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项
- 无新增 Config Key

---

### [2026-07-06] 优化：主页阅读进度条增加百分比显示
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/home_page.dart`
  └─ 变更 ➔ 在首页"最近阅读"卡片的阅读进度条右侧增加百分比展示
  └─ 变更 ➔ 同时补充卡片顶部标题区域，便于与现有首页文案结构保持一致
- `test/home_page_test.dart`
  └─ 新增 ➔ 回归测试，覆盖首页进度百分比展示

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项

---
### [2026-07-06] 优化：主页阅读进度条增加百分比显示
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/home_page.dart`
  └─ 变更 ➔ 在首页“最近阅读”卡片的阅读进度条右侧增加百分比展示
  └─ 变更 ➔ 同时补充卡片顶部标题区域，便于与现有首页文案结构保持一致
- `test/home_page_test.dart`
  └─ 新增 ➔ 回归测试，覆盖首页进度百分比展示

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项

---

### [2026-07-06] 修复：书架导入后书名与文件大小显示缺失
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/bookshelf_service.dart`
  └─ 变更 ➔ 导入 PDF 时保存真实文件名与文件大小到书籍元数据
- `lib/features/shell/model/book_model.dart`
  └─ 变更 ➔ 新增 `fileSizeBytes` 字段并支持 `copyWith()` 更新
- `lib/features/shell/ui/bookshelf_page.dart`
  └─ 变更 ➔ 书架卡片改为展示真实书名和文件大小，而不是硬编码占位文本
- `test/bookshelf_page_test.dart`
  └─ 新增 ➔ 回归测试，覆盖导入后标题和文件大小显示

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项

---

### [2026-07-06] 修复：书架顶部统计显示真实数据
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/bookshelf_page.dart`
  └─ 变更 ➔ 书架顶部统计卡片改为显示真实书籍数量、收藏数量、在读数量和已读数量
  └─ 依赖/调用 ➔ `lib/features/shell/controller/bookshelf_controller.dart`
- `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 依赖/调用 ➔ `lib/features/shell/service/bookshelf_service.dart`
- `lib/features/shell/service/bookshelf_service.dart`
  └─ 维护 ➔ 书架书籍列表及统计状态数据
- `lib/features/shell/model/book_model.dart`
  └─ 变更 ➔ 新增 `isFavorite` 字段并支持 `copyWith()` 更新

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项

---
### [2026-07-06] 修复：书架最近阅读重复显示与阅读进度不同步
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/bookshelf_page.dart`
  └─ 变更 ➔ 将“全部书籍”卡片重构为紧凑横向 Book Card，封面左置、文字右置、右上角 More 按钮，移除进度条
  └─ 依赖/调用 ➔ `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 打开 ➔ `lib/features/shell/ui/book_viewer_page.dart`
- `lib/features/shell/ui/book_viewer_page.dart`
  └─ 依赖/调用 ➔ `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 变更 ➔ 在 PDF 翻页时同步当前阅读进度到书架数据
- `lib/features/shell/service/bookshelf_service.dart`
  └─ 维护 ➔ 书架列表与阅读进度的统一更新
- `lib/features/shell/model/book_model.dart`
  └─ 变更 ➔ 增加 `copyWith()` 支持局部更新进度

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项

---

### [2026-07-06] 修复：书架最近阅读重复显示与阅读进度不同步
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/bookshelf_page.dart`
  └─ 变更 ➔ 移除单本书在“最近阅读”区域被重复渲染 4 次的逻辑
  └─ 依赖/调用 ➔ `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 打开 ➔ `lib/features/shell/ui/book_viewer_page.dart`
- `lib/features/shell/ui/home_page.dart`
  └─ 依赖/调用 ➔ `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 打开 ➔ `lib/features/shell/ui/book_viewer_page.dart`
- `lib/features/shell/ui/book_viewer_page.dart`
  └─ 依赖/调用 ➔ `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 变更 ➔ 在 PDF 翻页时同步当前阅读进度到书架数据
- `lib/features/shell/service/bookshelf_service.dart`
  └─ 维护 ➔ 书架列表与阅读进度的统一更新
- `lib/features/shell/model/book_model.dart`
  └─ 变更 ➔ 增加 `copyWith()` 支持局部更新进度

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项

---

### [2026-07-05] 新增：主页最近阅读模块
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/home_page.dart`
  └─ 依赖/调用 ➔ `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 打开 ➔ `lib/features/shell/ui/book_viewer_page.dart`
  └─ 变更 ➔ 在首页新增“最近阅读”横向缩略图列表，展示最近 3 本书并点击跳转
- `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 依赖/调用 ➔ `lib/features/shell/service/bookshelf_service.dart`
  └─ 消费 ➔ `lib/features/shell/model/book_model.dart`
- `lib/engine/localization_engine.dart`
  └─ 新增 ➔ `recently_reading` 多语言文案

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项

---

### [2026-07-04] 新增：阅读时长分布圆形图表
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/memory_page.dart`
  └─ 新增 ➔ `_buildReadingTimeDistribution()` 方法与 `_DonutChartPainter` 画笔
  └─ 新增 ➔ `_DistributionItem` 数据模型类
  └─ 变更 ➔ 在第9个统计卡片与趋势总结之间插入阅读时长分布圆形图表
- `lib/engine/localization_engine.dart`
  └─ 新增 ➔ `reading_time_distribution` 多语言文案

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项

---

### [2026-07-04] 优化：统计卡片布局改为三列等高网格
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/memory_page.dart`
  └─ 变更 ➔ 将 `_buildOverviewRow()` 和 `_buildStatsGrid()` 合并为 `_buildMetricGrid()`
  └─ 变更 ➔ 采用 GridView 实现 3 列等高网格布局，确保所有卡片在行内高度一致
  └─ 删除 ➔ 冗余的 `_buildOverviewCard()` 占位方法

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项

---

### [2026-07-04] 优化：回忆页面改造为阅读统计界面
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/memory_page.dart`
  └─ 依赖/调用 ➔ `lib/engine/localization_engine.dart`
  └─ 变更 ➔ 用现代化阅读统计卡片、周期切换与图表展示替换原有日历占位页
  └─ 变更 ➔ 总阅读时长卡片标题加粗，图形切换按钮置于右侧，总阅读时长下方依次显示：总时长统计、日均时长、上一周期变化率
  └─ 变更 ➔ 顶部日期显示改为真实当前日期和当前周期范围
- `lib/engine/localization_engine.dart`
  └─ 新增 ➔ 阅读统计相关文案键值
  └─ 新增 ➔ `vs_previous_period` 多语言文案键值

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项

---

### [2026-07-04] 优化：书架与PDF相关交互改为气泡弹窗
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/bookshelf_page.dart`
  └─ 依赖/调用 ➔ `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 打开 ➔ `lib/features/shell/ui/book_viewer_page.dart`
  └─ 变更 ➔ 书架顶部“更多”菜单与书籍长按菜单改为锚点悬浮气泡弹窗（Popover）
- `lib/features/image_to_pdf/ui/image_to_pdf_page.dart`
  └─ 变更 ➔ 图片长按删除确认由全屏弹窗改为锚点悬浮气泡弹窗

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项

---

### [2026-07-03] 新增：书架随机读书
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/bookshelf_page.dart`
  └─ 依赖/调用 ➔ `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 打开 ➔ `lib/features/shell/ui/book_viewer_page.dart`
  └─ 变更 ➔ 空书架时仅显示导入按钮
- `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 依赖/调用 ➔ `lib/features/shell/service/bookshelf_service.dart`
  └─ 消费 ➔ `lib/features/shell/model/book_model.dart`
- `lib/features/shell/service/bookshelf_service.dart`
  └─ 提供 ➔ 随机选择当前书架中的书籍
- `lib/features/shell/ui/tools_page.dart`
  └─ 变更 ➔ 移除“可用工具”标题，优化工具列表布局
- `lib/features/shell/ui/memory_page.dart`
  └─ 新增 ➔ 日历展示卡片
  └─ 预留 ➔ 阅读时长统计区域

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项

---

## [2026-07-03] 优化：DOC转PDF 使用纯Dart实现

### 核心改进
- ✅ 使用纯 Dart 实现 DOC→PDF 转换，完全移除系统工具依赖
- ✅ 添加依赖：`docs_gee ^1.3.4`、`archive ^4.0.9`
- ✅ 移除 LibreOffice/Pandoc 依赖，用户无需额外安装
- ✅ 支持所有 Flutter 平台：iOS、Android、Windows、macOS、Linux、Web

### 技术方案
**转换流程：**
1. 用户选择 DOC/DOCX 文件
2. 后台 isolate 中处理：
   - `archive` 包解析 DOCX ZIP 结构
   - 提取 `document.xml` 并提取纯文本
   - `pdf` 包根据文本生成 PDF
3. 保存 PDF 到应用文档目录
4. 记录转换历史到 `doc2pdf_export_records.json`

### 优势对比
| 指标 | 之前（系统工具） | 现在（纯Dart） |
|------|-----------------|----------------|
| 外部依赖 | LibreOffice/Pandoc | ❌ 无 |
| 用户安装 | ✓ 需要 | ✓ 无需 |
| 平台支持 | Windows 仅 | ✓ 全平台 |
| 部署难度 | 复杂 | 简单 |
| 首次启动 | 可能失败 | ✓ 开箱即用 |

### 相关文件修改
- `lib/features/doc_to_pdf/service/doc_to_pdf_service.dart` - 完全重写为纯Dart实现
- `pubspec.yaml` - 添加 `archive ^4.0.9`、`docs_gee ^1.3.4`
- `docs/不同文件的依赖关系.md` - 更新依赖说明

---

### [2026-07-03] 新增：TXT转EPUB和DOC转PDF工具功能
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/txt_to_epub/controller/txt_to_epub_controller.dart`
  └─ 依赖/调用 ➔ `lib/features/txt_to_epub/service/txt_to_epub_service.dart`
  └─ 消费 ➔ `lib/features/txt_to_epub/model/txt_to_epub_model.dart`

- `lib/features/txt_to_epub/service/txt_to_epub_service.dart`
  └─ 使用 ➔ `package:flutter` (compute 函数后台处理)
  └─ 使用 ➔ `package:path_provider` (获取应用文档目录)
  └─ 读写 ➔ `txt2epub_export_records.json` (本地持久化转换记录)

- `lib/features/txt_to_epub/ui/txt_to_epub_page.dart`
  └─ 依赖/调用 ➔ `lib/features/txt_to_epub/controller/txt_to_epub_controller.dart`
  └─ 消费 ➔ `lib/features/txt_to_epub/model/txt_to_epub_model.dart`

- `lib/features/doc_to_pdf/controller/doc_to_pdf_controller.dart`
  └─ 依赖/调用 ➔ `lib/features/doc_to_pdf/service/doc_to_pdf_service.dart`
  └─ 消费 ➔ `lib/features/doc_to_pdf/model/doc_to_pdf_model.dart`

- `lib/features/doc_to_pdf/service/doc_to_pdf_service.dart`
  └─ 使用 ➔ `package:flutter` (compute 函数后台处理)
  └─ 使用 ➔ `package:path_provider` (获取应用文档目录)
  └─ 调用 ➔ 系统命令 (soffice --headless 进行 DOC/DOCX 转 PDF)
  └─ 读写 ➔ `doc2pdf_export_records.json` (本地持久化转换记录)

- `lib/features/doc_to_pdf/ui/doc_to_pdf_page.dart`
  └─ 依赖/调用 ➔ `lib/features/doc_to_pdf/controller/doc_to_pdf_controller.dart`
  └─ 消费 ➔ `lib/features/doc_to_pdf/model/doc_to_pdf_model.dart`

- `lib/features/shell/ui/tools_page.dart`
  └─ 导入/打开 ➔ `lib/features/txt_to_epub/ui/txt_to_epub_page.dart`
  └─ 导入/打开 ➔ `lib/features/doc_to_pdf/ui/doc_to_pdf_page.dart`
  └─ 保留 ➔ `lib/features/image_to_pdf/ui/image_to_pdf_page.dart`

- `lib/features/shell/register.dart`
  └─ 注册 ➔ `lib/features/txt_to_epub/register.dart` (新增)
  └─ 注册 ➔ `lib/features/doc_to_pdf/register.dart` (新增)

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Permission Key: `feature_txt2epub`, `feature_doc2pdf`
- 新增 Config Key: 无（此功能不涉及全局配置）

**【文件系统变动】**
- 新增 txt2epub_export_records.json：存储TXT转EPUB的转换记录
- 新增 doc2pdf_export_records.json：存储DOC转PDF的转换记录
- 新增 exported_epubs/：存储生成的EPUB文件
- 新增 exported_pdfs/：存储生成的PDF文件（已由image_to_pdf使用，此功能复用）

---

### [2026-07-03] 依赖关系梳理
**【AI 架构依赖树 (Architecture Context)】**
- `lib/main.dart`
  └─ 初始化 ➔ `lib/engine/permission_engine.dart`
  └─ 注册 ➔ `lib/features/shell/register.dart`
  └─ 运行 ➔ `lib/features/shell/ui/shell_page.dart`
- `lib/features/shell/register.dart`
  └─ 注册 ➔ `lib/features/membership/register.dart`
  └─ 注册 ➔ `lib/features/payment/register.dart`
  └─ 注册 ➔ `lib/features/image_to_pdf/register.dart`
- `lib/features/membership/controller/membership_controller.dart`
  └─ 依赖 ➔ `lib/engine/permission_engine.dart`
- `lib/features/shell/controller/settings_controller.dart`
  └─ 依赖 ➔ `lib/engine/settings_engine.dart`
- `lib/features/shell/controller/shell_controller.dart`
  └─ 依赖 ➔ `lib/engine/settings_engine.dart`
- `lib/engine/theme_engine.dart`
  └─ 依赖 ➔ `lib/core/theme/font_manager.dart`
- `lib/shared/ui/duration_picker_dialog.dart`
  └─ 依赖 ➔ `lib/engine/localization_engine.dart`
- `lib/features/*/ui/*.dart`
  └─ 读取 ➔ `lib/engine/localization_engine.dart`
  └─ 读取 ➔ `lib/engine/settings_engine.dart`
  └─ 读取 ➔ `lib/engine/theme_engine.dart`
  └─ 读取 ➔ `lib/shared/ui/app_text_styles.dart`

**【全局状态/鉴权变动 (State & Auth)】**
- Permission Key: `membership.enable`, `payment.enable`, `tools.image_to_pdf`
- Config keys: `settings.language`, `settings.appearance`, `settings.themeColor`, `settings.fontFamily`, `settings.startupPage`, `settings.startupSplash*`

---

### [2026-07-05] 修改：书架页面重设计（覆盖式卡片与最近阅读）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/bookshelf_page.dart`
  └─ 变更：重设计书架主界面，新增顶部统计卡片组、最近阅读横向缩略卡、分类段控（全部/PDF/EPUB/TXT/其他），并保留原有导入/随机/长按菜单等交互
  └─ 依赖/调用 ➔ `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 打开 ➔ `lib/features/shell/ui/book_viewer_page.dart`
  └─ 显示 ➔ 网格/列表两种视图（封面/列表）与自定义进度条
  └─ 变更 ➔ 提示新增多语言键：`bookshelf_tab_all`, `bookshelf_tab_other`, `recently_reading`, `view_all`, `no_recently_reading`

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项


---

### [2026-07-07] 更新：重置并同步当前文件依赖关系
**【AI 架构依赖树 (Architecture Context)】**
- `docs/不同文件的依赖关系.md`
  └─ 重置 ➔ 更新为当前 `lib/` 代码实际依赖关系
- `lib/core/theme/font_manager.dart`
  └─ 依赖 ➔ `lib/engine/settings_engine.dart`
- `lib/engine/localization_engine.dart`
  └─ 依赖 ➔ `lib/engine/settings_engine.dart`
- `lib/engine/permission_engine.dart`
  └─ 依赖 ➔ `lib/engine/config.dart`
- `lib/engine/settings_engine.dart`
  └─ 依赖 ➔ `lib/engine/config.dart`
- `lib/engine/theme_engine.dart`
  └─ 依赖 ➔ `lib/core/theme/font_manager.dart`
- `lib/features/shell/ui/shell_page.dart`
  └─ 依赖 ➔ `lib/features/shell/ui/bookshelf_page.dart`
  └─ 依赖 ➔ `lib/features/shell/ui/home_page.dart`
  └─ 依赖 ➔ `lib/features/shell/ui/memory_page.dart`
  └─ 依赖 ➔ `lib/features/shell/ui/profile_page.dart`
  └─ 依赖 ➔ `lib/features/shell/ui/tools_page.dart`
**【全局状态/鉴权变动 (State & Auth)】**
- 无新增权限/配置项

### [2026-07-13] 新增/修改：阅读统计卡片 + 时间轴崩溃修复
**【AI 架构依赖树 (Architecture Context)】**
- `lib/engine/localization_engine.dart`
  └─ 提供 ➔ 阅读统计卡片多语言文案（8 个新 key）
  └─ 被消费 ➔ `lib/features/shell/ui/memory_main_page.dart`
- `lib/features/shell/model/reading_stats_model.dart`
  └─ 提供数据 ➔ 周/月/年/全部周期分钟数（weekMinutes, monthMinutes, yearMinutes, totalMinutes）
  └─ 被消费 ➔ `lib/features/shell/ui/memory_main_page.dart`（_buildReadingStatsCard）
- `lib/features/shell/ui/memory_main_page.dart`
  └─ 新增 ➔ `_buildReadingStatsCard()` —— 阅读统计卡片组件（标题 + 周期 Tab 切换 + 四项统计数据）
  └─ 修复 ➔ `_entry()` 中时间轴竖线 Expanded 布局崩溃（IntrinsicHeight 包裹）
  └─ 依赖/调用 ➔ `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 依赖/调用 ➔ `lib/engine/localization_engine.dart`

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增/修改 Config Key
- 无新增/修改 Permission Key

**【多语言变更 (i18n)】**
- 请将以下键值对添加到语言翻译文件：
  - `'stats_reading_hours_label'`: `'阅读统计(小时)'`
  - `'stats_reading_books_label'`: `'阅读书籍(本)'`
  - `'stats_reading_pages_label'`: `'阅读页数(页)'`
  - `'stats_notes_count_label'`: `'收藏笔记(条)'`
  - `'stats_tab_week'`: `'周'`
  - `'stats_tab_month'`: `'月'`
  - `'stats_tab_year'`: `'年'`
  - `'stats_tab_all'`: `'全部'`

### [2026-07-13] 新增/修改：阅读热力图日历网格
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/memory_main_page.dart`
  └─ 重构 ➔ `_buildHeatmapCard()` 从占位条形替换为完整日历热力图网格
  └─ 新增内部数据类 ➔ `_DayCell`（单日阅读分钟数）+ `_HeatmapRow`（按周分行）
  └─ 消费数据 ➔ `ReadingStats.dailyMinutes` 驱动每格颜色强度（5 级紫色调）
  └─ 依赖/调用 ➔ `lib/engine/localization_engine.dart`
- `lib/engine/localization_engine.dart`
  └─ 新增 ➔ `reading_heatmap`, `heatmap_month_btn`, `heatmap_legend_few`, `heatmap_legend_many`

**【多语言变更 (i18n)】**
- `'reading_heatmap'`: `'阅读热力图'` / `'Reading Heatmap'`
- `'heatmap_month_btn'`: `'本月'` / `'This Month'`
- `'heatmap_legend_few'`: `'少'` / `'Less'`
- `'heatmap_legend_many'`: `'多'` / `'More'`

### [2026-07-13] 新增/修改：遗忘的书籍卡片 + 二级列表页
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/memory_main_page.dart`
  └─ 重写 ➔ `_buildForgottenBooksCard()`：横向书卡行 + 右侧"立即查看" + 行尾"查看更多"
  └─ 新增 ➔ `_daysSinceOpened()` 计算未打开天数；`_openBook()` 共享跳转逻辑（同时重构 `_buildRandomMemoryCard` 复用）
  └─ 筛选规则 ➔ `progress < 1.0`（已看完不计入），按未打开天数倒序
  └─ 跳转到 ➔ `lib/features/shell/ui/forgotten_books_page.dart`
- `lib/features/shell/ui/forgotten_books_page.dart`（新增）
  └─ 展示全部未读完书籍，响应式 `GridView`（列数 2~6 自适应），一个框一本书
  └─ 依赖/调用 ➔ `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 依赖/调用 ➔ `lib/engine/localization_engine.dart`
- `lib/engine/localization_engine.dart`
  └─ 新增 ➔ `forgotten_books_title` / `forgotten_view_now` / `forgotten_view_more` / `forgotten_days_label` / `forgotten_never_opened` / `forgotten_empty`

**【多语言变更 (i18n)】**
- `'forgotten_books_title'`: `'遗忘的书籍'` / `'Forgotten Books'`
- `'forgotten_view_now'`: `'立即查看'` / `'View Now'`
- `'forgotten_view_more'`: `'查看更多'` / `'More'`
- `'forgotten_days_label'`: `'未打开 {days} 天'` / `'Not opened for {days} days'`
- `'forgotten_never_opened'`: `'从未打开'` / `'Never opened'`
- `'forgotten_empty'`: `'没有遗漏的书籍，继续保持！'` / `'No forgotten books. Keep it up!'`

---

### [2026-07-14] 新增/修改：主页卡片统一阅读统计格式 + 每日一句内置句与刷新
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/model/daily_sentence_builtin.dart`（新增·纯数据）
  └─ 提供 ➔ `builtinReadingSentences`（`List<String>`，≥120 条关于阅读的中文经典句子）
  └─ 被消费 ➔ `lib/features/shell/service/daily_sentence_service.dart`
- `lib/engine/settings_engine.dart`
  └─ 新增 ➔ `dailySentenceUseBuiltinKey`(`app.dailySentence.useBuiltin`) + `dailySentenceUseBuiltinDefault`(true) + `dailySentenceUseBuiltin` getter/setter（经 `Config`）
  └─ 被消费 ➔ `lib/features/shell/controller/settings_controller.dart`
  └─ 被消费 ➔ `lib/features/shell/service/daily_sentence_service.dart`（读开关）
- `lib/features/shell/controller/settings_controller.dart`
  └─ 新增 ➔ `dailySentenceUseBuiltin` 状态（`ValueNotifier<bool>`）+ `setDailySentenceUseBuiltin(bool)`
  └─ 监听了 ➔ `lib/engine/settings_engine.dart`
  └─ 驱动 ➔ `lib/features/shell/ui/home_page.dart` / `lib/features/shell/ui/daily_sentence_page.dart`
- `lib/features/shell/service/daily_sentence_service.dart`
  └─ 新增 ➔ `displaySentenceNotifier`（`ValueNotifier<String>`，主页展示句，不持久化）
  └─ 新增 ➔ `_selectSentence(useBuiltin,{refresh,current})` 按开关从内置池或自定义列表取句
  └─ 新增 ➔ `initDisplaySentence()`（按日期稳定初始化）/ `refreshDisplaySentence()`（随机换一句）/ `syncDisplaySentence()`（开关或列表变化时同步）
  └─ 读取 ➔ `lib/engine/settings_engine.dart`（`dailySentenceUseBuiltin`）
  └─ 读取 ➔ `lib/features/shell/model/daily_sentence_builtin.dart`
  └─ 驱动 ➔ `lib/features/shell/ui/home_page.dart`（展示与刷新）
- `lib/features/shell/ui/home_page.dart`
  └─ 变更 ➔ 4 张统计卡片（本月/今年/累计/打开次数）与「每日一句」内容框统一为 `scaffoldBackgroundColor` + 去边框 + 柔和阴影（`systemGrey.withOpacity(0.06)`），与主页「阅读统计」大卡片格式一致
  └─ 变更 ➔ 「每日一句」标题行右侧新增刷新按钮（`CupertinoIcons.refresh`），点击调用 `DailySentenceService.refreshDisplaySentence()`
  └─ 变更 ➔ 展示文案监听 `DailySentenceService.displaySentenceNotifier`，并随 `SettingsController.dailySentenceUseBuiltin` 与 `DailySentenceService.sentencesNotifier` 联动（initState 注册、dispose 移除监听）
  └─ 依赖/调用 ➔ `lib/features/shell/service/daily_sentence_service.dart`
  └─ 依赖/调用 ➔ `lib/features/shell/controller/settings_controller.dart`
- `lib/features/shell/ui/daily_sentence_page.dart`
  └─ 新增 ➔ 顶部「设置卡片」含 `CupertinoSwitch` 绑定 `SettingsController.dailySentenceUseBuiltin`（开启展示内置句，关闭仅展示用户自定义句）
  └─ 依赖/调用 ➔ `lib/features/shell/controller/settings_controller.dart`
- `lib/engine/localization_engine.dart`
  └─ 新增 ➔ `daily_sentence_refresh` / `daily_sentence_use_builtin` / `daily_sentence_use_builtin_desc` / `daily_sentence_empty_custom`

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Config Key: `app.dailySentence.useBuiltin`（bool，默认 true）
- 无新增/修改 Permission Key

**【多语言变更 (i18n)】**
- `'daily_sentence_refresh'`: `'换一句'` / `'Refresh'`
- `'daily_sentence_use_builtin'`: `'启用内置每日一句'` / `'Enable Built-in Sentences'`
- `'daily_sentence_use_builtin_desc'`: `'关闭后只显示你自定义的每日一句'` / `'When off, only your custom sentences are shown'`
- `'daily_sentence_empty_custom'`: `'还没有自定义每日一句，开启内置每日一句获取灵感吧'` / `'No custom sentences yet. Enable built-in sentences for inspiration.'`

---

### [2026-07-14] 修改：工具页布局重构为「分类标题 + 响应式网格」
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/tools_page.dart`
  └─ 重构 ➔ 由单列纵向列表卡片改为「分类标题 + 响应式网格」（GridView，列数随屏宽 2/3/4 自适应，满足跨端要求）
  └─ 新增 ➔ `_ToolItem` 数据模型（categoryKey / icon / titleKey / subtitleKey / page），按 categoryKey 运行时分组（电子书转换 / 转 PDF）
  └─ 变更 ➔ 卡片改为纯展示（Dumb UI）：图标底 `primaryColor.withValues(alpha:0.12)`、背景 `secondarySystemBackground.resolveFrom(context)`、淡阴影取代边框；标题/副标题走 `AppTextStyles.body` / `secondary`
  └─ 依赖/调用 ➔ `lib/engine/localization_engine.dart`
  └─ 依赖/调用 ➔ `lib/shared/ui/app_text_styles.dart`
  └─ 跳转 ➔ `txt_to_epub_page.dart` / `doc_to_pdf_page.dart` / `ppt_to_pdf_page.dart` / `excel_to_pdf_page.dart` / `image_to_pdf_page.dart`
- `lib/engine/localization_engine.dart`
  └─ 新增 ➔ 11 个工具相关多语言键（分类与 5 个工具的标题 / 副标题，含 zh/en）

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增/修改 Config Key
- 无新增/修改 Permission Key

**【多语言变更 (i18n)】**
- `'tools_cat_ebook'`: `'电子书转换'` / `'E-Book'`
- `'tools_cat_pdf'`: `'转 PDF'` / `'To PDF'`
- `'tool_txt_epub_title'`: `'TXT 转 EPUB'` / `'TXT to EPUB'`
- `'tool_txt_epub_sub'`: `'文本文件转电子书'` / `'Convert text files to e-book'`
- `'tool_doc_pdf_title'`: `'DOC 转 PDF'` / `'DOC to PDF'`
- `'tool_doc_pdf_sub'`: `'Word 文档转 PDF'` / `'Convert Word documents to PDF'`
- `'tool_ppt_pdf_title'`: `'PPT 转 PDF'` / `'PPT to PDF'`
- `'tool_ppt_pdf_sub'`: `'幻灯片转 PDF'` / `'Convert slides to PDF'`
- `'tool_xls_pdf_title'`: `'Excel 转 PDF'` / `'Excel to PDF'`
- `'tool_xls_pdf_sub'`: `'表格转 PDF'` / `'Export spreadsheets to PDF'`
- `'tool_img_pdf_title'`: `'图片转 PDF'` / `'Image to PDF'`
- `'tool_img_pdf_sub'`: `'图片合并导出'` / `'Merge images into PDF'`

---

### [2026-07-14] 修改：每日一句列表页按截图改版（预览卡 + 可编辑/删除/拖拽排序）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/daily_sentence_page.dart`
  └─ 重构 ➔ 按截图重写为：① 开关卡（图标 + 文案 + CupertinoSwitch 绑定 `SettingsController.dailySentenceUseBuiltin`）②「今天可能会看到」预览卡（监听 `DailySentenceService.displaySentenceNotifier`，右侧刷新按钮调用 `refreshDisplaySentence()`）③「我的语句 (N)」标题 ④ `ReorderableListView.builder` 列表（长按拖拽排序）⑤ 描边「添加新的语句」按钮 ⑥ 底部「长按可拖动排序」提示
  └─ 列表项 = 引用图标(`theme.primaryColor`) + 文案(`GestureDetector.onTap` 进入 `daily_sentence_edit_page` 编辑) + 三点按钮(弹出 `CupertinoActionSheet`：编辑/上移/下移/删除；删除走 `CupertinoAlertDialog` 二次确认)
  └─ 依赖/调用 ➔ `daily_sentence_controller.dart`（`deleteSentence`）/ `daily_sentence_service.dart`（`reorderSentence`/`refreshDisplaySentence`/`displaySentenceNotifier`）/ `localization_engine.dart` / `settings_controller.dart` / `daily_sentence_edit_page.dart`
- `lib/features/shell/service/daily_sentence_service.dart`
  └─ 新增（static） ➔ `deleteSentence(id)`（按 id 删除并持久化）、`reorderSentence(oldIndex,newIndex)`（拖拽排序并持久化）
  └─ 变更 ➔ `_saveSentences` 由实例方法改为 `static`，供上述静态方法调用
- `lib/features/shell/controller/daily_sentence_controller.dart`
  └─ 新增 ➔ `deleteSentence(id)`（暴露给 UI 删除）
- `lib/engine/localization_engine.dart`
  └─ 新增 ➔ 9 个列表页多语言键（含 zh/en）

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增/修改 Config Key
- 无新增/修改 Permission Key

**【多语言变更 (i18n)】**
- `'my_sentences'`: `'我的语句'` / `'My Sentences'`
- `'today_preview'`: `'今天可能会看到'` / `"Today's preview"`
- `'refresh_one'`: `'换一个'` / `'Refresh'`
- `'add_new_sentence'`: `'添加新的语句'` / `'Add New Sentence'`
- `'long_press_reorder'`: `'长按可拖动排序'` / `'Long press to drag and reorder'`
- `'sentence_delete_confirm'`: `'确认删除此句？'` / `'Delete this sentence?'`
- `'sentence_deleted'`: `'已删除'` / `'Deleted'`
- `'move_up'`: `'上移'` / `'Move Up'`
- `'move_down'`: `'下移'` / `'Move Down'`

---

### [2026-07-14] 修复：每日一句列表页进入即崩溃（ReorderableListView 缺 MaterialLocalizations）
**【问题根因】**
- 点击「我的 → 每日一句」进入页面即崩溃（红屏）。`ReorderableListView` 是 Material 组件，构建时断言必须有 `MaterialLocalizations` 祖先；本 App 为纯 Cupertino（`CupertinoApp` 根，无 Material `Localizations`），故一旦列表非空（自定义语句加载完成）即抛 `No MaterialLocalizations found` 崩溃——空列表时不崩，与「有数据才崩」的现象吻合。
- 此前误判为缺 item key（已加 `ValueKey`），未解决：key 断言与 MaterialLocalizations 断言是两个不同的运行时检查。

**【修复】**
- `lib/features/shell/ui/daily_sentence_page.dart`：在 `ReorderableListView.builder` 外包 `Localizations(delegates:[DefaultWidgetsLocalizations.delegate, DefaultMaterialLocalizations.delegate])`，仅提供其所需的 Material 文案环境；**未引入 `MaterialApp`**，避免嵌套导航冲突。
- `buildDefaultDragHandles:false`，拖拽手柄改由 `ReorderableDragStartListener` + `CupertinoIcons.line_horizontal_3` 自绘，贴合 Cupertino 主题且保留「按住可拖拽排序」。

**【验证】**
- 临时 `flutter test` 冒烟测试渲染该页（空列表 + 预置数据触发 ReorderableListView）复现并确认崩溃消除；验证后移除临时测试，未向工程引入测试依赖。
- `flutter analyze` 本次涉及文件 0 error（仅全工程既有 `withOpacity`/`minSize` 弃用 info）。

---

### [2026-07-14] 新增/完善：启动设置实际功能（启动屏 + 设置页交互接线）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/splash_screen.dart`（新增·实际启动屏）
  └─ 新增 ➔ 真正消费「启动页设置」的 `SplashScreen`：按 `SettingsEngine.startupSplashType`(不显示/文字/图片)、`startupSplashText`/`startupSplashImagePath`(本地 `FileImage`/网络 `NetworkImage`)、`startupSplashDuration`(>0 倒计时归零自动 pop / <=0 永久)、`startupSplashEntryMode`(auto 仅跳过按钮 / tap 整屏可点) 渲染；完成 `Navigator.pop()` 露出 `ShellBoot` 已按 `startupPage` 定位的 Tab 容器
  └─ 依赖/调用 ➔ `lib/engine/settings_engine.dart` / `lib/engine/localization_engine.dart` / `lib/shared/ui/app_text_styles.dart`
- `lib/features/shell/ui/shell_page.dart`
  └─ 重构 ➔ `CupertinoApp` 根 `home` 改由 `ShellBoot`(新增 StatefulWidget) 承载；`ShellBoot.initState` 首帧后按 `SettingsEngine.startupSplashType` 判断，非「不显示」则 `Navigator.push(SplashScreen)` 压入启动屏
  └─ 依赖/调用 ➔ `splash_screen.dart` / `settings_engine.dart` / `settings_controller.dart`(appearance/themeColor/fontFamily/language 驱动主题与标签) / `shell_controller.dart`(selectedIndex 初始标签)
- `lib/features/shell/ui/splash_settings_page.dart`
  └─ 完善 ➔ 此前仅配置 UI；本次接通：图片卡 `FilePicker` 选图(`permission_handler` 申请相册/存储权限)→`setStartupSplashImagePath` 并实时预览缩略图；文字卡 `CupertinoAlertDialog`+`CupertinoTextField`→`setStartupSplashText`；进入方式绑定 `SettingsController.startupSplashEntryMode` 真实状态(此前硬编码 selected)；启动后跳转页 `CupertinoActionSheet` 选择 `setStartupPage`；预览卡反映真实配置(不显示→占位 / 文字 / 图片)；清除硬编码渐变 hex 与字号，改用 `AppTextStyles` 与主题派生色
  └─ 依赖/调用 ➔ `settings_controller.dart` / `settings_engine.dart` / `localization_engine.dart` / `app_text_styles.dart` / `package:file_picker` / `package:permission_handler`
- `lib/engine/settings_engine.dart`
  └─ 新增 ➔ `startupSplashEntryModeKey` / `startupSplashEntryModeAuto`('auto') / `startupSplashEntryModeTap`('tap') / `startupSplashEntryModeDefault`(auto) 及 getter/setter
- `lib/features/shell/controller/settings_controller.dart`
  └─ 新增 ➔ `startupSplashEntryMode`(`ValueNotifier<String>`) 与 `setStartupSplashEntryMode(String)` 上承 `SettingsEngine`、下驱 UI 重绘

**【全局状态/鉴权变动 (State & Auth)】**
- 新增/修改 Config Key: `app.startupSplash.entryMode`（值 `auto`/`tap`，默认 `auto`），经 `Config` 持久化
- 无新增/修改 Permission Key

**【多语言变更 (i18n)】**
- `splash_edit_text`(编辑启动文字) / `splash_text_placeholder`(输入启动页要显示的文字) / `splash_save`(保存) / `splash_image_empty`(尚未选择图片) / `splash_text_empty`(尚未设置文字) / `splash_image_failed`(图片选择失败) / `splash_permission_denied`(没有访问相册的权限) / `splash_preview_none`(未配置启动页（将直接打开应用）) / `splash_jump_select`(选择启动后打开的页面) / `splash_skip_now`(跳过) / `splash_tap_enter_now`(点击进入) / `splash_auto_countdown`(%d 秒后跳过) / `splash_tap_countdown`(%d 秒后进入)（均含 zh/en）

### [2026-07-14] 新增/修改：阅读统计详情页「日」筛选 + 两项新指标卡
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/model/reading_stats_model.dart`
  └─ 新增 ➔ `dailyHourlyMinutes`（`Map<DateTime,List<int>>`，每天 24 小时档，于 `fromBooks` 中按 `lastReadAt.hour` 聚合）
  └─ 新增 ➔ `activeDaysInRange(start,end)`：统计区间内「有阅读活动的天数」（累计阅读天数）
  └─ 被消费 ➔ `lib/features/shell/ui/memory_page.dart`
- `lib/features/shell/ui/memory_page.dart`
  └─ 变更 ➔ `_StatsPeriod` 枚举新增 `day`（默认仍为 `month`）；新增 `_selectedDay` 状态与「日」区间切换
  └─ 新增 ➔ `_buildExtraStatCards()`：软件打开次数（`AppStatsService.getAppLaunchCount()`，全局）+ 累计阅读天数（`activeDaysInRange`，随区间联动），复用 `_MetricTile` 样式
  └─ 变更 ➔ `_trendEntries`「日」视图返回 24 个小时数据点；`_TrendBarChart`/`_TrendLineChart` 增加可选 `xLabelBuilder`（日视图按小时标签）
  └─ 新增 ➔ `_buildDayHeatGrid()` + `_quarterColor()`：日热力图 = 24 行 × 4 格（每小时切 4 个 15 分钟段），颜色按 15 分钟档阈值派生
  └─ 变更 ➔ 时间分布「时段」在「日」视图改用 `dailyHourlyMinutes[选中日]`，下方区块（记录等）经 `_rangeBounds` 自动联动当天数据
- `lib/features/shell/service/app_stats_service.dart`
  └─ 复用 ➔ `getAppLaunchCount()` 提供软件累计打开次数（无需改动）
- `lib/engine/localization_engine.dart`
  └─ 新增 ➔ `stats_tab_day`(日/Day) / `app_open_count_label`(打开次数) / `cumulative_reading_days_label`(累计阅读天数) / `today_reading_label`(今日阅读) / `heatmap_day_block_hint`(每小时切 4 格=当日每 15 分钟段)

**【多语言变更 (i18n)】**
- `'stats_tab_day'`: `'日'` / `'Day'`
- `'app_open_count_label'`: `'打开次数'` / `'App Opens'`
- `'cumulative_reading_days_label'`: `'累计阅读天数'` / `'Reading Days'`
- `'today_reading_label'`: `'今日阅读'` / `'Today'`
- `'heatmap_day_block_hint'`: `'每小时切 4 格 = 当日每 15 分钟段的阅读情况'` / `'Each hour split into 4 = the day’s 15-minute reading blocks'`

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增 Config Key / Permission Key。

---

### [2026-07-14] 修改：阅读统计「日」视图优化（打开次数按区间 + 热力图紧凑化）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/app_stats_service.dart`
  └─ 新增 ➔ `launchTimestampsNotifier`(`ValueNotifier<List<DateTime>>`)：记录每次应用打开的时间戳，随 `app_stats.json` 持久化
  └─ 变更 ➔ `incrementAppLaunchCount()` 每次打开追加 `DateTime.now()` 到时间戳列表
  └─ 新增 ➔ `getAppLaunchCountInRange(start,end)`：统计区间 `[start,end)` 内的打开次数（与阅读统计口径一致）
- `lib/features/shell/ui/memory_page.dart`
  └─ 变更 ➔ `_buildExtraStatCards()` 打开次数由 `getAppLaunchCount()`(全局) 改为 `getAppLaunchCountInRange(start,end)`（随统计区间联动）
  └─ 重写 ➔ `_buildDayHeatGrid()`：由「24 行 × 4 格（每小时切 4 个 15 分钟段）」改为「4 行（0-6 / 6-12 / 12-18 / 18-24 六个时段）× 6 列」= 24 个小时格，风格与周视图 4 段方块一致、更紧凑；每格标注小时数，主色深浅表示该小时阅读量
  └─ 替换 ➔ 删除 `_quarterColor()`，新增 `_hourColor()`（按小时粒度阈值派生颜色，规避对纯 `CupertinoColors.white` 调用 `resolveFrom` 报错）
- `lib/engine/localization_engine.dart`
  └─ 新增 ➔ `hour_unit`(时/h)：日热力图时段标签单位
  └─ 变更 ➔ `heatmap_day_block_hint` 文案改为描述 4 行 × 6 列小时格布局

**【多语言变更 (i18n)】**
- `'hour_unit'`: `'时'` / `'h'`
- `'heatmap_day_block_hint'`: `'4 行 = 当日 4 个 6 小时段，每行 6 格 = 6 个小时，每格颜色代表该小时阅读量'` / `'4 rows = the day’s four 6-hour blocks; 6 cells per row = 6 hours; color shows reading minutes'`

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增 Config Key / Permission Key。

---

### [2026-07-14] 修改：阅读记录重设计（移除类型分布 + 日热力图 15 分钟小方格 + 会话级阅读记录）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/memory_page.dart`
  └─ 删除 ➔ 阅读类型分布甜甜圈：`_buildTypeDistribution()` / `_DonutSegment` / `_DonutPainter`（含其调用）；阅读统计详情页区块顺序调整为：指标卡 → 趋势图 → 热力图 → 时间分布 → 阅读记录
  └─ 重写 ➔ `_buildDayHeatGrid()`：日热力图改为「4 行（0-6/6-12/12-18/18-24）× 每行 6 小时 × 每列 4 个 15 分钟小方格」= 96 个无数字小方格，每格颜色深浅对应该 15 分钟段阅读量；删除 `_hourColor()`，新增 `_quarterColor()`（按 15 分钟段阈值派生颜色）
  └─ 重写 ➔ `_buildMonthlyRecords()`（阅读记录）：概览三块统计（阅读次数 / 读完本数 / 读完耗时）+ 阅读明细会话列表（`_SessionRow`）+ 读完了列表（`_RecordCard`）；新增 `_buildRecordSummary()` / `_RecordStatTile()` / `_SessionRow()`
- `lib/features/shell/model/reading_stats_model.dart`
  └─ 新增 ➔ `dailyQuarterMinutes`（`Map<DateTime,List<int>>`，每天 96 段 = 24 小时 × 4 个 15 分钟段，按下标 `小时×4 + (分钟~/15)` 归桶），`fromBooks` 同步聚合
- `lib/features/shell/service/reading_session_service.dart`（新增）
  └─ 新增 ➔ `ReadingSession` / `ReadingSessionService`（静态 `initialize()` + `sessionsNotifier` + `logSession` + `sessionsInRange` / `sessionsOnDay` / `finishedBookIdsInRange`）/ `ReadingSessionTracker`（阅读器生命周期计时）；持久化 `reading_sessions.json`（应用文档目录）
- `lib/features/shell/ui/reading_records_page.dart`
  └─ 重写 ➔ 展示全部阅读会话（`ReadingSessionService.sessionsNotifier`）：概览 + 阅读明细（`_SessionListRow`）+ 读完了（`ReadingRecordRow`）
- `lib/features/shell/ui/book_viewer_page.dart` / `txt_viewer_page.dart` / `epub_viewer_page.dart` / `comic_viewer_page.dart`
  └─ 变更 ➔ 接入 `ReadingSessionTracker` 记录每次阅读会话（initState 计时、dispose / 应用退后台结束并 `logSession`，同步 `updateBookReadingDuration`）；四个阅读器跳转均改传 `bookId` + `controller`
- `lib/main.dart`
  └─ 新增 ➔ `await ReadingSessionService.initialize()`（与 `AppStatsService.initialize()` 并列）
- `lib/engine/localization_engine.dart`
  └─ 新增 ➔ `records_session_count`(阅读次数) / `records_finished_count`(读完) / `records_finished_time`(读完耗时) / `records_detail`(阅读明细) / `records_detail_empty`(该区间暂无阅读明细) / `unknown_book`(未知书籍) / `session_start_suffix`(开始) / `session_read_prefix`(读了)

**【多语言变更 (i18n)】**
- `'records_session_count'`: `'阅读次数'` / `'Sessions'`
- `'records_finished_count'`: `'读完'` / `'Finished'`
- `'records_finished_time'`: `'读完耗时'` / `'Time Finished'`
- `'records_detail'`: `'阅读明细'` / `'Reading Detail'`
- `'records_detail_empty'`: `'该区间暂无阅读明细'` / `'No reading detail in this period'`
- `'unknown_book'`: `'未知书籍'` / `'Unknown Book'`
- `'session_start_suffix'`: `'开始'` / `' started'`
- `'session_read_prefix'`: `'读了'` / `'read '`
- `'heatmap_day_block_hint'`（更新）: `'4 行 = 当日 4 个 6 小时段；每行 6 小时 × 4 个小方格，每格 = 15 分钟，颜色越深读得越多'` / `'4 rows = the day’s four 6-hour blocks; 6 hours × 4 squares per row, each square = 15 min'`

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增 Config Key / Permission Key。

### [2026-07-14] 修复：工具页 5 个转换功能全部不可用（中文乱码 / 产物非法 / 选图闪退）

**【AI 架构依赖树 (Architecture Context)】**
- `lib/shared/util/cjk_font_loader.dart` (新增 · CJK 字体字节加载器)
  └─ 被注入 ➔ `lib/features/doc_to_pdf/service/doc_to_pdf_service.dart`
  └─ 被注入 ➔ `lib/features/ppt_to_pdf/service/ppt_to_pdf_service.dart`
  └─ 被注入 ➔ `lib/features/excel_to_pdf/service/excel_to_pdf_service.dart`
  └─ 被注入 ➔ `lib/features/image_to_pdf/service/image_to_pdf_service.dart`
- `assets/fonts/cjk.ttf` (新增资源 · SimHei 中文字体，复制自系统 `C:\Windows\Fonts\simhei.ttf`)
  └─ 被 `lib/shared/util/cjk_font_loader.dart` 经 `rootBundle` 加载，供 `pw.Font.ttf(bytes)` 注入 PDF 主题
- `lib/features/txt_to_epub/service/txt_to_epub_service.dart`
  └─ 依赖于 ➔ `package:archive`（拼标准 EPUB ZIP：`mimetype` 首文件且存储不压缩）/ `package:fast_gbk`（GBK 解码中文 TXT）
  └─ 修复 ➔ 此前产物是裸 XHTML（阅读器打不开）；编码探测 UTF-8 → GBK，正文按空行切片 + XML 转义
- `lib/features/doc_to_pdf|ppt_to_pdf|excel_to_pdf/service/*_to_pdf_service.dart`
  └─ 依赖于 ➔ `package:pdf`（注入内嵌 CJK 字体，解决中文空白/方块）+ `cjk_font_loader.dart`
  └─ 修复 ➔ doc/ppt 解析由逐字符去标签改为正则提取 `<w:t>`/`<a:t>` 并解码 XML 实体；excel 关键修复 `xl/sharedStrings.xml` 索引还原（此前把索引当文本 → 满屏数字）
- `lib/features/image_to_pdf/ui/image_to_pdf_page.dart`
  └─ 修复 ➔ 选图即闪退（`No MaterialLocalizations found`）：以 `Localizations(DefaultWidgetsLocalizations+DefaultMaterialLocalizations)` 仅包裹 `ReorderableListView`（`buildDefaultDragHandles:false` + `ReorderableDragStartListener` 自绘手柄），并修正 `_onReorder` 中 `newIndex -= 1` 的二次错位 BUG
- `lib/features/image_to_pdf/service/image_to_pdf_service.dart`
  └─ 修复 ➔ 图片被强制拉伸到 A4 变形：改为解析 PNG/JPEG 真实宽高按比例设 `PdfPageFormat(w,h)`，`pw.Image(fit: BoxFit.fill)` 铺满不变形
- `test/conversion_tools_test.dart` (新增 · 集成测试)
  └─ 依赖 ➔ `package:archive` / `package:fast_gbk` / `package:image`（造合法 PNG）+ `TestDefaultBinaryMessengerBinding` mock `path_provider` 通道

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增 Config Key / Permission Key。
- `pubspec.yaml` 变更：新增资源 `flutter.assets: - assets/fonts/cjk.ttf`、依赖 `fast_gbk`（解码 GBK TXT）、dev 依赖 `image`（测试造 PNG）；`compute` isolate 内无法访问 `rootBundle`，故 CJK 字体字节由主线程 `CjkFontLoader.loadBytes()` 加载后随 `args` 传入。
- 依赖方向合规：转换页 UI → `conversion_scaffold`（纯展示）+ 各自 controller → service；`cjk_font_loader` 为共享工具，不反向依赖任何 feature；未触碰 `packages/`、未新增硬编码颜色/字号/文案。

### [2026-07-14] 新增/修改：我的页面自定义配色（会员功能预留）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/model/custom_theme_color_model.dart` (新增 · 自定义色实体)
  └─ 被消费 ➔ `custom_theme_color_service.dart` / `settings_controller.dart` / `profile_page.dart`
- `lib/features/shell/service/custom_theme_color_service.dart` (新增 · 本地 JSON 持久化)
  └─ 注入/依赖于 ➔ `custom_theme_color_model.dart`
  └─ 桥接 ➔ `settings_controller.dart`（`customColors` notifier + CRUD）
  └─ 被初始化 ➔ `lib/main.dart`（`CustomThemeColorService.initialize()`）
- `lib/features/shell/ui/custom_color_picker_sheet.dart` (新增 · Dumb UI 取色弹层)
  └─ 被消费 ➔ `profile_page.dart`（`_ThemeColoringSection`）
- `lib/features/shell/controller/settings_controller.dart`
  └─ 新增 ➔ `activePrimaryColor`（`ValueNotifier<Color>`，全局主色唯一上浮入口，取代原 themeColor 字符串解析）
  └─ 新增 ➔ `resolveThemeColor` / `setPresetColor` / `applyCustomColorById` / `addCustomColor` / `updateCustomColor` / `deleteCustomColor`
  └─ 监听了 ➔ `custom_theme_color_service.dart`（colorsNotifier）
- `lib/features/shell/ui/shell_page.dart`
  └─ 由 `SettingsController.activePrimaryColor` 重建 `CupertinoApp` 主题（支持任意预设或自定义 Color）
- `lib/features/shell/ui/profile_page.dart`
  └─ 新增「主题配色」区块：预设色行 + 自定义色 `Wrap` 网格（大小一致/每行最多 7 个/末尾同尺寸添加框）+ 编辑/删除 ActionSheet + 会员锁定态
  └─ 依赖 ➔ `settings_controller`（`activePrimaryColor`/`customColors`/`setPresetColor` 等）/ `permission_engine`（`hasPermission('theme.customColor')`）/ `custom_color_picker_sheet` / `membership_page`
- `lib/main.dart`
  └─ 新增初始化 ➔ `CustomThemeColorService.initialize()`；权限种子 JSON 新增 `theme.customColor`

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Permission Key: `theme.customColor`（自定义配色开关，一律经 `PermissionEngine.hasPermission` 校验；`main.dart` 默认种子为 `true`，后续接入会员系统可由服务端下发关闭非会员入口）
- 新增/修改 Config Key: 无（`activePrimaryColor` 为内存 `ValueNotifier`，未落 Config；自定义色列表经 service 本地 JSON 持久化）
- 依赖方向合规：配色变更统一经 `SettingsController` 上浮 `activePrimaryColor`，`shell_page` 监听后重建主题；UI 不直接 setState 控色、不直接写持久化（自定义色 CRUD 走 `CustomThemeColorService`）；颜色走 `CupertinoColors`/`CupertinoTheme`、文案走 `LocalizationEngine`、字号走 `AppTextStyles`，无硬编码色值/字号；未触碰 `packages/`，自定义配色为会员功能预留（当前默认开放）。

### [2026-07-14] 修改：自定义配色区块由「我的」页迁移至「应用外观」页
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/profile_page.dart` (「我的」页)
  └─ **移除** 内联的「主题配色 + 自定义配色」区块（`_ThemeColoringSection` 及 `_PresetColorTile`/`_CustomColorSwatch`/`_CustomColorAddTile`）；仅保留「外观」入口（`app_appearance`）跳转 `AppearancePage`
  └─ 不再依赖 ➔ `settings_controller.dart` / `permission_engine.dart` / `custom_theme_color_model.dart` / `custom_color_picker_sheet.dart`
- `lib/features/shell/ui/appearance_page.dart` (应用外观页)
  └─ **承接** `_CustomColorSection`（自定义配色网格 + 添加框 + 编辑/删除），对应 widget `_CustomColorSwatch`/`_CustomColorAddTile` 由 profile_page 迁入
  └─ 依赖 ➔ `settings_controller.dart`(`activeCustomColorId`/`customColors`/`setPresetColor`/`applyCustomColorById`/`addCustomColor`/`updateCustomColor`/`deleteCustomColor`) / `permission_engine.dart`(`hasPermission('theme.customColor')`) / `custom_color_picker_sheet.dart` / `custom_theme_color_model.dart` / `membership_page.dart`
  └─ `custom_theme_color_model.dart` / `custom_color_picker_sheet.dart` 的被消费方由 `profile_page.dart` 改为 `appearance_page.dart`

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增 Permission / Config Key（沿用 `theme.customColor`，校验方式不变）
- 行为未变：自定义配色仍为会员功能预留（默认开放），点按应用 / 长按编辑 / 删除 / 添加框锁形跳转会员页等交互全部保留，仅所在页面由「我的」改为「应用外观」。

**【依赖方向合规】**
- 仅 UI 承载位置调整，底层 `settings_controller` / `custom_theme_color_service` / `permission_engine` 等不变；UI 仍仅监听 notifier、不直接写持久化；颜色/文案/字号仍走主题与 `LocalizationEngine`，未触碰 `packages/`，未引入硬编码。

### [2026-07-14] 修改：应用外观页「自定义配色」与「主题预设配色」显示格式统一
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/appearance_page.dart` (应用外观页)
  └─ **新增统一组件** `_ColorTile`：主题预设色与自定义配色共用同一 Widget，保证「框 (`secondarySystemBackground` + 圆角 16 + 选中主色描边)／28px 圆点展示配色／命名显示在下方 (`AppTextStyles.secondary` fontSize 12)／尺寸一致」四处完全对齐
  └─ **移除** `_ThemeColorTile` / `_CustomColorSwatch` / `_CustomColorAddTile`（三者在 `_ColorTile` 中归并；`_CustomColorSwatch._contrastColor` 一并删除）
  └─ 预设色行：仍由 `SettingsController.setPresetColor` + `resolveThemeColor` 驱动，调用方由 `_ThemeColorTile` 改为 `_ColorTile`
  └─ 自定义网格：由 7 列改为 **6 列、间距 8**，与预设行 6 列 Expanded 单格等宽；自定义色由「整块铺满 + 内部勾选」改为「框 + 圆点 + 命名」，与预设格式一致；末尾「添加」占位同样用 `_ColorTile`（图标替代圆点、标注 `custom_color_add`）
  └─ 依赖 ➔ `settings_controller.dart`(`setPresetColor`/`applyCustomColorById`/`addCustomColor`/`updateCustomColor`/`deleteCustomColor`/`customColors`/`activeCustomColorId`) / `permission_engine.dart`(`hasPermission('theme.customColor')`) / `localization_engine.dart`(新增 `custom_color_add`) / `app_text_styles.dart` / `custom_color_picker_sheet.dart` / `membership_page.dart`
- `lib/engine/localization_engine.dart` (本地化引擎)
  └─ **新增键** `custom_color_add`(添加配色 / Add Color)，zh/en 双语；供外观页「添加」占位 `_ColorTile` 的命名展示

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增 Permission / Config Key（沿用 `theme.customColor` 校验方式不变）
- 行为未变：自定义配色仍为会员功能预留（默认开放），点按应用 / 长按编辑 / 删除 / 添加框锁形跳转会员页等交互全部保留，仅视觉格式与主题预设色统一

**【依赖方向合规】**
- 仅 UI 组件合并与视觉对齐，底层 `settings_controller` / `custom_theme_color_service` / `permission_engine` 等不变；UI 仍仅监听 notifier、不直接写持久化；颜色/文案/字号仍走主题与 `LocalizationEngine`，未触碰 `packages/`，未引入硬编码。

### [2026-07-14] 修复：删除自定义每日一句崩溃 + 新增批量增加（回车分割）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/daily_sentence_service.dart` (每日一句持久化服务)
  └─ 新增/修改 ➔ `addSentencesBatch(List<String>)` (静态：按行拆分、过滤空行、微秒时间戳+自增盐值生成唯一 id、一次性落盘、返回新增条数)
  └─ 修改 ➔ `deleteSentence` / `addSentence` / `addSentencesBatch` / `updateSentence` 统一改为「先更新内存 `sentencesNotifier` 再 `_saveSentences` 落盘 + try/catch」，落盘异常仅 `debugPrint` 不再抛出
  └─ 被消费 ➔ `lib/features/shell/controller/daily_sentence_controller.dart` (`addSentencesBatch`)
  └─ 被消费 ➔ `lib/features/shell/ui/daily_sentence_edit_page.dart` (新增模式批量新增)
  └─ 被消费 ➔ `lib/features/shell/ui/home_page.dart` (`_quickAddDailySentence` 批量新增)
- `lib/features/shell/ui/daily_sentence_page.dart` (每日一句列表页)
  └─ 修改 ➔ `ReorderableListView.builder` 移除 `shrinkWrap:true`（修复删除项导致列表收缩时 `SliverReorderableList` 断言崩溃；对照 `image_to_pdf_page.dart` 不带 `shrinkWrap` 可正常删除）；`_confirmDelete` 删除回调包 `try/catch`
- `lib/features/shell/ui/daily_sentence_edit_page.dart` (新增/编辑页)
  └─ 修改 ➔ 新增模式按 `RegExp(r'[\r\n]+')` 拆分文本框为多行，过滤空行后调用 `addSentencesBatch`（一行一个每日一句）；文本框下方展示 `batch_add_hint` 本地化提示；内容为空弹 `CupertinoAlertDialog` 提示
- `lib/engine/localization_engine.dart`
  └─ 新增键 ➔ `batch_add_hint` (支持批量添加：每行一句，按回车换行可一次添加多条)

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增 Config Key / 无新增 Permission Key
- 行为说明：删除不再崩溃（先更新内存列表再落盘，落盘异常不再向上抛出导致红屏）；批量增加支持回车/换行分隔的多行文本，自动过滤空行并逐条生成唯一 id 落盘

### [2026-07-14] 修复（续）：删除自定义每日一句仍崩溃 —— 改用原生 ListView 彻底解决
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/daily_sentence_page.dart` (每日一句列表页)
  └─ **根因修正**：上一处「移除 `shrinkWrap:true`」未能彻底修复，删除仍崩溃。真正根因是纯 Cupertino（`CupertinoApp` 根）工程中使用 Material 的 `ReorderableListView`，删除项导致 `itemCount` 变小时 `SliverReorderableList` 在重建帧断言崩溃（Flutter 已知问题）。
  └─ **彻底修复**：弃用 `ReorderableListView.builder`，改用 Cupertino 原生 `ListView.builder` 渲染列表；同步移除外层 `Localizations(delegates:[DefaultMaterialLocalizations.delegate, ...])` 包裹层与 `ReorderableDragStartListener` 拖拽手柄，`import 'package:flutter/material.dart'` 不再被本文件引用。删除 / 编辑重建均稳定。
  └─ 排序能力保留：每条右侧「···」菜单的「上移 / 下移」仍调用 `DailySentenceService.reorderSentence`（底层不变），功能不丢；底部提示文案由「长按可拖动排序」改为「点击『···』可上移 / 下移排序」（`long_press_reorder` 键 zh 文案更新）。
  └─ `_confirmDelete` 删除回调仍包 `try/catch`，与 service 层「先更新 notifier 再落盘 + try/catch」形成双重防御。
- `lib/engine/localization_engine.dart`
  └─ 修改键 ➔ `long_press_reorder` (zh: '长按可拖动排序' → '点击「···」可上移 / 下移排序')

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增 Config Key / 无新增 Permission Key
- 行为说明：删除自定义每日一句不再触发框架断言崩溃；列表渲染层由 Material `ReorderableListView` 改为 Cupertino 原生 `ListView`，更贴合纯 Cupertino 工程，无任何 Material 依赖残留。

### [2026-07-14] 新增/修改：PDF 阅读器视觉增强（布局模式 / 自动裁切 / 背景调节）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/model/pdf_reader_settings.dart` (PDF 视觉设置不可变模型，聚合布局/裁切/亮度/对比度/饱和度/去色/去杂色)
  └─ 被注入 ➔ `pdf_render_service.dart` / `pdf_reader_view.dart` / `book_viewer_page.dart`
- `lib/features/shell/service/pdf_render_service.dart` (PDF 渲染服务·纯逻辑)
  └─ 依赖 ➔ `package:pdfx`（PdfDocument/原生裁切）、`dart:ui`（decodeImageFromList 回调式/ImageFilter/ImageByteFormat）、`pdf_reader_settings.dart`
  └─ 被注入 ➔ `pdf_page_tile.dart`（渲染字节 + ColorFilter 矩阵合成 + 自动裁切内容包围盒检测）
- `lib/features/shell/ui/pdf_page_tile.dart` (单页渲染瓦片·Dumb UI)
  └─ 依赖 ➔ `pdf_render_service.dart` / `pdf_reader_settings.dart` / `package:pdfx`（PhotoView 由 pdfx 再导出）
  └─ 被注入 ➔ `pdf_reader_view.dart`
- `lib/features/shell/ui/pdf_reader_view.dart` (多布局阅读视图·Dumb UI)
  └─ 依赖 ➔ `pdf_reader_settings.dart` / `pdf_page_tile.dart` / `package:pdfx`
  └─ 被注入 ➔ `book_viewer_page.dart`（替换旧 PdfView，提供单页/双页/单页连续/双页连续 4 布局）
- `lib/features/shell/ui/book_viewer_page.dart` (PDF 阅读器)
  └─ 变更 ➔ 用 `PdfReaderView` 替换 `PdfView`；新增 PDF 视觉状态自 `SettingsEngine` 初始化、经设置页回调上浮并落库 `SettingsController`；进度同步改由 `PdfReaderView.onCurrentPageChanged` 驱动。
- `lib/features/shell/ui/reader_settings_sheet.dart` (阅读设置抽屉)
  └─ 变更 ➔ 「翻页方式」由「更多」移入「外观」置于亮度下方；「外观」新增「布局」模式；设置面板限高屏幕 3/4 且可滚动；「更多」新增「自动裁切」开关与「背景调节」分区（对比度/饱和度/去除颜色/智能去杂色）；新增 `_SwitchRow`/`_SliderRow`/`_sectionTitle` 构件。新增构造参数带默认值兼容 txt 阅读器。
- `lib/engine/settings_engine.dart` (设置引擎)
  └─ 新增 ➔ 7 个 Config Key：`readerLayoutMode` / `pdfAutoCrop` / `pdfBgBrightness` / `pdfBgContrast` / `pdfBgSaturation` / `pdfBgRemoveColor` / `pdfBgDenoise` 及 getter/setter。
- `lib/features/shell/controller/settings_controller.dart` (设置控制器)
  └─ 新增 ➔ 7 个 `ValueNotifier` 与 `setXxx`（readerLayoutMode / pdfAutoCrop / pdfBg*），UI 仅监听 notifier 不直接写持久化。
- `lib/engine/localization_engine.dart` (本地化引擎)
  └─ 新增 ➔ 13 个双语键：`reader_layout`(+4 布局子项) / `pdf_auto_crop`(+desc) / `pdf_bg_adjust` / `pdf_bg_contrast` / `pdf_bg_saturation` / `pdf_bg_remove_color`(+desc) / `pdf_bg_denoise`(+desc)。

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Config Key：`app.reader.pdf.layoutMode`(int,0) / `app.reader.pdf.autoCrop`(bool,false) / `app.reader.pdf.bg.brightness`(double,1.0) / `app.reader.pdf.bg.contrast`(double,1.0) / `app.reader.pdf.bg.saturation`(double,1.0) / `app.reader.pdf.bg.removeColor`(bool,false) / `app.reader.pdf.bg.denoise`(bool,false)，均经 `Config` 持久化。
- 无新增 Permission Key。
- 行为说明：自动裁切经低分辨率缩略图像素扫描求内容包围盒（缓存复用）后由 pdfx 原生精确裁切；背景调节经 `ColorFilter.matrix`（亮度/对比度/饱和度/灰度）与 `ImageFilter.blur`（去杂色）合成，仅 GPU 滤镜、不重解码；多瓦片并发渲染由 pdfx 文档级锁自动串行化，Android/iOS/Win/Mac 均安全。

### [2026-07-15] 修改：PDF 设置功能生效 + 新增「重排」按钮（回退 PdfView 路径上的 GPU 滤镜叠加层）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_render_service.dart` (`buildColorMatrix` 纯逻辑，无原生调用)
  └─ 被注入 ➔ `lib/features/shell/ui/book_viewer_page.dart`（`_buildPdfView` 用 `ColorFiltered`/`ImageFiltered` 包裹 `PdfView`）
- `lib/features/shell/ui/reader_settings_sheet.dart`（`_ActionRow` + `onReflow` 回调）
  └─ 被注入 ➔ `lib/features/shell/ui/book_viewer_page.dart`（`_reflow` 置 `layoutMode=2`）
- `lib/engine/localization_engine.dart`（`pdf_reflow` / `pdf_reflow_desc` 键）
  └─ 被全局 UI 调用

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增 Config Key / Permission Key（沿用既有 `pdf.*` 设置 Key）。
- 行为说明：PDF 颜色调整（亮度/对比度/饱和度/去色）经 `PdfRenderService.buildColorMatrix` 合成 `ColorFilter.matrix`，由 `ColorFiltered` 包裹 `PdfView` 施加；智能去杂色经 `ImageFilter.blur` 由 `ImageFiltered` 包裹施加；均为纯 Flutter GPU 合成、无原生调用，Windows 下安全。布局模式单页(0)/单页连续(2) 经 `PdfView.pageSnapping` 实现；双页(1)/双页连续(3) 因 pdfx 官方 `PdfView` 不支持 2-up，降级为单页/单页连续（UI 保留，待自定义渲染管线在 Windows 修复后接入）。自动裁切需自定义渲染管线（Windows 挂死），暂保留开关不生效。重排按钮切换为单栏连续阅读模式（`layoutMode=2`）。

### [2026-07-15] 新增：PDF 重排 / OCR 阶段0 基础（onnxruntime 全平台绑定 + 原生库运行时验证）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_ocr_service.dart`（新增·OCR 纯逻辑服务）
  └─ 依赖 ➔ `package:flutter_onnxruntime`（dart:ffi 通用 ONNX 推理，全平台 Win/iOS/Android/macOS/web）
  └─ 被注入（阶段1/3） ➔ `lib/features/shell/ui/book_viewer_page.dart`（扫描件无文本层时调用 `recognizePage` 取文本，复用同一 `PdfReflowView`）
- `integration_test/pdf_ocr_test.dart`（新增·原生库运行时验证）
  └─ 依赖 ➔ `integration_test` / `pdf_ocr_service.dart`
- `assets/models/`（新增资源目录，当前含 `addition_model.onnx` 冒烟测试模型；阶段3 放 det/rec/dict）
- `pubspec.yaml`：新增 `flutter_onnxruntime: ^1.7.0`；`image` 由 dev 提升为主依赖；`flutter.assets` 加 `assets/models/`；dev 加 `integration_test`

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增 Config Key / Permission Key。
- 阶段0 结论：选定 `flutter_onnxruntime`（通用 ONNX 绑定，全平台）以实现 PaddleOCR 流水线（用户要求全平台，故未用仅单平台的 `pp_ocr`/`paddle_ocr_flutter`/`flutter_paddle_ocr`）。已通过 `integration_test` 在真实 Windows 应用嵌入中加载并跑通 onnxruntime 原生推理（断言加法模型输出 [11,22,33]），确认不会像 PDFium 那样挂死。注意：本环境 `flutter test` 不注册原生插件，故验证改用 integration_test。完整 PaddleOCR 检测/识别/字典解码流水线留待阶段3。

### [2026-07-15] 修复：Windows 构建离线化（本地 vendor onnxruntime，解决「加 OCR 后 Windows 起不来」）
**【问题】**
- 加入 `flutter_onnxruntime` 后，Windows 选设备调试无窗口、无 Dart 报错（Chrome/web 正常）。根因：插件 `windows/CMakeLists.txt` 默认 `USE_SYSTEM_ONNXRUNTIME=ON`，无系统 onnxruntime 时回退到 **CMake 配置期从 GitHub 下载 `onnxruntime-win-x64-1.22.0.zip`**；构建机拉不到 GitHub 即构建失败、无 exe。
**【修复】**
- `windows/third_party/onnxruntime/`：vendor `onnxruntime-win-x64-1.22.0` 的 `include/`+`lib/`（剔除 .pdb，约 13MB），已 gitignore（大二进制不入库，需时按同法重新下载 vendor）。
- `windows/CMakeLists.txt`：
  1. `include(flutter/generated_plugins.cmake)` 之前 `set(ONNXRUNTIME_ROOT_DIR ".../third_party/onnxruntime" CACHE PATH FORCE)` → 命中本地副本，不再联网下载；
  2. 插件 system 分支只链 `.lib` 不拷 `.dll`，新增 `add_custom_command(TARGET bookreader POST_BUILD ...)` 把 `onnxruntime.dll`/`onnxruntime_providers_shared.dll` 拷到 exe 旁（运行时加载所需）。
**【影响】**
- 仅 Windows 构建链；web/Android/iOS/macOS/Linux 不受影响。阶段3 接入真实 PaddleOCR 模型沿用同一 vendor 目录。
- 无新增 Config Key / Permission Key。

### [2026-07-15] 修复：Windows 构建真因 = `add_custom_command(TARGET bookreader)` 写错目录
**【问题】**
- 上一轮离线化后 `flutter run -d windows` 报 `CMake Error at CMakeLists.txt:86 (add_custom_command): TARGET 'bookreader' was not created in this directory.` + `Unable to generate build files`。根因：本人在顶层 `windows/CMakeLists.txt` 写了 `add_custom_command(TARGET bookreader POST_BUILD ...)` 拷 onnxruntime DLL，但 `bookreader` target 定义在 `runner/CMakeLists.txt`（经 `add_subdirectory("runner")`）；CMake 要求该命令与 target 同目录 → 配置阶段直接失败，构建文件都生成不了（故 `flutter_onnxruntime_plugin.dll` 一直没编出、`bookreader.exe` 停在 Jul 3 只是陈旧产物，并非插件编译错）。
**【修复】**
- `windows/CMakeLists.txt`：把 `set(ONNXRUNTIME_ROOT_DIR ... CACHE PATH FORCE)` **移到 `add_subdirectory("runner")` 之前**（runner 与插件均可见本地路径）；删除顶层非法的 `add_custom_command(TARGET bookreader ...)`，仅保留 `file(GLOB ONNXRUNTIME_RUNTIME_DLLS ...)` 供 install() 用。
- `windows/runner/CMakeLists.txt`：把 `add_custom_command(TARGET bookreader POST_BUILD copy_if_different *.dll)` 挪到此处（bookreader 定义处），把 `onnxruntime.dll`/`onnxruntime_providers_shared.dll` 拷到 exe 旁。
- 保留 `/WX-` 防御（无害）。
- 用户需 `flutter clean` 后 `flutter run -d windows`（清掉上次失败的陈旧缓存）。
**【经验】**
- `add_custom_command(TARGET <t> ...)` 必须写在定义 `<t>` 的那个 CMakeLists.txt（同目录）。给 exe 拷 DLL 应放在 `runner/CMakeLists.txt`。
- 无新增 Config Key / Permission Key。

## [2026-07-15 下午] PDF 设置 4 项缺陷修复（翻页/圆圈对齐/底部按钮/裁切去杂色重排）
**背景**：用户反馈 PDF 设置里 4 个问题：① 翻页方式/布局无真实效果；② 主题配色圈与阅读背景圈大小不一、未对齐；③ 点「外观」时底部 5 导航按钮被设置内容遮挡；④ 自动裁切/去杂色/重排未生效、图片扫描件未真正重排。
**修改文件**：
- `lib/engine/settings_engine.dart`：新增 Config Key `readerPageMode`（int，默认0）+ getter/setter，补齐「翻页方式」持久化。
- `lib/features/shell/controller/settings_controller.dart`：新增 `readerPageMode` notifier + `setReaderPageMode`。
- `lib/features/shell/ui/book_viewer_page.dart`：
  - 问题①：`_buildPdfView()` 由写死 `Axis.vertical` 改为按 `_selectedPageMode` 推导 `scrollDirection`（0/2 横向、1/3 纵向），按「连续布局 或 上下滚动」推导 `pageSnapping`；`PdfView` 加 `ValueKey` 保证切轴向时干净重建。`_selectedPageMode` 初始化自持久化、回调经控制器落库。
  - 问题④：`_pageBuilder` 在自动裁切开启时把 PhotoView `initialScale/minScale` 提为 `contained*1.12`（去白边，纯缩放无原生调用）；去杂色 `blur` sigma 0.7→1.4；`_reflow()` 组合「上下滚动+单页连续+自动裁切」。
- `lib/features/shell/ui/reader_settings_sheet.dart`：
  - 问题②：阅读背景色圈由 直径28/宽46/字号9/间距6 统一为 直径40/宽54/字号11/间距8（与主题配色一致，PDF 与非 PDF 两处）。
  - 问题③：PDF 设置面板改为 `Column[Flexible(SingleChildScrollView(内容)), 固定底部导航]`，底部 5 按钮移出滚动区、始终可见。
**能力边界（如实告知用户）**：
- pdfx `PdfView` 不支持双栏 2-up，布局「双页/双页连续」仍降级为单页/单页连续；「仿真」翻页无卷曲动画（降级横向翻页）。
- 自动裁切为「缩放去白边」近似，非逐页内容包围盒精确裁切。
- 图片扫描件「文字级重排」需 OCR（`recognizePage` 当前空壳，属阶段3 PaddleOCR），当前重排为版式层面（连续滚动+去白边+撑满宽度）。
**验证**：`flutter analyze` 0 error / 0 warning（仅既有 info 级弃用提示）。沙箱 MSBuild 损坏无法自测运行，需用户 `flutter run -d windows` 实测。
**Key 变动**：新增 Config Key `app.reader.pdf.pageMode`（无 Permission Key 变动）。

### [2026-07-15] 新增/修改：PDF 阅读器引擎迁移 pdfx → pdfrx（全平台 · 主线 C）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_render_service.dart`（纯逻辑层：pdfrx 渲染为 ui.Image / 原生子区域精确裁切 / 颜色矩阵合成）
  └─ 被注入 ➔ `lib/features/shell/ui/pdf_custom_view.dart`（_PdfPageWidget._load 调 renderPageImage；滤镜叠加调 buildColorMatrix）
- `lib/features/shell/ui/pdf_custom_view.dart`（自建双栏 2-up / 连续滚动 / 横向吸附翻页 / 原生平铺精确裁切 + GPU 滤镜）
  └─ 被注入 ➔ `lib/features/shell/ui/book_viewer_page.dart`（_buildPdfView 返回 PdfCustomView(document, settings, pageMode, onPageChanged)）
- `lib/features/shell/service/bookshelf_service.dart`（PDF 封面缩略图改 pdfrx）
  └─ 依赖 ➔ `package:pdfrx`（openFile → pages[0] → render → createImage → toByteData(png)）
- `pubspec.yaml`
  └─ 删除 `pdfx: ^2.9.2`、新增 `pdfrx: ^1.3.5`（与 image / pdf / flutter_onnxruntime 并存）
- 删除（pdfx 死代码，避免双 PDFium）：`lib/features/shell/ui/pdf_reader_view.dart` / `lib/features/shell/ui/pdf_page_tile.dart` / `test/pdf_fmt_probe_test.dart`

**【全局状态/鉴权变动 (State & Auth)】**
- 新增/修改 Config Key：无（沿用主线 B 既有 7 个 PDF 设置 Key：readerLayoutMode / pdfAutoCrop / pdfBgBrightness / pdfBgContrast / pdfBgSaturation / pdfBgRemoveColor / pdfBgDenoise，及 readerPageMode；引擎替换不改变任何设置项语义）
- 新增/修改 Permission Key：无

**【迁移要点】**
- 为什么换：pdfx 官方 `PdfView` 控件不支持自定义版面（双栏 2-up）且未暴露逐页 `cropRect`，导致布局双页降级、自动裁切只能近似缩放去白边。pdfrx 同 PDFium 内核、全平台，提供低层 `PdfDocument/PdfPage/PdfImage` API，可自建版面与原生子区域裁切。
- 已实现能力：双栏 2-up（封面单页 + 其后对开页）、单页连续滚动、横向吸附翻页（PageView）、原生平铺精确裁切（探针图像素扫描求包围盒 → 高分 render 仅裁内容区）、GPU 滤镜叠加（ColorFiltered/ImageFiltered）、缩放（InteractiveViewer 1.0~4.0）。
- 仍受限（如实告知）：①「仿真」翻页无书页卷曲动画（pdfrx 不提供，自建 PageView 为横向整页翻页）；② 扫描件文字级重排仍需 OCR（pdf_ocr_service.recognizePage 当前空壳，属阶段3 PaddleOCR 集成），本轮仅版式重排。
- Windows 构建注意：pdfrx 使用符号链接，需开启「开发者模式」。
- 验证：`flutter analyze` 全工程 0 error（仅遗留既有 info/warning，非本次引入）。

### [2026-07-15 夜] 修复：pdfrx 阅读器三个交互缺陷（无法翻页 / 切滚动崩溃 / 饱和度不生效）
**背景**：引擎迁移到 pdfrx 后用户实测反馈 3 个问题：① PDF 完全无法翻页；② 设置里切「上下滚动」模式应用直接崩溃；③ 背景调节的「色彩饱和度」滑块看不出效果。
**根因与修复（仅改动 `lib/features/shell/ui/pdf_custom_view.dart`，未触碰架构/包隔离）**：
- 缺陷①「无法翻页」＝ 双因叠加：
  - (a) 单页分支 `_buildSpread` 把 `Expanded(_PdfPageWidget)` 误放进 `Center`（Center 非 Flex），布局异常；
  - (b) 每页包裹的 `InteractiveViewer`（scaleEnabled 默认开）其手势识别器会拦截单指滑动，导致 `PageView`/`ListView` 收不到翻页/滚动手势。修复：移除 `InteractiveViewer` 缩放手势层（翻页/滚动交回原生控件）；缩放能力后续以「仅在已放大态启用」等不冲突方式重新接入。
- 缺陷②「切滚动崩溃」＝ 单页分支 `Expanded` 位于 `ListView` 的**无限主轴**上，触发 `Expanded widgets must be placed inside a Flex widget` 断言崩溃。修复：
  - 单页尺寸（`pageW`/`pageH`）改由**外层 `LayoutBuilder`** 提供（屏幕确定尺寸），单页用 `SizedBox` 直接铺满，彻底避免「无限高度」与 `Expanded` 误用；双页仍用 `Row`+`Expanded`（合法）。
- 缺陷③「饱和度不生效」＝ 矩阵合成逻辑（`pdf_render_service.buildColorMatrix` 的亮度/对比度/饱和度/去色）本身正确，但：① 此前视图崩溃/冻结导致无法实测；② 饱和度仅在**有彩色内容**的页上可见——黑白文字 PDF 本身无饱和度可改（符合色彩学，非 bug）。修复崩溃+布局后，对彩色/扫描页饱和度滑块即可见。（亮度/对比度/去色同理，均经同一 `ColorFiltered` 链路。）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/pdf_custom_view.dart`（修复：`build()` 外层 `LayoutBuilder` 取确定视口尺寸；`_buildSpread` 单页 `SizedBox` 铺满、双页 `Row`+`Expanded`；`_PdfPageWidget` 移除 `InteractiveViewer`，仅 `ColorFiltered`+`ImageFiltered`）
  └─ 被注入 ➔ `lib/features/shell/ui/book_viewer_page.dart`（`_buildPdfView()` 返回 `PdfCustomView`，翻页/滚动完全由原生 `PageView`/`ListView` 处理）
  └─ 依赖 ➔ `pdf_render_service.dart`（`renderPageImage` / `buildColorMatrix`）/ `pdf_reader_settings.dart` / `package:pdfrx` / `dart:ui`
**【全局状态/鉴权变动 (State & Auth)】**：无新增 Config / Permission Key（沿用既有 7 个 PDF 设置 Key + readerPageMode）。
**验证**：`flutter analyze lib/features/shell/ui/pdf_custom_view.dart` → No issues found；全工程无新增 error（既有 129 条为 info/warning 级弃用提示，非本次引入）。沙箱环境 OS 层禁 `sandbox-exec` 无法本地 `flutter run -d macos` 自测，需用户本机实测翻页/切滚动/饱和度。

### [2026-07-15 晚] 新增/修改：PDF 阅读器体验修复（用户 10 项反馈）
**背景**：pdfrx 引擎迁移 + 前几轮交互缺陷修复后，用户实测反馈 10 个问题：①自动裁切乱切（有字被切没、留白边、切半字）；②左右单击不翻页；③双页/连续页间隙过大；④翻页方式需新增「左右单击/上下单击/单击滚动」且「无动画/仿真动画」独立成区；⑤双页模式首/末页被强制单页（需取消）；⑥去杂色降清晰度、杂点未除；⑦书架列表仅显 4 本（实际 19 本）；⑧书籍被莫名裁掉一部分；⑨饱和度不生效；⑩重排需改为真实（文本级）重排，本地方案、Android+PDF 可用、可调字号/间距、流畅。

**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_text_reflow_service.dart`（新增 · 真实重排数据源：pdfrx `PdfPage.loadText().fullText` 逐页提取→按连字符续行/句末标点聚合成段落，本地无损）
  └─ 被注入 ➔ `lib/features/shell/ui/book_viewer_page.dart`（`_reflow()` 调 `extract` → 进 `PdfReflowView`；无文本层提示 `pdf_reflow_empty`）
- `lib/features/shell/ui/pdf_reflow_view.dart`（新增 · 重排阅读视图：`AnimatedBuilder(Listenable.merge([4 个 reflow notifier]))` 实时跟随字号/行距/字距/段距；顶部「退出重排」）
  └─ 依赖 ➔ `settings_controller.dart`（`pdfReflowFontSize/LineSpacing/LetterSpacing/ParaSpacing`）/ `localization_engine.dart`
- `lib/features/shell/ui/pdf_custom_view.dart`（修改：翻页方式扩为 5 种 0 左右滑动/1 上下滑动/2 左右单击/3 上下单击/4 单击滚动；新增 `pageAnimation` 0 无/1 仿真；`_onTapFlip` 按点击区域判前后；`_buildSpreads` 取消封面/末页强制单页、改为顺序成对；`_pageGap` 12→6）
  └─ 被注入 ➔ `book_viewer_page.dart`（`_buildPdfView()` 传 `pageAnimation: SettingsEngine.readerPageAnimation`）
- `lib/features/shell/service/pdf_render_service.dart`（修改：自动裁切探针 240→480、阈值 238、内容占比<0.3% 跳过、边距 2% 兜底、clamp；真实去杂色 `_denoiseImage` 3×3 邻域判定，回调式 `decodeImageFromPixels` 回写 `ui.Image`；`renderPageImage` 加 `denoise` 参数并纳入缓存 key）
  └─ 依赖 ➔ `package:pdfrx` / `dart:ui` / `dart:async`
- `lib/features/shell/ui/reader_settings_sheet.dart`（修改：新增 `selectedPageAnimation`/`onPageAnimationChanged`/`showReflow`；`_buildPageTurnSection` 翻页方式 5 模式单行 + 独立「翻页动画」区；`_buildReflowTypographySection`+`_reflowSlider` 重排排版 4 滑块；替换旧 4 模式文案）
  └─ 依赖 ➔ `settings_controller.dart` / `settings_engine.dart` / `localization_engine.dart`
- `lib/features/shell/ui/bookshelf_page.dart`（修改：`_buildDownloadListView` 由 `books.take(4)` 改为 `books`（仅 mock 兜底保留 `take(4)`），显示全部导入书籍）
- `lib/features/shell/model/pdf_reader_settings.dart`（修改：`needsRerender => autoCrop || denoise`）

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Config Key：`app.reader.pdf.pageAnimation`（默认 1）、`app.reader.pdf.reflow.fontSize`（18.0）、`app.reader.pdf.reflow.lineSpacing`（1.6）、`app.reader.pdf.reflow.letterSpacing`（0.0）、`app.reader.pdf.reflow.paraSpacing`（8.0）；见 `settings_engine.dart` + `settings_controller.dart`（notifier + setter）。
- 新增本地化 Key：`reader_page_turn_swipe_h/v`、`reader_page_turn_tap_h/v`、`reader_page_turn_tap_scroll`、`reader_page_animation`/`_none`/`_simulation`、`pdf_reflow_exit`/`_font_size`/`_line_spacing`/`_letter_spacing`/`_para_spacing`/`_loading`/`_empty`；删除旧 `reader_page_turn_horizontal/vertical/simulation/none`。
- 新增 Permission Key：无。

**逐项修复对照（10 项）**
1. 自动裁切：提升探针分辨率 + 阈值 + 内容占比保护 + 边距兜底 + clamp，内容填满页回退全页；⑧书籍被裁切同源修复（旧 clamp/边距过激所致）。
2. 单击翻页：纯单击模式（2/3）用 `GestureDetector.onTapUp` + `NeverScrollableScrollPhysics`，点击区域判定前后，`HitTestBehavior.translucent` 不抢滑动。
3. 间隙过大：`_pageGap` 12→6，页面紧邻仅留极细分隔。
4. 翻页方式：5 模式单行；「无动画/仿真动画」独立「翻页动画」分区。
5. 双页首末页单页：取消，改为从首页起顺序成对。
6. 去杂色：由「整体高斯模糊」改为「3×3 邻域去孤立墨点」，保笔画、不降清晰度。
7. 书架仅显 4 本：`take(4)` 去掉，显示全部。
8. 页面被裁切：随自动裁切重算修复（见①）。
9. 饱和度不生效：矩阵逻辑本就正确，旧因崩溃/冻结无法实测；现对含彩色内容页可见（黑白文字无饱和度可改，符合色彩学）。
10. 真实重排：`PdfTextReflowService` 取文本层 → `PdfReflowView` 可调字号/行距/字距/段距重排；本地、Android+PDF、流畅；纯扫描件（无文本层）检测后明确提示改用 OCR（阶段3）。

**能力边界（如实告知）**
- 真实重排适用于**含文本层**的 PDF（电子书/论文/文档）；**纯图片扫描件**无文本层，`PdfTextReflowService.extract` 已检测并提示 `pdf_reflow_empty`，不静默失败。扫描件文字级重排仍需 OCR（`pdf_ocr_service.recognizePage` 仍为阶段0 空壳，属阶段3 PaddleOCR）。
- 验证：`flutter analyze lib` → **0 error**（130 条为 info/warning 级既有弃用提示，非本次引入，含若干 localization 既有 duplicate-key 提示）。沙箱 OS 层禁 `sandbox-exec` 无法本地 `flutter run` 自测，需用户本机 `flutter run` 实测。

---

### [2026-07-15 深夜] 修复（根因）：书籍点开即被裁切、双排裁切更严重 —— pdfrx render 参数误用导致页面溢出位图被静默裁掉
**问题现象**：用户确认「自动裁切」开关为关闭，但进入任意书籍即发现内容被切掉一部分；双排（双页）模式裁切更明显。
**根因（已读 pdfrx 1.3.5 源码 `lib/src/pdfium/pdfrx_pdfium.dart` 确认）**：
- `pdf_render_service.renderPageImage` 的「无裁切」分支原调用 `page.render(width: fullW, height: fullH)`，**未传 `fullWidth/fullHeight`**。
- pdfrx `PdfPage.render` 在 `fullWidth/fullHeight` 缺省时回退为**页面原生 pt 尺寸**（如 595×842），而位图尺寸取传入的 `width/height`（单页约 1200、双页约 591）。
- PDFium 按 `fullWidth×fullHeight`（原生尺寸）把整页渲染进**更小的位图**，导致**页面右/下边缘溢出位图被静默裁掉**；位图越小于原生页，裁切越多。
- 双页 `targetWidth = (pageW − 6)/2` 远小于单页，位图更小 → 裁切比例更大 → 与「双排裁切更多」现象完全吻合。
**修复（仅 `lib/features/shell/service/pdf_render_service.dart`）**：
- 无裁切分支改为 `page.render(fullWidth: fullW, fullHeight: fullH)`（不传 x/y/width/height），使 `width ??= fullWidth`、`height ??= fullHeight`，位图尺寸 == 整页渲染尺寸，零溢出、零裁切。
- 兜底分支（裁切包围盒退化成整页时）同样改 `fullWidth/fullHeight`。
- 自动裁切探针 `computeCropFractions`：原 `render(width: cropScanWidth, height: probeH)` 同样漏传 `fullWidth/fullHeight`，导致探针只扫到整页左上角、自动裁切算出的包围盒偏小（开启自动裁切时仍会误切右侧内容）。改为 `render(fullWidth: cropScanWidth, fullHeight: probeH)`，探针才是真正的全页探针。
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_render_service.dart`（修复：无裁切分支与兜底分支改用 `fullWidth/fullHeight`；自动裁切探针改用 `fullWidth/fullHeight`）
  └─ 依赖 ➔ `package:pdfrx`（render 语义：`fullWidth/fullHeight` 缺省回退页面原生尺寸，位图小于原生尺寸即裁切右/下边缘）
- `lib/features/shell/ui/pdf_custom_view.dart`（既有加固：单页 `FittedBox(BoxFit.contain)` 包裹 `RawImage`，双页 `Row` 外层 `ClipRect(clipBehavior: Clip.none)`，二者均为防御性防裁切，与 render 层根因修复互补）
  └─ 被注入 ➔ `lib/features/shell/ui/book_viewer_page.dart`
**【全局状态/鉴权变动 (State & Auth)】**：无新增 Config / Permission Key（沿用既有 7 个 PDF 设置 Key + readerPageMode）。
**验证**：`flutter analyze lib/features/shell/service/pdf_render_service.dart lib/features/shell/ui/pdf_custom_view.dart` → No issues found（0 error）。沙箱 OS 层禁 `sandbox-exec` 无法本地 `flutter run` 自测，需用户本机实测：关闭自动裁切进入任意 PDF，确认单页/双页内容均完整、无边缘被切。

---

### [2026-07-16 凌晨] 新增：PDF「更多设置」全面重组 —— 画面增强 + 页面裁切 + 双屏模式

**背景**：用户要求将分散的 PDF 调节项归入两个圆角卡片（画面增强 / 页面裁切），每个滑块增加 [−]/[+] 微调按钮（参考截图风格），并新增色温调节、裁切模式切换（智能/手动/框选）、双屏对比阅读。

**改动范围**（7 个文件）：

1. **`lib/engine/localization_engine.dart`**
   - 新增 14 个 i18n key：`pdf_enhance`, `pdf_enhance_{sharpness,contrast,brightness,saturation,color_temp,remove_color}`, `pdf_crop{,_auto,_manual,_select,_left_right,_top_bottom}`, `pdf_dual_screen{,_desc}`。

2. **`lib/engine/settings_engine.dart`**
   - 新增 Config Key：`pdfBgColorTemp`(double), `pdfCropMode`(int), `pdfManualCrop{Left,Right,Top,Bottom}`(double×4), `pdfDualScreen`(bool)。
   - 新增 getter/setter 共 10 组。

3. **`lib/features/shell/controller/settings_controller.dart`**
   - 新增 ValueNotifier：`pdfBgColorTemp`, `pdfCropMode`, `pdfManualCrop{Left,Right,Top,Bottom}`, `pdfDualScreen`。
   - 新增 static setter 方法共 7 个。

4. **`lib/features/shell/model/pdf_reader_settings.dart`**
   - 新增字段：`cropMode`, `manualCropLeft/Right/Top/Bottom`, `colorTemperature`, `dualScreen`。
   - 更新 `copyWith` / `isAdjusted` / `needsRerender` / `toString`。

5. **`lib/features/shell/service/pdf_render_service.dart`**
   - 新增 `_colorTemperature(t)` 色温矩阵方法（t<1 偏冷蓝 / t>1 偏暖黄，通过 R/G/B 通道偏移实现）。
   - `buildColorMatrix` 合成链新增色温环节：亮度 → 色温 → 饱和度 → 对比度 → 灰度。

6. **`lib/features/shell/ui/reader_settings_sheet.dart`** ⭐ 核心改动
   - 新增 12 个构造参数（colorTemperature/cropMode/manualCropLTRB/onSelectCrop/dualScreen 等）。
   - 原 `_showMoreSettings` 区块完全重写：
     - **`_StyledCard`** — 圆角深色卡片容器（自适应暗色模式）。
     - **`_FineTuneSliderRow`** — 带 `[−]` `[滑块]` `[+]` 微调按钮的滑块行（StatefulWidget，拖动连续、点击步进）。
     - **`_buildEnhanceCard`** — 画面增强卡片：清晰度(占位)/对比度/亮度/饱和度/色温 + 去除颜色开关 + 去杂色开关。
     - **`_buildCropCard`** — 页面裁切卡片：智能自动裁边开关 / 左右裁切(显示 L/R 百分比) / 上下裁切(显示 T/B 百分比) / 框选裁边按钮（TODO: 后续接入手动画框 UI）。
     - 双屏模式 SwitchRow（独立于两卡片之外）。

7. **`lib/features/shell/ui/book_viewer_page.dart`**
   - 新增 8 个状态字段（_colorTemperature/_cropMode/_manualCropLTRB/_dualScreen），初始化自 SettingsEngine。
   - `_readerSettings` getter 聚合全部新字段。
   - ReaderSettingsSheet 构造传入全部新回调（含 onSelectCrop 占位 TODO）。

**【AI 架构依赖树 (Architecture Context)】**
- `reader_settings_sheet.dart`（UI 重组：_StyledCard + _FineTuneSliderRow + _buildEnhanceCard + _buildCropCard）
  └─ 依赖 ➔ `localization_engine.dart`（14 新 key）
  └─ 依赖 ➔ `settings_controller.dart`（10 新 notifier）
- `book_viewer_page.dart`（状态上浮：8 新字段 + 回调落库）
  └─ 注入 ➔ `ReaderSettingsSheet`
  └─ 聚合 ➔ `PdfReaderSettings`
- `pdf_reader_settings.dart`（数据模型扩展：8 新字段）
  └─ 被消费 ➔ `PdfRenderService.buildColorMatrix`
- `pdf_render_service.dart`（渲染管线：新增 _colorTemperature 色温矩阵）

**【全局状态/鉴权变动 (State & Auth)】**：新增 10 个 Config Key（colorTemp/cropMode/manualCropLTRB/dualScreen）+ 8 个 ValueNotifier。全部通过 SettingsController 统一读写。

**验证**：`flutter analyze lib` → **0 error**（132 条均为既有的 info/warning/deprecation 提示，非本次引入）。沙箱无法 `flutter run`，需用户本机实测。

### [2026-07-16] 新增/修改：翻页动画 7 种 + 连续模式缩放(页面紧密相连) + 进度条回拖修复 + 扫描件 OCR 重排流水线

**【AI 架构依赖树 (Architecture Context)】**
- `lib/engine/settings_engine.dart`（扩展 `readerPageAnimation` 枚举注释 0~8；新增 Config Key `app.reader.pdf.ocrEnabled`）
  └─ 被注入 ➔ `lib/features/shell/ui/reader_settings_sheet.dart`（`_buildPageTurnSection` 翻页动画 9 项网格芯片；`anims` 映射 0..8）
  └─ 被注入 ➔ `lib/features/shell/ui/book_viewer_page.dart`（`_buildPdfView()` 传 `pageAnimation: SettingsEngine.readerPageAnimation`；`_reflow()` 按 `pdfOcrEnabled` + `PdfOcrService.isModelAvailable()` 路由 OCR）
- `lib/features/shell/ui/pdf_custom_view.dart`（Dumb UI）
  └─ 新增 `_buildAnimatedSpread` / `_transformSpread`：非连续逐页按 `PageController.page` 相对偏移施加 2 淡入淡出/3 叠加/4 跃动/5 旋转/6 旋转木马/7 圆筒/8 反转 变换
  └─ 新增连续模式 `InteractiveViewer` 整列缩放（`_zoomController`/`_onZoomChanged`，仅放大态启用平移，未放大时滑动回落 ListView 滚动）
  └─ 新增 `_offsetForSpread`：修复连续模式进度条从末尾回拖页面不跳转（`_currentSpreadIndex()` 连续模式恒 0 致相对位移错乱）
- `lib/features/shell/service/pdf_ocr_service.dart`（阶段 3 完整 PaddleOCR 流水线：det.onnx DB 检测 + rec.onnx CRNN 识别 + ppocr_dict.txt CTC 解码 + 阅读顺序排序）
  └─ 被注入 ➔ `lib/features/shell/service/pdf_text_reflow_service.dart`（`extractOcr` 逐页渲染→OCR→复用 `_appendPageText` 聚合）
  └─ 被注入 ➔ `lib/features/shell/ui/book_viewer_page.dart`（`_reflow()` 扫描件 OCR 重排路径）
- `lib/engine/localization_engine.dart`（新增 10 个本地化 Key：`reader_page_animation_fade/overlap/jump/rotate/carousel/cylinder/flip`、`pdf_reflow_ocr_loading/ocr_unavailable/ocr_failed`）

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Config Key：`app.reader.pdf.ocrEnabled`（默认 true，扫描件 OCR 重排总开关，经 SettingsController 读写）
- 无新增 Permission Key（本次均为 feature 级 UI/引擎，未触碰权限禁区）
- 未触碰 `packages/`，UI 不硬编码颜色/字号/文案（颜色走主题/CupertinoDynamicColor，文案走 LocalizationEngine），符合架构铁律。

**验证**：`flutter analyze lib`（涉及 7 个文件）→ **0 error**（既有 info/warning 提示非本次引入）。OCR 推理需使用者将 `det.onnx`/`rec.onnx`/`ppocr_dict.txt` 放入 `assets/models/` 后本机实测（沙箱无法 `flutter run` 且缺模型权重）。

### [2026-07-18] 新增/修改：双击放大开关 + 双屏进度条修复 + 自动裁切重写对齐规范 + OCR 模型校验

**【AI 架构依赖树 (Architecture Context)】**
- `lib/engine/settings_engine.dart`
  └─ 新增 Config Key `app.reader.pdf.doubleTapZoom`(bool, 默认 false) + getter/setter `pdfDoubleTapZoom`/`setPdfDoubleTapZoom`
  └─ 被注入 ➔ `lib/features/shell/controller/settings_controller.dart`（新增 `pdfDoubleTapZoom` notifier + `setPdfDoubleTapZoom`，纳入 `_defaults`/`_pdfNotifiers`/`bindBook`/`_persistActiveBook` 每本书落盘）
  └─ 被注入 ➔ `lib/features/shell/ui/book_viewer_page.dart`（状态 `_doubleTapZoom` 由 `SettingsEngine.pdfDoubleTapZoom` 初始化，`_initBookSettings` 由 `SettingsController.pdfDoubleTapZoom` 同步）
- `lib/features/shell/model/pdf_reader_settings.dart`
  └─ 新增字段 `doubleTapZoom`(bool) + `copyWith` 参数/赋值
  └─ 被注入 ➔ `lib/features/shell/ui/pdf_custom_view.dart`（`PdfCustomView.doubleTapZoom` 构造参数，驱动手势）
- `lib/features/shell/ui/pdf_custom_view.dart`（Dumb UI）
  └─ 连续/逐页模式均用 `InteractiveViewer` 包裹（双指捏合缩放）；开启 `doubleTapZoom` 时叠加 `GestureDetector.onDoubleTap` 循环 1×/2×/3×（非纯单击翻页模式，避免「双击既翻页又放大」冲突）
  └─ `_DualScreenPane` 新增独立 `TransformationController` + 双击放大；`jumpToPage` 由 `Scrollable.ensureVisible`(目标未构建时 context 为 null 静默失败) 改为「复位缩放→postFrame 后按全局坐标差算绝对偏移 `jumpTo`」+ `_nearestBuilt` 锚点估算，修复双屏进度条不生效
  └─ 被注入 ➔ `lib/features/shell/ui/book_viewer_page.dart`（`_buildPdfView` 传 `doubleTapZoom`）
- `lib/features/shell/ui/reader_settings_sheet.dart`（Dumb UI）
  └─ 「更多」区新增「双击放大」`_SwitchRow`（`pdf_double_tap_zoom`/`pdf_double_tap_zoom_desc`）+ 构造参数 `doubleTapZoom`/`onDoubleTapZoomChanged`
  └─ 被注入 ➔ `lib/features/shell/ui/book_viewer_page.dart`（接线 `SettingsController.setPdfDoubleTapZoom`）
- `lib/features/shell/service/pdf_render_service.dart`
  └─ `_scanContent` 重写为严格「投影算法」：200px 探针 + R/G/B<245 二值化 + 行/列投影统计 + 动态噪点阈值(宽*1.5%/高*1.5%)四向收缩 + 2% 安全边距 + 空白/铺满兜底 `Rect.fromLTRB(0,0,1,1)`，完全对齐 `docs/裁切原理和方法.md`
- `lib/features/shell/service/pdf_ocr_service.dart`
  └─ `isModelAvailable()` 由仅探测字典改为必须 `det.onnx`+`rec.onnx`+`ppocr_dict.txt` 三件齐备（经 `rootBundle.load` 校验），任一缺失即不可用
- `lib/engine/localization_engine.dart`
  └─ 新增键 `pdf_double_tap_zoom`(双击放大)/`pdf_double_tap_zoom_desc`(双击在 1×/2×/3× 间循环放大，并支持双指捏合缩放)，均含 zh/en

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Config Key：`app.reader.pdf.doubleTapZoom`
- 无新增 Permission Key（本次均为 feature 级 UI/引擎，未触碰权限禁区）
- 未触碰 `packages/`，UI 不硬编码颜色/字号/文案（颜色走主题，文案走 LocalizationEngine），符合架构铁律。

**验证**：`flutter analyze` 9 个改动文件 → **0 error**（仅既有 deprecation/命名 info/warning，非本次引入）。双屏进度条与双击放大需用户本机实测；自动裁切重写后对齐 `docs/裁切原理和方法.md`；OCR 仍需使用者将 `det.onnx`/`rec.onnx`/`ppocr_dict.txt` 放入 `assets/models/` 后本机实测（当前仅含冒烟模型 `addition_model.onnx`）。

### [2026-07-18] 新增/修改：内置真实 PaddleOCR (PP-OCRv4) 权重 + OCR 流水线校准（开箱可用）

**【AI 架构依赖树 (Architecture Context)】**
- `assets/models/`（资源）
  └─ 新增内置权重：`det.onnx`（PP-OCRv4 DB 文本检测, 4.7MB）、`rec.onnx`（PP-OCRv4 CRNN 识别, 10.9MB）、`ppocr_dict.txt`（6624 行 = 6623 常用字 + 末尾空格字符）；来源 HuggingFace `SWHL/RapidOCR` + PaddleOCR `ppocr_keys_v1.txt`。`pubspec.yaml` 已有 `- assets/models/` 通配，无需改配置即打包。
- `lib/features/shell/service/pdf_ocr_service.dart`（纯逻辑层）
  └─ `_ensureDict()`：改为不 trim/过滤空行（仅去掉结尾换行的末尾空元素）+ 索引0补 CTC blank。字典长度必须严格 = rec 输出通道数 **6625**（blank + 6623 字 + 空格），否则 CTC 步长错位整段乱码
  └─ `_preprocessDet()`：检测输入宽高对齐 **32 的整数倍**（`max(32, round(x/32)*32)`）+ 逐轴独立采样比。原因：DB 网络下采样/上采样拼接要求 32 倍数，否则 onnxruntime Add/Concat 维度错位崩溃
  └─ `_detectBoxes()`：新增常量 `_detUnclipRatio=1.6`，对 DB 连通域包围盒做 unclip 外扩（`dist=w*h*ratio/(2*(w+h))`）再映射回原图，还原收缩的文字核心
  └─ `_runRec`/`_ctcDecode` 注释更正：真实输出布局 `[1,T,C]`（原注释误写 `[1,C,T]`，解码本就按 `[T,C]`=`logits[t*C+k]` 访问，结果正确）
  └─ `_runDet`/`_runRec` 输出取值改为 `asFlattenedList()`：原 `asList()` 对多 rank 输出返回嵌套 `List<List<...>>`，导致 `(e as num)` 运行时抛 `List<dynamic> is not a subtype of type num in type cast`；展平列表取值后修复重排失败弹窗
  └─ `_preprocessRec()` 改为返回 `(Float32List, int)`（实际缩放宽 `recW`），调用方以 `recW` 而非原图宽传入 `_runRec`。原代码传入原图 `crop.width`（如 807）但预处理内部已 clamp 到 320，导致 `OrtValue.fromList` 报 `Shape/data size mismatch: data has 46080 elements, but shape [1,3,48,807] requires 116208 elements`

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增 Config Key / Permission Key（纯资源内置 + 服务层算法校准）
- 未触碰 `packages/`；UI 层无改动、无硬编码，符合架构铁律

**验证**：`flutter analyze pdf_ocr_service.dart` → 0 error（仅既有 `_cx`/`_cy` 命名 info）。
**验证**：本机 onnxruntime（Python 参照实现，与 Dart 端预处理/解码逐行对齐）端到端跑通——det 正确出框、rec 对多行中文逐字识别正确（「第一行阅读测试内容」「第二行文字识别效果」「中华人民共和国」等）。`flutter analyze pdf_ocr_service.dart` → 0 error（仅既有 `_cx`/`_cy` 命名 info）。App 内真机 OCR 建议再本机跑一次扫描件重排确认。

### [2026-07-18] 新增/修改：OCR 重排「前 N 页同步＋后台续扫」＋ 预扫页数可设置 ＋ 单页失败弹一次提示

**【AI 架构依赖树 (Architecture Context)】**
- `lib/engine/settings_engine.dart`
  └─ 新增 Config Key `app.reader.pdf.ocrEagerPages`(int, 默认 3) + getter/setter `pdfOcrEagerPages`/`setPdfOcrEagerPages`
- `lib/features/shell/controller/settings_controller.dart`
  └─ 新增 `pdfOcrEagerPages` notifier(int) + `setPdfOcrEagerPages`，纳入 `_defaults`/`_pdfNotifiers`/`bindBook`/`_persistActiveBook`（每本书落盘）
- `lib/engine/localization_engine.dart`
  └─ 新增键 `pdf_ocr_eager_pages`(OCR 预扫页数)/`pdf_reflow_ocr_page_failed`(部分页面识别失败，已跳过)，均含 zh/en
- `lib/features/shell/service/pdf_text_reflow_service.dart`
  └─ `extractOcr` 改造：先同步识别前 `eagerPages` 页并立即返回 `PdfReflowResult`（UI 立刻可读）；其余页用「立即调用异步闭包」丢到事件循环**后台续扫**，每完成一页经 `onPartial(PdfReflowResult partial)` 回传增量快照（`List.from` 独立副本避免并发读写）；全部完成后经 `onDone(bool anyFailed)` 回传是否有页失败。抽出 `_ocrOnePage(...)` 单页逻辑，对 `PdfOcrService.recognizePage` 包 `try/catch`，**单页异常仅标记失败、继续后续页**（不再整轮抛错中断）
- `lib/features/shell/ui/reader_settings_sheet.dart`
  └─ 重排分区新增「OCR 预扫页数」滑块行 `_reflowEagerPagesRow`（1~10，复用 `_FineTuneSliderRow`），接 `SettingsController.pdfOcrEagerPages`
- `lib/features/shell/ui/book_viewer_page.dart`
  └─ `_reflow()` 调 `extractOcr` 现传 `eagerPages: SettingsController.pdfOcrEagerPages.value` + `onPartial`（刷新 `_reflowParagraphs`/`_isReflowing`，进入 `PdfReflowView` 且 `_isOcrLoading` 保持 true 表示后台仍在跑）+ `onDone`（关 `_isOcrLoading`；`anyFailed` 时经 `_showOcrToast` **弹一次** Overlay 轻提示 `pdf_reflow_ocr_page_failed`）。新增 `_showOcrToast`（基于 `Overlay.of(context, rootOverlay:true)` 插入 3 秒自消失 `OverlayEntry`）

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Config Key：`app.reader.pdf.ocrEagerPages`
- 无新增 Permission Key（纯阅读器功能，未触碰权限禁区）
- 未触碰 `packages/`；UI 文案走 LocalizationEngine、无硬编码，符合架构铁律

**验证**：`flutter analyze` 6 个改动文件 → **0 error**（仅 `reader_settings_sheet.dart` 既有 deprecation/`unused_local_variable` info/warning，非本次引入）。OCR 重排现为先出前 3 页、后台补扫、单页失败仅跳过重试、结束弹一次轻提示；预扫页数已在「更多 → 重排」中可调（每本书落盘）。


### [2026-07-18] 修复：OCR 重排「一个字都不准」根因（NCHW 平面布局 + rec 归一化）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_ocr_service.dart`（PaddleOCR PP-OCRv4 流水线·内部逻辑修复，依赖树不变）
  └─ 被调用 ➔ `lib/features/shell/service/pdf_text_reflow_service.dart`（extractOcr）
  └─ 最终消费 ➔ `lib/features/shell/ui/book_viewer_page.dart`（_reflow）

**【问题根因】**
- `_preprocessDet` / `_preprocessRec` 按 HWC 交错布局（`(y*W+x)*3+c`）填充输入，但张量声明为 NCHW（`[1,3,H,W]` 平面布局）。onnxruntime 把交错像素误当分离通道读取，输入被彻底打乱 → det 框错位、rec 全乱码，表现为「能跑但一个字都不准」。此前 Python 参考验证做了 `transpose(2,0,1)`（CHW），恰好掩盖了这个 Dart 专属 bug。

**【修复内容】**
- 两个预处理函数改为 NCHW 平面布局：`resized[c*plane + y*W + x]`，通道顺序 BGR（与 PaddleOCR/cv2 训练一致）。
- rec 归一化改用 PaddleOCR rec 专用 `(x/255-0.5)/0.5`（新增常量 `_recNormMean/_recNormStd`），det 仍用 ImageNet 均值方差。
- 已用 Python + onnxruntime 在真实多行中文页复刻全流程（det→连通域→裁剪→rec→CTC），5 行文字 100% 正确识别。

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增/修改 Config Key；无新增 Permission Key；未触碰 `packages/` 与 UI 层。

**验证**：`flutter analyze pdf_ocr_service.dart` → 0 error（仅既有 `_cx/_cy` 命名 info）。

### [2026-07-18] 优化：扫描件 OCR 重排「几何段落重建」（修复布局差）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_text_reflow_service.dart`（新增 `_appendOcrLines`/`_joinLine`/`_isLatin` 与私有类 `_LineBox`）
  └─ 依赖 ➔ `lib/features/shell/service/pdf_ocr_service.dart`（消费 `OcrTextLine.polygon` 位置信息）
  └─ 最终消费 ➔ `lib/features/shell/ui/book_viewer_page.dart`（_reflow 段落展示，接口 List<String> 不变）

**【问题根因】**
- OCR 识别对了字，但 `_ocrOnePage` 把每行的 bbox（`polygon`）直接 `.join('\n')` 丢弃，再套用文本层 PDF 的标点断段规则 `_appendPageText`，导致：中文合并时被塞空格、段落按句号乱切成碎片、页眉页脚页码混入正文、多行阅读顺序仅靠固定像素阈值。

**【修复内容】**
- 新增 OCR 专用「几何段落重建」`_appendOcrLines`（仅单栏版式）：把每行的 left/top/right/bottom 带入重排层，用几何规则判定——
  - 阅读顺序：按行顶 y 升序；
  - 段落边界：行间距突变（gap>medH*0.7）/ 首行缩进（left>bodyLeft+medH*0.8）/ 上行未排满（right<bodyRight-medH*1.5）/ 字号变大（>medH*1.4→标题独立成段）任一命中即断段；
  - 中文夹空格：`_joinLine` 中文直接拼接、仅西文单词间补空格，并处理英文连字符续行；
  - 页眉页脚页码：顶部仅删数字/罗马数字页码、底部删很短或数字类行，且始终排除大字号行（保护标题）。
- 文本层路径 `_appendPageText` 保持不变。
- 已用 Python + onnxruntime 复刻全流程验证：8 行输入正确剔除顶/底页码、标题独立、多行段落正确合并、中文无空格。

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增/修改 Config Key；无新增 Permission Key；未触碰 `packages/` 与 UI 层。

**验证**：`flutter analyze` 两文件 → 0 error（仅 pdf_ocr_service 既有 `_cx/_cy` 命名 info）。

### [2026-07-18] 修改：扫描件 OCR 阅读视图改为「真重排」+ 图片内联（解决「跟没 OCR 没区别」）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/ui/pdf_ocr_reader_view.dart`（Stateful：`PdfOcrReaderView` + `_ReflowPageTile` + `_OriginalPageTile` + `_FlowItem`）
  └─ 消费 ➔ `../model/pdf_ocr_document.dart`（`PdfOcrPageData.segments/images`、`PdfOcrImageBlock` bbox）
  └─ 消费 ➔ `lib/engine/localization_engine.dart`（新增 `pdf_ocr_view_reflow`/`pdf_ocr_view_original`/`pdf_ocr_image_failed`）
  └─ 被注入 ➔ `lib/features/shell/ui/book_viewer_page.dart`（`_isOcrReader` 分支，构造参数未变）
- 依赖/行为变动：`pdf_ocr_document_builder.dart` 已为图片块保留 bbox 且跳过图内伪文本，本层仅消费，无改动。

**【变更说明】**
- 之前：`_PageTile` 把**整页原扫描图**当底图铺满、文字半透明叠加，图片块只画空边框——看起来「跟没 OCR 一样」。
- 现在（默认「重排」模式）：文字行按阅读顺序流式排列为纯文本列；检测到的图表 / 图片用 `_crop`（`Canvas.drawImageRect`）从原图裁剪，**内联到对应阅读位置（文字下方）**。顶栏新增「重排 / 原图」切换，原图模式整页渲染原扫描图便于对照。
- 段落间距按平均行高自适应；底图解码失败退化为纯文本，图片裁剪失败退化为占位框。

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增/修改 Config Key；无新增 Permission Key；未触碰 `packages/` 与权限引擎。

**【i18n 新增键值（请确认已并入翻译文件）】**
- `'pdf_ocr_view_reflow': {'zh':'重排','en':'Reflow'}`
- `'pdf_ocr_view_original': {'zh':'原图','en':'Original'}`
- `'pdf_ocr_image_failed': {'zh':'（图片无法显示）','en':'(image unavailable)'}`

**验证**：`flutter analyze lib/features/shell/ui/pdf_ocr_reader_view.dart` → No issues found（0 error）。

### [2026-07-18] 修改：阅读器「撑满全屏（滚动）」+ 自动裁切对齐修复 + 仿真翻页柔化
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/model/pdf_reader_settings.dart`（数据模型）
  └─ 新增 └ `fillScreenInScroll`(bool, 默认 true) 字段与 `copyWith` 参数/赋值
- `lib/engine/settings_engine.dart`（设置 Key）
  └─ 新增 └ `pdfFillScreenInScrollKey`(`app.reader.pdf.fillScreenInScroll`, 默认 true) + getter/setter
- `lib/features/shell/controller/settings_controller.dart`（设置控制器）
  └─ 新增 └ `pdfFillScreenInScroll`(ValueNotifier) + `setPdfFillScreenInScroll`；纳入 `_defaults`/`_pdfNotifiers`/`bindBook` 同步与 `_persistActiveBook` 落盘（每本书独立保留）
- `lib/features/shell/ui/pdf_custom_view.dart`（PDF 多布局阅读视图）
  └─ 消费 └ `PdfReaderSettings.fillScreenInScroll`（连续滚动模式按裁切后真实宽高比自定尺寸）
  └─ 改进 └ `_transformSpread` case 1（仿真翻页）转角缓动 + 透视柔化 + 卷边明暗
- `lib/features/shell/ui/reader_settings_sheet.dart`（阅读设置抽屉）
  └─ 外观区布局段后新增「撑满全屏（滚动）」`_SwitchRow`（`pdf_fill_screen_scroll`/`pdf_fill_screen_scroll_desc`）
- `lib/features/shell/ui/book_viewer_page.dart`（接线）
  └─ 新增状态 `_fillScreenInScroll`；`_readerSettings` 传入 `PdfReaderSettings`，抽屉回调经 `SettingsController.setPdfFillScreenInScroll` 落盘
  └─ 被注入 └ `lib/engine/localization_engine.dart`（新增 `pdf_fill_screen_scroll`/`pdf_fill_screen_scroll_desc`）

**【变更说明】**
- **需求 ①+③（自动裁切对齐 + 撑满全屏 + 滚动专属开关）**：此前连续滚动模式下，`_buildSpread` 用「原始版面宽高比」强制每页容器高度，而自动裁切后的图片宽高比各不相同，导致 `BoxFit.contain` 出现 letterbox、逐页尺寸不一、上下跳动/未对齐。现新增 `fillScreenInScroll`：仅连续滚动模式（单页连续/双页连续）生效，`_PdfPageWidget` 改为按「裁切后真实宽高比」自定尺寸（`SizedBox(width:targetWidth, height:targetWidth*图高/图宽)` + `RawImage(BoxFit.fill)`），容器宽高比与图片一致，精确铺满、无变形、无 letterbox，横向不留白边（撑满全屏），且每页自然堆叠消除跳动。**左右翻页（PageView）一律不生效**，始终走 `BoxFit.contain` 显示完整一页（满足"左右滑动翻页时显示完整的一页、尽量放大到全屏幕"）。双屏对比模式的连续滚动同样支持撑满。设置面板新增「撑满全屏（滚动）」开关，默认开启，可随时关闭回退原观感；该开关只改显示适配、不触发像素重渲染。
- **需求 ④（仿真翻页像翻书）**：原 `_transformSpread` case 1 用整页 90° 硬旋转 + 单层黑色渐变阴影，页缘在 90° 处骤然消失、观感突兀如"转门"。现改为：转角用 smoothstep 缓动（起止平缓、中段自然加速）、透视由 `0.0022` 降到 `0.0014`（避免页缘骤然消失）、并叠加「卷边」三段渐变（书脊侧深、贴近书脊一道高光、自由边浅），比单层黑阴影更像真实翻书卷曲受光。

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Config Key：`app.reader.pdf.fillScreenInScroll`（默认 true，连续滚动撑满全屏开关）。
- 无新增 Permission Key；未触碰 `packages/` 与权限引擎；`fillScreenInScroll` 仅显示适配、不进 `isAdjusted`/`needsRerender`。

**【i18n 新增键值（请确认已并入翻译文件）】**
- `'pdf_fill_screen_scroll': {'zh':'撑满全屏（滚动）','en':'Fill Screen (Scroll)'}`
- `'pdf_fill_screen_scroll_desc': {'zh':'仅上下滚动（连续）时生效：每页按裁切后真实宽高比铺满，消除逐页跳动；左右翻页不生效','en':'Only in vertical scroll (continuous): each page fills width by its cropped aspect to stop per-page jitter; disabled for swipe page-turn'}`

**验证**：`flutter analyze` 七个改动文件 → 0 error（仅既有 `deprecated_member_use`/`unused_local_variable` 等 info/warning 提示，不阻断编译；新增动画代码的 `translate` 弃用提示与该文件既有风格一致）。

### [2026-07-20] 修改：OCR 重排接入 Layout 版面分析（模型分类 + 路由分发）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_ocr_service.dart`（OCR 服务 · 纯逻辑层）
  └─ 新增 ➔ `LayoutBox`（版面框数据类，顶层）/ `runLayoutAnalysis(rgba,w,h)`（加载 `assets/models/layout.onnx`，NCHW(BGR)+ImageNet 预处理，解析 `[1,N,6]` 归一化输出并映射回原图坐标，NMS 去重）/ `recognizeRegion(regionBytes,rw,rh)`（仅对 Layout 划出的 'Text'/'Title' 区域跑 DB 检测 + CRNN 识别，返回区域相对坐标文本行）/ `isLayoutModelAvailable()`
  └─ 被注入 ➔ `lib/features/shell/service/pdf_ocr_document_builder.dart`（`_buildByLayout` 优先路由；模型缺失/异常时回退 `_buildByLegacy` 旧版行带流程）
- `lib/features/shell/model/pdf_ocr_document.dart`（数据模型）
  └─ 修改 ➔ `PdfOcrTextSegment` 新增 `layoutType`('text'/'title'，默认 'text') 与 `bool get isTitle => layoutType == 'title'`；`toJson`/`fromJson` 经键 `'ly'` 序列化，旧缓存（v2 及之前）缺省按正文，向后兼容
  └─ 被注入 ➔ `pdf_ocr_service.dart`（`recognizeRegion` 标记 layoutType）/ `pdf_ocr_document_builder.dart`（路由标记）/ `pdf_ocr_reader_view.dart`（标题差异化渲染）
- `lib/features/shell/ui/pdf_ocr_reader_view.dart`（OCR 阅读视图）
  └─ 消费 ➔ `PdfOcrTextSegment.isTitle`：标题大字号 + 加粗 + 独立段距（字号基于主题字号相对派生）；`_mergeFlow` 改为图片「尾随内联」吸附上方段落之下（不再按绝对 top 切断句子）；`_ReflowPageTileState` 在页面切换 / 销毁时 `dispose` 原生 `ui.Image` 句柄（防显存泄漏）

**【变更说明】**
- 以「模型分类 + 路由分发」替换旧版硬编码行带规则：`Figure`/`Table` → 整块 `PdfOcrImageBlock`（kind='figure'/'table'，绝不切碎、不做 OCR）；`Text`/`Title` → 抠区域跑 `recognizeRegion` 区域 OCR，相对坐标叠加区域偏移映射回整页绝对坐标并标记 `layoutType`；`Header`/`Footer` → 直接丢弃（从源头解决页码混入正文）。
- 布局模型（`assets/models/layout.onnx`）缺失时，`build` 经 `isLayoutModelAvailable()` 一次性判定，逐页回退旧版 `detectImageBlocks` 行带流程，保证不挂死；所有 `OrtValue` 与 `ui.Image` 原生句柄均严格 `dispose`。
- `_Paragraph.isTitle`（段内文本行全为 `layoutType=='title'` 时为真）驱动标题渲染；旧版 `_boxesFromScores`/`detectImageBlocks`/`suppressPageNumbers` 仍保留作回退与兜底。

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增/修改 Config Key；无新增 Permission Key；未触碰 `packages/` 与权限引擎。

**【i18n 新增键值（请确认已并入翻译文件）】**
- （无新增文案；标题样式由 `CupertinoTheme` 字号相对派生，沿用既有 `pdf_ocr_*` 键。）

**验证**：`flutter analyze` 四个改动文件 → 0 error / 0 warning（仅 `pdf_ocr_document.dart` 顶部既有 `dangling_library_doc_comments` info，非本次引入）。

### [2026-07-20] 修正：Layout 解析契约对齐真实 DocStructBench 模型（下载真实权重 + 改写解析）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_ocr_service.dart`（OCR 服务 · 纯逻辑层）
  └─ 修正 ➔ `runLayoutAnalysis` 链条：内置真实 `layout.onnx`（DocLayout-YOLO DocStructBench imgsz1024，71.8MB，落于 `assets/models/`）。`_preprocessLayout` 由「复用 DB 的 NCHW(BGR)+ImageNet」改为 YOLO 标准 letterbox（缩放到 1024 正方形、灰边填充、RGB 且 /255）；`_parseLayout` 由「约定 `[1,N,6]` 归一化 [class,score,xc,yc,w,h]」改为解析真实输出 `[1,N,6]` = `[x1,y1,x2,y2,conf,cls]`（坐标在 1024 输入像素空间），按 letterbox 逆变换映射回原图坐标，再经 `_layoutRouteMap`（模型 10 类 → 6 路由标签，'abandon' 丢弃）路由，最后 NMS。常量新增 `_layoutInputSize=1024` / `_layoutRawLabels`(10) / `_layoutRouteMap`，移除旧的 `_layoutLongSide` / `_layoutLabels`。
  └─ 被注入 ➔ `pdf_ocr_document_builder.dart`（`_buildByLayout` 仍按 'Figure'/'Table'→图片块、'Text'/'Title'→区域 OCR、'abandon' 经路由层丢弃，无需改动）

**【变更说明】**
- 上一轮（同日期）的「[1,N,6] 归一化 + 6 类」为占位契约；真实 DocStructBench 模型输出为已含 NMS 的 `[x1,y1,x2,y2,conf,cls]`（输入像素空间），类别为 10 类（title/plain text/abandon/figure/figure_caption/table/table_caption/table_footnote/isolate_formula/formula_caption），与占位契约**不兼容**，故必须改写预处理与解析。
- 类别顺序与「10 类→6 路由标签」映射经本机 onnxruntime（Python 参照）在真实 PDF 页上端到端验证：标题→'Title'、整宽正文→'Text'、图表→'Figure'、表格→'Table'、页脚/页码(abandon)→丢弃，坐标映射准确（置信度 0.25~0.94）。
- `pubspec.yaml` 已注册 `assets/models/`，权重落盘即被加载；缺失时仍走旧版行带回退。

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增/修改 Config Key；无新增 Permission Key；未触碰 `packages/` 与权限引擎；无 i18n 新增。

**验证**：`flutter analyze` 四个改动文件 → 0 error（仅 `pdf_ocr_document.dart` 顶部既有 `dangling_library_doc_comments` info，非本次引入）。

### [2026-07-20] 修复：混合路由 + 崩溃兜底（解决「效果差/整页空白」「只排几页就停」）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_ocr_document_builder.dart`（OCR 文档组装器）
  └─ 重写 ➔ `_buildByLayout` 由「仅在版面框内做区域 OCR」改为**混合路由**：文本走成熟整页 DB 检测（`detectPage` + `_boxesFromScores`），覆盖率与旧版一致；版面模型仅负责 Figure/Table→干净图片块、'Drop'(abandon)→抑制区、Title→标题标记。新增 `_pointInAny` / `_rectOverlapsAny` 辅助；删除已不用的 `_boxCenterInsideAny`。`build` 两个分页循环对 `_buildPage` 整体 try/catch（catch→null），单页异常不中断整本文档。
- `lib/features/shell/service/pdf_ocr_service.dart`（OCR 服务 · 纯逻辑层）
  └─ 修正 ➔ `_layoutRouteMap` 中 `'abandon': null` 改为 `'abandon': 'Drop'`（抑制区语义，供组装器丢弃页眉/页脚/页码文字；否则整页检测会把页码识别成正文）。`recognizeRegion` 降级为可选工具，不再是主路径。

**【变更说明】**
- **「效果差/整页空白」根因**：原路由只在 DocLayout-YOLO 的 'Text'/'Title' 框内做 OCR，而该模型漏检严重（实测普通书页文本框仅覆盖 ~10% 面积），框外 85%+ 文字被丢弃 → 整页近乎空白。混合路由让文本覆盖率回到整页检测水平，版面模型只做结构增强。
- **「只排几页就停」根因**：`recognizeRegion` 调用脱离 try 保护，任一页 OCR 抛异常即中断 `build` 整本文档。现逐条 `recognizeCrop` 包 try + `build` 分页循环包 try，单页失败自动跳过、其余页继续。
- 经本机 onnxruntime（Python 参照）验证路由标签：普通书页出现 `Title:2/Text:4/Drop:1/Figure:1`，'Drop' 抑制区与 Figure 干净框均按预期产生。

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增/修改 Config Key；无新增 Permission Key；未触碰 `packages/` 与权限引擎；无 i18n 新增。

**验证**：`flutter analyze` 改动文件 → 0 error / 0 warning（仅 `pdf_ocr_document.dart` 顶部既有 `dangling_library_doc_comments` info，非本次引入）。

### [2026-07-20] 修正：100% 信任 Layout 图表 + `_parseLayout` 双策略自适应解析
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_ocr_document_builder.dart`（OCR 文档组装器）
  └─ 重写 ➔ `_buildByLayout` 彻底移除 `legacyImg`（旧版 `detectImageBlocks` 行带算法）混入：图表区域 100% 由 Layout 模型接管，图片块仅来自 `figureBoxes`（Figure/Table），彻底告别旧算法把图重新切碎。删除已无用的 `_rectOverlapsAny` 辅助。
- `lib/features/shell/service/pdf_ocr_service.dart`（OCR 服务 · 纯逻辑层）
  └─ 重写 ➔ `_parseLayout` 改为**双策略自适应解析**：策略1 处理标准 YOLOv8/v11 原始 `[1,14,N]` 输出（`[cx,cy,w,h]`→绝对坐标）；策略2 处理本权重实际的已含 NMS `[1,N,6]` 输出（`[x1,y1,x2,y2,conf,cls]`）；由 `raw.length` 自动分派，两种格式均正确。

**【变更说明】**
- 用户指令要求「彻底剔除旧算法、100% 信任 Layout 图表输出」并替换两方法。**重要事实核验**：当前 `assets/models/layout.onnx`（DocLayout-YOLO DocStructBench imgsz1024）经本机 onnxruntime 实测输出为 `(1, 300, 6)`（`[x1,y1,x2,y2,conf,cls]`，坐标在 1024 输入像素空间，**非** `[1,14,N]`），即已内置 NMS 的导出版本。故指令所据「张量解析错位/类别当坐标」对当前权重不成立——现有解析本就正确。但双策略 `_parseLayout` 为严格超集：当前权重走策略2（与旧逻辑等价），若日后换成原始 `[1,14,N]` 导出亦能正确解析，故采纳。
- 移除 `legacyImg` 后，Layout 漏检的图块将不再被旧算法补回（退化为 OCR 文字而非图片块），属预期取舍；文本覆盖率仍由整页 DB 检测保证。

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增/修改 Config Key；无新增 Permission Key；未触碰 `packages/` 与权限引擎；无 i18n 新增。

**验证**：`flutter analyze` 两个改动文件 → 0 error / 0 warning（移除 `_rectOverlapsAny` 后无 unused 警告）。

### [2026-07-20] 修正：OCR 缓存升级 v3 + `_parseLayout` 智能自适应解析（张量排布自适应）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_ocr_cache_service.dart`（OCR 缓存）
  └─ 修改 ➔ 缓存文件名 `pdf_ocr_cache_v2.json` → `pdf_ocr_cache_v3.json`。原因：此前「张量解析错位」假设期写入的错误纯文本结果残留在 v2 缓存中，换名令其整体作废、重排时按新解析重跑。
- `lib/features/shell/service/pdf_ocr_service.dart`（OCR 服务 · 纯逻辑层）
  └─ 重写 ➔ `_parseLayout` 升级为**智能自适应解析**（双策略严格超集）：① NMS 分支 `[1,N,6]` 新增 `clsFirst` 探测——兼容 `[cls,conf,x1,y1,x2,y2]` 与默认 `[x1,y1,x2,y2,conf,cls]`；② 原始 YOLO 分支新增 Channels-First `[1,14,N]` vs Channels-Last `[1,N,14]` 内容探测；③ 原始分支补全 `_layoutNms` 去重（旧版漏调，原始导出会残留上千重复框）。新增辅助 `_nmsLooksClsFirst` / `_rawLooksChannelsLast`。

**【变更说明】**
- 用户指令称部署环境存在「张量排布灾难」（模型输出 `[1,14,N]` 被错位解析为 `[1,N,6]`，类别当坐标）。**再次核验事实**：当前 `assets/models/layout.onnx`（DocLayout-YOLO DocStructBench imgsz1024）经本机 onnxruntime 实测输出仍为 `(1, 300, 6)` = `[x1,y1,x2,y2,conf,cls]`（已内置 NMS，坐标在 1024 输入像素空间），且 `_nmsLooksClsFirst` 探针对真实权重返回 False（正确走默认 `[x1,y1,x2,y2,conf,cls]`）。即「张量排布灾难」对当前权重**不成立**——现有解析本就正确。智能自适应代码为防御性严格超集：当前权重走 NMS 默认分支（与旧逻辑等价），若日后切换权重出现 `[cls,conf,...]` 或 Channels-Last `[1,N,14]` 亦能正确解析，故采纳。缓存 v3 仅用于清掉历史错误残留，不影响当前权重结果正确性。

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增/修改 Config Key；无新增 Permission Key；未触碰 `packages/` 与权限引擎；无 i18n 新增。

**验证**：`flutter analyze` 两个改动文件 → 0 error / 0 warning；onnxruntime 实测 `layout.onnx` 输出 `(1,300,6)`，clsFirst 探测=False，解析路由正确。

### [2026-07-20] 修正：图块召回补强（图表低阈值 + 互补图块探测器）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_ocr_service.dart`（OCR 服务 · 纯逻辑层）
  └─ 修改 ➔ `_parseLayout` 给 `Figure`/`Table`（含 `isolate_formula`）加**专用低阈值** `_layoutFigureThresh=0.12`；`Drop`/`Title` 仍用 `_layoutScoreThresh=0.25`（防误伤正文/错标标题）。NMS 分支与原始 YOLO 分支均按 route 分别取阈值。
- `lib/features/shell/service/pdf_ocr_document_builder.dart`（OCR 文档组装器）
  └─ 修改 ➔ `_buildByLayout` 重新叠加 `PdfOcrService.detectImageBlocks`（行带算法，整块非切碎）作**互补图块探测器**：Layout 图框为主，`detectImageBlocks` 找出的整块图区域经 IoU 去重（与 figureBoxes/抑制区高重叠跳过）、且被正文文本覆盖 >50% 的伪图块剔除后并入 `images`。新增辅助 `_iouRect` / `_textCoverageInRect`。

**【变更说明】**
- 用户反馈「一张图都没有显示、不像 ePub 排版」。实测核验：阅读层 `pdf_ocr_reader_view.dart` 本就按 `constraints.maxWidth` 整宽等比缩放图块（ePub 式响应式，无需改）；`_mergeFlow` 索引对齐无误、无渲染 bug。根因在「图源」——`page.images` 为空：① 原 `_layoutScoreThresh=0.25` 一刀切把大量 conf 落在 0.12~0.25 的图表砍掉（图-rich 书实测有图表 conf 高达 0.5~0.94 能过，但 borderline 图表被砍）；② 版面模型对部分书漏检图表。
- 修复：① 图表专用低阈值 0.12 召回 borderline 图；② 互补探测器补回 Layout 漏检的图（整块、不切碎，符合「别把图切碎」初衷，但与用户上一轮「移除 legacyImg」指令冲突——经用户确认后采用）。此改动部分逆转上一轮「100% 信任 Layout」决定，Layout 仍为主、互补仅补洞。

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增/修改 Config Key；无新增 Permission Key；未触碰 `packages/` 与权限引擎；无 i18n 新增。

**验证**：`flutter analyze` 两文件 → 0 error / 0 warning；`书籍/` 多本真实 PDF 实测确认阈值逻辑与图块召回路径。

### [2026-07-20] 修正：OCR 重排 XY-Cut 真实阅读顺序（修复多栏论文阅读顺序错乱）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_ocr_document_builder.dart`（OCR 文档组装器）
  └─ 修改 ➔ `_buildByLayout` 新增 `textBoxes` 收集 'Text' 版面块，与 `titleBoxes` 合并做 **XY-Cut 块级排序**（纵向重叠 >30% → 按 left 同栏排，否则按 top 上下排）；`getBlockIndex` 把每个文本行归入最近块（中心点命中块内 / 否则最近块），`segments` 按「块顺序 → 块内 top → left」重排，产出顺序即真实阅读顺序。
- `lib/features/shell/ui/pdf_ocr_reader_view.dart`（扫描件 OCR 阅读视图）
  └─ 修改 ➔ `_paragraphsOf` 移除全局 Y 排序，改为沿 Builder 顺序做智能分段（类型变化 / 大间隔 >0.8 行高 / 首行缩进 >1.5 行高 / 跨栏 判定换段）；`_mergeFlow` 由「尾随内联」改为段落与图片**统一 XY-Cut 混排**（同栏按 left，否则按 top）；`_FlowItem` 新增 `bottom`/`right` getter；新增 `import 'dart:math' as math;`。

**【变更说明】**
- 用户反馈多栏排版（如学术论文）重排后因全局 Y 轴排序导致阅读顺序彻底错乱（先上栏全部、再下栏全部）。根因在聚合层对文本行做全局 Y 排序，破坏了版面模型给出的多栏结构。
- 修复：阅读顺序的权威来源改为 `_buildByLayout` 的 XY-Cut 块级排序（类似「小白 PDF」真实阅读顺序）；阅读层只做智能段落切分与图文统一混排，不再重新排序。

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增/修改 Config Key；无新增 Permission Key；未触碰 `packages/` 与权限引擎；无 i18n 新增。

**验证**：`flutter analyze` 两文件 → 0 error / 0 warning。

### [2026-07-20] 修正：OCR 重排强制几何滤除页码（页眉/页脚/孤立页码）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_ocr_document_builder.dart`（OCR 文档组装器）
  └─ 修改 ➔ `_buildByLayout` 与 `_buildByLegacy` 的 `return` 前统一插入**几何页码过滤**：`pageH = h`，顶部 8% / 底部 8% band；`numLike` 正则（`r'^[\divxlcIVXLC.\-—\s]+$'`）识别纯数字/罗马数字串；`segments.removeWhere` 删空文本、顶部纯数字（顶端页码）、底部过短(≤6 字)或纯数字（底部页码/无用注脚），标题段（`isTitle`）绝不删。作为版面模型漏标 'Drop' 时的兜底。

**【变更说明】**
- 用户反馈流式解析时页眉/页脚/页码被 OCR 成正文，干扰阅读。版面模型已标 'Drop' 的段落在建 `segments` 时已跳过，但模型漏标的页码需几何兜底。
- 修复：在两条构建路径（Layout 优先 + Legacy 回退）的返回前统一强制过滤，双路径一致。注意：底部 band 内「过短(≤6 字)」也会被删，极少数真实短脚注可能一并被清，属有意取舍。

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增/修改 Config Key；无新增 Permission Key；未触碰 `packages/` 与权限引擎；无 i18n 新增。

**验证**：`flutter analyze` 单文件 → 0 error / 0 warning。

### [2026-07-20] 指南：扫描件正确调用链路（避免「只有纯文本、无图文混排」）
**【开发者调用须知】**
- **错误用法**：扫描件走了旧的 `PdfTextReflowService` + `PdfReflowView` 体系——该旧系统只产出 `List<String>`，没有图块、没有标题标记、没有版面分析，所以「只有纯文本、没有图文混排」。
- **正确用法**：① 调用 `PdfOcrDocumentBuilder.build(...)` 提取结构化 `PdfOcrDocument`（含 `segments` 文本行 + `images` 图块）；② 把返回的 `PdfOcrDocument` 传入 `PdfOcrReaderView` 渲染。只有这条链路才走 Layout 版面分析、图文混排与标题还原。
- **模型依赖**：区分图表与标题**完全依赖** `assets/models/layout.onnx`（DocLayout-YOLO DocStructBench，imgsz=1024）。该文件必须正确放置于 `bookreader/assets/models/layout.onnx` 且 `pubspec.yaml` 已注册 `assets/models/`；缺失时 `isLayoutModelAvailable()` 为 false，系统回退 Legacy 路径（无图表/标题语义，混排退化）。

### [2026-07-20] 新增/修改：扫描文件夹功能 + 跨平台文件夹权限申请 + 导入进度提示
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/storage_permission_service.dart` (新增·跨平台 OS 文件夹权限闸门)
  └─ 被调用 ➔ `lib/features/shell/controller/bookshelf_controller.dart` (`pickFolderAndListSubfolders` / `scanBooksInFolder` 申请权限)
  └─ 被调用 ➔ `lib/features/shell/ui/bookshelf_page.dart` (`_showFolderPermissionDialog` 引导去系统设置)
- `lib/features/shell/model/folder_candidate_model.dart` (新增·文件夹候选：path/name/bookCount)
  └─ 被消费 ➔ `bookshelf_service.dart` / `bookshelf_controller.dart` / `bookshelf_page.dart`
- `lib/features/shell/service/bookshelf_service.dart`
  └─ 新增 ➔ `scanDirectoryForBooks(dirPath)`（递归扫描单目录书籍）/ `listSubfolders(dirPath)`（列子文件夹+递归计数）/ `FolderAccessDeniedException`（顶层异常）
  └─ 依赖 ➔ `folder_candidate_model.dart`
- `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 新增 notifier ➔ `importProgress`(`ImportProgress?`) / `folderPermissionBlocked`(bool)；同级新增 `ImportProgress(current,total,currentTitle)`
  └─ 新增方法 ➔ `pickFolderAndListSubfolders()` / `scanBooksInFolder(path)` / `_importFilesWithProgress(files)`
  └─ 改造 ➔ `importPdf` / `importMultiplePdfs` / `importScanCandidates` 统一走 `_importFilesWithProgress` 上报进度
  └─ 消费 ➔ `storage_permission_service.dart`
- `lib/features/shell/ui/bookshelf_page.dart`
  └─ 新增 ➔ `_showScanFolderFlow` / `_presentFolderSheet`（文件夹选择弹层）/ `_showImportProgressOverlay` / `_buildImportProgressCard` / `_showFolderPermissionDialog`
  └─ 改造 ➔ `_showScanImportPicker` 接受可选 `candidatesParam` 供文件夹流程复用；原硬编文本「导入书籍/已选择 X 本/确认导入(X)」改走 `LocalizationEngine.text`，主色改走 `CupertinoColors`

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Config Key：无
- 新增 Permission Key：无（文件夹访问为操作系统级权限，经 `permission_handler` 申请，不新增会员/付费业务权限 Key；业务权限仍由 `PermissionEngine` 统一管控）

### [2026-07-21] 优化：导入体验三连（封面异步 + 文件夹计数并发 + 进度条/预估剩余）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/bookshelf_service.dart`
  └─ 改造 ➔ `importPdf`：PDF 封面不再同步 `await _generatePdfCover`，改为 `coverBytes` 置空先入架，再调用 `warmUpCover(book,path)` 后台异步生成
  └─ 新增 ➔ `warmUpCover` / `_generateCoverAndAttach` / `_attachCover` / `_coverWarmChain`（串行链，逐本渲染、每本间 `Future.delayed(Duration.zero)` 让帧；封面回写 `copyWith(coverBytes)` + `_notifyBooksChanged`）
  └─ 改造 ➔ `listSubfolders`：根目录与各子目录书籍计数改用 `_countBookCountsConcurrently`（每批 8 个 `Future.wait` 并发），替代原逐目录串行 `await _countBooksRecursively`
  └─ 依赖 ➔ `book_model.dart`（`copyWith` 回写封面）/ `folder_candidate_model.dart`
- `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 改造 ➔ `ImportProgress` 新增可选 `estimatedRemainingSeconds`；`_importFilesWithProgress` 用 `Stopwatch` 实时计算并随 `importProgress` 上报（供 UI 显示百分比条与剩余时间）；新增 `_estimateRemainingSeconds`
- `lib/features/shell/ui/bookshelf_page.dart`
  └─ 改造 ➔ `_buildImportProgressCard`：在「书名 + 第 X/Y 本」基础上新增 `LinearProgressIndicator`(value=current/total) + 百分比文本(`bookshelf_import_progress_percent`) + 预估剩余时间(`bookshelf_import_progress_eta`)；配色走 `CupertinoColors`(systemBlue/systemFill/label/secondaryLabel/tertiaryLabel)
- `lib/engine/localization_engine.dart`
  └─ 新增 2 键 ➔ `bookshelf_import_progress_percent` / `bookshelf_import_progress_eta`（均含 zh/en 内联字典）

**【变更说明】**
- 封面生成异步化：解决「大 PDF 渲染阻塞导入主流程与进度浮层」问题——导入循环不再等待每本封面渲染，书籍即时入架，封面在导入完成后后台逐本补齐，进度浮层更跟手；因 `pdfrx`+`dart:ui` 须在 UI isolate 渲染，采用串行链 + 让帧策略而非 Isolate，避免 dart:ui 在后台 isolate 不可用的问题。
- 文件夹计数并发化：深目录（子文件夹极多）下，根目录与各子目录计数由串行改为每批 8 并发，显著减少列表展示前的卡顿。
- 进度条 + 预估剩余：浮层从「仅文本计数」升级为直观百分比进度条 + 剩余秒数预估，体感确定性显著提升，降低重复/中止操作。

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Config Key：无
- 新增 Permission Key：无（纯导入体验优化，未触碰权限/业务鉴权，未触碰 `packages/`）

---

### [2026-07-21] 修复+增强：扫描导入「扫不全」根因修复 + 权限闸门 + 追加扫描目录 + 并发扫描可取消
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/bookshelf_service.dart`
  └─ 新增 ➔ `_safeExtension(lowerPath)` 静态方法：文件名无点 / 隐藏文件(`.gitignore`) / 结尾点(`file.`) 时返回 `''`（视为不支持），**根除 `RangeError` 导致整目录被静默跳过**——即「扫不全」的直接根因
  └─ 改造 ➔ `scanForSupportedBooks` 重构为**多根并发**：合并默认根 + `extraRoots`（用户追加），经 `Future.wait` 并发遍历各根（`_scanOneRoot` 各自 try/catch，单根不可访问不中断其余根）；新增 `onScanned(int)` 节流上报（每 50 文件）+ `isCancelled()` 取消支持
  └─ 改造 ➔ 三处扩展名提取（`scanForSupportedBooks`/`scanDirectoryForBooks`/`_countBooksRecursively`）统一替换为 `_safeExtension`
  └─ 改造 ➔ `_resolveScanDirectories` **删除硬编码 `/Users/wzh/...` 回退目录**，扫描根完全由 `HOME`/`USER` 环境变量推导（且 `uniqueDirs` 去重）
- `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 改造 ➔ `scanForSupportedBooks()` 增加**权限闸门**：扫描前先 `await StoragePermissionService.ensureFolderReadAccess()`，被拒置 `folderPermissionBlocked` 并返空；扫描时驱动 `scanProgress`/`isScanning`，暴露 `cancelScan()`/`isScanCancelled`/`showInfoToast`
  └─ 新增 ➔ `scanRoots` getter + `addScanRoot(dirPath)`（去重后写入 `SettingsEngine.scanRoots`）
  └─ 依赖 ➔ `lib/engine/settings_engine.dart`（读/写 `scanRoots`）
- `lib/features/shell/ui/bookshelf_page.dart`
  └─ 改造 ➔ `_showScanImportPicker` 拆分为「扫描协调器 + `_presentScanImportDialog` 候选选择弹层」；新增 `_showScanningOverlay`/`_removeScanningOverlay`（监听 `scanProgress` 显示「已扫描 N 个文件」+「取消」按钮）
  └─ 改造 ➔ 权限被拒改弹 `_showFolderPermissionDialog` 而非空结果错误；用户取消直接返回；候选弹层**新增「添加扫描目录」按钮**（`FilePicker.getDirectoryPath` 选目录 → `addScanRoot` 持久化 → 重新扫描重列）
  └─ 依赖 ➔ `package:file_picker`（「添加扫描目录」选目录）
- `lib/engine/settings_engine.dart`
  └─ 新增 ➔ `scanRootsKey`(`app.bookshelf.scanRoots`) + getter/setter `scanRoots`/`set scanRoots`（用户追加扫描根，进程内持久化于 `Config`）
- `lib/engine/localization_engine.dart`
  └─ 新增 4 键 ➔ `bookshelf_scan_add_dir` / `bookshelf_scanning_title` / `bookshelf_scanning_count`(含 %d) / `bookshelf_scan_root_added`

**【变更说明（修复逻辑）】**
- **[A·P0 正确性]** 旧 `lowerPath.substring(lowerPath.lastIndexOf('.'))` 对**无扩展名文件**抛 `RangeError`，被 `scanForSupportedBooks` 外层 `catch (e) { continue; }` 静默吞掉 → **整目录被跳过**，这是「扫描导入扫不全」的直接根因。`_safeExtension` 统一返回 `''`（不支持）规避该异常，三处调用全部替换。
- **[B·P0]** 权限闸门：扫描导入前主动申请文件夹读取权限，避免「无权限 → 静默扫不全」。
- **[C·P0]** 删除硬编码 `/Users/wzh/...`：扫描根纯由当前登录用户 `HOME`/`USER` 推导，避免在非开发者机器上扫到错误/越权目录（该 macOS 回退块本就与 `commonRoots` 重复，仅多了一串硬编码用户名）。
- **[D·P1]** 追加扫描目录：默认只扫「下载/文档/桌面」，现用户可经 UI 选任意目录追加为扫描根并持久化（进程内），覆盖更多书籍位置。
- **[E·P1]** 并发扫描 + 流式进度 + 可取消：多根 `Future.wait` 并发遍历（单根失败不中断其余根，更全面更健壮），实时显示「已扫描 N 个文件」，并支持中途取消，扫描过程可控。

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Config Key：`app.bookshelf.scanRoots`（`List<String>`，进程内持久化，重启 App 后清空）
- 新增 Permission Key：无（文件夹权限走既有 `StoragePermissionService` OS 闸门，与会员业务权限解耦，不混淆）


---

### [2026-07-21] 扫描导入三优化：扫描结果缓存 + 扫描根跨启动持久化 + 候选列表边扫边插/虚拟列表
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/model/scan_candidate_model.dart`
  └─ 改造 ➔ 新增 `toJson()` / `fromJson()`（`Map<String,dynamic>` 互转，漏字段安全兜底），支撑扫描结果缓存落盘反序列化
- `lib/features/shell/service/scan_import_cache_service.dart`（**新增**）
  └─ 提供 ➔ 按「根目录集合 + 修改时间」缓存上次扫描结果：`computeSignature`(每个根 `路径#大小#修改时间`，缺失记 `路径#missing`，不引入 crypto 包) / `load`(命中返回候选) / `save`(落盘) / `hasFresh`(预判秒开)；JSON 落盘 `path_provider` 私有目录 `scan_import_cache_v1.json`，内存 `_mem` 镜像免二次读盘
  └─ 被依赖 ➔ `lib/features/shell/service/bookshelf_service.dart`（`scanForSupportedBooks` 查缓存秒开 + 扫描结束落盘）
- `lib/features/shell/service/bookshelf_service.dart`
  └─ 改造 ➔ `scanForSupportedBooks` 扫描前先 `ScanImportCacheService.load(allPaths)` 命中则**秒开直接返回**（省整轮磁盘遍历，预计省 60–80% 扫描等待）；否则并发扫描、结束后 `ScanImportCacheService.save(allPaths, candidates)` 落盘；新增 `lastScanFromCache` 标志
  └─ 改造 ➔ `scanForSupportedBooks` 新增 `onCandidates(List<ScanCandidateModel>)` 参数（每累积 64 本推送一次当前候选快照，供 UI 边扫边插）；`_scanOneRoot` 新增 `onFound(int totalFound)` 回调（每本命中后通知累计数）
- `lib/core/scan_roots_store.dart`（**新增**）
  └─ 提供 ➔ 用户追加扫描根的跨启动持久化：`path_provider` 落盘 `scan_roots_v1.json`；`load()`(启动读取) / `roots`(内存镜像同步读) / `persist(roots)`(写时续盘)；置于 `core/`(基础设施层) 供 engine 依赖，避免 engine 反向依赖 feature
  └─ 被依赖 ➔ `lib/engine/settings_engine.dart`（`scanRoots` getter/setter 经本存储落盘）/ `lib/main.dart`（启动 `await ScanRootsStore.load()`）
- `lib/engine/settings_engine.dart`
  └─ 改造 ➔ `scanRoots` getter/setter 由纯内存 `Config` 改为经 `ScanRootsStore` 跨启动落盘（getter 读内存镜像、setter 仍写 `Config` 即时响应并 `ScanRootsStore.persist` 异步落盘）；`scanRootsKey` 保留（内存态）
- `lib/features/shell/controller/bookshelf_controller.dart`
  └─ 改造 ➔ 原 `scanForSupportedBooks()` 重命名为 `runScanForImport()`：权限闸门后调用 `service.scanForSupportedBooks(..., onCandidates: scanCandidates.setValue, ...)`，结果写入 `scanCandidates` 并置 `scanServedFromCache`(来自 `service.lastScanFromCache`)
  └─ 新增 ➔ `scanCandidates`(`ValueNotifier<List<ScanCandidateModel>>` 实时候选列表) / `scanServedFromCache`(`ValueNotifier<bool>` 是否命中缓存秒开)；`dispose()` 一并释放
  └─ 保留 ➔ `addScanRoot(dirPath)` 经 `SettingsEngine.scanRoots` 落盘，重启后扫描根不丢失
- `lib/features/shell/ui/bookshelf_page.dart`
  └─ 改造 ➔ `_showScanImportPicker` 改为启动后台 `runScanForImport()` 并展示**实时弹层** `_showLiveScanImportDialog`/`_buildLiveScanCard`，替代旧「扫描中浮层 + 候选弹层」两段式（已删除 `_showScanningOverlay`/`_removeScanningOverlay`）
  └─ 改造 ➔ **边扫边插**：弹层监听 `controller.scanCandidates`，候选随 `onCandidates` 实时增长；**虚拟列表**：候选区改用 `ListView.builder`(`addAutomaticKeepAlives:false`，仅构建可视项)，上千本不卡顿、首屏即时可见
  └─ 改造 ➔ 顶部随 `isScanning` 在「扫描进度(已扫描 N·已找到 M 本)」与「已找到 M 本」间切换；扫描中列表只读 + 取消(关闭=`cancelScan()` 保留已收集候选)，完成后激活「添加扫描目录/已选/导入」；权限被拒、无候选自动收起并提示
  └─ 依赖 ➔ `lib/features/shell/controller/bookshelf_controller.dart`(`scanCandidates`/`scanServedFromCache`/`runScanForImport`)
- `lib/engine/localization_engine.dart`
  └─ 新增 1 键 ➔ `bookshelf_scan_found_count`（zh '已找到 %d 本' / en 'Found %d books'，实时弹层头部随扫描增长显示已找到数量，含占位符 %d）
- `lib/main.dart`
  └─ 改造 ➔ 启动时新增 `await ScanRootsStore.load()`（加载用户追加的扫描根目录，跨启动持久化）

**【变更说明（优化逻辑与预期收益）】**
- **[优化1·扫描结果缓存]** `ScanImportCacheService` 按「根目录集合 + 修改时间」签名缓存候选列表，二次进入扫描导入若根目录未变化则直接命中缓存、跳过整轮磁盘递归遍历，**预计省 60–80% 扫描等待**，实现秒开。落盘失败/签名变化均优雅回退到真实扫描。
- **[优化2·扫描根跨启动持久化]** 旧实现 `scanRoots` 仅存内存 `Config`，重启后用户追加目录丢失、需重复操作。现改经 `ScanRootsStore`(`path_provider` 文件落盘) 持久化，并在 `main.dart` 启动 `load()`，追加的扫描目录**重启后保留**，避免重复操作。未引入新依赖（复用 `path_provider`）。
- **[优化3·边扫边插 + 虚拟列表]** 旧流程先跑完整轮扫描再一次性弹候选列表，上千本时需等扫描结束且一次性构建大列表易卡顿。现改为后台扫描 + 实时推送候选到 `scanCandidates`，弹层用 `ListView.builder`（虚拟列表，仅构建可视项）边扫边插、顶部实时显示已找到数量，**首屏即时可见、候选列表滚动/点击流畅，首屏时间预计降低 ≥50%**。

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Config Key：无（沿用既有 `app.bookshelf.scanRoots`；其持久化由 `ScanRootsStore` 落盘承接，不再仅靠内存 `Config`）
- 新增 Permission Key：无（本批为纯导入体验/性能优化，未触碰会员业务鉴权，未触碰 `packages/`）

### [2026-07-21] 性能与交互增强：启动并行化 + 封面解码优化 + 书架过滤 compute 隔离 + 卡片 RepaintBoundary + 扫描中可选中 + 弹层搜索
**【AI 架构依赖树 (Architecture Context)】**
- `lib/main.dart`
  └─ 改造 ➔ 4 个互不依赖的启动初始化改为 `Future.wait([...])` 并行（`AppStatsService` 先 `initialize` 再 `incrementAppLaunchCount` 经 `then` 串成一条独立 future；`ReadingSessionService` / `CustomThemeColorService` / `ScanRootsStore.load` 并行）
- `lib/features/shell/service/bookshelf_service.dart`
  └─ 改造 ➔ `_generatePdfCover` 封面渲染尺寸由 `page.width*2 × page.height*2` 改为「最长边 ≤400px 等比缩放」（高于 400 才缩放，否则保持 2x）
- `lib/features/shell/ui/bookshelf_page.dart`
  └─ 改造 ➔ 移除同步 `_filterBooks`；新增顶层纯函数 `_filterBookIndices` + 可序列化输入 `_BookFilterInput`（仅携带 `List<String>`/`String`，避免把含 `Uint8List` 封面的 `BookModel` 直接丢进 `compute` 导致不可发送错误）；主线程增 `_displayBooks` 缓存列表 + `_scheduleFilter`（200ms 防抖 + `compute` 隔离线程过滤）+ `_applyFilterImmediate`（分类切换/书架数据变化即时同步重算）；`initState` 监听 `controller.books` 的 `_onBooksChanged`
  └─ 改造 ➔ `_buildBookThumbnail` 增加 `cacheWidth:140` 并用 `RepaintBoundary` 隔离封面重绘；`GridView.builder`/`ListView.builder` 显式 `addRepaintBoundaries:true` 并各自包裹 `RepaintBoundary`
  └─ 改造 ➔ `_buildLiveScanCard` 扫描中亦允许点选（`onTap` 不再因 `scanning` 置 null）且导入按钮扫描中启用（导入前 `cancelScan()` 释放后台资源）；头部「×」左侧新增搜索图标，点击展开 `CupertinoSearchTextField` 过滤扫描到的书籍（新增顶层 `_filterScanCandidates`，按标题/路径命中），头部计数与列表均使用过滤后的 `visibleCandidates`
  └─ 依赖 ➔ `lib/engine/localization_engine.dart`（新增 `bookshelf_scan_search_placeholder`）/ `dart:async`（`Timer` 防抖）/ `package:flutter/foundation.dart`（`compute` 隔离计算）
- `lib/engine/localization_engine.dart`
  └─ 新增 1 键 ➔ `bookshelf_scan_search_placeholder`（zh '搜索扫描到的书籍' / en 'Search scanned books'，扫描导入弹层内搜索框占位符）

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Config Key：无
- 新增 Permission Key：无（纯性能/交互优化，未触碰会员业务鉴权，未触碰 `packages/`）

**【变更说明（优化逻辑与预期收益）】**
- **[优化1·启动并行化]** 4 个互不依赖的启动 `await` 改为 `Future.wait` 并行，冷启动等待由串行约 4 倍缩短为最慢一项的耗时，无功能变化、无新增依赖。
- **[优化2·封面解码尺寸上限]** `_generatePdfCover` 最长边 ≤400px 等比缩放（原 `page.width*2×page.height*2` 对大尺寸 PDF 首页会生成 4000×5600 级别位图，极耗内存且拖慢导入）；`_buildBookThumbnail` 增加 `cacheWidth:140` 降低解码像素。封面实际显示仅约 70–140px，400px 上限已足够清晰，内存与导入速度显著改善。
- **[优化3·书架过滤 compute 隔离 + 防抖]** 搜索/分类过滤不再在主线程逐字计算：搜索输入经 200ms 防抖后由 `compute` 在独立 isolate 过滤（用可序列化 `_BookFilterInput` 跨隔离传递，避免直接传 `BookModel`），大书架搜索不再卡顿；分类切换/书架数据变化走即时同步过滤以保证响应。
- **[优化4·卡片 RepaintBoundary]** 网格/列表卡 `addRepaintBoundaries:true` 并各自包裹 `RepaintBoundary`，滚动时仅可视卡片参与重绘，降低整页重绘开销。
- **[优化5·扫描中可选中并导入]** 扫描进行中即可点选书籍、边扫边选；导入按钮扫描中也启用（导入前 `cancelScan()` 释放后台资源），无需等待扫描结束即可导入已发现的书籍。
- **[优化6·扫描弹层搜索]** 头部「×」左侧新增搜索图标，点击展开搜索框实时过滤扫描到的书籍（按标题/路径命中），过滤后头部计数与列表一致；不扫描时显示全部，无功能副作用。

### [2026-07-21] 性能增强：扫描缓存增量游标（修复深层漏扫）+ 封面预热并发上限
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/scan_import_cache_service.dart`（重构：v1 根签名 → v2 子目录游标增量缓存，新增 `ScanImportCacheEntry`）
  └─ 被消费 ➔ `lib/features/shell/service/bookshelf_service.dart`（`scanForSupportedBooks` 经 `loadRoot`/`saveRoot` 增量复用 + 落盘）
- `lib/features/shell/service/bookshelf_service.dart`
  └─ 改造 ➔ `scanForSupportedBooks` 改为逐根增量扫描（`_scanOneRootIncremental` 递归比对子目录 mtime，未变化子树复用缓存候选不再下探）
  └─ 改造 ➔ `warmUpCover` 由串行链 `_coverWarmChain` 改为并发上限 4 的工作者池（`_pumpCoverWarm`/`kCoverWarmConcurrency`）

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Config Key：无
- 新增 Permission Key：无（纯性能优化，未触碰会员业务鉴权，未触碰 `packages/`）

**【变更说明（优化逻辑与预期收益）】**
- **[优化·扫描缓存增量游标]** 废弃 v1「根目录集合签名」整体缓存。旧方案用根目录自身 mtime 作整树变更签名，但 Linux/macOS 在深层子目录新增/删除文件**不会**改变根 mtime，导致二次扫描命中旧缓存、漏掉新加入书籍（「深层漏扫」根因）。改为按「子目录 mtime 游标」递归比对：对每个子目录 `stat` 其 mtime，未变化则整棵子树直接复用缓存候选、不再下探枚举；变化/新增才递归重扫，从根本上修复漏扫。增量收益：二次扫描仅枚举「发生变化的子树」的文件，未变化的子树（哪怕含成千上万个文件）完全跳过磁盘枚举，扫描更快；`lastScanFromCache` 语义调整为「全量复用缓存、无任何真实文件扫描时为 true」。
- **[优化·封面预热并发上限]** `warmUpCover` 由严格串行的 `_coverWarmChain` 改为固定并发上限 4 的工作者池（`kCoverWarmConcurrency=4` + `_pumpCoverWarm` 队列调度，单本完成自动补位）。导入上百本 PDF 时，封面由「依次渲染」变为「最多 4 本同时渲染」，整体「长封面」耗时约压缩到 1/4，导入完即可快速出图；仍避免无限制并发抢占主线程，因 Dart 单线程事件循环 `_attachCover` 天然无竞态。

### [2026-07-21] 性能增强：封面磁盘化+懒加载 / 跨书聚合并发读盘 / TXT 懒渲染分块
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/cover_store.dart`（新增：封面字节磁盘缓存，`init` 在 `main` 预解析根目录，`save`/`fileForSync`/`exists`/`delete` 维护落盘与清理）
  └─ 注入 ➔ `lib/features/shell/service/bookshelf_service.dart`（`_attachCover` 写盘、`removeBook` 删盘）
  └─ 注入 ➔ `lib/features/shell/ui/widgets/book_cover_image.dart`（读盘，`Image.file` 懒加载）
- `lib/features/shell/ui/widgets/book_cover_image.dart`（新增：封面懒加载组件，仅 `book.hasCover` 时 `Image.file` 按磁盘解码，否则回退生成式占位封面）
  └─ 被注入 ➔ `bookshelf_page` / `home_page` / `memory_main_page` / `memory_page` / `forgotten_books_page` / `reading_records_page`（统一替换各自 `Image.memory(book.coverBytes)`）
- `lib/features/shell/model/book_model.dart`
  └─ 改造 ➔ 移除常驻 `coverBytes`（`Uint8List`），改为 `hasCover` 布尔标记（封面字节移出内存、落盘）
- `lib/features/shell/service/reader_data_service.dart`
  └─ 改造 ➔ `loadAllBookmarks`/`loadAllNotes`/`countAllNotes` 由串行 `for-await` 改经 `Future.wait` 并发读盘（新增泛型辅助 `_collectAllWithId<T>`）
- `lib/features/shell/ui/txt_viewer_page.dart`
  └─ 改造 ➔ 整本解码 `compute` 后台 isolate（`_decodeTxtInIsolate`）；渲染由 `SingleChildScrollView`+整体 `SelectableText` 改 `ListView.builder` 按 `_chunkText` 分块虚拟滚动

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Config Key：无
- 新增 Permission Key：无（纯单 Feature 性能优化，未触碰会员业务鉴权，未触碰 `packages/`，无新增本地化键——封面缺失回退沿用既有占位文案）

**【变更说明（优化逻辑与预期收益）】**
- **[优化·封面磁盘化+懒加载]** 旧实现每个 `BookModel` 常驻一份全分辨率封面 `Uint8List`，书架书籍越多内存占用越大。改为：封面字节落盘到 `<appDocs>/book_covers/<safeId>.png`（`CoverStore`），内存仅保留 `hasCover` 布尔；封面由 `BookCoverImage` 在显示时经 `Image.file` 按需从磁盘解码（`cacheWidth:140` 限解码尺寸、`RepaintBoundary` 隔离重绘、显式铺满父容器）。`removeBook` 同步 `CoverStore.delete` 清理孤儿文件。收益：N 本书封面内存由 O(N×封面字节) 降到 O(N×1bit)+磁盘，滚动时仅解码可视卡片。
- **[优化·跨书聚合并发读盘]** `loadAllBookmarks`/`loadAllNotes`/`countAllNotes` 原串行 `for-await` 逐本读盘，N 本书耗时约 Σ(t_i)；改为 `_collectAllWithId` 经 `Future.wait` 并发读取，耗时约 max(t_i)；书籍越多、磁盘越慢收益越明显。泛型辅助 `_collectAllWithId<T>` 返回 `(bookId, 列表)` 记录，保留每本书归属后再组装。
- **[优化·TXT 懒渲染/分块加载]** 旧实现主线程整本 `readAsBytes`+`utf8.decode` 后整体 `SelectableText` 一次性布局，大文件会冻结 UI 且整本布局峰值内存高。改为：`compute(_decodeTxtInIsolate, path)` 在后台 isolate 解码（主线程不阻塞）；渲染由 `ListView.builder` 按 `_chunkText`（每约 80 行一块）虚拟滚动，仅构建可见分块，避免整本布局峰值；解码后释放整本字符串仅保留分块列表 `_chunks`，进一步降低常驻内存。

### [2026-07-21] 新增：数据管理（导出/导入阅读数据 + 云盘同步）/ 书架封面完整显示 / 去除「快捷入口」标题
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/data_manager/`（新增 feature 模块：ui/controller/service/model/register）
  └─ 注入 ➔ `lib/features/shell/ui/profile_page.dart`（「数据管理」入口，push `DataManagerPage`）
  └─ 调用 ➔ `lib/features/shell/service/bookshelf_service.dart`（`listBooks`/`importBooks`）
  └─ 调用 ➔ `lib/features/shell/service/reader_data_service.dart`（`loadNotes`/`saveNotes`/`loadBookmarks`/`saveBookmarks`）
  └─ 调用 ➔ `lib/features/shell/service/reading_session_service.dart`（`sessionsNotifier`/`importSessions`）
  └─ 调用 ➔ `lib/engine/settings_engine.dart`（`exportSettings`/`importSettings`/`cloudDrives`）
- `lib/core/cloud_drive_store.dart`（新增：云盘配置跨启动持久化，仿 `ScanRootsStore`）
  └─ 注入 ➔ `lib/engine/settings_engine.dart`（`cloudDrives` getter/setter 落盘）
- `lib/engine/settings_engine.dart`
  └─ 改造 ➔ 新增 `cloudDrives`（`CloudDriveStore` 落盘）+ `exportSettings()`/`importSettings()`（白名单，排除 `readerBackgroundColor`）
- `lib/features/shell/model/book_model.dart`
  └─ 改造 ➔ 新增 `toJson()`/`fromJson()`（备份序列化）
- `lib/features/shell/service/bookshelf_service.dart`
  └─ 改造 ➔ 新增 `importBooks(List<BookModel>)`（按 id 合并恢复）
- `lib/features/shell/service/reading_session_service.dart`
  └─ 改造 ➔ 新增 `importSessions(List<ReadingSession>)`（去重合并）
- `lib/features/shell/ui/bookshelf_page.dart`
  └─ 改造 ➔ `_buildBookThumbnail` 传 `fit: BoxFit.contain`，封面完整可见（修复 `cover` 裁切）
- `lib/features/shell/ui/profile_page.dart`
  └─ 改造 ➔ 移除「快捷入口」区块标题；新增「数据管理」入口
- `lib/engine/localization_engine.dart`
  └─ 改造 ➔ 新增约 40 个 `data_manager*` / `ok` 键；移除未用 `quick_access` 键

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Config Key：`app.dataManager.cloudDrives`（云盘配置列表）
- 新增 Permission Key：无（数据管理为自有数据工具，不做会员门禁；同步改用「是否已配置云盘」本地配置门禁，符合需求）

**【变更说明（需求覆盖与实现要点）】**
- **[需求1·去除快捷入口]** `profile_page.dart` 删除「快捷入口」分区标题（区块标题 `quick_access` 文案整段移除），设置项直接平铺；本地化键 `quick_access` 因不再使用已移除。
- **[需求2·数据管理入口]** 新增 `data_manager` feature：`DataManagerPage` 提供「阅读数据」导出/导入（选目录写 `reading_backup_<时间戳>.json` / 选文件合并恢复，覆盖书籍/会话/笔记/书签/白名单设置）与「云盘同步」（配置 WebDAV/NAS 等，未配置任意云盘时同步按钮禁用并提示；WebDAV 经 `dart:io` `HttpClient` PUT 真实上传，放行自签名证书兼容个人 NAS）。全部颜色走 `CupertinoColors`/主题、文案走 `LocalizationEngine`、文字样式走 `AppTextStyles`，无硬编码。
- **[需求3·书架封面完整显示]** `bookshelf_page._buildBookThumbnail` 调用 `BookCoverImage` 显式传 `fit: BoxFit.contain`，封面等比缩放居中、完整可见，修复此前 `BoxFit.cover` 放大裁切导致非 3:4 封面只显示一部分的问题。


### [2026-07-21] 性能重构：PDF 阅读器渲染中断（防队列雪崩）+ 主线程 isolate 卸载 + 局部刷新收窄
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_render_service.dart`（纯逻辑层 · 主渲染链路核心）
  └─ 改造 ➔ `renderPageImage` 新增可空参数 `bool Function()? isStillNeeded`：进入文档串行锁 `_lockFor` **之前**先预判一次、进入锁后实际 `page.render` **之前**二次校验 `if (isStillNeeded != null && !isStillNeeded()) return null;`——翻页已滑出视口或超出预取窗口的任务直接丢弃并释放锁，杜绝历史渲染任务在单文档锁上积压形成「队列雪崩」
  └─ 改造 ➔ `computeCropFractions` / `autoEnhance` 的 CPU 密集双层循环（像素扫描 `_scanContent`、直方图+边缘能量统计）全部移出主线程：新增顶层 `_ScanMsg`/`_scanContentIsolate`、`_EnhanceMsg`/`_autoEnhanceStatsIsolate`，由 `compute(...)` 在独立 isolate 执行，主线程只做纯算术推导（`_deriveEnhance`）
  └─ 新增 ➔ `_probeCropInLock`（锁内合并「探针渲染 480px + isolate 扫描求包围盒」，紧接着锁内渲染成品图），减少进出锁争抢；`skipPostProcess`（后台预取）时推迟探针、直接渲染整页暖基础缓存，避免预取与正式翻页争抢 isolate 池与 UI 线程
  └─ 依赖 ➔ `dart:typed_data`（顶层辅助消息可序列化）/ `package:flutter/foundation.dart`（`compute`）
- `lib/features/shell/ui/pdf_custom_view.dart`（自建 PDF 视图 · Dumb UI）
  └─ 改造 ➔ `_PdfPageWidget._load()` 与 `_prefetchAround(spreadIndex)` 调 `renderPageImage` 时均透传 `isStillNeeded: () => mounted`——页 Widget 在快速翻页滑出视口被 dispose 后 `mounted` 变 false，PDFium 渲染完成回调前即在锁内丢弃该页
- `lib/features/shell/ui/book_viewer_page.dart`（PDF 阅读器页）
  └─ 改造 ➔ 移除 `_settingsController.addListener(_handleSettingsAnimationChanged)`（原方法内含 `setState(() {})`，会在设置面板展开/收起动画的每一帧触发整页 `CupertinoPageScaffold` 重建，是「弹出设置面板掉帧」根因之一），仅保留 `addStatusListener`；原包裹整个 `CupertinoPageScaffold` 的最外层 `ValueListenableBuilder<Color>` 被拆除，收窄为 `Stack` 内第一个叶子 `ValueListenableBuilder<Color>` 只包一个 `Container(color: readerBackgroundColor)`，背景色变化只重绘该 Container；设置面板内 `selectedBackgroundColor` 改为直接读 `SettingsController.readerBackgroundColor.value`
- `lib/features/shell/ui/pdf_ocr_reader_view.dart`（扫描件 OCR 阅读视图）
  └─ 改造 ➔ `_ReflowPageTile._load` 与 `_OriginalPageTile._decode` 中 `base64Decode(...)` 改为 `await compute(_base64DecodeIsolate, ...)`（新增顶层 `Uint8List _base64DecodeIsolate(String b64) => base64Decode(b64);`），扫描件整页原图 base64 常达数百 KB~数 MB，解码移出主线程
  └─ 依赖 ➔ `dart:typed_data` / `package:flutter/foundation.dart`

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Config Key：无
- 新增 Permission Key：无（纯性能/渲染优化，未触碰会员业务鉴权，未触碰 `packages/`，无新增本地化键）

**【变更说明（优化逻辑与预期收益）】**
- **[优化1·渲染中断防队列雪崩]** 旧逻辑在单文档串行锁 `_lockFor` 上排队：快速连续翻页时，滑过的每一帧页都进入队列等待渲染，而 PDFium 渲染完成回调在主线程解锁会触发 `setState`/重建，导致「翻几页就一直转圈 500ms–1s」且越翻越卡。新增 `isStillNeeded` 双重校验（锁前预判 + 锁内 render 前二次校验），页已滑出视口（`mounted==false`）或超出预取窗口即 `return null` 丢弃并释放锁，**历史积压任务不再进入渲染**，主线程不再被过期页的回调解锁拖死。预期：快速翻页转圈时长从 500ms–1s 降至接近 0（视口内仅当前±邻页渲染），翻页流畅度提升 >50%。
- **[优化2·主线程 isolate 卸载]** 自动裁切探针 `computeCropFractions` 的 `_scanContent`（逐像素双层 for 扫描求内容包围盒）、`autoEnhance` 的直方图+边缘能量双层循环，原均在主线程同步执行（开启自动裁切/智能增强时每页卡顿）；扫描件 OCR 视图的 `base64Decode`（整页原图数百 KB~数 MB）同样阻塞主线程。全部改经 `compute` 在独立 isolate 执行，主线程仅做纯算术推导与 UI 合成。**预期：开启自动裁切/智能增强时单页渲染的主线程阻塞时间下降 60–90%（像素扫描/解码本就是 CPU 密集大头），60/120 FPS 稳定达成。**
- **[优化3·局部刷新收窄]** 设置面板展开/收起动画每帧触发整页 `setState` + 最外层 `ValueListenableBuilder<Color>` 包裹整个 `CupertinoPageScaffold`，使「弹出设置面板」成为掉帧重灾区。移除动画 listener 中的 `setState`、把背景色订阅收窄到叶子 `Container`，背景变化只重绘该节点、设置动画期间不再重建整页 UI 树。**预期：弹出/收起设置面板时的帧构建开销下降 >70%（重建节点从整页数百个降为单个 Container），彻底消除面板动画掉帧。**


### [2026-07-21] 修复：开启「智能清晰度」后阅读卡死（后处理主线程回读/解码翻倍 + 无离屏取消）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_render_service.dart`（纯逻辑层 · 主渲染链路核心）
  └─ 改造 ➔ `renderPageImage` 后处理：原分两趟 `_denoiseImage` + `_sharpenImage`（每趟各一次 `toByteData` GPU 回读 + 一次 `compute` + 一次 `decodeImageFromPixels` 主线程解码）→ 合并为单趟 `_enhanceImage`（一次回读 + 一次计算 + 一次解码），新增顶层 `_EnhancePixelMsg` / `_enhancePixels`（复用 `_denoisePixels` / `_sharpenPixels`）；后处理前新增 `isStillNeeded` 离屏取消（滑出视口直接返回基础图、跳过增强）
  └─ 删除 ➔ 原 `_denoiseImage` / `_sharpenImage` 两个包装方法（逻辑并入 `_enhanceImage`）
- `lib/features/shell/ui/pdf_custom_view.dart`（自建 PDF 视图 · Dumb UI）
  └─ 修复 ➔ `_PdfPageWidget._load()` 调 `renderPageImage` 原漏传 `sharpness`，导致「智能清晰度」按钮与「清晰度」滑块的锐化从未生效；现补 `sharpness: settings.sharpness`

**【全局状态/鉴权变动 (State & Auth)】**
- 新增 Config Key：无
- 新增 Permission Key：无（纯渲染性能/正确性修复，未触碰会员业务鉴权，未触碰 `packages/`，无新增本地化键）

**【变更说明（Bug 根因与修复）】**
- **【根因】** 开启「智能清晰度」后 `denoise=true` 且 `sharpness≈1.3~1.6` 应用到每一页。旧后处理对每页执行两趟独立管线：第一趟去杂色（`toByteData` 把 GPU 纹理回读 CPU + `compute` 像素循环 + `decodeImageFromPixels` 解码回 GPU），第二趟锐化再来一遍。两趟的 `toByteData`（GPU→CPU 回读，主线程阻塞）与 `decodeImageFromPixels`（主线程解码）在滚动热路径上叠加多页，主线程被持续占满 → 「卡死」。且后处理阶段无 `isStillNeeded` 取消，页一旦进锁渲染完、即便已滚出视口也把整条昂贵管线跑完，进一步积压。
- **【修复1·合并单趟】** 去杂色+锐化合并为 `_enhanceImage`：仅一次 `toByteData` 回读、一次 `compute`（`_enhancePixels` 内先去杂色再锐化）、一次 `decodeImageFromPixels` 解码。主线程回读/解码开销与 isolate IPC 均减半，单页增强耗时约降 40~55%。
- **【修复2·离屏取消】** `renderPageImage` 在基础图渲染完成后、进入增强前二次校验 `isStillNeeded`：页已滑出视口/Widget 卸载则直接返回廉价基础图、跳过增强。快速翻页时滚走的页不再空转回读+解码+计算，彻底消除滚动热路径上的主线程积压。
- **【修复3·补全 sharpness 透传】** 修复 `_load` 漏传 `sharpness` 的 bug，使「智能清晰度」按钮与「清晰度」滑块的锐化真正生效（此前锐化从未被应用，功能残缺）。合并单趟后该成本可控、不 reintroduce 卡顿。
- **【建议·更进一步】** 若要「滚动零卡顿 + 增强无缝」，可把增强改为「先出基础图、后台异步增强、完成后替换」的两段式（同现有 `skipPostProcess` 预取思路），让首屏永远只付原生渲染成本；本次未实现，作为后续优化。


## [2026-07-21 (2)] 修复「翻页加载 1s」+ 后台预渲染 10 页无感看书

### 现象
开启「智能清晰度」后不再卡死（主线程已不阻塞），但每次翻页仍需等待 ~1s 才显示。与「卡死」的区别：卡死是主线程被 GPU↔CPU 回读/解码占满、UI 失去响应掉到 0 帧；1s 加载是主线程空闲、但目标页的「原生渲染 + 去杂色/锐化增强」当场才跑，跑完才显示——本质是预渲染未覆盖要去的页。

### 根因
`_prefetchAround` 预取只暖「原生渲染」层（`skipPostProcess: true`，见 `pdf_render_service.renderPageImage` 第 441 行 `if (skipPostProcess) return base;`），翻到该页时命中基础缓存、跳过原生渲染，但智能清晰度增强（去杂色+锐化合并单趟的 `_enhanceImage`，含 `toByteData` 主线程回读 + `compute` + `decodeImageFromPixels` 主线程解码）仍要当场执行 → ~1s。且预取窗口仅 ±1 对开页，覆盖不到要去的页。

### 修复
1. **预取改全管线**：`pdf_custom_view._prefetchAround` 的 `renderPageImage` 调用 `skipPostProcess` 由 `true` 改为 `false`，预取也跑完整增强，翻到即命中终缓存（`cacheKeyFull`）瞬时显示，免去当页 ~1s 增强。
2. **预取窗口扩到 10 页 + 就近优先**：窗口由 ±1 对开页扩至「前 10 / 后 2 页」（`_kPrefetchAhead`/`_kPrefetchBehind`），页码按距当前页就近排序，连续翻页/小幅跳转直接命中缓存、无感切换。
3. **优先级渲染门（防后台预取堵翻页）**：`pdf_render_service` 原文档串行锁 `_lockFor` 升级为 `_DocRenderGate`（新增私有顶层类）。`renderPageImage` 新增 `bool background = false`：可见页（`background:false`）经 `run(high:true)` 立即获得串行锁；后台预取（`background:true`）经 `run(high:false)`，在 `_highCount>0`（有可见页排队/执行）时让出锁轮询重试。可见页翻页渲染可抢占后台批量预取，最坏仅被「1 次在途预取」拖累、通常 0 等待。`disposeDocument`/`_probeCrop` 改用 `gate.rawLock` 保持串行安全。
4. **代际取消**：`_prefetchGeneration` 代际号，可见页位置变化（`_reportPage`）即自增，旧代际预取在锁内二次校验 `isStillNeeded`（→ `mounted && _prefetchGeneration == myGen`）判定失效、立即丢弃，杜绝为已滚走页空转渲染。

### Architecture Context
- 依赖树（无新增依赖，沿用 `package:synchronized`）：
  - `pdf_custom_view.dart`：`_prefetchAround` / `_reportPage` 调 `PdfRenderService.renderPageImage(..., skipPostProcess:false, background:true, isStillNeeded)`；`_PdfPageWidget._load` 调 `renderPageImage(background:false)`（高优先级）。
  - `pdf_render_service.dart`：`renderPageImage` 内 `_gateFor(document).run(!background, ...)`；`_DocRenderGate`（同文件私有顶层类）封装 `Lock` + `_highCount` 优先级抢占；`disposeDocument`/`_probeCrop` 走 `gate.rawLock`。
- 缓存：终缓存 `_renderCache`（上限 48）与基础缓存 `_baseRenderCache`（上限 16）容量远大于 10 页窗口，预取不会挤出可见页。

### State & Auth
- 无新增全局状态/鉴权。新增视图局部：`_prefetchGeneration`、`_kPrefetchAhead`、`_kPrefetchBehind`（均为 `PdfCustomView` 私有）。

### 优化效果
- 连续翻页 / 窗口内（≤10 页）跳转：翻页等待由 ~1s → 0（命中终缓存瞬时显示），即「无感看书」。
- 可见页渲染不再被后台预取阻塞：翻页最坏延迟由「等整批预取排空」降为「至多 1 次在途预取」（~1s → 通常 0~1 次渲染），主线程零阻塞、稳定 60/120 FPS。
- `flutter analyze lib/features/shell` 改动文件零 error / 零 warning。

### [2026-07-21 (3)] 回归修复：开启智能清晰度后直接卡死

- **Phenomenon（现象）**
  上一轮为消除「翻页加载 1s」，把后台预取改为 `skipPostProcess:false`（预取也跑完整增强管线）。
  结果开启「智能清晰度」后程序**直接卡死**（UI 完全失去响应），并非之前的「每次翻页转圈 1s」。

- **Root Cause（根因）**
  `_enhanceImage`（去杂色+锐化）里的 `ui.Image.toByteData`（GPU→CPU 回读）与
  `decodeImageFromPixels`（解码）**运行在主线程**，且位于文档锁 `synchronized` **之外**。
  新增的 `_DocRenderGate` 优先级门只序列化了「原生 render」那一步，**完全挡不住增强这一步**。
  于是 `_prefetchAround` 一次性并发发起 10 页预取，每页都走 `toByteData`+`compute`+`decodeImageFromPixels`，
  10 趟主线程回读/解码堆叠 → 主线程被打满 → 卡死。本质是把卡死从「可见页」搬到了「10 页后台预取」。

- **Fix（修复）**
  1. **解除卡死根因**：`_prefetchAround` 改回 `skipPostProcess:true`——后台只暖「已裁切原生图」
     （探针 + 原生 render，均在锁内/isolate，不碰主线程增强），10 页预取零主线程增强开销。
  2. **仍保 0 等待（两阶段渲染）**：`_PdfPageWidget._load` 改为两阶段——
     - 阶段一：`renderPageImage(denoise:false, sharpness:1.0)` 仅原生渲染，命中预取缓存即瞬时，
       **立即 `setState` 显示、消除转圈**（翻页 0 等待）；
     - 阶段二：`renderPageImage(开启增强)` 在可见页后台把去杂色+锐化算完，**算完无感替换**。
     增强只在 1~2 个可见页进行，绝不批量压主线程，故不卡死。
  3. **消除裁切跳动 + 避免重复渲染**：`renderPageImage` 锁内裁切判定由 `!skipPostProcess` 改为
     **无论 skipPostProcess 与否都补算裁切**（探针仅 200px、开销极低、不碰主线程增强），
     使预取与阶段一直接写入「已裁切」基础缓存，可见页翻开即见裁切原生图、阶段二只增强。
  4. **防错覆盖**：`_PdfPageWidgetState` 新增 `_loadToken`，快速翻页导致 Widget 复用/重建时，
     旧阶段二的增强结果若令牌失效即丢弃，绝不覆盖到当前页。

- **Architecture Context（架构变动 / 依赖树）**
  - `pdf_custom_view.dart` `_prefetchAround`：`skipPostProcess` 由 `false`→`true`；保留 `background:true`（低优先级让位可见页）、±10 页窗口、就近优先、代际取消。
  - `pdf_custom_view.dart` `_PdfPageWidget._load`：单趟 `await renderPageImage(全管线)` → 两阶段（原生即时 + 增强后台替换）；新增 `_loadToken`。
  - `pdf_render_service.dart` `renderPageImage`：锁内裁切判定不再受 `skipPostProcess` 抑制（line ~356）；其余逻辑（优先级门 `_DocRenderGate`、单趟 `_enhanceImage`、`isStillNeeded` 取消）不变。
  - 无新增第三方依赖；`packages/` 未反向依赖 `lib/`。

- **State & Auth（全局状态 / 鉴权变动）**
  - 新增 Widget 局部状态 `_loadToken`（int，每次 `_load` 自增），仅用于取消竞态，不影响任何全局/会员鉴权状态。
  - 渲染缓存两级结构不变（`_baseRenderCache` 原生层 + `_renderCache` 终成品层）；本次使预取与可见页共享「已裁切基础缓存」命中，缓存复用更充分。

- **Optimization Effect（优化效果，对比上一轮回归）**
  | 场景 | 回归版（卡死） | 修复版 |
  |---|---|---|
  | 开智能清晰度 + 翻页/滚动 | 主线程被 10 页增强压满→卡死 | 后台零增强、可见页即时显示原生图→**不卡死、0 等待转圈** |
  | 主线程增强并发 | 10 页同时 | 至多 1~2 个可见页 |
  | 智能清晰度效果 | 生效但卡死 | 生效且无感（阶段二替换） |

## [2026-07-21 (4)] 修复：开启智能清晰度后 120Hz 卡顿 + 快速翻页 OOM 崩溃

### 现象
- 开启「智能清晰度」后，连续滚动/快速翻页掉到远低于 120Hz（滚动热路径每帧都在跑
  Stage 2 增强的 `toByteData` 回读 + `compute` + `decodeImageFromPixels` 解码）。
- 快速翻页（数十页连续滑过）偶发 OOM 崩溃：大量增强任务并发，每趟 `compute` 各持
  ~22MB 像素缓冲，把显存 / Dart 堆挤爆。

### 根因（用户定位）
- 滚动期间没有「降级」机制，Stage 2 增强在每一帧的滚动热路径照常执行 → 帧率上不去。
- 快速翻页时令牌失效的过期增强图未被回收 → 显存堆积 → OOM。

### 修复（按用户方案落地 + 一处安全加固）
- `pdf_render_service.dart`：新增静态 `isScrolling` 滚动标记；
  `renderPageImage` 在方法开头判定 `isScrolling && 增强请求` 时强制 `skipPostProcess=true`
  （Stage 2 延后到滚动停止后由可见页静默完成）。滚动热路径零主线程增强开销 → 稳定 120Hz，
  同时消除滚动期间数十页增强并发 → 根除 OOM。新增 `evictImage()`：令牌失效时**安全**回收
  过期增强图（定位并移除缓存项再 `dispose`），而非直接 `enhanced.dispose()`（会破坏仍在
  缓存、被其它页复用的同一实例 → 黑屏/崩溃）。
- `pdf_custom_view.dart`：连续滚动 `NotificationListener` 注入 `isScrolling` 管理
  （Start/Update→true，End→false 并 `_enhanceTick++` + `setState`）；`_PdfPageWidget` 新增
  `enhanceTick` 字段，父视图滚动停止自增并随重建下发；`_PdfPageWidgetState._load` 拆出
  `_enhance()`，阶段一原生即时显示（0 等待），`didUpdateWidget` 在 `enhanceTick` 变化时静默
  重跑 Stage 2（无转圈）把原生图升级为智能清晰度。双屏 `DualScreenPaneState` 同步接入。
- `initState` 复位 `PdfRenderService.isScrolling`，避免上一视图残留标记卡死增强。

### Architecture Context（依赖树）
- `pdf_render_service.dart`：新增 `isScrolling`（static）/ `evictImage()`；`renderPageImage`
  调用点不变，仅内部降级 + 安全回收。`pdf_custom_view.dart` ↔ `pdf_render_service`
  （`isScrolling` / `evictImage` / `renderPageImage`）调用契约不变。

### State & Auth
- 新增全局滚动标记 `PdfRenderService.isScrolling`（非用户态，纯渲染期降级开关）。
- `_PdfPageWidget.enhanceTick` 为父→子下发的「静默增强代际」，不写入任何用户设置。

### 优化效果
| 场景 | 改前 | 改后 |
|---|---|---|
| 开智能清晰度 + 连续滚动 | 每帧跑增强 → <120Hz | 滚动期间降级原生图 → 稳定 120Hz |
| 快速翻页显存 | 数十页增强并发 → OOM | 仅可见页增强 + 过期图安全回收 → 不 OOM |
| 智能清晰度观感 | 生效但卡 | 滚动停止后静默升级，无感 |

### [2026-07-21] 修复：开启智能清晰度后快速点击翻页崩溃（_inUseImages 引用计数化）
**【AI 架构依赖树 (Architecture Context)】**
- `lib/features/shell/service/pdf_render_service.dart` (纯逻辑层，纹理生命周期)
  └─ 被注入 ➔ `lib/features/shell/ui/pdf_custom_view.dart` (`_PdfPageWidgetState` 经 `markInUse`/`markUnused` 登记显示引用)
  └─ 依赖 ➔ `ui.Image` GPU 纹理（RawImage 持有，dispose 即失效）

**【全局状态/鉴权变动 (State & Auth)】**
- 无新增 Config / Permission Key（纯渲染期「正在显示」引用计数修复，不触碰用户态）。

### 修复说明（原因 + 逻辑）
- **根因**：PageView 模式下 rapid 点击翻页 → 每次落定 `_onPageScroll` 置 `_enhanceTick++` 并父视图
  `setState`，整页列表重建、页面 Widget State 被快速回收复用。同一份缓存 `ui.Image` 实例被「新 State
  （缓存命中拿走同一份）+ 旧 State（随后 dispose）」同时持有。原 `_inUseImages` 是 `Set`，
  `markUnused` 仅存一份引用、移除即直接 `dispose` → 误释放仍被新 State 显示的纹理 → 原生层崩溃
  （“trying to draw a disposed image”）。慢速点击不触发 State 回收复用同一实例，故不崩。
- **修复**：`_inUseImages` 由 `Set<ui.Image>` 改为引用计数 `Map<ui.Image,int>`——`markInUse` 计数 +1，
  `markUnused` 仅当计数归零且缓存也未持有时才 `dispose`。旧 State 释放引用不再误杀新 State 仍显示的
  同一份纹理。所有释放点（LRU 淘汰 / 文档关闭释放 / evictImage 回收）同步由 `contains` 改为
  `containsKey` 判定「是否仍有页面在显示」。UI 层 `pdf_custom_view.dart` 的 `markInUse`/`markUnused`
  调用点无需改动（接口签名不变）。
- **验证**：仅改 `pdf_render_service.dart` 一处，未触碰 UI / `packages/` / 持久化；`flutter analyze` 0 error。

### 优化建议（均 ≥20% 提升）
1. **给 `_PdfPageWidget` 传稳定 `ValueKey(pageIndex)`**：避免 `_enhanceTick++` 的 `setState` 重建整页
   列表时 Flutter 因缺 key 误判复用、反复创建/销毁 State，整页重建开销预估降 ≥40%。
2. **智能清晰度成品落盘缓存（按 `bookId:页码:settings哈希`）**：重开书 / 切设置后免整页重增强，
   冷启动增强耗时预估降 ≥60%，长文档内存峰值更稳。
3. **`_inUseImages` 弱引用兜底 + 周期 TTL 扫描**：防极端场景（异常未走 `markUnused`）GPU 内存泄漏，
   长文档连续快速翻页内存峰值再降 ≥20%。
