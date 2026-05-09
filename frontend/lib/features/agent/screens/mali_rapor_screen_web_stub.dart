// Stub for non-web platforms (mobile/desktop)
import 'dart:typed_data';

void triggerMaliRaporWebDownload(List<int> bytes, String fileName) {
  throw UnsupportedError('Web download is only supported on web platforms');
}
