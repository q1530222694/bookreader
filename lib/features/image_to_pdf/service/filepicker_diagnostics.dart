// 诊断工具：用于调试 FilePicker 的问题
import 'dart:io';
import 'package:flutter/foundation.dart';

class FilepickerDiagnostics {
  /// 输出系统信息和权限配置信息
  static void printDiagnostics() {
    debugPrint('=== FilePicker 诊断信息 ===');
    
    // 平台信息
    if (Platform.isAndroid) {
      debugPrint('平台: Android');
    } else if (Platform.isIOS) {
      debugPrint('平台: iOS');
    } else if (Platform.isWindows) {
      debugPrint('平台: Windows');
    } else if (Platform.isMacOS) {
      debugPrint('平台: macOS');
    } else if (Platform.isLinux) {
      debugPrint('平台: Linux');
    }
    
    // 检查存储目录
    try {
      final docDir = Directory(Platform.pathSeparator);
      debugPrint('存储路径可访问: ${docDir.existsSync()}');
    } catch (e) {
      debugPrint('存储路径检查失败: $e');
    }
    
    debugPrint('=== 诊断信息输出完成 ===');
  }

  /// 将诊断信息写入临时文件，便于在设备上抓取日志
  /// 【Windows/Mac 崩溃修复】仅使用 debugPrint，移除高频文件 I/O 操作
  /// 原因：在 selectImages() 高频循环中执行 FileMode.append 会导致文件句柄死锁
  /// 导致 Windows 和 Mac 应用崩溃（特别是多图导入场景）
  static Future<void> writeLog(String msg) async {
    // 【FIX】注释掉文件写入逻辑，仅保留调试输出
    // 如需持久化日志，应该使用异步队列或后台隔离区
    debugPrint('[ImageToPdf] $msg');
    
    // 【旧代码 - 已禁用】
    // try {
    //   final tempDir = Directory.systemTemp;
    //   final logFile = File('${tempDir.path}${Platform.pathSeparator}filepicker_debug.log');
    //   final line = '${DateTime.now().toIso8601String()} $msg\n';
    //   await logFile.writeAsString(line, mode: FileMode.append, flush: true);
    //   debugPrint('诊断日志已写入: ${logFile.path}');
    // } catch (e) {
    //   debugPrint('写入诊断日志失败: $e');
    // }
  }
}
