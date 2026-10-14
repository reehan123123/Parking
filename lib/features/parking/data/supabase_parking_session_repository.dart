import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/parking_session.dart';
import 'parking_photo.dart';
import 'parking_session_repository.dart';

class SupabaseParkingSessionRepository implements ParkingSessionRepository {
  SupabaseParkingSessionRepository(
    SupabaseClient? client, {
    ParkingSessionStore? sessionStore,
    VehiclePhotoStorage? photoStorage,
    String? Function()? currentUserId,
  }) : _sessionStore =
           sessionStore ?? _SupabaseParkingSessionStore(_requireClient(client)),
       _photoStorage =
           photoStorage ?? _SupabaseVehiclePhotoStorage(_requireClient(client)),
       _currentUserId = currentUserId ?? (() => client?.auth.currentUser?.id);

  final ParkingSessionStore _sessionStore;
  final VehiclePhotoStorage _photoStorage;
  final String? Function() _currentUserId;

  @override
  Future<ParkingSessionSaveResult> save({
    required ParkingSession session,
    ParkingPhoto? photo,
  }) async {
    final userId = _currentUserId();
    if (userId == null || userId.trim().isEmpty) {
      return const ParkingSessionSaveFailure(
        message: 'Your sign-in session has expired. Sign in again and retry.',
      );
    }

    final plateNumber = session.plateNumber.trim().toUpperCase();
    final validationMessage = _validateSession(session, plateNumber);
    if (validationMessage != null) {
      return ParkingSessionSaveFailure(message: validationMessage);
    }

    final values = {
      'plate_number': plateNumber,
      'photo_path': null,
      'entry_time': session.entryTime.toUtc().toIso8601String(),
      'allowed_duration_value': session.allowedDuration.value,
      'allowed_duration_unit': session.allowedDuration.unit.name,
      'expires_at': session.expiresAt.toUtc().toIso8601String(),
      'created_by': userId,
    };

    late final String sessionId;
    try {
      sessionId = await _sessionStore.insert(values);
    } on Exception catch (error) {
      return ParkingSessionSaveFailure(message: _messageForSaveError(error));
    }

    final savedSession = ParkingSession(
      id: sessionId,
      plateNumber: plateNumber,
      photoPath: null,
      entryTime: session.entryTime,
      allowedDuration: session.allowedDuration,
      expiresAt: session.expiresAt,
    );

    if (photo == null) {
      return ParkingSessionSaveSuccess(session: savedSession);
    }

    final photoPath = _buildPhotoPath(
      userId: userId,
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
      session: ParkingSession(
        id: sessionId,
        plateNumber: plateNumber,
        photoPath: photoPath,
        entryTime: session.entryTime,
        allowedDuration: session.allowedDuration,
        expiresAt: session.expiresAt,
      ),
    );
  }

  @override
  Future<ParkingSessionCleanupResult> retryCleanup({
    required String sessionId,
    required String photoPath,
  }) async {
    final userId = _currentUserId();
    if (userId == null || userId.trim().isEmpty) {
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
    } on Exception catch (error) {
      return ParkingSessionCleanupFailure(
        message: _messageForCleanupError(error),
        sessionId: sessionId,
        photoPath: photoPath,
      );
    }
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
  Future<void> setPhotoPath({
    required String sessionId,
    required String photoPath,
  }) async {
    await _client
        .from('parking_sessions')
        .update({'photo_path': photoPath})
        .eq('id', sessionId);
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
  }) async {
    await _client.storage
        .from('vehicle-photos')
        .uploadBinary(
          path,
          photo.bytes,
          fileOptions: FileOptions(contentType: photo.mimeType, upsert: false),
        );
  }

  @override
  Future<void> remove({required String path}) async {
    await _client.storage.from('vehicle-photos').remove([path]);
  }
}
