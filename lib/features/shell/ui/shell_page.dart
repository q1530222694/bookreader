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
import 'tools_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  final ShellController _controller = ShellController();

  static const _tabIcons = <IconData>[
    CupertinoIcons.home,
    CupertinoIcons.book,
    CupertinoIcons.time,
    CupertinoIcons.wrench,
    CupertinoIcons.person,
  ];

  Widget _buildTabPage(int tabIndex) {
    final pages = <Widget>[
      HomePage(),
      BookshelfPage(),
      MemoryMainPage(),
      ToolsPage(),
      ProfilePage(),
    ];
    return pages[tabIndex];
  }

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
        return ValueListenableBuilder<String>(
          valueListenable: SettingsController.themeColor,
          builder: (context, themeColor, child) {
            final brightness = appearance == SettingsEngine.appearanceLight
                ? Brightness.light
                : appearance == SettingsEngine.appearanceDark
                    ? Brightness.dark
                    : WidgetsBinding.instance.platformDispatcher.platformBrightness;

            final primaryColor = themeColor == SettingsEngine.themeColorGreen
                ? CupertinoColors.activeGreen
                : themeColor == SettingsEngine.themeColorPink
                    ? CupertinoColors.systemPink
                    : themeColor == SettingsEngine.themeColorOrange
                        ? CupertinoColors.systemOrange
                        : themeColor == SettingsEngine.themeColorPurple
                            ? CupertinoColors.systemIndigo
                            : themeColor == SettingsEngine.themeColorRed
                                ? CupertinoColors.systemRed
                                : CupertinoColors.activeBlue;

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
                  home: ValueListenableBuilder<String>(
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
                        valueListenable: _controller.selectedIndex,
                        builder: (context, index, child) {
                          return CupertinoTabScaffold(
                            tabBar: CupertinoTabBar(
                              currentIndex: index,
                              onTap: _controller.setIndex,
                              items: List<BottomNavigationBarItem>.generate(
                                tabTitles.length,
                                (itemIndex) => BottomNavigationBarItem(
                                  icon: Icon(_tabIcons[itemIndex]),
                                  label: tabTitles[itemIndex],
                                ),
                              ),
                            ),
                            tabBuilder: (context, tabIndex) {
                              return _buildTabPage(tabIndex);
                            },
                          );
                        },
                      );
                    },
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
