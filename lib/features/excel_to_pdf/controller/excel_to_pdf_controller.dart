import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../model/excel_to_pdf_model.dart';
import '../service/excel_to_pdf_service.dart';

class ExcelToPdfController {
  ExcelToPdfController._();

  static Future<bool> _requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        return status.isGranted;
      } else if (Platform.isIOS) {
        final status = await Permission.photos.request();
        return status.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('权限请求失败: $e');
      return false;
    }
  }

  static Future<String?> selectExcelFile() async {
    try {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) return null;

      final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['xls', 'xlsx'], allowMultiple: false);
      if (result == null || result.files.isEmpty) return null;
      return result.files.first.path;
    } catch (e) {
      debugPrint('文件选择失败: $e');
      return null;
    }
  }

  static Future<ConversionResult> convertToPdf({required String excelFilePath, required String pdfFileName}) async {
    return ExcelToPdfService.convertExcelToPdf(excelFilePath: excelFilePath, outputFileName: pdfFileName);
  }

  static Future<List<ExportRecord>> getExportRecords() async {
    return ExcelToPdfService.getExportRecords();
  }

  static Future<void> saveExportRecord({required String sourceFileName, required String pdfFileName, required String filePath}) async {
    return ExcelToPdfService.saveExportRecord(sourceFileName: sourceFileName, pdfFileName: pdfFileName, filePath: filePath);
  }
}
