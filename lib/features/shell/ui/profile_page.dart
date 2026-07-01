import 'package:flutter/cupertino.dart';

/// ProfilePage displays the user's personal section for the shell module.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        leading: Text(
          '我的',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      child: const SafeArea(
        child: Center(
          child: Icon(
            CupertinoIcons.person,
            size: 88,
            color: CupertinoColors.inactiveGray,
          ),
        ),
      ),
    );
  }
}
