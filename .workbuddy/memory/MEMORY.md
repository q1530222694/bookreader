# 项目长期记忆（MEMORY.md）

## 项目：bookreader（Flutter 阅读器 App，Monorepo + packages 中台架构）

### 用户强制规范（每次任务必须遵守）
1. **改前必读**：任何修改、新增或完成任务前，必须先读取 `/Users/wzh/flutter/bookreader/docs/提示词.md` 并按其架构规则（包隔离、禁区、UI 不硬编码、i18n、CHANGELOG 等）执行。
2. **依赖文档同步**：每次更新或新增文件都要先确认依赖关系，并把「文件功能 + 依赖关系」写入 `/Users/wzh/flutter/bookreader/docs/不同文件的依赖关系.md`（只保留最新完整说明，不要丢失既有章节）。

### 架构要点（速记）
- `packages/` = 跨应用复用中台 SDK（membership_sdk / payment_sdk / ad_sdk），**禁止反向 import 主工程 `lib/`**。
- 主工程 `lib/`：app / core / engine / features / shared。
- UI 严禁硬编码颜色/字号/间距/明文文本；字体统一交给 `core/theme/font_manager.dart`；主题色走 `Theme.of(context).extension<AppColors>()`。
- 权限必须过 `engine/permission_engine.dart`，禁止 UI 层硬编码 `if (level == x)`。
- 跨模块状态/事件走全局 Config/EventBus，UI 不直接调持久化。

### 构建环境注意
- `android/gradle.properties` 的 `org.gradle.java.home` 是**操作系统强相关**：macOS=`/Applications/Android Studio.app/Contents/jbr/Contents/Home`（Java 21），Windows=`C:/Program Files/Android/Android Studio/jbr`。本机 PATH 的 java 是 Java 25，Gradle 8.10.2 不支持，故必须显式指定 Java 17~21 的 JDK，不能删该行落环境 Java 25。
- macOS 原生构建：`Runner` 的 `MACOSX_DEPLOYMENT_TARGET` 必须 ≥ 14.0（因 `flutter_onnxruntime` 要求），CocoaPods 已弃用改 SwiftPM。
