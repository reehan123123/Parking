import 'parking_photo.dart';

/// Reports OCR worker progress to the caller.
typedef ParkingOcrProgressCallback = void Function(ParkingOcrProgress progress);

/// Describes progress reported by the local OCR worker.
class ParkingOcrProgress {
  /// Creates an OCR progress value.
  ParkingOcrProgress({required this.status, required double fraction})
    : fraction = fraction.clamp(0.0, 1.0).toDouble();

  /// Describes the current OCR stage.
  final String status;

  /// Represents progress from zero to one.
  final double fraction;
}

/// Allows an OCR request to be cancelled by the presentation layer.
class ParkingOcrCancellationToken {
  bool _isCancelled = false;
  final List<void Function()> _listeners = [];

  /// Indicates whether cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// Registers a callback that releases the active OCR operation.
  void addCancellationListener(void Function() listener) {
    if (_isCancelled) {
      listener();
      return;
    }

    _listeners.add(listener);
  }

  /// Requests cancellation once.
  void cancel() {
    if (_isCancelled) {
      return;
    }

    _isCancelled = true;
    final listeners = List<void Function()>.from(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }
}

/// Represents a result from a local OCR attempt.
sealed class ParkingOcrResult {
  const ParkingOcrResult();
}

/// Contains text returned by the OCR engine.
final class ParkingOcrTextResult extends ParkingOcrResult {
  /// Creates a text result.
  const ParkingOcrTextResult({required this.rawText});

  /// The unmodified text returned by the OCR engine.
  final String rawText;
}

/// Indicates that the OCR engine completed without finding text.
final class ParkingOcrNoTextResult extends ParkingOcrResult {
  /// Creates an empty OCR result.
  const ParkingOcrNoTextResult();
}

/// Indicates that local OCR is unavailable in the current build or browser.
final class ParkingOcrUnavailableResult extends ParkingOcrResult {
  /// Creates an unavailable result.
  const ParkingOcrUnavailableResult({required this.message});

  /// Explains why OCR cannot be used.
  final String message;
}

/// Indicates that the user cancelled OCR.
final class ParkingOcrCancelledResult extends ParkingOcrResult {
  /// Creates a cancelled result.
  const ParkingOcrCancelledResult();
}

/// Indicates that OCR failed but the user can continue manually.
final class ParkingOcrFailureResult extends ParkingOcrResult {
  /// Creates a failure result.
  const ParkingOcrFailureResult({required this.message});

  /// Explains the recoverable OCR failure.
  final String message;
}

/// Runs OCR without knowing about Flutter widgets or persistence.
abstract interface class ParkingOcrService {
  /// Recognizes text from an in-memory vehicle photo.
  Future<ParkingOcrResult> recognize({
    required ParkingPhoto photo,
    required ParkingOcrCancellationToken cancellationToken,
    required ParkingOcrProgressCallback onProgress,
  });
}
