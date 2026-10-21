import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/validation/indian_mobile_normalizer.dart';
import '../domain/parking_tenant.dart';
import 'tenant_repository.dart';

class TenantRepositoryException implements Exception {
  const TenantRepositoryException(
    this.message, {
    this.temporaryPassword,
    this.code,
  });

  final String message;
  final String? temporaryPassword;
  final String? code;

  @override
  String toString() => message;
}

class TenantMemberLimitReachedException extends TenantRepositoryException {
  const TenantMemberLimitReachedException({
    this.memberLimit,
    this.activeMemberCount,
    this.remainingMemberCount,
  }) : super(
         'You have reached this tenant’s member limit. Remove a member or ask '
         'your Super Admin to increase the limit.',
         code: 'MEMBER_LIMIT_REACHED',
       );

  final int? memberLimit;
  final int? activeMemberCount;
  final int? remainingMemberCount;
}

class TenantStoreException implements Exception {
  const TenantStoreException(
    this.message, {
    this.temporaryPassword,
    this.code,
    this.details,
  });

  final String message;
  final String? temporaryPassword;
  final String? code;
  final Map<String, dynamic>? details;
}

abstract interface class TenantStore {
  Future<bool> isSuperAdmin();

  Future<List<Map<String, dynamic>>> memberships();

  Future<List<Map<String, dynamic>>> tenants({List<String>? tenantIds});

  Future<Map<String, dynamic>> createTenant({
    required String name,
    required String ownerEmail,
    required String requestId,
    required bool isActive,
    required DateTime validUntil,
    String? contactName,
    String? contactMobile,
    String? contactEmail,
  });

  Future<Map<String, dynamic>> updateTenant({
    required String tenantId,
    required String name,
    required DateTime validUntil,
    String? contactName,
    String? contactMobile,
    String? contactEmail,
  });

  Future<void> archiveTenant({required String tenantId});

  Future<void> restoreTenant({required String tenantId});

  Future<List<Map<String, dynamic>>> listTenantMembers({
    required String tenantId,
  });

  Future<Map<String, dynamic>> getTenantMemberCapacity({
    required String tenantId,
  });

  Future<List<Map<String, dynamic>>> listTenantMemberCapacities();

  Future<Map<String, dynamic>> setTenantMemberLimit({
    required String tenantId,
    required int memberLimit,
  });

  Future<List<Map<String, dynamic>>> listTenantMemberAuditEvents({
    required String tenantId,
  });

  Future<Map<String, dynamic>> addTenantMember({
    required String tenantId,
    required String email,
    required String requestId,
    required String role,
  });

  Future<void> setTenantMemberPermissions({
    required String tenantId,
    required String userId,
    required TenantEntryPermissions permissions,
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

/// Loads a member's tenant choices before tenant RLS access is established.
abstract interface class DeviceSessionTenantChoiceStore {
  /// Returns only the signed-in user's active tenant choices.
  Future<List<Map<String, dynamic>>> currentTenantChoices();
}

class SupabaseTenantRepository implements TenantRepository {
  SupabaseTenantRepository(SupabaseClient? client, {TenantStore? tenantStore})
    : _tenantStore =
          tenantStore ?? _SupabaseTenantStore(_requireClient(client));

  final TenantStore _tenantStore;

  @override
  Future<ParkingTenantAccess> loadAccess() async {
    final TenantStore store = _tenantStore;
    try {
      final isSuperAdmin = await store.isSuperAdmin();
      final membershipRoles = <String, ParkingTenantRole>{};
      final membershipPermissions = <String, TenantEntryPermissions>{};
      late final List<Map<String, dynamic>> rows;
      if (isSuperAdmin) {
        rows = await store.tenants();
      } else if (store case DeviceSessionTenantChoiceStore choiceStore) {
        final choices = await choiceStore.currentTenantChoices();
        for (final row in choices) {
          final tenantId = _requiredString(row['tenant_id'], 'tenant_id');
          final roleName = _requiredString(row['role'], 'role');
          membershipRoles[tenantId] = ParkingTenantRole.values.byName(roleName);
          membershipPermissions[tenantId] = _entryPermissions(row, roleName);
        }
        rows = choices
            .map(
              (row) => {
                'id': row['tenant_id'],
                'name': row['tenant_name'],
                'slug': row['tenant_slug'],
                'archived_at': row['archived_at'],
                'valid_until': row['valid_until'],
                'can_view_entries': row['can_view_entries'],
                'can_add_entries': row['can_add_entries'],
                'can_edit_entries': row['can_edit_entries'],
                'can_delete_entries': row['can_delete_entries'],
              },
            )
            .toList(growable: false);
      } else {
        for (final row in await store.memberships()) {
          final tenantId = _requiredString(row['tenant_id'], 'tenant_id');
          final roleName = _requiredString(row['role'], 'role');
          membershipRoles[tenantId] = ParkingTenantRole.values.byName(roleName);
          membershipPermissions[tenantId] = _entryPermissions(row, roleName);
        }
        rows = await store.tenants(tenantIds: membershipRoles.keys.toList());
      }
      final tenants = rows
          .map((row) {
            final String tenantId = _requiredString(row['id'], 'id');
            return ParkingTenant(
              id: tenantId,
              name: _requiredString(row['name'], 'name'),
              slug: _requiredString(row['slug'], 'slug'),
              role: membershipRoles[tenantId],
              entryPermissions:
                  membershipPermissions[tenantId] ??
                  (isSuperAdmin
                      ? const TenantEntryPermissions.all()
                      : const TenantEntryPermissions.none()),
              isArchived: row['archived_at'] != null,
              validUntil: _optionalDate(row['valid_until']),
              contactName: row['contact_name'] as String?,
              contactMobile: row['contact_mobile'] as String?,
              contactEmail: row['contact_email'] as String?,
            );
          })
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
    } on FormatException {
      throw const TenantRepositoryException(
        'Tenant access data is invalid. Contact the system administrator.',
      );
    } on ArgumentError {
      throw const TenantRepositoryException(
        'Tenant access data is invalid. Contact the system administrator.',
      );
    } on Exception {
      throw const TenantRepositoryException(
        'Tenant access could not be loaded. Check your connection and retry.',
      );
    }
  }

  @override
  Future<TenantCreationResult> createTenant({
    required String name,
    required String ownerEmail,
    required String requestId,
    required bool isActive,
    required DateTime validUntil,
    String? contactName,
    String? contactMobile,
    String? contactEmail,
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
    final normalizedContactMobile = _normalizeContactMobile(contactMobile);
    final normalizedContactEmail = _normalizeContactEmail(contactEmail);
    final normalizedContactName = _normalizeContactName(contactName);

    try {
      final row = await _tenantStore.createTenant(
        name: normalizedName,
        ownerEmail: normalizedEmail,
        requestId: requestId,
        isActive: isActive,
        validUntil: validUntil,
        contactName: normalizedContactName,
        contactMobile: normalizedContactMobile,
        contactEmail: normalizedContactEmail,
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
          validUntil: validUntil,
          contactName: normalizedContactName,
          contactMobile: normalizedContactMobile,
          contactEmail: normalizedContactEmail,
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
            'Check the tenant name, owner email, validity date, and contact '
            'details, then try again.',
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
    required DateTime validUntil,
    String? contactName,
    String? contactMobile,
    String? contactEmail,
  }) async {
    final normalizedName = name.trim();
    if (tenantId.trim().isEmpty ||
        normalizedName.isEmpty ||
        normalizedName.length > 120) {
      throw const TenantRepositoryException(
        'Enter a tenant name between 1 and 120 characters.',
      );
    }
    final normalizedContactMobile = _normalizeContactMobile(contactMobile);
    final normalizedContactEmail = _normalizeContactEmail(contactEmail);
    final normalizedContactName = _normalizeContactName(contactName);

    try {
      final row = await _tenantStore.updateTenant(
        tenantId: tenantId,
        name: normalizedName,
        validUntil: validUntil,
        contactName: normalizedContactName,
        contactMobile: normalizedContactMobile,
        contactEmail: normalizedContactEmail,
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
              permissions: _entryPermissions(
                row,
                _requiredString(row['role'], 'role'),
              ),
              createdAt: _requiredDate(row['created_at'], 'created_at'),
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
  Future<TenantMemberCapacity> getMemberCapacity({
    required String tenantId,
  }) async {
    if (tenantId.trim().isEmpty) {
      throw const TenantRepositoryException(
        'Select a tenant to view member usage.',
      );
    }

    try {
      final row = await _tenantStore.getTenantMemberCapacity(
        tenantId: tenantId,
      );
      return _capacityFromRow(row, tenantId: tenantId);
    } on TenantStoreException catch (error) {
      throw TenantRepositoryException(error.message, code: error.code);
    } on PostgrestException catch (error) {
      throw _managementError(
        error,
        fallback: 'Member usage could not be loaded. Check your connection and retry.',
      );
    } on FormatException {
      throw const TenantRepositoryException(
        'Member usage data is invalid. Contact the system administrator.',
      );
    }
  }

  @override
  Future<List<TenantMemberCapacity>> listMemberCapacities() async {
    try {
      final rows = await _tenantStore.listTenantMemberCapacities();
      return rows.map((row) => _capacityFromRow(row)).toList(growable: false);
    } on TenantStoreException catch (error) {
      throw TenantRepositoryException(error.message, code: error.code);
    } on PostgrestException catch (error) {
      throw _managementError(
        error,
        fallback: 'Tenant member usage could not be loaded. Check your connection and retry.',
      );
    } on FormatException {
      throw const TenantRepositoryException(
        'Member usage data is invalid. Contact the system administrator.',
      );
    }
  }

  @override
  Future<TenantMemberCapacity> setMemberLimit({
    required String tenantId,
    required int memberLimit,
  }) async {
    if (tenantId.trim().isEmpty || memberLimit < 1 || memberLimit > 50) {
      throw const TenantRepositoryException(
        'The member limit must be a whole number from 1 to 50.',
      );
    }

    try {
      final row = await _tenantStore.setTenantMemberLimit(
        tenantId: tenantId,
        memberLimit: memberLimit,
      );
      return _capacityFromRow(row, tenantId: tenantId);
    } on TenantStoreException catch (error) {
      throw TenantRepositoryException(error.message, code: error.code);
    } on PostgrestException catch (error) {
      throw _managementError(
        error,
        fallback: 'The member limit could not be saved. Check your connection and retry.',
      );
    } on FormatException {
      throw const TenantRepositoryException(
        'Member usage data is invalid. Contact the system administrator.',
      );
    }
  }

  @override
  Future<List<TenantMemberAuditEvent>> listMemberAuditEvents({
    required String tenantId,
  }) async {
    if (tenantId.trim().isEmpty) {
      throw const TenantRepositoryException(
        'Select a tenant to view the member audit history.',
      );
    }

    try {
      final rows = await _tenantStore.listTenantMemberAuditEvents(
        tenantId: tenantId,
      );
      return rows
          .map(
            (row) => TenantMemberAuditEvent(
              id: _requiredInteger(row['id'], 'id'),
              action: _requiredString(row['action'], 'action'),
              details: _mapRow(row['details'], 'audit details are invalid.'),
              createdAt: _requiredDate(row['created_at'], 'created_at'),
              actorEmail: row['actor_email'] as String?,
              subjectEmail: row['subject_email'] as String?,
            ),
          )
          .toList(growable: false);
    } on TenantStoreException catch (error) {
      throw TenantRepositoryException(error.message, code: error.code);
    } on PostgrestException catch (error) {
      throw _managementError(
        error,
        fallback: 'Member audit history could not be loaded. Check your connection and retry.',
      );
    } on FormatException {
      throw const TenantRepositoryException(
        'Member audit data is invalid. Contact the system administrator.',
      );
    }
  }

  @override
  Future<TenantMemberCreationResult> addMember({
    required String tenantId,
    required String email,
    required String requestId,
    required ParkingTenantRole role,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (tenantId.trim().isEmpty ||
        !_looksLikeEmail(normalizedEmail) ||
        !_isUuidV4(requestId)) {
      throw const TenantRepositoryException(
        'Enter a valid member email address and request identifier.',
      );
    }

    try {
      final Map<String, dynamic> result = await _tenantStore.addTenantMember(
        tenantId: tenantId,
        email: normalizedEmail,
        requestId: requestId,
        role: role.name,
      );
      if (result['success'] != true || result['accountCreated'] is! bool) {
        throw const FormatException('The member creation response is invalid.');
      }

      final Object? passwordValue = result['temporaryPassword'];
      if (passwordValue != null &&
          (passwordValue is! String || passwordValue.isEmpty)) {
        throw const FormatException(
          'The temporary member password response is invalid.',
        );
      }
      return TenantMemberCreationResult(
        accountCreated: result['accountCreated'] as bool,
        temporaryPassword: passwordValue as String?,
      );
    } on TenantStoreException catch (error) {
      if (error.code == 'MEMBER_LIMIT_REACHED' ||
          error.code == 'member_limit_reached') {
        throw _memberLimitError(error.details);
      }
      throw TenantRepositoryException(
        error.message,
        code: error.code,
        temporaryPassword: error.temporaryPassword,
      );
    } on PostgrestException catch (error) {
      if (error.message == 'MEMBER_LIMIT_REACHED') {
        throw _memberLimitError(_decodeDetails(error.details));
      }
      throw _managementError(
        error,
        fallback:
            'The member could not be added. Check your connection and retry.',
      );
    } on FormatException {
      throw const TenantRepositoryException(
        'The member creation response was invalid. Contact the system administrator.',
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
  Future<void> updateMemberPermissions({
    required String tenantId,
    required String userId,
    required TenantEntryPermissions permissions,
  }) async {
    await _runTenantAction(
      tenantId: tenantId,
      action: () => _tenantStore.setTenantMemberPermissions(
        tenantId: tenantId,
        userId: userId,
        permissions: permissions,
      ),
      fallback: 'Member permissions could not be updated. Check your connection and retry.',
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
      if (error.code == 'MEMBER_LIMIT_REACHED' ||
          error.code == 'member_limit_reached') {
        throw _memberLimitError(error.details);
      }
      throw TenantRepositoryException(error.message, code: error.code);
    } on PostgrestException catch (error) {
      throw _managementError(error, fallback: fallback);
    }
  }

  static TenantEntryPermissions _entryPermissions(
    Map<String, dynamic> row,
    String role,
  ) {
    if (role == ParkingTenantRole.owner.name) {
      return const TenantEntryPermissions.all();
    }

    final values = [
      row['can_view_entries'],
      row['can_add_entries'],
      row['can_edit_entries'],
      row['can_delete_entries'],
    ];
    if (values.any((value) => value is! bool)) {
      throw const FormatException('Tenant entry permission data is invalid.');
    }

    return TenantEntryPermissions(
      canView: values[0] as bool,
      canAdd: values[1] as bool,
      canEdit: values[2] as bool,
      canDelete: values[3] as bool,
    );
  }

  static TenantMemberCapacity _capacityFromRow(
    Map<String, dynamic> row, {
    String? tenantId,
  }) {
    return TenantMemberCapacity(
      tenantId: _requiredString(row['tenant_id'] ?? tenantId, 'tenant_id'),
      memberLimit: _requiredInteger(row['member_limit'], 'member_limit'),
      activeMemberCount: _requiredInteger(
        row['active_member_count'],
        'active_member_count',
      ),
      remainingMemberCount: _requiredInteger(
        row['remaining_member_count'],
        'remaining_member_count',
      ),
    );
  }

  static TenantMemberLimitReachedException _memberLimitError(
    Map<String, dynamic>? details,
  ) {
    return TenantMemberLimitReachedException(
      memberLimit: _optionalInteger(details?['memberLimit']),
      activeMemberCount: _optionalInteger(details?['activeMemberCount']),
      remainingMemberCount: _optionalInteger(details?['remainingMemberCount']),
    );
  }

  static Map<String, dynamic>? _decodeDetails(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  static ParkingTenant _tenantFromRow(Map<String, dynamic> row) {
    return ParkingTenant(
      id: _requiredString(row['id'], 'id'),
      name: _requiredString(row['name'], 'name'),
      slug: _requiredString(row['slug'], 'slug'),
      isArchived: row['archived_at'] != null,
      validUntil: _optionalDate(row['valid_until']),
      contactName: row['contact_name'] as String?,
      contactMobile: row['contact_mobile'] as String?,
      contactEmail: row['contact_email'] as String?,
    );
  }

  static DateTime? _optionalDate(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static String? _normalizeContactName(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _normalizeContactMobile(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final normalized = IndianMobileNormalizer.tryNormalize(trimmed);
    if (normalized == null) {
      throw const TenantRepositoryException(
        'Enter a valid 10-digit Indian mobile number, optionally with a '
        '+91 prefix.',
      );
    }
    return normalized;
  }

  static String? _normalizeContactEmail(String? value) {
    final trimmed = value?.trim().toLowerCase();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (!_looksLikeEmail(trimmed)) {
      throw const TenantRepositoryException(
        'Enter a valid contact email address.',
      );
    }
    return trimmed;
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
    if (error.message == 'MEMBER_LIMIT_REACHED') {
      return _memberLimitError(_decodeDetails(error.details));
    }

    final message = switch (error.code) {
      '42501' => 'You are not authorized to manage this tenant setting.',
      'P0002' => 'The tenant or Supabase account could not be found.',
      '22023' => 'Check the tenant name, email, and selected role.',
      '23514' => 'Every tenant must keep at least one owner.',
      '55000' => 'Restore this tenant before adding members.',
      _ => fallback,
    };
    return TenantRepositoryException(message, code: error.code);
  }

  static bool _looksLikeEmail(String value) {
    final atIndex = value.indexOf('@');
    return atIndex > 0 &&
        atIndex < value.length - 1 &&
        value.indexOf('.', atIndex) > atIndex + 1 &&
        value.indexOf('.', atIndex) < value.length - 1;
  }

  static bool _isUuidV4(String value) {
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);
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

  static int _requiredInteger(Object? value, String fieldName) {
    final parsed = _optionalInteger(value);
    if (parsed != null) {
      return parsed;
    }
    throw FormatException('The $fieldName value is invalid.');
  }

  static int? _optionalInteger(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static DateTime _requiredDate(Object? value, String fieldName) {
    final date = _optionalDate(value);
    if (date != null) {
      return date;
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

class _SupabaseTenantStore
    implements TenantStore, DeviceSessionTenantChoiceStore {
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
    return _client
        .from('tenant_memberships')
        .select(
          'tenant_id,role,can_view_entries,can_add_entries,'
          'can_edit_entries,can_delete_entries',
        );
  }

  @override
  Future<List<Map<String, dynamic>>> currentTenantChoices() async {
    final result = await _client.rpc('list_my_device_session_tenant_choices');
    if (result is! Iterable) {
      throw const FormatException(
        'The device-session tenant-choice response is invalid.',
      );
    }
    return result
        .map((row) {
          if (row is Map<String, dynamic>) {
            return row;
          }
          if (row is Map) {
            return Map<String, dynamic>.from(row);
          }
          throw const FormatException(
            'The device-session tenant-choice row is invalid.',
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> setTenantMemberPermissions({
    required String tenantId,
    required String userId,
    required TenantEntryPermissions permissions,
  }) async {
    await _client.rpc(
      'set_tenant_member_permissions',
      params: {
        'p_tenant_id': tenantId,
        'p_user_id': userId,
        'p_can_view_entries': permissions.canView,
        'p_can_add_entries': permissions.canAdd,
        'p_can_edit_entries': permissions.canEdit,
        'p_can_delete_entries': permissions.canDelete,
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> tenants({List<String>? tenantIds}) {
    if (tenantIds != null && tenantIds.isEmpty) {
      return Future.value(const []);
    }

    var query = _client
        .from('tenants')
        .select(
          'id,name,slug,archived_at,valid_until,contact_name,'
          'contact_mobile,contact_email',
        );
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
    required bool isActive,
    required DateTime validUntil,
    String? contactName,
    String? contactMobile,
    String? contactEmail,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'create-tenant-owner',
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
    required DateTime validUntil,
    String? contactName,
    String? contactMobile,
    String? contactEmail,
  }) async {
    return _mapResult(
      await _client.rpc(
        'update_tenant',
        params: {
          'p_tenant_id': tenantId,
          'p_name': name,
          'p_valid_until': _isoDate(validUntil),
          'p_contact_name': contactName,
          'p_contact_mobile': contactMobile,
          'p_contact_email': contactEmail,
        },
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
  Future<Map<String, dynamic>> getTenantMemberCapacity({
    required String tenantId,
  }) async {
    return _mapSingleRow(
      await _client.rpc(
        'get_tenant_member_capacity',
        params: {'p_tenant_id': tenantId},
      ),
      'The tenant member-capacity response is invalid.',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> listTenantMemberCapacities() async {
    final result = await _client.rpc('list_tenant_member_capacities');
    if (result is! List) {
      throw const FormatException(
        'The tenant member-capacity response is invalid.',
      );
    }
    return result
        .map(
          (row) => row is Map<String, dynamic>
              ? row
              : row is Map
              ? Map<String, dynamic>.from(row)
              : throw const FormatException(
                  'The tenant member-capacity row is invalid.',
                ),
        )
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> setTenantMemberLimit({
    required String tenantId,
    required int memberLimit,
  }) async {
    return _mapSingleRow(
      await _client.rpc(
        'set_tenant_member_limit',
        params: {'p_tenant_id': tenantId, 'p_member_limit': memberLimit},
      ),
      'The updated tenant member-capacity response is invalid.',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> listTenantMemberAuditEvents({
    required String tenantId,
  }) async {
    final result = await _client.rpc(
      'list_tenant_member_audit_events',
      params: {'p_tenant_id': tenantId, 'p_limit': 100},
    );
    if (result is! List) {
      throw const FormatException(
        'The tenant member-audit response is invalid.',
      );
    }
    return result
        .map(
          (row) => row is Map<String, dynamic>
              ? row
              : row is Map
              ? Map<String, dynamic>.from(row)
              : throw const FormatException(
                  'The tenant member-audit row is invalid.',
                ),
        )
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> addTenantMember({
    required String tenantId,
    required String email,
    required String requestId,
    required String role,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'create-tenant-member',
        body: {
          'tenantId': tenantId,
          'email': email,
          'requestId': requestId,
          'role': role,
        },
      );
      return _mapResult(
        response.data,
        'The created member response is invalid.',
      );
    } on FunctionException catch (error) {
      final Map<String, dynamic>? payload = _mapOptionalRow(error.details);
      final Object? codeValue = payload?['code'];
      final String? code = codeValue is String ? codeValue : null;
      final Map<String, dynamic>? details = _mapOptionalRow(
        payload?['details'],
      );
      final String message = switch (code) {
        'authentication_required' =>
          'Your session expired. Sign in again and retry.',
        'super_admin_required' || 'tenant_management_required' =>
          'You are not authorized to manage members in this tenant.',
        'tenant_setup_incomplete' => 'Member account setup is not available. Check the Supabase Edge Function configuration.',
        'member_account_creation_failed' => 'The new member account could not be created. Check the email address and retry.',
        'member_account_lookup_failed' => 'The existing Supabase account could not be loaded. Check your connection and retry.',
        'member_account_not_found' => 'The account could not be found or created. Check the email address and retry.',
        'member_onboarding_state_invalid' => 'This member account has an incomplete setup record. Contact the system administrator.',
        'temporary_password_rotation_failed' => 'A temporary password could not be recovered. Retry adding the same email.',
        'member_setup_incomplete' => 'Member setup may be incomplete. Retry adding the same email to safely finish setup.',
        'tenant_archived' => 'Restore this tenant before adding members.',
        'MEMBER_LIMIT_REACHED' ||
        'member_limit_reached' => 'The tenant member limit has been reached.',
        'invalid_request' => 'Enter a valid member email address.',
        _ => 'The member could not be added. Check your connection and retry.',
      };
      throw TenantStoreException(message, code: code, details: details);
    }
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

  static Map<String, dynamic> _mapSingleRow(Object? value, String message) {
    if (value is List && value.length == 1) {
      return _mapResult(value.single, message);
    }
    return _mapResult(value, message);
  }

  static Map<String, dynamic>? _mapOptionalRow(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    if (value is String) {
      try {
        final Object? decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } on FormatException {
        return null;
      }
    }

    return null;
  }

  static String _isoDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
