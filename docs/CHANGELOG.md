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
