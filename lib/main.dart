import 'package:flutter/material.dart';

import 'engine/permission_engine.dart';
import 'core/scan_roots_store.dart';
import 'features/shell/register.dart';
import 'features/shell/service/app_stats_service.dart';
import 'features/shell/service/cover_store.dart';
import 'features/shell/service/custom_theme_color_service.dart';
import 'features/shell/service/reading_session_service.dart';
import 'features/shell/ui/shell_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 并行初始化互不依赖的启动服务，缩短冷启动耗时（原串行等待约 4 倍时间）。
  // AppStats 需先 initialize 再累加打开次数，故用 then 串成一条独立 future。
  await Future.wait([
    AppStatsService.initialize().then((_) => AppStatsService.incrementAppLaunchCount()),
    ReadingSessionService.initialize(),
    CustomThemeColorService.initialize(),
    // 封面磁盘根目录预解析（CoverStore 全局单例，供 UI 同步懒加载封面文件）。
    CoverStore.init(),
    // 加载扫描导入的用户追加根目录（跨启动持久化，避免重启后丢失、需重复添加）
    ScanRootsStore.load(),
  ]);

  // 本地默认权限种子：后续接入会员系统时改由服务端下发即可关闭非会员入口。
  // theme.customColor 控制「自定义配色」是否可用（当前默认开放）。
  const permissionJson =
      '{"membership.enable": true, "payment.enable": true, "tools.image_to_pdf": true, "theme.customColor": true}';
  PermissionEngine.initializeFromJson(permissionJson);
  PermissionEngine.cacheRawPayload(permissionJson);

  ShellRegister.register();
  runApp(const ShellPage());
}
