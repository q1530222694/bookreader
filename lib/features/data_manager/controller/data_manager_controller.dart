import 'package:flutter/foundation.dart';

import '../model/cloud_drive_config.dart';
import '../model/reading_backup_model.dart';
import '../service/backup_service.dart';
import '../service/cloud_drive_service.dart';

/// 数据管理「聪明大脑」：编排备份导出/导入与云盘同步，向 UI 提供数据与回调。
///
/// 自身不持有业务状态（书籍/会话等直接从各服务读取），仅做「服务编排」与
/// 「同步门禁判定」，UI 通过它发起操作并接收结果。符合 feature 标准结构
/// （controller 调引擎/服务，注入数据给 Dumb UI）。
class DataManagerController {
  /// 当前云盘配置列表（每次读取自内存镜像）。
  List<CloudDriveConfig> get drives => CloudDriveService.drives;

  /// 是否已配置任意云盘（同步按钮门禁）。
  bool get canSync => CloudDriveService.hasAnyDrive;

  /// 是否存在支持真实同步的云盘（WebDAV）。
  bool get hasSyncCapableDrive => CloudDriveService.hasSyncCapableDrive;

  /// 导出阅读数据到用户选择目录，返回文件路径或 null（取消）。
  Future<String?> exportData() => BackupService.exportToFile();

  /// 从用户选择文件导入阅读数据（合并恢复），返回导入的备份概要。
  Future<ReadingBackup> importData() => BackupService.importFromFile();

  /// 保存/更新一条云盘配置。
  void saveDrive(CloudDriveConfig config) => CloudDriveService.save(config);

  /// 删除一条云盘配置。
  void deleteDrive(String id) => CloudDriveService.delete(id);

  /// 同步当前阅读数据到所有支持同步的云盘。
  /// [onProgress] 透传给服务层，按已完成云盘数 / 总云盘数上报进度（0~1）。
  /// 返回每条云盘的同步结果（单盘失败不中断其余盘）；无云盘或无支持类型时结果列表为空。
  Future<List<CloudDriveSyncResult>> syncNow({
    ValueChanged<double>? onProgress,
  }) async {
    final bytes = BackupService.encode(await BackupService.buildBackup());
    return CloudDriveService.sync(bytes, onProgress: onProgress);
  }
}
