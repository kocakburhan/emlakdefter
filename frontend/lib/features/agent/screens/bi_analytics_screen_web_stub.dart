// Stub for non-web platforms
import 'dart:typed_data';

void triggerWebDownload(List<int> bytes, String fileName) {
  throw UnsupportedError('Web download is only supported on web platforms');
}

void triggerExcelWebDownload(List<int> bytes, String fileName) {
  throw UnsupportedError('Web download is only supported on web platforms');
}
