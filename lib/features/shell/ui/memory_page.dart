import 'package:flutter/cupertino.dart';

/// MemoryPage displays recall and note-related content for the shell module.
class MemoryPage extends StatelessWidget {
  const MemoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: Text(
          '回忆',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: CupertinoTheme.of(context).primaryColor),
        ),
      ),
      child: const SafeArea(
        child: Center(
          child: Icon(
            CupertinoIcons.time,
            size: 88,
            color: CupertinoColors.inactiveGray,
          ),
        ),
      ),
    );
  }
}
