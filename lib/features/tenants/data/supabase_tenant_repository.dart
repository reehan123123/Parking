import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/parking_tenant.dart';
import 'tenant_repository.dart';

class TenantRepositoryException implements Exception {
  const TenantRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class TenantStore {
  Future<bool> isSuperAdmin();

  Future<List<Map<String, dynamic>>> memberships();

  Future<List<Map<String, dynamic>>> tenants({List<String>? tenantIds});

  Future<Map<String, dynamic>> createTenant({
    required String name,
    required String ownerEmail,
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
            ),
          )
          .toList(growable: false);

      return ParkingTenantAccess(isSuperAdmin: isSuperAdmin, tenants: tenants);
    } on PostgrestException catch (error) {
      if (_isMissingTenantSchema(error)) {
        throw const TenantRepositoryException(
          'Tenant setup is not installed yet. Apply the tenant administration '
          'migration, then retry.',
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
  Future<ParkingTenant> createTenant({
    required String name,
    required String ownerEmail,
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
      );
      return ParkingTenant(
        id: _requiredString(row['id'], 'id'),
        name: _requiredString(row['name'], 'name'),
        slug: _requiredString(row['slug'], 'slug'),
        role: ParkingTenantRole.owner,
      );
    } on PostgrestException catch (error) {
      switch (error.code) {
        case 'P0002':
          throw const TenantRepositoryException(
            'That email does not have a Supabase account yet. Create the '
            'account in Supabase Authentication, then try again.',
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
    }
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

    var query = _client.from('tenants').select('id,name,slug');
    if (tenantIds != null) {
      query = query.inFilter('id', tenantIds);
    }

    return query.order('name');
  }

  @override
  Future<Map<String, dynamic>> createTenant({
    required String name,
    required String ownerEmail,
  }) async {
    final result = await _client.rpc(
      'create_tenant',
      params: {'p_name': name, 'p_owner_email': ownerEmail},
    );
    if (result is Map<String, dynamic>) {
      return result;
    }
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    throw const FormatException('The created tenant response is invalid.');
  }
}
