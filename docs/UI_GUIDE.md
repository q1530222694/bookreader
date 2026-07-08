# UI Guide

## 1. 程序入口

- `lib/main.dart`
  - `main()`
    - 初始化权限与设置引擎
    - 注册 Shell
    - 运行 `ShellPage`

## 2. 顶层 Shell UI

- `lib/features/shell/ui/shell_page.dart`
  - `ShellPage`
    - `CupertinoApp`
      - 主题与语言配置
    - `CupertinoTabScaffold`
      - `CupertinoTabBar`
        - Tab 0: `Home`  (首页)
        - Tab 1: `Bookshelf`  (书架)
        - Tab 2: `Memory`  (记忆/统计)
        - Tab 3: `Tools`  (工具)
        - Tab 4: `Profile`  (我的)
      - `tabBuilder` 返回具体页面：
        - `HomePage()`
        - `BookshelfPage()`
        - `MemoryPage()`
        - `ToolsPage()`
        - `ProfilePage()`

## 3. Home 页面层级

- `lib/features/shell/ui/home_page.dart`
  - 顶层：`CupertinoPageScaffold`
    - `CupertinoNavigationBar`
      - 左侧：静态文本 `home`
      - 右侧按钮：
        - 语言切换按钮 (`_buildLanguageButton`) -> 地球图标
        - 主题切换按钮 (`_buildThemeButton`) -> 月亮/太阳图标
    - 正文：`SafeArea` -> `ListView`
      - `GreetingSection`
        - 标题文本 `greeting_title`
        - 副标题文本 `greeting_subtitle`
      - `RecentReadingCard`
        - 书籍封面展示
        - 书名文本 / 默认提示 `no_recently_reading`
        - 阅读进度文字 `reading_progress_label`
        - 进度条
        - `Continue` 按钮 `continue_reading`
      - `ReadingDataSection`
        - 大号阅读时长卡片
          - 阅读总时长文本
          - 今日/累计标签文字 `today_reading`
        - 三个统计卡片
          - `monthly_reading`
          - `yearly_reading`
          - `cumulative_reading`
      - `Quick Functions`
        - 快捷功能图标按钮（四个卡片）
          - `import_pdf`
          - `recent_files`
          - `reading_stats`
          - `favorites`
      - `DailySentence` 卡片
        - 今日金句文本
        - 添加按钮 `add_circled_solid`
          - 点击弹出对话框
            - 内容输入框
            - 取消按钮 `cancel`
            - 保存按钮 `save`

## 4. Bookshelf 页面层级

- `lib/features/shell/ui/bookshelf_page.dart`
  - 顶层：`CupertinoPageScaffold`
    - `CupertinoNavigationBar`
      - 左侧：`bookshelf` 标题
      - 右侧按钮：
        - 搜索按钮 (`CupertinoIcons.search`)
          - 弹出搜索弹窗
          - 内部包含：搜索输入框、Done 按钮
        - 更多按钮 (`CupertinoIcons.ellipsis`)
          - 弹出菜单 `ShowMoreOptions`
            - `bookshelf_import_single`
            - `bookshelf_import_multiple`
            - `bookshelf_random_read`
    - 正文：`SafeArea` -> `Column`
      - 统计卡片区域 (`_buildStatsCards`)
      - 最近阅读区域 (`_buildRecentReading`)
      - 文件类型标签行
        - `bookshelf_tab_all`
        - `file_type_pdf`
        - `file_type_epub`
        - `file_type_txt`
        - `bookshelf_tab_other`
      - 过滤按钮 (`CupertinoIcons.slider_horizontal_3`)
        - 弹出 `CupertinoActionSheet`
      - 书籍展示区
        - 空书架时：导入按钮 `bookshelf_import_button`
        - 无筛选结果时：提示文本 `bookshelf_no_match_books`
        - 有书籍时：
          - 封面网格模式 `_showCoverMode`
          - 列表模式
      - 单本书籍操作菜单
        - `bookshelf_delete`

## 5. Memory 页面层级

- `lib/features/shell/ui/memory_page.dart`
  - 顶层：`CupertinoPageScaffold`
    - `CupertinoNavigationBar`
      - 返回按钮
      - 标题 `reading_statistics`
      - 分享按钮 (`CupertinoIcons.share`)
    - 正文：`SafeArea` -> `SingleChildScrollView`
      - `SegmentedControl` 选择时间周期
        - `_ReadingPeriod` 标签
      - 日期切换栏
        - 左箭头按钮
        - 当前日期标签
        - 日历按钮 (`CupertinoIcons.calendar`)
      - 图表卡片
      - 指标网格
      - 阅读时长分布卡片
      - 趋势卡片

## 6. Tools 页面层级

- `lib/features/shell/ui/tools_page.dart`
  - 顶层：`CupertinoPageScaffold`
    - `CupertinoNavigationBar`
      - 标题 `tools`
    - 正文：`SafeArea` -> `SingleChildScrollView`
      - 工具卡片列表
        - `TXT转EPUB` -> 打开 `TxtToEpubPage`
        - `DOC转PDF` -> 打开 `DocToPdfPage`
        - `PPT转PDF` -> 打开 `PptToPdfPage`
        - `Excel转PDF` -> 打开 `ExcelToPdfPage`
        - `图片转PDF` -> 打开 `ImageToPdfPage`

## 7. Profile 页面层级

- `lib/features/shell/ui/profile_page.dart`
  - 顶层：`CupertinoPageScaffold`
    - `CupertinoNavigationBar`
      - 标题 `profile`
    - 正文：`SafeArea` -> `CustomScrollView`
      - 账号设置区域
        - Premium 按钮 -> 打开 `MembershipPage`
        - Sync 按钮
      - 快捷入口列表
        - `daily_sentence`
        - `ai_assistant`
        - `language`
        - `app_appearance`
        - `theme_color`
        - `more_settings`
        - `about`
      - 列表项类型：`_ProfileSettingItem`
        - 图标
        - 文本标签
        - 右侧箭头

## 8. 相关设置子页面

- `lib/features/shell/ui/settings_page.dart`
  - `SettingsPage`
    - 语言设置项
      - 打开 `LanguagePage`
    - 外观设置项
      - 打开 `AppearancePage`

- `lib/features/shell/ui/appearance_page.dart`
  - `AppearancePage`
    - 主题与字体选择项

- `lib/features/shell/ui/language_page.dart`
  - `LanguagePage`
    - 语言切换选项
