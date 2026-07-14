import 'package:flutter/material.dart';

import 'engine/permission_engine.dart';
import 'features/shell/register.dart';
import 'features/shell/service/app_stats_service.dart';
import 'features/shell/service/custom_theme_color_service.dart';
import 'features/shell/service/reading_session_service.dart';
import 'features/shell/ui/shell_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化应用统计服务并增加打开次数计数
  await AppStatsService.initialize();
  await AppStatsService.incrementAppLaunchCount();
  // 初始化阅读会话日志服务（记录每次阅读的开始时间/时长/是否读完）
  await ReadingSessionService.initialize();
  // 初始化自定义主题色服务（加载用户本地保存的自定义配色列表）
  await CustomThemeColorService.initialize();

  // 本地默认权限种子：后续接入会员系统时改由服务端下发即可关闭非会员入口。
  // theme.customColor 控制「自定义配色」是否可用（当前默认开放）。
  const permissionJson =
      '{"membership.enable": true, "payment.enable": true, "tools.image_to_pdf": true, "theme.customColor": true}';
  PermissionEngine.initializeFromJson(permissionJson);
  PermissionEngine.cacheRawPayload(permissionJson);

  ShellRegister.register();
  runApp(const ShellPage());
}
