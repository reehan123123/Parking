import 'dart:async';

import 'package:parking_management/features/parking/data/parking_photo.dart';
import 'package:parking_management/features/parking/data/parking_session_repository.dart';
import 'package:parking_management/features/parking/domain/parking_session.dart';
import 'package:parking_management/features/tenants/domain/parking_tenant_scope.dart';

class TestParkingSessionRepository implements ParkingSessionRepository {
  TestParkingSessionRepository({
    this.sessions = const [],
    this.summaryValue = const ParkingSessionSummary(
      activeCount: 0,
      expiredCount: 0,
    ),
    this.listResult,
    this.summaryResult,
    this.detailResult,
    this.photoUrlResult,
    this.updateResult,
    this.deleteResult,
    this.saveResult,
  });

  List<ParkingSession> sessions;
  ParkingSessionSummary summaryValue;
  ParkingSessionListResult? listResult;
  Completer<ParkingSessionListResult>? nextListCompleter;
  ParkingSessionSummaryResult? summaryResult;
  ParkingSessionDetailResult? detailResult;
  ParkingSessionPhotoUrlResult? photoUrlResult;
  ParkingSessionUpdateResult? updateResult;
  ParkingSessionDeleteResult? deleteResult;
  ParkingSessionSaveResult? saveResult;
  String? lastSearch;
  int listCalls = 0;
  int summaryCalls = 0;
  int detailCalls = 0;
  int deleteCalls = 0;
  String? lastDetailSessionId;
  int lastOffset = 0;
  int lastPageSize = 50;
  ParkingTenantScope? lastScope;
  ParkingSession? updatedSession;
  ParkingPhoto? replacementPhoto;

  @override
  Future<ParkingSessionListResult> list({
    required ParkingTenantScope scope,
    String search = '',
    int offset = 0,
    int pageSize = 50,
  }) async {
    listCalls++;
    lastScope = scope;
    lastSearch = search;
    lastOffset = offset;
    lastPageSize = pageSize;
    final configuredResult = listResult;
    if (configuredResult != null) {
      return configuredResult;
    }

    final completer = nextListCompleter;
    if (completer != null) {
      nextListCompleter = null;
      return completer.future;
    }

    final page = sessions.skip(offset).take(pageSize).toList(growable: false);
    return ParkingSessionListSuccess(
      sessions: List.unmodifiable(page),
      hasMore: sessions.length > offset + pageSize,
    );
  }

  @override
  Future<ParkingSessionSummaryResult> summary({
    required ParkingTenantScope scope,
  }) async {
    summaryCalls++;
    lastScope = scope;
    return summaryResult ?? ParkingSessionSummarySuccess(summary: summaryValue);
  }

  @override
  Future<ParkingSessionDetailResult> getById({
    required String sessionId,
  }) async {
    detailCalls++;
    lastDetailSessionId = sessionId;
    if (detailResult != null) {
      return detailResult!;
    }

    for (final session in sessions) {
      if (session.id == sessionId) {
        return ParkingSessionDetailSuccess(session: session);
      }
    }

    return const ParkingSessionDetailFailure(message: 'Session not found.');
  }

  @override
  Future<ParkingSessionPhotoUrlResult> createSignedPhotoUrl({
    required String sessionId,
    required String photoPath,
    int expiresInSeconds = 300,
  }) async {
    return photoUrlResult ??
        const ParkingSessionPhotoUrlFailure(message: 'Photo unavailable.');
  }

  @override
  Future<ParkingSessionSaveResult> save({
    required ParkingSession session,
    ParkingPhoto? photo,
  }) async {
    return saveResult ?? ParkingSessionSaveSuccess(session: session);
  }

  @override
  Future<ParkingSessionUpdateResult> update({
    required ParkingSession session,
    ParkingPhoto? replacementPhoto,
  }) async {
    updatedSession = session;
    this.replacementPhoto = replacementPhoto;
    return updateResult ?? ParkingSessionUpdateSuccess(session: session);
  }

  @override
  Future<ParkingSessionDeleteResult> delete({
    required ParkingSession session,
  }) async {
    deleteCalls++;
    return deleteResult ?? const ParkingSessionDeleteSuccess();
  }

  @override
  Future<ParkingSessionCleanupResult> retryCleanup({
    required String sessionId,
    required String photoPath,
  }) async {
    return const ParkingSessionCleanupSuccess();
  }

  @override
  Future<ParkingPhotoCleanupResult> retryPhotoCleanup({
    required String photoPath,
  }) async {
    return const ParkingPhotoCleanupSuccess();
  }
}
