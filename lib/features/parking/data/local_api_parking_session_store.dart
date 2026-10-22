import '../../../core/network/local_api_client.dart';
import '../../tenants/domain/parking_tenant_scope.dart';
import 'parking_photo.dart';
import 'parking_session_repository.dart';

class LocalApiParkingSessionStore implements ParkingSessionStore {
  const LocalApiParkingSessionStore(this._api);

  final LocalApiClient _api;

  @override
  Future<String> insert(Map<String, dynamic> values) async {
    final response = await _api.requestJson(
      'POST',
      '/api/parking-sessions',
      body: values,
    );
    return _requiredString(response['id']);
  }

  @override
  Future<List<Map<String, dynamic>>> list({
    required ParkingTenantScope scope,
    required int offset,
    required int limit,
    String? search,
  }) async {
    final query = <String, String>{
      'offset': '$offset',
      'limit': '$limit',
      if (search != null && search.isNotEmpty) 'search': search,
      if (scope.tenantId != null) 'tenant_id': scope.tenantId!,
    };
    final response = await _api.requestJson(
      'GET',
      '/api/parking-sessions',
      queryParameters: query,
    );
    return _rows(response['sessions']);
  }

  @override
  Future<ParkingSessionSummary> summary({
    required ParkingTenantScope scope,
    required DateTime asOf,
  }) async {
    final response = await _api.requestJson(
      'GET',
      '/api/parking-sessions/summary',
      queryParameters: {
        if (scope.tenantId != null) 'tenant_id': scope.tenantId!,
      },
    );
    return ParkingSessionSummary(
      activeCount: _requiredInt(response['activeCount']),
      expiredCount: _requiredInt(response['expiredCount']),
    );
  }

  @override
  Future<Map<String, dynamic>?> find({required String sessionId}) async {
    try {
      return await _api.requestJson(
        'GET',
        '/api/parking-sessions/${Uri.encodeComponent(sessionId)}',
      );
    } on LocalApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> setPhotoPath({
    required String sessionId,
    required String photoPath,
  }) {
    return _api
        .requestJson(
          'POST',
          '/api/parking-sessions/${Uri.encodeComponent(sessionId)}/photo-path',
          body: {'photo_path': photoPath},
        )
        .then((_) {});
  }

  @override
  Future<void> completePhotoUpload({required String sessionId}) {
    return _api
        .requestJson(
          'POST',
          '/api/parking-sessions/${Uri.encodeComponent(sessionId)}/photo-complete',
        )
        .then((_) {});
  }

  @override
  Future<void> update({
    required String sessionId,
    required Map<String, dynamic> values,
  }) async {
    await _api.requestJson(
      'PATCH',
      '/api/parking-sessions/${Uri.encodeComponent(sessionId)}',
      body: values.cast<String, Object?>(),
    );
  }

  @override
  Future<void> delete({required String sessionId}) async {
    await _api.requestJson(
      'DELETE',
      '/api/parking-sessions/${Uri.encodeComponent(sessionId)}',
    );
  }

  @override
  Future<bool> markFullyPaid({required String sessionId}) async {
    final Map<String, dynamic>? row = await find(sessionId: sessionId);
    if (row == null) {
      return false;
    }

    final Object? totalChargeValue = row['total_charge'];
    final double? totalCharge = totalChargeValue is num
        ? totalChargeValue.toDouble()
        : double.tryParse(totalChargeValue?.toString() ?? '');
    final Object? paidAmountValue = row['paid_amount'];
    final double paidAmount = paidAmountValue is num
        ? paidAmountValue.toDouble()
        : double.tryParse(paidAmountValue?.toString() ?? '') ?? 0;
    if (totalCharge == null || totalCharge <= 0 || paidAmount >= totalCharge) {
      return false;
    }

    await update(sessionId: sessionId, values: {'paid_amount': totalCharge});
    return true;
  }

  List<Map<String, dynamic>> _rows(Object? value) {
    if (value is! List) {
      throw const FormatException(
        'The local parking-session response is invalid.',
      );
    }
    return value
        .map(
          (row) => row is Map<String, dynamic>
              ? row
              : row is Map
              ? Map<String, dynamic>.from(row)
              : throw const FormatException(
                  'The local parking-session response is invalid.',
                ),
        )
        .toList(growable: false);
  }

  String _requiredString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw const FormatException(
      'The local parking-session response is invalid.',
    );
  }

  int _requiredInt(Object? value) {
    if (value is int && value >= 0) {
      return value;
    }
    throw const FormatException('The local parking summary is invalid.');
  }
}

class LocalApiVehiclePhotoStorage implements VehiclePhotoStorage {
  const LocalApiVehiclePhotoStorage(this._api);

  final LocalApiClient _api;

  @override
  Future<void> upload({
    required String path,
    required ParkingPhoto photo,
    bool upsert = false,
  }) async {
    final response = await _api.send(
      'PUT',
      '/api/photos/upload',
      queryParameters: {'path': path},
      bodyBytes: photo.bytes,
      contentType: photo.mimeType ?? _mimeTypeFromName(photo.fileName),
      headers: {'X-Upsert': upsert ? 'true' : 'false'},
    );
    _api.ensureSuccessful(response);
  }

  @override
  Future<void> remove({required String path}) async {
    await _api.requestJson(
      'DELETE',
      '/api/photos',
      queryParameters: {'path': path},
    );
  }

  @override
  Future<String> createSignedUrl({
    required String path,
    required int expiresInSeconds,
  }) async {
    final response = await _api.requestJson(
      'POST',
      '/api/photos/signed-url',
      body: {'path': path, 'expiresInSeconds': expiresInSeconds},
    );
    final url = response['url'];
    final uri = url is String ? Uri.tryParse(url) : null;
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const FormatException('The local photo URL response is invalid.');
    }
    return url;
  }

  String _mimeTypeFromName(String fileName) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.png')) {
      return 'image/png';
    }
    if (lowerName.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }
}
