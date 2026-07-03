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
  static Future<void> writeLog(String msg) async {
    try {
      final tempDir = Directory.systemTemp;
      final logFile = File('${tempDir.path}${Platform.pathSeparator}filepicker_debug.log');
      final line = '${DateTime.now().toIso8601String()} $msg\n';
      await logFile.writeAsString(line, mode: FileMode.append, flush: true);
      debugPrint('诊断日志已写入: ${logFile.path}');
    } catch (e) {
      debugPrint('写入诊断日志失败: $e');
    }
  }
}
