import '../../core/cloud_drive_store.dart';

/// 数据管理 feature 注册入口。
///
/// 启动时确保云盘配置已从磁盘加载到内存镜像（幂等；[main] 亦会调用，
/// 此处调用可兜住未接入的启动路径）。其余状态由页面按需经
/// [DataManagerController] 从各服务读取，无需常驻初始化。
class DataManagerRegister {
  static void register() {
    CloudDriveStore.load();
  }
}
