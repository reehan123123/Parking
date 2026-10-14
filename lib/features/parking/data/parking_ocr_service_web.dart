import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'parking_ocr_service_common.dart';
import 'parking_photo.dart';

@JS()
extension type _ParkingOcrBridge._(JSObject _) implements JSObject {
  external _ParkingOcrOperation start(
    String base64Image,
    String mimeType,
    JSFunction onProgress,
  );

  external void cancel(String operationId);
}

@JS()
extension type _ParkingOcrOperation._(JSObject _) implements JSObject {
  external String get id;

  external JSPromise<JSString> get promise;
}

@JS('ParkingOcr')
external _ParkingOcrBridge? get _parkingOcr;

/// Runs Tesseract.js through the local browser adapter.
class WebParkingOcrService implements ParkingOcrService {
  /// Creates a Web OCR service.
  const WebParkingOcrService({this.timeout = const Duration(seconds: 30)});

  /// Bounds each OCR attempt so the entry form cannot remain loading forever.
  final Duration timeout;

  @override
  Future<ParkingOcrResult> recognize({
    required ParkingPhoto photo,
    required ParkingOcrCancellationToken cancellationToken,
    required ParkingOcrProgressCallback onProgress,
  }) async {
    if (cancellationToken.isCancelled) {
      return const ParkingOcrCancelledResult();
    }

    final bridge = _parkingOcr;
    if (bridge == null) {
      return const ParkingOcrUnavailableResult(
        message: 'Local OCR is unavailable. Enter the registration manually.',
      );
    }

    String? operationId;
    final progressCallback = ((JSString value) {
      final progress = _decodeProgress(value.toDart);
      if (progress != null && !cancellationToken.isCancelled) {
        onProgress(progress);
      }
    }).toJS;

    try {
      final operation = bridge.start(
        base64Encode(photo.bytes),
        photo.mimeType ?? 'image/jpeg',
        progressCallback,
      );

      operationId = operation.id;
      cancellationToken.addCancellationListener(
        () => _cancelOperation(bridge, operationId),
      );

      final rawText = await operation.promise.toDart.timeout(
        timeout,
        onTimeout: () {
          _cancelOperation(bridge, operationId);
          throw const _ParkingOcrTimeoutException();
        },
      );

      if (cancellationToken.isCancelled) {
        return const ParkingOcrCancelledResult();
      }

      if (rawText.toDart.trim().isEmpty) {
        return const ParkingOcrNoTextResult();
      }

      return ParkingOcrTextResult(rawText: rawText.toDart);
    } on _ParkingOcrTimeoutException {
      return const ParkingOcrFailureResult(
        message:
            'OCR took too long. Enter the registration manually or try again.',
      );
    } on Exception {
      if (cancellationToken.isCancelled) {
        return const ParkingOcrCancelledResult();
      }

      return const ParkingOcrFailureResult(
        message: 'The local OCR engine failed. Enter the registration manually or try again.',
      );
    }
  }

  ParkingOcrProgress? _decodeProgress(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        return null;
      }

      final status = decoded['status'];
      final fraction = decoded['progress'];
      if (status is! String || fraction is! num) {
        return null;
      }

      return ParkingOcrProgress(status: status, fraction: fraction.toDouble());
    } on FormatException {
      return null;
    }
  }

  void _cancelOperation(_ParkingOcrBridge bridge, String? operationId) {
    if (operationId == null) {
      return;
    }

    try {
      bridge.cancel(operationId);
    } on Object {
      // Cancellation is best effort; the request state still prevents UI updates.
    }
  }
}

class _ParkingOcrTimeoutException implements Exception {
  const _ParkingOcrTimeoutException();
}

/// Creates the Web OCR implementation.
ParkingOcrService createParkingOcrService() {
  return const WebParkingOcrService();
}
