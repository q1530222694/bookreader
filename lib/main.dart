import 'package:flutter/material.dart';

import 'engine/permission_engine.dart';
import 'features/shell/register.dart';
import 'features/shell/service/app_stats_service.dart';
import 'features/shell/ui/shell_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化应用统计服务并增加打开次数计数
  await AppStatsService.initialize();
  await AppStatsService.incrementAppLaunchCount();

  const permissionJson = '{"membership.enable": true, "payment.enable": true, "tools.image_to_pdf": true}';
  PermissionEngine.initializeFromJson(permissionJson);
  PermissionEngine.cacheRawPayload(permissionJson);

  ShellRegister.register();
  runApp(const ShellPage());
}
