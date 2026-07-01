import 'package:flutter/cupertino.dart';

/// HomePage displays the main dashboard content for the shell module.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        leading: Text(
          '主页',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      child: const SafeArea(
        child: Center(
          child: Icon(
            CupertinoIcons.home,
            size: 88,
            color: CupertinoColors.inactiveGray,
          ),
        ),
      ),
    );
  }
}
