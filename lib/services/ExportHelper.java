import 'dart:io';
import 'package:excel/excel.dart' as excel_lib;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// Shared helpers for the "Export to Excel" buttons.
class ExportHelper {
  /// Makes a string safe to use inside a file name.
  static String safe(String s) {
    final cleaned = s.trim().replaceAll(RegExp(r'[^\w\-]+'), '_');
    return cleaned.isEmpty ? 'NA' : cleaned;
  }

  /// Today's date as ddMMyyyy (used as a file-name suffix).
  static String today() => DateFormat('ddMMyyyy').format(DateTime.now());

  /// Creates a named sheet and removes the empty default "Sheet1".
  static excel_lib.Sheet newSheet(excel_lib.Excel excel, String name) {
    final sheet = excel[name];
    if (name != 'Sheet1') {
      try {
        excel.delete('Sheet1');
      } catch (_) {}
    }
    return sheet;
  }

  /// Writes the workbook to disk and returns the full path (null on failure).
  static Future<String?> saveExcel(
      excel_lib.Excel excel, String fileName) async {
    final bytes = excel.save();
    if (bytes == null) return null;

    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory();
    }
    dir ??= await getApplicationDocumentsDirectory();

    final path = '${dir.path}/$fileName';
    await File(path).writeAsBytes(bytes);
    return path;
  }
}