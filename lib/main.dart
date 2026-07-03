import 'package:flutter/material.dart';

import 'engine/permission_engine.dart';
import 'features/shell/register.dart';
import 'features/shell/ui/shell_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const permissionJson = '{"membership.enable": true, "payment.enable": true, "tools.image_to_pdf": true}';
  PermissionEngine.initializeFromJson(permissionJson);
  PermissionEngine.cacheRawPayload(permissionJson);

  ShellRegister.register();
  runApp(const ShellPage());
}
