import 'parking_ocr_service_common.dart';
import 'parking_ocr_service_stub.dart'
    if (dart.library.js_interop) 'parking_ocr_service_web.dart'
    as implementation;

/// Creates the OCR implementation for the current compilation target.
ParkingOcrService createParkingOcrService() {
  return implementation.createParkingOcrService();
}
