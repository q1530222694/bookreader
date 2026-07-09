import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../model/txt_to_epub_model.dart';
import '../service/txt_to_epub_service.dart';

/// TxtToEpubController 负责处理TXT转EPUB的业务逻辑
/// 调用TxtToEpubService进行实际转换
class TxtToEpubController {
  TxtToEpubController._();

  /// 请求文件访问权限
  ///
  /// 返回权限是否已授予
  static Future<bool> _requestStoragePermission() async {
    try {
      // 检查当前平台
      if (Platform.isAndroid) {
        // Android 13+ 需要请求 READ_MEDIA_IMAGES 或 READ_MEDIA_DOCUMENTS 权限
        final status = await Permission.storage.request();
        return status.isGranted;
      } else if (Platform.isIOS) {
        // iOS 需要请求文件访问权限
        final status = await Permission.photos.request();
        return status.isGranted;
      }

      // 其他平台（如 Windows、Web）默认允许
      return true;
    } catch (e) {
      debugPrint('权限请求失败: $e');
      return false;
    }
  }

  /// 选择单个TXT文件
  ///
  /// 返回选中的TXT文件路径，若用户取消或权限被拒绝，返回null
  static Future<String?> selectTxtFile() async {
    try {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        debugPrint('用户拒绝了存储权限');
        return null;
      }

      // 选择单个文件
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final filePath = result.files.first.path;
      return filePath;
    } catch (e) {
      debugPrint('文件选择失败: $e');
      return null;
    }
  }

  /// 执行TXT转EPUB的转换操作
  ///
  /// 参数：
  /// - [txtFilePath] TXT文件路径
  /// - [epubFileName] 输出EPUB文件名
  /// - [bookTitle] 书籍标题（可选）
  ///
  /// 返回转换结果
  static Future<ConversionResult> convertToEpub({
    required String txtFilePath,
    required String epubFileName,
    String? bookTitle,
  }) async {
    return TxtToEpubService.convertTxtToEpub(
      txtFilePath: txtFilePath,
      outputFileName: epubFileName,
      bookTitle: bookTitle,
    );
  }

  /// 获取所有转换记录
  static Future<List<ExportRecord>> getExportRecords() async {
    return TxtToEpubService.getExportRecords();
  }

  /// 保存转换记录
  static Future<void> saveExportRecord(ExportRecord record) async {
    return TxtToEpubService.saveExportRecord(record);
  }
}
