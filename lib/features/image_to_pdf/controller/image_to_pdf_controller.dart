import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../model/export_record_model.dart';
import '../model/image_to_pdf_model.dart';
import '../service/image_to_pdf_service.dart';
import '../service/filepicker_diagnostics.dart';

/// ImageToPdfController 负责处理图片转PDF的业务逻辑
/// 调用ImageToPdfService进行实际转换
class ImageToPdfController {
  ImageToPdfController._();

  /// 请求文件访问权限
  ///
  /// 返回权限是否已授予
  static Future<bool> _requestStoragePermission() async {
    try {
      // 检查当前平台
      if (Platform.isAndroid) {
        // Android 13+ 需要请求 READ_MEDIA_IMAGES 权限
        final photosStatus = await Permission.photos.request();
        if (photosStatus.isGranted) {
          return true;
        }

        // 降级方案：请求 READ_EXTERNAL_STORAGE（用于 Android 6-12）
        final status = await Permission.storage.request();
        return status.isGranted;
      } else if (Platform.isIOS) {
        // iOS 需要请求 photos 权限
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

  /// 选择多张图片文件
  ///
  /// 返回选中的图片文件路径列表（按用户选择顺序）
  /// 若用户取消或权限被拒绝，返回空列表
  /// 选择多张图片文件
  static Future<List<String>> selectImages() async {
    try {
      FilepickerDiagnostics.printDiagnostics();
      
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        debugPrint('用户拒绝了存储权限');
        return [];
      }

      // 注意：千万不要在这里加 withData: true，否则选择多图时直接 OOM 崩溃
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        return [];
      }

      final imagePaths = <String>[];
      
      // 使用索引来避免相同时间戳导致的文件名冲突
      for (int i = 0; i < result.files.length; i++) {
        final file = result.files[i];
        String? filePath = file.path;

        // 处理偶尔出现的纯 content:// 且无物理路径的情况
        if (filePath != null && filePath.startsWith('content://')) {
          // 由于没有启用 withData: true，我们不能依赖 file.bytes
          // 如果真的遇到未被插件自动缓存的 content URI，建议忽略或使用 native channel 专门处理
          debugPrint('警告: 遇到无法解析的 content URI: $filePath');
          continue; 
        }

        // 校验文件是否真实存在
        if (filePath != null && filePath.isNotEmpty) {
          try {
            final f = File(filePath);
            if (await f.exists()) {
              imagePaths.add(filePath);
            } else if (file.bytes != null) {
              // 仅兼容 Web 端或明确要求使用 bytes 的特殊场景
              final recovered = await _saveBytesToTempFile(file.bytes!, file.name, i);
              if (recovered != null) {
                imagePaths.add(recovered);
              }
            }
          } catch (e) {
            debugPrint('校验选中文件失败，跳过该文件: $e');
            continue;
          }
        }
      }

      return imagePaths;
    } catch (e) {
      debugPrint('选择图片时发生错误: $e');
      return [];
    }
  }

  /// 将字节数据保存到临时文件 (修复了高并发文件名冲突)
  static Future<String?> _saveBytesToTempFile(
    Uint8List bytes,
    String fileName,
    int index, // 传入索引确保唯一性
  ) async {
    try {
      final tempDir = Directory.systemTemp;
      // 加上 index 和 hash，彻底杜绝高并发重名
      final fileNameUnique = '${DateTime.now().millisecondsSinceEpoch}_${index}_$fileName';
      final tempFile = File('${tempDir.path}${Platform.pathSeparator}$fileNameUnique');

      await tempFile.writeAsBytes(bytes);
      debugPrint('已保存临时文件: ${tempFile.path}');
      return tempFile.path;
    } catch (e) {
      debugPrint('保存临时文件失败: $e');
      return null;
    }
  }

  /// 调整图片顺序（将指定索引的图片移到新位置）
  ///
  /// 参数：
  /// - [images] 原始图片列表
  /// - [oldIndex] 原始索引
  /// - [newIndex] 新索引
  ///
  /// 返回排序后的图片列表
  static List<String> reorderImages(
    List<String> images,
    int oldIndex,
    int newIndex,
  ) {
    final result = List<String>.from(images);
    
    // 处理边界情况
    if (oldIndex < 0 || oldIndex >= result.length) {
      return result;
    }
    if (newIndex < 0 || newIndex > result.length) {
      return result;
    }
    
    // 执行移动操作
    final item = result.removeAt(oldIndex);
    result.insert(newIndex, item);
    
    return result;
  }

  /// 将选中的图片转换为PDF
  ///
  /// 参数：
  /// - [imagePaths] 图片文件路径列表（按转换顺序）
  /// - [pdfFileName] 输出PDF文件名，默认为 "output.pdf"
  ///
  /// 返回转换结果，包含导出记录信息
  static Future<ConversionResult> convertToPdf({
    required List<String> imagePaths,
    String pdfFileName = 'output.pdf',
  }) async {
    final result = await ImageToPdfService.convertImagesToSinglePdf(
      imagePaths: imagePaths,
      outputFileName: pdfFileName,
    );

    // 如果转换成功，保存导出记录
    if (result.success && result.filePath != null) {
      final pdfFile = File(result.filePath!);
      final fileSize = await pdfFile.length();
      
      final record = ExportRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filePath: result.filePath!,
        fileName: pdfFileName,
        imageCount: imagePaths.length,
        exportedAt: DateTime.now(),
        fileSize: fileSize,
      );
      
      await ImageToPdfService.saveExportRecord(record);
    }

    return result;
  }

  /// 获取所有导出记录列表
  static Future<List<ExportRecord>> getExportRecords() {
    return ImageToPdfService.getExportRecords();
  }

  /// 删除导出记录及其PDF文件
  ///
  /// 参数：[recordId] 要删除的记录ID
  ///
  /// 返回是否删除成功
  static Future<bool> deleteExportRecord(String recordId) {
    return ImageToPdfService.deleteExportRecord(recordId);
  }

  /// 将导出的PDF添加到书架
  ///
  /// 参数：
  /// - [record] 导出记录
  /// - [addToShelfCallback] 添加到书架的回调函数
  ///
  /// 返回是否添加成功
  static Future<bool> addExportedPdfToShelf(
    ExportRecord record,
    Future<bool> Function(File) addToShelfCallback,
  ) async {
    try {
      final pdfFile = File(record.filePath);
      
      // 检查文件是否存在
      if (!await pdfFile.exists()) {
        debugPrint('PDF文件不存在: ${record.filePath}');
        return false;
      }

      // 调用书架添加回调
      final success = await addToShelfCallback(pdfFile);

      if (success) {
        // 更新记录状态
        final updatedRecord = record.copyWith(addedToShelf: true);
        await ImageToPdfService.updateExportRecord(updatedRecord);
      }

      return success;
    } catch (e) {
      debugPrint('添加到书架失败: $e');
      return false;
    }
  }

  /// 获取导出的PDF的文件大小，格式化为可读字符串
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }
}
