import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/parking_tenant.dart';
import 'tenant_repository.dart';

class TenantRepositoryException implements Exception {
  const TenantRepositoryException(this.message, {this.temporaryPassword});

  final String message;
  final String? temporaryPassword;

  @override
  String toString() => message;
}

class TenantStoreException implements Exception {
  const TenantStoreException(this.message, {this.temporaryPassword});

  final String message;
  final String? temporaryPassword;
}

abstract interface class TenantStore {
  Future<bool> isSuperAdmin();

  Future<List<Map<String, dynamic>>> memberships();

  Future<List<Map<String, dynamic>>> tenants({List<String>? tenantIds});

  Future<Map<String, dynamic>> createTenant({
    required String name,
    required String ownerEmail,
    required String requestId,
  });

  Future<Map<String, dynamic>> updateTenant({
    required String tenantId,
    required String name,
  });

  Future<void> archiveTenant({required String tenantId});

  Future<void> restoreTenant({required String tenantId});

  Future<List<Map<String, dynamic>>> listTenantMembers({
    required String tenantId,
  });

  Future<Map<String, dynamic>> addTenantMember({
    required String tenantId,
    required String email,
    required String role,
  });

  Future<void> updateTenantMemberRole({
    required String tenantId,
    required String userId,
    required String role,
  });

  Future<void> removeTenantMember({
    required String tenantId,
    required String userId,
  });
}

class SupabaseTenantRepository implements TenantRepository {
  SupabaseTenantRepository(SupabaseClient? client, {TenantStore? tenantStore})
    : _tenantStore =
          tenantStore ?? _SupabaseTenantStore(_requireClient(client));

  final TenantStore _tenantStore;

  @override
  Future<ParkingTenantAccess> loadAccess() async {
    try {
      final isSuperAdmin = await _tenantStore.isSuperAdmin();
      final membershipRoles = <String, ParkingTenantRole>{};
      if (!isSuperAdmin) {
        for (final row in await _tenantStore.memberships()) {
          final tenantId = _requiredString(row['tenant_id'], 'tenant_id');
          final roleName = _requiredString(row['role'], 'role');
          membershipRoles[tenantId] = ParkingTenantRole.values.byName(roleName);
        }
      }

      final rows = await _tenantStore.tenants(
        tenantIds: isSuperAdmin ? null : membershipRoles.keys.toList(),
      );
      final tenants = rows
          .map(
            (row) => ParkingTenant(
              id: _requiredString(row['id'], 'id'),
              name: _requiredString(row['name'], 'name'),
              slug: _requiredString(row['slug'], 'slug'),
              role: membershipRoles[_requiredString(row['id'], 'id')],
              isArchived: row['archived_at'] != null,
            ),
          )
          .toList(growable: false);

      return ParkingTenantAccess(isSuperAdmin: isSuperAdmin, tenants: tenants);
    } on TenantStoreException catch (error) {
      throw TenantRepositoryException(error.message);
    } on PostgrestException catch (error) {
      if (_isMissingTenantSchema(error)) {
        throw const TenantRepositoryException(
          'Tenant setup is not installed yet. Apply all tenant migrations, '
          'then retry.',
        );
      }

      throw const TenantRepositoryException(
        'Tenant access could not be loaded. Check your connection and retry.',
      );
    } on Exception {
      throw const TenantRepositoryException(
        'Tenant access data is invalid. Contact the system administrator.',
      );
    }
  }

  @override
  Future<TenantCreationResult> createTenant({
    required String name,
    required String ownerEmail,
    required String requestId,
  }) async {
    final normalizedName = name.trim();
    final normalizedEmail = ownerEmail.trim().toLowerCase();
    if (normalizedName.isEmpty || normalizedName.length > 120) {
      throw const TenantRepositoryException(
        'Enter a tenant name between 1 and 120 characters.',
      );
    }
    if (!_looksLikeEmail(normalizedEmail)) {
      throw const TenantRepositoryException(
        'Enter a valid owner email address.',
      );
    }

    try {
      final row = await _tenantStore.createTenant(
        name: normalizedName,
        ownerEmail: normalizedEmail,
        requestId: requestId,
      );
      if (row['success'] != true) {
        throw const FormatException('The tenant creation response is invalid.');
      }
      final tenantRow = _mapRow(
        row['tenant'],
        'The created tenant response is invalid.',
      );
      final temporaryPassword = row['temporaryPassword'];
      if (temporaryPassword != null && temporaryPassword is! String) {
        throw const FormatException(
          'The temporary password response is invalid.',
        );
      }

      return TenantCreationResult(
        tenant: ParkingTenant(
          id: _requiredString(tenantRow['id'], 'id'),
          name: _requiredString(tenantRow['name'], 'name'),
          slug: _requiredString(tenantRow['slug'], 'slug'),
          role: ParkingTenantRole.owner,
        ),
        temporaryPassword: temporaryPassword as String?,
      );
    } on TenantStoreException catch (error) {
      throw TenantRepositoryException(
        error.message,
        temporaryPassword: error.temporaryPassword,
      );
    } on PostgrestException catch (error) {
      switch (error.code) {
        case 'P0002':
          throw const TenantRepositoryException(
            'The owner Supabase account could not be found. Check the email '
            'address and retry.',
          );
        case '42501':
          throw const TenantRepositoryException(
            'Only a Super Admin can create tenants.',
          );
        case '22023':
          throw const TenantRepositoryException(
            'Check the tenant name and owner email, then try again.',
          );
        default:
          throw const TenantRepositoryException(
            'The tenant could not be created. Check your connection and retry.',
          );
      }
    } on FormatException {
      throw const TenantRepositoryException(
        'The tenant creation response was invalid. Contact the system administrator.',
      );
    }
  }

  @override
  Future<ParkingTenant> updateTenant({
    required String tenantId,
    required String name,
  }) async {
    final normalizedName = name.trim();
    if (tenantId.trim().isEmpty ||
        normalizedName.isEmpty ||
        normalizedName.length > 120) {
      throw const TenantRepositoryException(
        'Enter a tenant name between 1 and 120 characters.',
      );
    }

    try {
      final row = await _tenantStore.updateTenant(
        tenantId: tenantId,
        name: normalizedName,
      );
      return _tenantFromRow(row);
    } on TenantStoreException catch (error) {
      throw TenantRepositoryException(error.message);
    } on PostgrestException catch (error) {
      throw _managementError(
        error,
        fallback:
            'The tenant could not be updated. Check your connection and retry.',
      );
    }
  }

  @override
  Future<void> archiveTenant({required String tenantId}) async {
    await _runTenantAction(
      tenantId: tenantId,
      action: () => _tenantStore.archiveTenant(tenantId: tenantId),
      fallback:
          'The tenant could not be archived. Check your connection and retry.',
    );
  }

  @override
  Future<void> restoreTenant({required String tenantId}) async {
    await _runTenantAction(
      tenantId: tenantId,
      action: () => _tenantStore.restoreTenant(tenantId: tenantId),
      fallback:
          'The tenant could not be restored. Check your connection and retry.',
    );
  }

  @override
  Future<List<ParkingTenantMember>> listMembers({
    required String tenantId,
  }) async {
    if (tenantId.trim().isEmpty) {
      throw const TenantRepositoryException('Select a tenant to view members.');
    }

    try {
      final rows = await _tenantStore.listTenantMembers(tenantId: tenantId);
      return rows
          .map(
            (row) => ParkingTenantMember(
              userId: _requiredString(row['user_id'], 'user_id'),
              email: row['email'] is String ? row['email'] as String : '',
              role: ParkingTenantRole.values.byName(
                _requiredString(row['role'], 'role'),
              ),
            ),
          )
          .toList(growable: false);
    } on TenantStoreException catch (error) {
      throw TenantRepositoryException(error.message);
    } on PostgrestException catch (error) {
      throw _managementError(
        error,
        fallback: 'Tenant members could not be loaded. Check your connection and retry.',
      );
    } on Exception {
      throw const TenantRepositoryException(
        'Tenant member data is invalid. Contact the system administrator.',
      );
    }
  }

  @override
  Future<void> addMember({
    required String tenantId,
    required String email,
    required ParkingTenantRole role,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (tenantId.trim().isEmpty || !_looksLikeEmail(normalizedEmail)) {
      throw const TenantRepositoryException(
        'Enter a valid member email address.',
      );
    }

    try {
      await _tenantStore.addTenantMember(
        tenantId: tenantId,
        email: normalizedEmail,
        role: role.name,
      );
    } on TenantStoreException catch (error) {
      throw TenantRepositoryException(error.message);
    } on PostgrestException catch (error) {
      throw _managementError(
        error,
        fallback:
            'The member could not be added. Check your connection and retry.',
      );
    }
  }

  @override
  Future<void> updateMemberRole({
    required String tenantId,
    required String userId,
    required ParkingTenantRole role,
  }) async {
    await _runTenantAction(
      tenantId: tenantId,
      action: () => _tenantStore.updateTenantMemberRole(
        tenantId: tenantId,
        userId: userId,
        role: role.name,
      ),
      fallback: 'The member role could not be updated. Check your connection and retry.',
    );
  }

  @override
  Future<void> removeMember({
    required String tenantId,
    required String userId,
  }) async {
    await _runTenantAction(
      tenantId: tenantId,
      action: () =>
          _tenantStore.removeTenantMember(tenantId: tenantId, userId: userId),
      fallback:
          'The member could not be removed. Check your connection and retry.',
    );
  }

  Future<void> _runTenantAction({
    required String tenantId,
    required Future<void> Function() action,
    required String fallback,
  }) async {
    if (tenantId.trim().isEmpty) {
      throw const TenantRepositoryException('Select a tenant.');
    }

    try {
      await action();
    } on TenantStoreException catch (error) {
      throw TenantRepositoryException(error.message);
    } on PostgrestException catch (error) {
      throw _managementError(error, fallback: fallback);
    }
  }

  static ParkingTenant _tenantFromRow(Map<String, dynamic> row) {
    return ParkingTenant(
      id: _requiredString(row['id'], 'id'),
      name: _requiredString(row['name'], 'name'),
      slug: _requiredString(row['slug'], 'slug'),
      isArchived: row['archived_at'] != null,
    );
  }

  static Map<String, dynamic> _mapRow(Object? value, String errorMessage) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw FormatException(errorMessage);
  }

  static TenantRepositoryException _managementError(
    PostgrestException error, {
    required String fallback,
  }) {
    final message = switch (error.code) {
      '42501' => 'Only a Super Admin can manage tenants and members.',
      'P0002' => 'The tenant or Supabase account could not be found.',
      '22023' => 'Check the tenant name, email, and selected role.',
      '23514' => 'Every tenant must keep at least one owner.',
      '55000' => 'Restore this tenant before adding members.',
      _ => fallback,
    };
    return TenantRepositoryException(message);
  }

  static bool _looksLikeEmail(String value) {
    final atIndex = value.indexOf('@');
    return atIndex > 0 &&
        atIndex < value.length - 1 &&
        value.indexOf('.', atIndex) > atIndex + 1 &&
        value.indexOf('.', atIndex) < value.length - 1;
  }

  static bool _isMissingTenantSchema(PostgrestException error) {
    return error.code == 'PGRST202' ||
        error.code == 'PGRST204' ||
        error.code == 'PGRST205' ||
        error.code == '42P01' ||
        error.code == '42703';
  }

  static String _requiredString(Object? value, String fieldName) {
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    throw FormatException('The $fieldName value is invalid.');
  }

  static SupabaseClient _requireClient(SupabaseClient? client) {
    if (client == null) {
      throw ArgumentError(
        'A Supabase client is required when a tenant store is not injected.',
      );
    }

    return client;
  }
}

class _SupabaseTenantStore implements TenantStore {
  const _SupabaseTenantStore(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> isSuperAdmin() async {
    final result = await _client.rpc('is_super_admin');
    if (result is bool) {
      return result;
    }

    throw const FormatException('The Super Admin role response is invalid.');
  }

  @override
  Future<List<Map<String, dynamic>>> memberships() {
    return _client.from('tenant_memberships').select('tenant_id,role');
  }

  @override
  Future<List<Map<String, dynamic>>> tenants({List<String>? tenantIds}) {
    if (tenantIds != null && tenantIds.isEmpty) {
      return Future.value(const []);
    }

    var query = _client.from('tenants').select('id,name,slug,archived_at');
    if (tenantIds != null) {
      query = query.inFilter('id', tenantIds);
    }

    return query.order('name');
  }

  @override
  Future<Map<String, dynamic>> createTenant({
    required String name,
    required String ownerEmail,
    required String requestId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'create-tenant-owner',
        body: {'name': name, 'ownerEmail': ownerEmail, 'requestId': requestId},
      );
      return _mapResult(
        response.data,
        'The created tenant response is invalid.',
      );
    } on FunctionException catch (error) {
      final details = _mapOptionalRow(error.details);
      final code = details?['code'];
      final temporaryPassword = details?['temporaryPassword'];
      final message = switch (code) {
        'authentication_required' =>
          'Your session expired. Sign in again and retry.',
        'super_admin_required' => 'Only a Super Admin can create tenants.',
        'tenant_setup_incomplete' =>
          'Apply the tenant-owner onboarding migration and deploy the '
              'Supabase Edge Functions before creating tenant owners.',
        'owner_account_creation_failed' => 'The owner account could not be created. Check the email address and retry.',
        'owner_account_not_found' => 'The owner Supabase account could not be found. Check the email address and retry.',
        'owner_onboarding_state_invalid' => 'This owner account has an incomplete setup record. Contact the system administrator.',
        'temporary_password_rotation_failed' => 'Tenant setup may be complete, but a temporary password could not be recovered. Retry the same tenant details.',
        'tenant_creation_incomplete' =>
          'The owner account was created, but tenant setup could not be confirmed. '
              'Retry the same tenant details and use the latest temporary password shown.',
        'invalid_request' =>
          'Check the tenant name and owner email, then try again.',
        _ =>
          'The tenant could not be created. Check your connection and retry.',
      };
      throw TenantStoreException(
        message,
        temporaryPassword: temporaryPassword is String
            ? temporaryPassword
            : null,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> updateTenant({
    required String tenantId,
    required String name,
  }) async {
    return _mapResult(
      await _client.rpc(
        'update_tenant',
        params: {'p_tenant_id': tenantId, 'p_name': name},
      ),
      'The updated tenant response is invalid.',
    );
  }

  @override
  Future<void> archiveTenant({required String tenantId}) async {
    await _client.rpc('archive_tenant', params: {'p_tenant_id': tenantId});
  }

  @override
  Future<void> restoreTenant({required String tenantId}) async {
    await _client.rpc('restore_tenant', params: {'p_tenant_id': tenantId});
  }

  @override
  Future<List<Map<String, dynamic>>> listTenantMembers({
    required String tenantId,
  }) async {
    final result = await _client.rpc(
      'list_tenant_members',
      params: {'p_tenant_id': tenantId},
    );
    if (result is! List) {
      throw const FormatException('The tenant member response is invalid.');
    }

    return result
        .map(
          (row) => row is Map<String, dynamic>
              ? row
              : row is Map
              ? Map<String, dynamic>.from(row)
              : throw const FormatException(
                  'The tenant member response is invalid.',
                ),
        )
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> addTenantMember({
    required String tenantId,
    required String email,
    required String role,
  }) async {
    return _mapResult(
      await _client.rpc(
        'add_tenant_member',
        params: {'p_tenant_id': tenantId, 'p_email': email, 'p_role': role},
      ),
      'The added member response is invalid.',
    );
  }

  @override
  Future<void> updateTenantMemberRole({
    required String tenantId,
    required String userId,
    required String role,
  }) async {
    await _client.rpc(
      'update_tenant_member_role',
      params: {'p_tenant_id': tenantId, 'p_user_id': userId, 'p_role': role},
    );
  }

  @override
  Future<void> removeTenantMember({
    required String tenantId,
    required String userId,
  }) async {
    await _client.rpc(
      'remove_tenant_member',
      params: {'p_tenant_id': tenantId, 'p_user_id': userId},
    );
  }

  static Map<String, dynamic> _mapResult(Object? result, String message) {
    if (result is Map<String, dynamic>) {
      return result;
    }
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    throw FormatException(message);
  }

  static Map<String, dynamic>? _mapOptionalRow(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }
}
