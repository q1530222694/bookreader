import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../../engine/settings_engine.dart';
import '../model/cloud_drive_config.dart';

/// 云盘/NAS 配置与同步服务（feature 层）。
///
/// - 配置：经 [SettingsEngine.cloudDrives] 落盘（底层 [CloudDriveStore]）；
/// - 同步门禁：仅当至少配置一个云盘时才允许同步（符合「必须配置好网盘才可同步」）；
///   WebDAV 类型走 HTTP PUT 真实上传，其余类型仅保存配置、暂未接入同步通道。
/// 同步不引入新依赖，WebDAV 上传使用 [dart:io] 的 [HttpClient]（HTTP Basic 鉴权）。
class CloudDriveService {
  /// 当前已配置的云盘列表（每次读取自内存镜像）。
  static List<CloudDriveConfig> get drives =>
      SettingsEngine.cloudDrives.map(CloudDriveConfig.fromJson).toList();

  /// 是否存在「支持同步」的云盘（当前指 WebDAV）。
  static bool get hasSyncCapableDrive =>
      drives.any((d) => d.supportsSync);

  /// 是否已配置任意云盘（同步按钮的启用门禁）。
  static bool get hasAnyDrive => drives.isNotEmpty;

  /// 保存（新增或更新）一条云盘配置并落盘。
  static void save(CloudDriveConfig config) {
    final list = drives;
    final idx = list.indexWhere((d) => d.id == config.id);
    if (idx < 0) {
      list.add(config);
    } else {
      list[idx] = config;
    }
    _persist(list);
  }

  /// 删除一条云盘配置并落盘。
  static void delete(String id) {
    final list = drives.where((d) => d.id != id).toList();
    _persist(list);
  }

  static void _persist(List<CloudDriveConfig> list) {
    SettingsEngine.cloudDrives = list.map((d) => d.toJson()).toList();
  }

  /// 将备份字节同步到所有「支持同步」的云盘（当前 WebDAV）。
  ///
  /// 逐盘顺序同步，单盘失败不影响其余盘（[CloudDriveSyncResult.error] 记录原因），
  /// 天然具备「多盘容错」：某盘网络异常不会中断其它盘。每完成一盘回调一次
  /// [onProgress]（已完成盘数 / 总盘数），供 UI 展示进度条。无任何可同步云盘时
  /// 返回空列表，调用方应先用 [hasSyncCapableDrive] 判断并提示。
  static Future<List<CloudDriveSyncResult>> sync(
    Uint8List bytes, {
    ValueChanged<double>? onProgress,
  }) async {
    final targets = drives.where((d) => d.supportsSync).toList();
    final results = <CloudDriveSyncResult>[];
    for (var i = 0; i < targets.length; i++) {
      results.add(await _uploadWebdav(targets[i], bytes));
      // 按已完成盘数 / 总盘数上报进度（最后一盘完成后达到 1.0）。
      onProgress?.call((i + 1) / targets.length);
    }
    return results;
  }

  /// WebDAV 上传：MKCOL 建目录（忽略失败）+ PUT 写入备份文件。
  /// 允许自签名证书（个人 NAS 常见），通过 badCertificateCallback 放行。
  static Future<CloudDriveSyncResult> _uploadWebdav(
    CloudDriveConfig drive,
    Uint8List bytes,
  ) async {
    final client = HttpClient()..badCertificateCallback = (_, __, ___) => true;
    try {
      final base = drive.url.trim();
      if (base.isEmpty) {
        return CloudDriveSyncResult(drive, false, '服务器地址为空');
      }
      final remoteDir = drive.remotePath.trim().replaceAll(RegExp(r'^/+'), '');
      final fileName = 'reading_backup.json';
      final dirUri = Uri.parse(_joinUrl(base, remoteDir));
      final fileUri = Uri.parse(_joinUrl(base, remoteDir, fileName));

      // 先尝试建目录（多数 WebDAV 服务器支持，失败不影响后续 PUT）。
      try {
        final mkcol = await client.openUrl('MKCOL', dirUri);
        final mkcolResp = await mkcol.close();
        await mkcolResp.drain<void>();
      } catch (_) {
        // 目录可能已存在或无 MKCOL 权限，忽略。
      }

      final req = await client.openUrl('PUT', fileUri);
      req.headers.set(
        'Authorization',
        'Basic ${base64Encode(utf8.encode('${drive.username}:${drive.password}'))}',
      );
      req.headers.contentType =
          ContentType('application', 'json', charset: 'utf-8');
      req.contentLength = bytes.length;
      req.add(bytes);
      final resp = await req.close();
      final status = resp.statusCode;
      await resp.drain<void>();
      final ok = status >= 200 && status < 300;
      return CloudDriveSyncResult(drive, ok, ok ? null : 'HTTP $status');
    } catch (e) {
      return CloudDriveSyncResult(drive, false, e.toString());
    } finally {
      client.close(force: true);
    }
  }

  static String _joinUrl(String base, String dir, [String? fileName]) {
    var u = base;
    if (!u.endsWith('/')) u += '/';
    if (dir.isNotEmpty) u += '$dir/';
    if (fileName != null) u += fileName;
    return u;
  }
}

/// 单条云盘的同步结果（成功/失败原因）。
class CloudDriveSyncResult {
  final CloudDriveConfig drive;
  final bool success;
  final String? error;

  const CloudDriveSyncResult(this.drive, this.success, this.error);
}
