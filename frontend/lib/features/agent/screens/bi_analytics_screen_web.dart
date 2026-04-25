// Web implementation for BI Analytics screen
import 'dart:convert';
import 'package:web/web.dart' as web;

void triggerWebDownload(List<int> bytes, String fileName) {
  final base64 = base64Encode(bytes);
  web.HTMLAnchorElement()
    ..href = 'data:application/pdf;base64,$base64'
    ..download = fileName
    ..click();
}

void triggerExcelWebDownload(List<int> bytes, String fileName) {
  final base64 = base64Encode(bytes);
  web.HTMLAnchorElement()
    ..href = 'data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,$base64'
    ..download = fileName
    ..click();
}
