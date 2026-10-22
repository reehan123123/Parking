import 'parking_photo.dart';
import '../domain/parking_session.dart';
import '../../tenants/domain/parking_tenant_scope.dart';

abstract interface class ParkingSessionRepository {
  Future<ParkingSessionListResult> list({
    required ParkingTenantScope scope,
    String search = '',
    int offset = 0,
    int pageSize = 50,
  });

  Future<ParkingSessionSummaryResult> summary({
    required ParkingTenantScope scope,
  });

  Future<ParkingSessionDetailResult> getById({required String sessionId});

  Future<ParkingSessionPhotoUrlResult> createSignedPhotoUrl({
    required String sessionId,
    required String photoPath,
    int expiresInSeconds = 300,
  });

  Future<ParkingSessionSaveResult> save({
    required ParkingSession session,
    ParkingPhoto? photo,
  });

  Future<ParkingSessionUpdateResult> update({
    required ParkingSession session,
    ParkingPhoto? replacementPhoto,
  });

  Future<ParkingSessionDeleteResult> delete({required ParkingSession session});

  /// Marks the remaining parking charge as paid through the authorized store.
  Future<ParkingSessionPaymentResult> markFullyPaid({
    required String sessionId,
  });

  Future<ParkingSessionCleanupResult> retryCleanup({
    required String sessionId,
    required String photoPath,
  });

  Future<ParkingPhotoCleanupResult> retryPhotoCleanup({
    required String photoPath,
  });
}

abstract interface class ParkingSessionStore {
  Future<String> insert(Map<String, dynamic> values);

  Future<List<Map<String, dynamic>>> list({
    required ParkingTenantScope scope,
    required int offset,
    required int limit,
    String? search,
  });

  Future<ParkingSessionSummary> summary({
    required ParkingTenantScope scope,
    required DateTime asOf,
  });

  Future<Map<String, dynamic>?> find({required String sessionId});

  Future<void> setPhotoPath({
    required String sessionId,
    required String photoPath,
  });

  Future<void> completePhotoUpload({required String sessionId});

  Future<void> update({
    required String sessionId,
    required Map<String, dynamic> values,
  });

  Future<void> delete({required String sessionId});

  Future<bool> markFullyPaid({required String sessionId});
}

abstract interface class VehiclePhotoStorage {
  Future<void> upload({
    required String path,
    required ParkingPhoto photo,
    bool upsert = false,
  });

  Future<void> remove({required String path});

  Future<String> createSignedUrl({
    required String path,
    required int expiresInSeconds,
  });
}

final class ParkingSessionSummary {
  const ParkingSessionSummary({
    required this.activeCount,
    required this.expiredCount,
  });

  final int activeCount;
  final int expiredCount;
}

sealed class ParkingSessionListResult {
  const ParkingSessionListResult();
}

final class ParkingSessionListSuccess extends ParkingSessionListResult {
  const ParkingSessionListSuccess({
    required this.sessions,
    this.hasMore = false,
  });

  final List<ParkingSession> sessions;
  final bool hasMore;
}

final class ParkingSessionListFailure extends ParkingSessionListResult {
  const ParkingSessionListFailure({required this.message});

  final String message;
}

sealed class ParkingSessionSummaryResult {
  const ParkingSessionSummaryResult();
}

final class ParkingSessionSummarySuccess extends ParkingSessionSummaryResult {
  const ParkingSessionSummarySuccess({required this.summary});

  final ParkingSessionSummary summary;
}

final class ParkingSessionSummaryFailure extends ParkingSessionSummaryResult {
  const ParkingSessionSummaryFailure({required this.message});

  final String message;
}

sealed class ParkingSessionDetailResult {
  const ParkingSessionDetailResult();
}

final class ParkingSessionDetailSuccess extends ParkingSessionDetailResult {
  const ParkingSessionDetailSuccess({required this.session});

  final ParkingSession session;
}

final class ParkingSessionDetailFailure extends ParkingSessionDetailResult {
  const ParkingSessionDetailFailure({required this.message});

  final String message;
}

sealed class ParkingSessionPhotoUrlResult {
  const ParkingSessionPhotoUrlResult();
}

final class ParkingSessionPhotoUrlSuccess extends ParkingSessionPhotoUrlResult {
  const ParkingSessionPhotoUrlSuccess({required this.url});

  final String url;
}

final class ParkingSessionPhotoUrlFailure extends ParkingSessionPhotoUrlResult {
  const ParkingSessionPhotoUrlFailure({required this.message});

  final String message;
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

sealed class ParkingSessionUpdateResult {
  const ParkingSessionUpdateResult();
}

final class ParkingSessionUpdateSuccess extends ParkingSessionUpdateResult {
  const ParkingSessionUpdateSuccess({required this.session});

  final ParkingSession session;
}

final class ParkingSessionUpdateFailure extends ParkingSessionUpdateResult {
  const ParkingSessionUpdateFailure({
    required this.message,
    required this.sessionId,
    this.photoPath,
    this.cleanupRequired = false,
  });

  final String message;
  final String sessionId;
  final String? photoPath;
  final bool cleanupRequired;
}

sealed class ParkingSessionDeleteResult {
  const ParkingSessionDeleteResult();
}

final class ParkingSessionDeleteSuccess extends ParkingSessionDeleteResult {
  const ParkingSessionDeleteSuccess();
}

final class ParkingSessionDeleteFailure extends ParkingSessionDeleteResult {
  const ParkingSessionDeleteFailure({
    required this.message,
    required this.sessionId,
  });

  final String message;
  final String sessionId;
}

sealed class ParkingSessionPaymentResult {
  const ParkingSessionPaymentResult();
}

final class ParkingSessionPaymentSuccess extends ParkingSessionPaymentResult {
  const ParkingSessionPaymentSuccess({required this.wasMarkedPaid});

  final bool wasMarkedPaid;
}

final class ParkingSessionPaymentFailure extends ParkingSessionPaymentResult {
  const ParkingSessionPaymentFailure({required this.message});

  final String message;
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

sealed class ParkingPhotoCleanupResult {
  const ParkingPhotoCleanupResult();
}

final class ParkingPhotoCleanupSuccess extends ParkingPhotoCleanupResult {
  const ParkingPhotoCleanupSuccess();
}

final class ParkingPhotoCleanupFailure extends ParkingPhotoCleanupResult {
  const ParkingPhotoCleanupFailure({
    required this.message,
    required this.photoPath,
  });

  final String message;
  final String photoPath;
}
