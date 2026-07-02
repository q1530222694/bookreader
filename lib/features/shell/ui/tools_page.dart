import 'package:flutter/cupertino.dart';

/// ToolsPage exposes utility actions for the shell module.
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: Text(
          '工具',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: CupertinoTheme.of(context).primaryColor),
        ),
      ),
      child: const SafeArea(
        child: Center(
          child: Icon(
            CupertinoIcons.wrench,
            size: 88,
            color: CupertinoColors.inactiveGray,
          ),
        ),
      ),
    );
  }
}
