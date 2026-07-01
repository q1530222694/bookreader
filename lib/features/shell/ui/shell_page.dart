import 'package:flutter/cupertino.dart';

import '../controller/shell_controller.dart';
import 'bookshelf_page.dart';
import 'home_page.dart';
import 'memory_page.dart';
import 'profile_page.dart';
import 'tools_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  final ShellController _controller = ShellController();

  static const _tabTitles = <String>['主页', '书架', '回忆', '工具', '我的'];

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
    return CupertinoApp(
      title: 'Book Reader',
      home: ValueListenableBuilder<int>(
        valueListenable: _controller.selectedIndex,
        builder: (context, index, child) {
          return CupertinoTabScaffold(
            tabBar: CupertinoTabBar(
              currentIndex: index,
              onTap: _controller.setIndex,
              items: List<BottomNavigationBarItem>.generate(
                _tabTitles.length,
                (itemIndex) => BottomNavigationBarItem(
                  icon: Icon(_tabIcons[itemIndex]),
                  label: _tabTitles[itemIndex],
                ),
              ),
            ),
            tabBuilder: (context, tabIndex) {
              return _tabPages[tabIndex];
            },
          );
        },
      ),
    );
  }
}
