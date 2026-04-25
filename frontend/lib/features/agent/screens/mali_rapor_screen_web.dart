// Mali Rapor web implementation
import 'dart:convert';
import 'package:web/web.dart' as web;

void triggerMaliRaporWebDownload(List<int> bytes, String fileName) {
  final base64 = base64Encode(bytes);
  web.HTMLAnchorElement()
    ..href = 'data:application/vnd.openxmlformats-officedocument.spreadsheetml.sheet;base64,$base64'
    ..download = fileName
    ..click();
}
