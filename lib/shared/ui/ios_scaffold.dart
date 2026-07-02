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
      navigationBar: CupertinoNavigationBar(
        middle: Text("Reader App", style: TextStyle(color: CupertinoTheme.of(context).primaryColor)),
      ),
      child: body,
    );
  }
}