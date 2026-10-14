import 'parking_photo.dart';
import '../domain/parking_session.dart';

abstract interface class ParkingSessionRepository {
  Future<ParkingSessionSaveResult> save({
    required ParkingSession session,
    ParkingPhoto? photo,
  });

  Future<ParkingSessionCleanupResult> retryCleanup({
    required String sessionId,
    required String photoPath,
  });
}

abstract interface class ParkingSessionStore {
  Future<String> insert(Map<String, dynamic> values);

  Future<void> setPhotoPath({
    required String sessionId,
    required String photoPath,
  });

  Future<void> delete({required String sessionId});
}

abstract interface class VehiclePhotoStorage {
  Future<void> upload({required String path, required ParkingPhoto photo});

  Future<void> remove({required String path});
}

sealed class ParkingSessionSaveResult {
  const ParkingSessionSaveResult();
}

final class ParkingSessionSaveSuccess extends ParkingSessionSaveResult {
  const ParkingSessionSaveSuccess({required this.session});

  final ParkingSession session;
}

final class ParkingSessionSaveFailure extends ParkingSessionSaveResult {
  const ParkingSessionSaveFailure({
    required this.message,
    this.sessionId,
    this.photoPath,
    this.cleanupRequired = false,
  });

  final String message;
  final String? sessionId;
  final String? photoPath;
  final bool cleanupRequired;
}

sealed class ParkingSessionCleanupResult {
  const ParkingSessionCleanupResult();
}

final class ParkingSessionCleanupSuccess extends ParkingSessionCleanupResult {
  const ParkingSessionCleanupSuccess();
}

final class ParkingSessionCleanupFailure extends ParkingSessionCleanupResult {
  const ParkingSessionCleanupFailure({
    required this.message,
    required this.sessionId,
    required this.photoPath,
  });

  final String message;
  final String sessionId;
  final String photoPath;
}
