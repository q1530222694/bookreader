import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../../../engine/theme_engine.dart';
import '../controller/settings_controller.dart';
import '../controller/shell_controller.dart';
import 'bookshelf_page.dart';
import 'home_page.dart';
import 'memory_main_page.dart';
import 'profile_page.dart';
import 'splash_screen.dart';
import 'tools_page.dart';

/// 底部 Tab 图标，顺序与 [_buildShellTabPage] 的页面列表一一对应。
const _tabIcons = <IconData>[
  CupertinoIcons.home,
  CupertinoIcons.book,
  CupertinoIcons.time,
  CupertinoIcons.wrench,
  CupertinoIcons.person,
];

/// 依据 Tab 索引返回对应的业务页面。
Widget _buildShellTabPage(int tabIndex) {
  const pages = <Widget>[
    HomePage(),
    BookshelfPage(),
    MemoryMainPage(),
    ToolsPage(),
    ProfilePage(),
  ];
  return pages[tabIndex];
}

/// ShellPage 是 App 根：构建 CupertinoApp 并应用全局主题/语言/字体，
/// 其 home 为 [ShellBoot]（负责在首帧按需压入启动屏）。
class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  final ShellController _controller = ShellController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: SettingsController.appearance,
      builder: (context, appearance, child) {
            return ValueListenableBuilder<Color>(
              valueListenable: SettingsController.activePrimaryColor,
              builder: (context, primaryColor, child) {
                final brightness = appearance == SettingsEngine.appearanceLight
                    ? Brightness.light
                    : appearance == SettingsEngine.appearanceDark
                        ? Brightness.dark
                        : WidgetsBinding
                            .instance.platformDispatcher.platformBrightness;

                return ValueListenableBuilder<String>(
                  valueListenable: SettingsController.fontFamily,
              builder: (context, fontFamily, child) {
                return CupertinoApp(
                  title: LocalizationEngine.text('about_app_title'),
                  theme: ThemeEngine.buildThemeData(
                    brightness: brightness,
                    primaryColor: primaryColor,
                    scaffoldBackgroundColor:
                        CupertinoColors.systemBackground.resolveFrom(context),
                    fontFamilyKey: fontFamily,
                  ),
                  // 底层 Tab 容器；启动屏按需压在其上。
                  home: ShellBoot(
                    controller: _controller,
                    fontFamilyKey: fontFamily,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// ShellBoot 承载底层 Tab 容器，并在首帧按需将 [SplashScreen] 压入导航栈。
///
/// 仅当启动内容类型非「不显示」时才展示启动屏；启动屏关闭后，
/// 本容器已按 [SettingsEngine.startupPage] 在 [ShellController] 构造时定位到对应标签。
class ShellBoot extends StatefulWidget {
  final ShellController controller;
  final String fontFamilyKey;

  const ShellBoot({
    required this.controller,
    required this.fontFamilyKey,
    super.key,
  });

  @override
  State<ShellBoot> createState() => _ShellBootState();
}

class _ShellBootState extends State<ShellBoot> {
  @override
  void initState() {
    super.initState();
    // 首帧后再压栈，确保导航上下文已就绪。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 仅当配置了要显示启动页时才压入启动屏（不显示则直接进应用）。
      if (SettingsEngine.startupSplashType !=
          SettingsEngine.startupSplashTypeNone) {
        Navigator.of(context).push(
          CupertinoPageRoute(
            fullscreenDialog: false,
            builder: (_) => const SplashScreen(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 语言变化驱动底部标签标题刷新。
    return ValueListenableBuilder<String>(
      valueListenable: SettingsController.language,
      builder: (context, language, child) {
        final tabTitles = <String>[
          LocalizationEngine.text('home'),
          LocalizationEngine.text('bookshelf'),
          LocalizationEngine.text('memory'),
          LocalizationEngine.text('tools'),
          LocalizationEngine.text('profile'),
        ];

        return ValueListenableBuilder<int>(
          valueListenable: widget.controller.selectedIndex,
          builder: (context, index, child) {
            return CupertinoTabScaffold(
              tabBar: CupertinoTabBar(
                currentIndex: index,
                onTap: widget.controller.setIndex,
                items: List<BottomNavigationBarItem>.generate(
                  tabTitles.length,
                  (itemIndex) => BottomNavigationBarItem(
                    icon: Icon(_tabIcons[itemIndex]),
                    label: tabTitles[itemIndex],
                  ),
                ),
              ),
              tabBuilder: (context, tabIndex) {
                return _buildShellTabPage(tabIndex);
              },
            );
          },
        );
      },
    );
  }
}
