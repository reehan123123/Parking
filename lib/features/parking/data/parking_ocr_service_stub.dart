import 'parking_ocr_service_common.dart';
import 'parking_photo.dart';

/// Creates the non-Web OCR fallback.
ParkingOcrService createParkingOcrService() {
  return const _UnavailableParkingOcrService();
}

class _UnavailableParkingOcrService implements ParkingOcrService {
  const _UnavailableParkingOcrService();

  @override
  Future<ParkingOcrResult> recognize({
    required ParkingPhoto photo,
    required ParkingOcrCancellationToken cancellationToken,
    required ParkingOcrProgressCallback onProgress,
  }) async {
    if (cancellationToken.isCancelled) {
      return const ParkingOcrCancelledResult();
    }

    return const ParkingOcrUnavailableResult(
      message: 'Local OCR is unavailable in this build. Enter the registration manually.',
    );
  }
}
