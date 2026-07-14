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
