import '../../../core/network/local_api_client.dart';
import 'supabase_tenant_repository.dart';

class LocalApiTenantStore implements TenantStore {
  LocalApiTenantStore(this._api);

  final LocalApiClient _api;
  Map<String, dynamic>? _access;
  String? _cachedAccessToken;

  @override
  Future<bool> isSuperAdmin() async {
    final value = (await _loadAccess())['isSuperAdmin'];
    if (value is! bool) {
      throw const FormatException(
        'The local Super Admin role response is invalid.',
      );
    }
    return value;
  }

  @override
  Future<List<Map<String, dynamic>>> memberships() async {
    return _rows((await _loadAccess())['memberships']);
  }

  @override
  Future<List<Map<String, dynamic>>> tenants({List<String>? tenantIds}) async {
    if (tenantIds != null && tenantIds.isEmpty) {
      return const [];
    }

    final rows = _rows((await _loadAccess())['tenants']);
    if (tenantIds == null) {
      return rows;
    }

    final tenantIdSet = tenantIds.toSet();
    return rows
        .where((row) => tenantIdSet.contains(row['id']))
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> createTenant({
    required String name,
    required String ownerEmail,
    required String requestId,
    required bool isActive,
    required DateTime validUntil,
    String? contactName,
    String? contactMobile,
    String? contactEmail,
  }) async {
    try {
      final response = await _api.requestJson(
        'POST',
        '/api/tenants',
        body: {
          'name': name,
          'ownerEmail': ownerEmail,
          'requestId': requestId,
          'isActive': isActive,
          'validUntil': _isoDate(validUntil),
          'contactName': ?contactName,
          'contactMobile': ?contactMobile,
          'contactEmail': ?contactEmail,
        },
      );
      _access = null;
      return response;
    } on LocalApiException catch (error) {
      throw _tenantStoreError(error);
    }
  }

  @override
  Future<Map<String, dynamic>> updateTenant({
    required String tenantId,
    required String name,
    required DateTime validUntil,
    String? contactName,
    String? contactMobile,
    String? contactEmail,
  }) async {
    try {
      final response = await _api.requestJson(
        'PATCH',
        '/api/tenants/${Uri.encodeComponent(tenantId)}',
        body: {
          'name': name,
          'validUntil': _isoDate(validUntil),
          'contactName': ?contactName,
          'contactMobile': ?contactMobile,
          'contactEmail': ?contactEmail,
        },
      );
      _access = null;
      return response;
    } on LocalApiException catch (error) {
      throw _tenantStoreError(error);
    }
  }

  static String _isoDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  Future<void> archiveTenant({required String tenantId}) async {
    await _tenantAction(tenantId, 'archive');
  }

  @override
  Future<void> restoreTenant({required String tenantId}) async {
    await _tenantAction(tenantId, 'restore');
  }

  @override
  Future<List<Map<String, dynamic>>> listTenantMembers({
    required String tenantId,
  }) async {
    try {
      final rows = await _api.requestJson(
        'GET',
        '/api/tenants/${Uri.encodeComponent(tenantId)}/members',
      );
      final members = rows['items'];
      if (members is List) {
        return _rows(members);
      }
      throw const FormatException(
        'The local tenant-member response is invalid.',
      );
    } on LocalApiException catch (error) {
      throw _tenantStoreError(error);
    }
  }

  @override
  Future<Map<String, dynamic>> addTenantMember({
    required String tenantId,
    required String email,
    required String role,
  }) async {
    try {
      final response = await _api.requestJson(
        'POST',
        '/api/tenants/${Uri.encodeComponent(tenantId)}/members',
        body: {'email': email, 'role': role},
      );
      _access = null;
      return response;
    } on LocalApiException catch (error) {
      throw _tenantStoreError(error);
    }
  }

  @override
  Future<void> updateTenantMemberRole({
    required String tenantId,
    required String userId,
    required String role,
  }) async {
    try {
      await _api.requestJson(
        'PATCH',
        '/api/tenants/${Uri.encodeComponent(tenantId)}/members/'
            '${Uri.encodeComponent(userId)}',
        body: {'role': role},
      );
      _access = null;
    } on LocalApiException catch (error) {
      throw _tenantStoreError(error);
    }
  }

  @override
  Future<void> removeTenantMember({
    required String tenantId,
    required String userId,
  }) async {
    try {
      await _api.requestJson(
        'DELETE',
        '/api/tenants/${Uri.encodeComponent(tenantId)}/members/'
            '${Uri.encodeComponent(userId)}',
      );
      _access = null;
    } on LocalApiException catch (error) {
      throw _tenantStoreError(error);
    }
  }

  Future<Map<String, dynamic>> _loadAccess() async {
    // Invalidate the cache whenever the signed-in account changes so a new
    // sign-in never reuses another account's tenant/Super Admin access.
    if (_api.accessToken != _cachedAccessToken) {
      _access = null;
    }

    final cached = _access;
    if (cached != null) {
      return cached;
    }
    try {
      final result = await _api.requestJson('GET', '/api/tenants/access');
      _access = result;
      _cachedAccessToken = _api.accessToken;
      return result;
    } on LocalApiException catch (error) {
      throw _tenantStoreError(error);
    }
  }

  Future<void> _tenantAction(String tenantId, String action) async {
    try {
      await _api.requestJson(
        'POST',
        '/api/tenants/${Uri.encodeComponent(tenantId)}/$action',
        body: const {},
      );
      _access = null;
    } on LocalApiException catch (error) {
      throw _tenantStoreError(error);
    }
  }

  TenantStoreException _tenantStoreError(LocalApiException error) {
    final message = switch (error.code) {
      'authentication_required' || 'session_expired' =>
        'Your local sign-in session expired. Sign in again and retry.',
      'super_admin_required' =>
        'Only a Super Admin can manage tenants and members.',
      'account_not_found' => 'The local account could not be found. Sign in with that account first.',
      'owner_required' => 'A tenant must keep at least one owner.',
      'tenant_archived' => 'Restore the tenant before adding members.',
      'tenant_not_found' ||
      'member_not_found' => 'The tenant or local account could not be found.',
      'invalid_request' || 'request_id_reused' =>
        'Check the tenant name, email, and selected role, then retry.',
      _ => error.message,
    };
    return TenantStoreException(message);
  }

  List<Map<String, dynamic>> _rows(Object? value) {
    if (value is! List) {
      throw const FormatException('The local tenant response is invalid.');
    }
    return value
        .map(
          (row) => row is Map<String, dynamic>
              ? row
              : row is Map
              ? Map<String, dynamic>.from(row)
              : throw const FormatException(
                  'The local tenant response is invalid.',
                ),
        )
        .toList(growable: false);
  }
}
