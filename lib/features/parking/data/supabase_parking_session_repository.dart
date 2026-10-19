import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/parking_duration.dart';
import '../domain/parking_duration_unit.dart';
import '../domain/parking_session.dart';
import 'parking_photo.dart';
import 'parking_session_repository.dart';
import '../../tenants/domain/parking_tenant_scope.dart';

const _parkingSessionColumns =
    'id,tenant_id,plate_number,photo_path,entry_time,allowed_duration_value,'
    'allowed_duration_unit,expires_at,created_by,created_at,updated_at';
const _maximumParkingSessionPageSize = 100;

class SupabaseParkingSessionRepository implements ParkingSessionRepository {
  SupabaseParkingSessionRepository(
    SupabaseClient? client, {
    ParkingSessionStore? sessionStore,
    VehiclePhotoStorage? photoStorage,
    String? Function()? currentUserId,
    DateTime Function()? now,
  }) : _sessionStore =
           sessionStore ?? _SupabaseParkingSessionStore(_requireClient(client)),
       _photoStorage =
           photoStorage ?? _SupabaseVehiclePhotoStorage(_requireClient(client)),
       _currentUserId = currentUserId ?? (() => client?.auth.currentUser?.id),
       _now = now ?? DateTime.now;

  final ParkingSessionStore _sessionStore;
  final VehiclePhotoStorage _photoStorage;
  final String? Function() _currentUserId;
  final DateTime Function() _now;

  @override
  Future<ParkingSessionListResult> list({
    required ParkingTenantScope scope,
    String search = '',
    int offset = 0,
    int pageSize = 50,
  }) async {
    final userId = _authenticatedUserId();
    if (userId == null) {
      return const ParkingSessionListFailure(
        message: 'Your sign-in session has expired. Sign in again and retry.',
      );
    }

    if (!scope.isValid) {
      return const ParkingSessionListFailure(
        message: 'Choose a tenant before loading parking sessions.',
      );
    }

    if (offset < 0 ||
        pageSize < 1 ||
        pageSize > _maximumParkingSessionPageSize) {
      return const ParkingSessionListFailure(
        message: 'The requested parking-session page is invalid.',
      );
    }

    try {
      final normalizedSearch = search.trim();
      final rows = await _sessionStore.list(
        scope: scope,
        offset: offset,
        limit: pageSize + 1,
        search: normalizedSearch.isEmpty ? null : normalizedSearch,
      );
      final hasMore = rows.length > pageSize;
      final pageRows = hasMore ? rows.take(pageSize) : rows;
      return ParkingSessionListSuccess(
        sessions: pageRows.map(_sessionFromRow).toList(growable: false),
        hasMore: hasMore,
      );
    } on Exception catch (error) {
      return ParkingSessionListFailure(message: _messageForReadError(error));
    }
  }

  @override
  Future<ParkingSessionSummaryResult> summary({
    required ParkingTenantScope scope,
  }) async {
    final userId = _authenticatedUserId();
    if (userId == null) {
      return const ParkingSessionSummaryFailure(
        message: 'Your sign-in session has expired. Sign in again and retry.',
      );
    }

    if (!scope.isValid) {
      return const ParkingSessionSummaryFailure(
        message: 'Choose a tenant before loading parking statistics.',
      );
    }

    try {
      final summary = await _sessionStore.summary(
        scope: scope,
        asOf: _now().toUtc(),
      );
      return ParkingSessionSummarySuccess(summary: summary);
    } on Exception catch (error) {
      return ParkingSessionSummaryFailure(message: _messageForReadError(error));
    }
  }

  @override
  Future<ParkingSessionDetailResult> getById({
    required String sessionId,
  }) async {
    final userId = _authenticatedUserId();
    if (userId == null) {
      return const ParkingSessionDetailFailure(
        message: 'Your sign-in session has expired. Sign in again and retry.',
      );
    }

    try {
      final row = await _sessionStore.find(sessionId: sessionId);
      if (row == null) {
        return const ParkingSessionDetailFailure(
          message: 'That parking session could not be found.',
        );
      }

      return ParkingSessionDetailSuccess(session: _sessionFromRow(row));
    } on Exception catch (error) {
      return ParkingSessionDetailFailure(message: _messageForReadError(error));
    }
  }

  @override
  Future<ParkingSessionPhotoUrlResult> createSignedPhotoUrl({
    required String sessionId,
    required String photoPath,
    int expiresInSeconds = 300,
  }) async {
    final userId = _authenticatedUserId();
    if (userId == null) {
      return const ParkingSessionPhotoUrlFailure(
        message: 'Your sign-in session has expired. Sign in again and retry.',
      );
    }

    if (expiresInSeconds <= 0) {
      return const ParkingSessionPhotoUrlFailure(
        message: 'The private photo link duration is invalid.',
      );
    }

    try {
      final row = await _sessionStore.find(sessionId: sessionId);
      if (row == null || row['photo_path'] != photoPath) {
        return const ParkingSessionPhotoUrlFailure(
          message: 'The private vehicle photo is no longer available.',
        );
      }

      final url = await _photoStorage.createSignedUrl(
        path: photoPath,
        expiresInSeconds: expiresInSeconds,
      );
      return ParkingSessionPhotoUrlSuccess(url: url);
    } on Exception catch (error) {
      return ParkingSessionPhotoUrlFailure(
        message: _messageForPhotoError(error),
      );
    }
  }

  @override
  Future<ParkingSessionSaveResult> save({
    required ParkingSession session,
    ParkingPhoto? photo,
  }) async {
    final userId = _authenticatedUserId();
    if (userId == null) {
      return const ParkingSessionSaveFailure(
        message: 'Your sign-in session has expired. Sign in again and retry.',
      );
    }

    final plateNumber = session.plateNumber.trim().toUpperCase();
    final validationMessage = _validateSession(session, plateNumber);
    if (validationMessage != null) {
      return ParkingSessionSaveFailure(message: validationMessage);
    }
    final tenantId = session.tenantId?.trim();
    if (tenantId == null || tenantId.isEmpty) {
      return const ParkingSessionSaveFailure(
        message: 'Choose a tenant before saving the parking entry.',
      );
    }

    final values = _sessionInsertValues(
      session: session,
      plateNumber: plateNumber,
      userId: userId,
      tenantId: tenantId,
    );

    late final String sessionId;
    try {
      sessionId = await _sessionStore.insert(values);
    } on Exception catch (error) {
      return ParkingSessionSaveFailure(message: _messageForSaveError(error));
    }

    final savedSession = _sessionWith(
      session,
      id: sessionId,
      plateNumber: plateNumber,
      photoPath: null,
      createdBy: userId,
    );

    if (photo == null) {
      return ParkingSessionSaveSuccess(session: savedSession);
    }

    final photoPath = _buildPhotoPath(
      userId: session.createdBy ?? userId,
      sessionId: sessionId,
      photo: photo,
    );

    try {
      await _sessionStore.setPhotoPath(
        sessionId: sessionId,
        photoPath: photoPath,
      );
      await _photoStorage.upload(path: photoPath, photo: photo);
    } on Exception catch (error) {
      return _handleSaveFailure(
        sessionId: sessionId,
        photoPath: photoPath,
        cause: error,
      );
    }

    return ParkingSessionSaveSuccess(
      session: _sessionWith(savedSession, photoPath: photoPath),
    );
  }

  @override
  Future<ParkingSessionUpdateResult> update({
    required ParkingSession session,
    ParkingPhoto? replacementPhoto,
  }) async {
    final sessionId = session.id;
    final userId = _authenticatedUserId();
    if (userId == null) {
      return ParkingSessionUpdateFailure(
        message: 'Your sign-in session has expired. Sign in again and retry.',
        sessionId: sessionId ?? '',
      );
    }

    if (sessionId == null || sessionId.trim().isEmpty) {
      return const ParkingSessionUpdateFailure(
        message: 'The parking session identifier is missing.',
        sessionId: '',
      );
    }

    final plateNumber = session.plateNumber.trim().toUpperCase();
    final validationMessage = _validateSession(session, plateNumber);
    if (validationMessage != null) {
      return ParkingSessionUpdateFailure(
        message: validationMessage,
        sessionId: sessionId,
      );
    }

    try {
      final currentRow = await _sessionStore.find(sessionId: sessionId);
      if (currentRow == null) {
        return ParkingSessionUpdateFailure(
          message: 'That parking session could not be found.',
          sessionId: sessionId,
        );
      }

      final currentPhotoPath = _optionalString(currentRow['photo_path']);
      final values = _sessionUpdateValues(
        session: session,
        plateNumber: plateNumber,
      );

      if (replacementPhoto == null) {
        await _sessionStore.update(sessionId: sessionId, values: values);
        return ParkingSessionUpdateSuccess(
          session: _sessionWith(
            session,
            id: sessionId,
            plateNumber: plateNumber,
            photoPath: currentPhotoPath,
          ),
        );
      }

      if (currentPhotoPath != null) {
        await _photoStorage.upload(
          path: currentPhotoPath,
          photo: replacementPhoto,
          upsert: true,
        );
        await _sessionStore.update(sessionId: sessionId, values: values);
        return ParkingSessionUpdateSuccess(
          session: _sessionWith(
            session,
            id: sessionId,
            plateNumber: plateNumber,
            photoPath: currentPhotoPath,
          ),
        );
      }

      final newPhotoPath = _buildPhotoPath(
        userId: session.createdBy ?? userId,
        sessionId: sessionId,
        photo: replacementPhoto,
      );
      await _photoStorage.upload(path: newPhotoPath, photo: replacementPhoto);

      try {
        await _sessionStore.update(
          sessionId: sessionId,
          values: {...values, 'photo_path': newPhotoPath},
        );
      } on Exception catch (error) {
        try {
          await _photoStorage.remove(path: newPhotoPath);
        } on Exception {
          return ParkingSessionUpdateFailure(
            message:
                '${_messageForUpdateError(error)} The new photo could not '
                'be cleaned up automatically. Retry photo cleanup before '
                'trying again.',
            sessionId: sessionId,
            photoPath: newPhotoPath,
            cleanupRequired: true,
          );
        }

        return ParkingSessionUpdateFailure(
          message: _messageForUpdateError(error),
          sessionId: sessionId,
        );
      }

      return ParkingSessionUpdateSuccess(
        session: _sessionWith(
          session,
          id: sessionId,
          plateNumber: plateNumber,
          photoPath: newPhotoPath,
        ),
      );
    } on Exception catch (error) {
      return ParkingSessionUpdateFailure(
        message: _messageForUpdateError(error),
        sessionId: sessionId,
      );
    }
  }

  @override
  Future<ParkingSessionDeleteResult> delete({
    required ParkingSession session,
  }) async {
    final sessionId = session.id;
    final userId = _authenticatedUserId();
    if (userId == null) {
      return ParkingSessionDeleteFailure(
        message: 'Your sign-in session has expired. Sign in again and retry.',
        sessionId: sessionId ?? '',
      );
    }

    if (sessionId == null || sessionId.trim().isEmpty) {
      return const ParkingSessionDeleteFailure(
        message: 'The parking session identifier is missing.',
        sessionId: '',
      );
    }

    try {
      final currentRow = await _sessionStore.find(sessionId: sessionId);
      if (currentRow == null) {
        return ParkingSessionDeleteFailure(
          message: 'That parking session could not be found.',
          sessionId: sessionId,
        );
      }

      final photoPath = _optionalString(currentRow['photo_path']);
      if (photoPath != null) {
        try {
          await _photoStorage.remove(path: photoPath);
        } on StorageException catch (error) {
          if (!_isMissingStorageObject(error)) {
            return ParkingSessionDeleteFailure(
              message:
                  'The vehicle photo could not be removed. The session was '
                  'not deleted. Retry when the connection is available.',
              sessionId: sessionId,
            );
          }
        }
      }

      await _sessionStore.delete(sessionId: sessionId);
      return const ParkingSessionDeleteSuccess();
    } on Exception catch (error) {
      return ParkingSessionDeleteFailure(
        message: _messageForDeleteError(error),
        sessionId: sessionId,
      );
    }
  }

  @override
  Future<ParkingSessionCleanupResult> retryCleanup({
    required String sessionId,
    required String photoPath,
  }) async {
    final userId = _authenticatedUserId();
    if (userId == null) {
      return ParkingSessionCleanupFailure(
        message: 'Your sign-in session has expired. Sign in again and retry.',
        sessionId: sessionId,
        photoPath: photoPath,
      );
    }

    try {
      await _photoStorage.remove(path: photoPath);
      await _sessionStore.delete(sessionId: sessionId);
      return const ParkingSessionCleanupSuccess();
    } on StorageException catch (error) {
      if (_isMissingStorageObject(error)) {
        try {
          await _sessionStore.delete(sessionId: sessionId);
          return const ParkingSessionCleanupSuccess();
        } on Exception catch (deleteError) {
          return ParkingSessionCleanupFailure(
            message: _messageForCleanupError(deleteError),
            sessionId: sessionId,
            photoPath: photoPath,
          );
        }
      }

      return ParkingSessionCleanupFailure(
        message: _messageForCleanupError(error),
        sessionId: sessionId,
        photoPath: photoPath,
      );
    } on Exception catch (error) {
      return ParkingSessionCleanupFailure(
        message: _messageForCleanupError(error),
        sessionId: sessionId,
        photoPath: photoPath,
      );
    }
  }

  @override
  Future<ParkingPhotoCleanupResult> retryPhotoCleanup({
    required String photoPath,
  }) async {
    if (_authenticatedUserId() == null) {
      return ParkingPhotoCleanupFailure(
        message: 'Your sign-in session has expired. Sign in again and retry.',
        photoPath: photoPath,
      );
    }

    try {
      await _photoStorage.remove(path: photoPath);
      return const ParkingPhotoCleanupSuccess();
    } on StorageException catch (error) {
      if (_isMissingStorageObject(error)) {
        return const ParkingPhotoCleanupSuccess();
      }

      return ParkingPhotoCleanupFailure(
        message: _messageForPhotoError(error),
        photoPath: photoPath,
      );
    } on Exception catch (error) {
      return ParkingPhotoCleanupFailure(
        message: _messageForPhotoError(error),
        photoPath: photoPath,
      );
    }
  }

  String? _authenticatedUserId() {
    final userId = _currentUserId();
    if (userId == null || userId.trim().isEmpty) {
      return null;
    }

    return userId;
  }

  Map<String, dynamic> _sessionInsertValues({
    required ParkingSession session,
    required String plateNumber,
    required String userId,
    required String tenantId,
  }) {
    return {
      'tenant_id': tenantId,
      'plate_number': plateNumber,
      'photo_path': null,
      'entry_time': session.entryTime.toUtc().toIso8601String(),
      'allowed_duration_value': session.allowedDuration.value,
      'allowed_duration_unit': session.allowedDuration.unit.name,
      'expires_at': session.expiresAt.toUtc().toIso8601String(),
      'created_by': userId,
    };
  }

  Map<String, dynamic> _sessionUpdateValues({
    required ParkingSession session,
    required String plateNumber,
  }) {
    return {
      'plate_number': plateNumber,
      'entry_time': session.entryTime.toUtc().toIso8601String(),
      'allowed_duration_value': session.allowedDuration.value,
      'allowed_duration_unit': session.allowedDuration.unit.name,
      'expires_at': session.expiresAt.toUtc().toIso8601String(),
    };
  }

  ParkingSession _sessionFromRow(Map<String, dynamic> row) {
    final id = _requiredString(row['id'], 'id');
    final tenantId = _optionalString(row['tenant_id']);
    final createdBy = _optionalString(row['created_by']);
    final plateNumber = _requiredString(row['plate_number'], 'plate_number');
    final photoPath = _optionalString(row['photo_path']);
    final entryTime = _parseDateTime(row['entry_time'], 'entry_time');
    final expiresAt = _parseDateTime(row['expires_at'], 'expires_at');
    final durationValue = _parseInteger(
      row['allowed_duration_value'],
      'allowed_duration_value',
    );
    final durationUnit = ParkingDurationUnit.values.byName(
      _requiredString(row['allowed_duration_unit'], 'allowed_duration_unit'),
    );

    return ParkingSession(
      id: id,
      tenantId: tenantId,
      createdBy: createdBy,
      plateNumber: plateNumber,
      photoPath: photoPath,
      entryTime: entryTime,
      allowedDuration: ParkingDuration(
        value: durationValue,
        unit: durationUnit,
      ),
      expiresAt: expiresAt,
    );
  }

  ParkingSession _sessionWith(
    ParkingSession session, {
    String? id,
    String? tenantId,
    String? createdBy,
    String? plateNumber,
    String? photoPath,
  }) {
    return ParkingSession(
      id: id ?? session.id,
      tenantId: tenantId ?? session.tenantId,
      createdBy: createdBy ?? session.createdBy,
      plateNumber: plateNumber ?? session.plateNumber,
      photoPath: photoPath,
      entryTime: session.entryTime,
      allowedDuration: session.allowedDuration,
      expiresAt: session.expiresAt,
    );
  }

  DateTime _parseDateTime(Object? value, String fieldName) {
    final text = _requiredString(value, fieldName);
    return DateTime.parse(text).toLocal();
  }

  int _parseInteger(Object? value, String fieldName) {
    if (value is int) {
      return value;
    }
    if (value is num && value == value.roundToDouble()) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }

    throw FormatException('The $fieldName value is invalid.');
  }

  String _requiredString(Object? value, String fieldName) {
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    throw FormatException('The $fieldName value is invalid.');
  }

  String? _optionalString(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    throw const FormatException('An optional text value is invalid.');
  }

  String? _validateSession(ParkingSession session, String plateNumber) {
    if (plateNumber.isEmpty) {
      return 'Enter a vehicle registration number.';
    }

    if (plateNumber.length > 64) {
      return 'The vehicle registration number must be 64 characters or fewer.';
    }

    if (!session.allowedDuration.isPositive) {
      return 'Enter a positive parking duration.';
    }

    if (!session.expiresAt.isAfter(session.entryTime)) {
      return 'The expiry time must be after the entry time.';
    }

    return null;
  }

  Future<ParkingSessionSaveFailure> _handleSaveFailure({
    required String sessionId,
    required String photoPath,
    required Exception cause,
  }) async {
    try {
      await _photoStorage.remove(path: photoPath);
    } on Exception {
      return ParkingSessionSaveFailure(
        message:
            '${_messageForSaveError(cause)} The incomplete session was retained '
            'because its photo cleanup needs to be retried.',
        sessionId: sessionId,
        photoPath: photoPath,
        cleanupRequired: true,
      );
    }

    try {
      await _sessionStore.delete(sessionId: sessionId);
    } on Exception {
      return ParkingSessionSaveFailure(
        message:
            '${_messageForSaveError(cause)} The incomplete session could not '
            'be removed. Retry cleanup before trying again.',
        sessionId: sessionId,
        photoPath: photoPath,
        cleanupRequired: true,
      );
    }

    return ParkingSessionSaveFailure(message: _messageForSaveError(cause));
  }

  String _buildPhotoPath({
    required String userId,
    required String sessionId,
    required ParkingPhoto photo,
  }) {
    return '$userId/$sessionId/${_safeFileName(photo)}';
  }

  String _safeFileName(ParkingPhoto photo) {
    final basename = photo.fileName.trim().split(RegExp(r'[\\/]')).last;
    final sanitized = basename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final baseName = sanitized.isEmpty || sanitized == '.' || sanitized == '..'
        ? 'vehicle-photo'
        : sanitized;

    if (baseName.contains('.')) {
      return _truncateFileName(baseName);
    }

    final extension = switch (photo.mimeType) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      _ => '.jpg',
    };
    return _truncateFileName('$baseName$extension');
  }

  String _truncateFileName(String fileName) {
    if (fileName.length <= 120) {
      return fileName;
    }

    return fileName.substring(0, 120);
  }

  String _messageForReadError(Exception error) {
    if (error is StorageException) {
      return 'The parking data could not be loaded. Check your connection and try again.';
    }
    if (error is PostgrestException) {
      return 'The parking data could not be loaded. Check your connection and try again.';
    }

    return 'The parking data could not be loaded. Try again.';
  }

  String _messageForPhotoError(Exception error) {
    if (error is StorageException) {
      return 'The private vehicle photo could not be loaded. Check your connection and try again.';
    }

    return 'The private vehicle photo could not be loaded. Try again.';
  }

  String _messageForSaveError(Exception error) {
    if (error is StorageException) {
      return 'The vehicle photo could not be uploaded. Check your connection '
          'and try again.';
    }

    if (error is PostgrestException) {
      return 'The parking session could not be saved. Check your connection '
          'and try again.';
    }

    return 'The parking session could not be saved. Try again.';
  }

  String _messageForUpdateError(Exception error) {
    if (error is StorageException) {
      return 'The vehicle photo could not be updated. Check your connection '
          'and try again.';
    }
    if (error is PostgrestException) {
      return 'The parking session could not be updated. Check your connection '
          'and try again.';
    }

    return 'The parking session could not be updated. Try again.';
  }

  String _messageForDeleteError(Exception error) {
    if (error is StorageException) {
      return 'The vehicle photo could not be removed. The session was not '
          'deleted. Check your connection and retry.';
    }
    if (error is PostgrestException) {
      return 'The parking session could not be deleted. Check your connection '
          'and retry.';
    }

    return 'The parking session could not be deleted. Try again.';
  }

  String _messageForCleanupError(Exception error) {
    if (error is StorageException) {
      return 'The photo cleanup could not complete. Check your connection and '
          'retry cleanup.';
    }

    if (error is PostgrestException) {
      return 'The incomplete session could not be removed. Check your '
          'connection and retry cleanup.';
    }

    return 'Cleanup could not complete. Check your connection and retry.';
  }

  bool _isMissingStorageObject(StorageException error) {
    return error.statusCode == '404';
  }

  static SupabaseClient _requireClient(SupabaseClient? client) {
    if (client == null) {
      throw ArgumentError(
        'A Supabase client is required when storage dependencies are not injected.',
      );
    }

    return client;
  }
}

class _SupabaseParkingSessionStore implements ParkingSessionStore {
  const _SupabaseParkingSessionStore(this._client);

  final SupabaseClient _client;

  @override
  Future<String> insert(Map<String, dynamic> values) async {
    final row = await _client
        .from('parking_sessions')
        .insert(values)
        .select('id')
        .single();
    final id = row['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException(
        'Supabase did not return a parking session id.',
      );
    }

    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> list({
    required ParkingTenantScope scope,
    required int offset,
    required int limit,
    String? search,
  }) async {
    var query = _client.from('parking_sessions').select(_parkingSessionColumns);
    if (scope.tenantId != null) {
      query = query.eq('tenant_id', scope.tenantId!);
    }
    if (search != null && search.isNotEmpty) {
      query = query.ilike('plate_number', '%${_escapeIlike(search)}%');
    }

    return query
        .order('entry_time', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + limit - 1);
  }

  @override
  Future<ParkingSessionSummary> summary({
    required ParkingTenantScope scope,
    required DateTime asOf,
  }) async {
    final cutoff = asOf.toUtc().toIso8601String();
    final counts = await Future.wait<int>([
      _countForExpiry(scope: scope, cutoff: cutoff, active: true),
      _countForExpiry(scope: scope, cutoff: cutoff, active: false),
    ]);

    return ParkingSessionSummary(
      activeCount: counts[0],
      expiredCount: counts[1],
    );
  }

  Future<int> _countForExpiry({
    required ParkingTenantScope scope,
    required String cutoff,
    required bool active,
  }) {
    var query = _client.from('parking_sessions').count(CountOption.exact);
    if (scope.tenantId != null) {
      query = query.eq('tenant_id', scope.tenantId!);
    }

    return active
        ? query.gt('expires_at', cutoff)
        : query.lte('expires_at', cutoff);
  }

  @override
  Future<Map<String, dynamic>?> find({required String sessionId}) async {
    return _client
        .from('parking_sessions')
        .select(_parkingSessionColumns)
        .eq('id', sessionId)
        .maybeSingle();
  }

  @override
  Future<void> setPhotoPath({
    required String sessionId,
    required String photoPath,
  }) async {
    await update(sessionId: sessionId, values: {'photo_path': photoPath});
  }

  @override
  Future<void> update({
    required String sessionId,
    required Map<String, dynamic> values,
  }) async {
    await _client.from('parking_sessions').update(values).eq('id', sessionId);
  }

  @override
  Future<void> delete({required String sessionId}) async {
    await _client.from('parking_sessions').delete().eq('id', sessionId);
  }
}

class _SupabaseVehiclePhotoStorage implements VehiclePhotoStorage {
  const _SupabaseVehiclePhotoStorage(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upload({
    required String path,
    required ParkingPhoto photo,
    bool upsert = false,
  }) async {
    await _client.storage
        .from('vehicle-photos')
        .uploadBinary(
          path,
          photo.bytes,
          fileOptions: FileOptions(contentType: photo.mimeType, upsert: upsert),
        );
  }

  @override
  Future<void> remove({required String path}) async {
    await _client.storage.from('vehicle-photos').remove([path]);
  }

  @override
  Future<String> createSignedUrl({
    required String path,
    required int expiresInSeconds,
  }) {
    return _client.storage
        .from('vehicle-photos')
        .createSignedUrl(path, expiresInSeconds);
  }
}

String _escapeIlike(String value) {
  return value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
