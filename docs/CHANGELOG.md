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

