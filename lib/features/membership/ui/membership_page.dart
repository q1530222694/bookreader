import 'package:flutter/cupertino.dart';

import '../controller/membership_controller.dart';

/// MembershipPage displays membership status and permission-driven UI.
class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  bool _membershipEnabled = false;
  String _statusText = '正在加载会员状态...';

  @override
  void initState() {
    super.initState();
    _membershipEnabled = MembershipController.isMembershipEnabled();
    _loadMembershipStatus();
  }

  Future<void> _loadMembershipStatus() async {
    final status = await MembershipController.fetchMembershipStatus();
    setState(() {
      _statusText = status.isVip
          ? '当前为 VIP 用户，等级：${status.level}'
          : '当前非 VIP 用户，等级：${status.level}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('会员中心')),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '会员中心',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                _membershipEnabled
                    ? '会员功能已启用，会员权限由云端控制。'
                    : '会员功能当前未开启，请检查服务器端权限配置。',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Text(_statusText, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
