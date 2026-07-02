import 'package:flutter/cupertino.dart';

import '../../../engine/localization_engine.dart';
import '../../../engine/settings_engine.dart';
import '../controller/settings_controller.dart';
import '../controller/shell_controller.dart';
import 'bookshelf_page.dart';
import 'home_page.dart';
import 'memory_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
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

  static const _tabPages = <Widget>[
    HomePage(),
    BookshelfPage(),
    MemoryPage(),
    ToolsPage(),
    ProfilePage(),
  ];

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
        final brightness = appearance == SettingsEngine.appearanceLight
            ? Brightness.light
            : appearance == SettingsEngine.appearanceDark
                ? Brightness.dark
                : WidgetsBinding.instance.platformDispatcher.platformBrightness;

        return CupertinoApp(
          title: 'Book Reader',
          theme: CupertinoThemeData(brightness: brightness),
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
                      return _tabPages[tabIndex];
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
