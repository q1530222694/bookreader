import 'package:flutter/cupertino.dart';

class IOSScaffold extends StatelessWidget {
  final Widget body;
  final CupertinoTabBar tabBar;

  const IOSScaffold({
    super.key,
    required this.body,
    required this.tabBar,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Reader App"),
      ),
      child: body,
    );
  }
}