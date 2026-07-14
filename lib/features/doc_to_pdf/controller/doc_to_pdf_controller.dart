import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../model/doc_to_pdf_model.dart';
import '../service/doc_to_pdf_service.dart';

/// DocToPdfController 负责处理DOC转PDF的业务逻辑
/// 调用DocToPdfService进行实际转换
class DocToPdfController {
  DocToPdfController._();

  /// 请求文件访问权限
  ///
  /// 返回权限是否已授予
  static Future<bool> _requestStoragePermission() async {
    try {
      // 检查当前平台
      if (Platform.isAndroid) {
        // Android 13+ 需要请求存储权限
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

  /// 选择单个DOC/DOCX文件
  ///
  /// 返回选中的DOC文件路径，若用户取消或权限被拒绝，返回null
  static Future<String?> selectDocFile() async {
    try {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        debugPrint('用户拒绝了存储权限');
        return null;
      }

      // 选择单个文件
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['doc', 'docx'],
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

  /// 执行DOC转PDF的转换操作
  ///
  /// 参数：
  /// - [docFilePath] DOC文件路径
  /// - [pdfFileName] 输出PDF文件名
  ///
  /// 返回转换结果
  static Future<ConversionResult> convertToPdf({
    required String docFilePath,
    required String pdfFileName,
  }) async {
    return DocToPdfService.convertDocToPdf(
      docFilePath: docFilePath,
      outputFileName: pdfFileName,
    );
  }

  /// 获取所有转换记录
  static Future<List<ExportRecord>> getExportRecords() async {
    return DocToPdfService.getExportRecords();
  }

  /// 保存转换记录
  static Future<void> saveExportRecord({
    required String sourceFileName,
    required String pdfFileName,
    required String filePath,
  }) async {
    return DocToPdfService.saveExportRecord(
      sourceFileName: sourceFileName,
      pdfFileName: pdfFileName,
      filePath: filePath,
    );
  }

  /// 删除转换记录及其文件（按时间戳唯一标识）
  static Future<bool> deleteExportRecord(int timestamp) async {
    return DocToPdfService.deleteExportRecord(timestamp);
  }
}
