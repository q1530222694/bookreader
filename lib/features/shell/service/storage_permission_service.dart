import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// 跨平台「文件夹 / 存储」操作系统权限服务。
///
/// 在扫描导入文件夹前主动申请对应平台的操作系统权限；若被用户拒绝
/// （尤其是被永久拒绝），引导其前往系统设置页手动开启。
///
/// 所有操作系统级权限均通过 [permission_handler] 申请，与会员/付费等业务
/// 权限（PermissionEngine）完全解耦——业务权限走服务端驱动，本服务只处理
/// 文件系统访问所需的 OS 授权。
class StoragePermissionService {
  StoragePermissionService._();

  /// 申请扫描/读取文件夹所需的操作系统权限。
  ///
  /// - Android：优先申请 [Permission.manageExternalStorage]
  ///   （Android 11+ 的「所有文件访问」），失败回退 [Permission.storage]；
  ///   二者皆未授予返回 false。
  /// - iOS：申请 [Permission.photos]（文件选择依赖媒体库权限），
  ///   limited 状态视为已授权。
  /// - macOS：尝试 [Permission.storage]（插件不支持时视为已授权，
  ///   由系统文件 picker 控制授权）。
  /// - Windows / Linux：无运行时权限，直接返回 true。
  ///
  /// 返回 true 表示已获得（或无需）授权，可继续文件夹选择；false 表示被拒。
  static Future<bool> ensureFolderReadAccess() async {
    if (Platform.isAndroid) {
      // Android 11+ 需要「所有文件访问」才能读取任意文件夹；旧版本用存储权限。
      final manage = await Permission.manageExternalStorage.request();
      if (manage.isGranted) return true;
      final storage = await Permission.storage.request();
      return storage.isGranted;
    }

    if (Platform.isIOS) {
      // iOS 通过系统文件 picker 选取文件夹本身即代表用户授权，
      // 此处补齐媒体库权限以便文件读取链路可用。
      final status = await Permission.photos.status;
      if (status.isGranted || status.isLimited) return true;
      final requested = await Permission.photos.request();
      return requested.isGranted || requested.isLimited;
    }

    if (Platform.isMacOS) {
      // macOS 访问用户选择的文件夹由系统 picker 授权；此处尝试 storage 权限。
      try {
        final status = await Permission.storage.status;
        if (status.isGranted) return true;
        final requested = await Permission.storage.request();
        return requested.isGranted;
      } catch (_) {
        // 插件在部分 macOS 版本不支持 storage 权限，交由系统 picker 授权。
        return true;
      }
    }

    // Windows / Linux：无运行时权限。
    return true;
  }

  /// 打开系统应用设置页，引导用户手动授予被永久拒绝的权限。
  static Future<void> openSystemSettings() async {
    await openAppSettings();
  }
}
