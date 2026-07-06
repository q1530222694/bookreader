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

