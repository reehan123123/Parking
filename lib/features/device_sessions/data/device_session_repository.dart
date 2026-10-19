import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/device_session_models.dart';

/// Reads and updates the authenticated user's tenant-scoped device sessions.
abstract interface class DeviceSessionRepository {
  /// Registers the current Auth session in the selected tenant.
  Future<void> registerCurrentSession({required String tenantId});

  /// Lists the signed-in user's active device installations.
  Future<List<UserDeviceSession>> listMySessions();

  /// Revokes all active Auth sessions on one of the user's installations.
  Future<void> revokeMyInstallation({
    required String tenantId,
    required String installationId,
  });

  /// Releases this Auth session from every tenant before sign-out.
  Future<void> releaseCurrentSession();
}

/// Reads and updates device policies and sessions as a Super Admin.
abstract interface class DeviceSessionAdminRepository {
  /// Loads the platform-wide device policy.
  Future<PlatformDeviceSessionPolicy> getPlatformPolicy();

  /// Updates the platform limit and stale-session expiry.
  Future<void> setPlatformPolicy({
    required int deviceLimit,
    required int staleSessionDays,
  });

  /// Loads the effective device policy and usage for one tenant.
  Future<TenantDeviceSessionPolicy> getTenantPolicy({required String tenantId});

  /// Sets a tenant limit, or clears it to inherit the platform default.
  Future<void> setTenantLimit({
    required String tenantId,
    required int? deviceLimit,
  });

  /// Lists tenant members with their effective limits and usage.
  Future<List<TenantMemberDevicePolicy>> listTenantMemberPolicies({
    required String tenantId,
  });

  /// Sets or clears a per-account override for one tenant member.
  Future<void> setMemberLimit({
    required String tenantId,
    required String userId,
    required int? deviceLimit,
  });

  /// Lists active installations for a tenant without browser fingerprints.
  Future<List<AdminDeviceSession>> listTenantSessions({
    required String tenantId,
  });

  /// Revokes one member's installation in one tenant.
  Future<void> revokeTenantInstallation({
    required String tenantId,
    required String userId,
    required String installationId,
  });

  /// Lists the latest platform and tenant device-session audit events.
  Future<List<DeviceSessionAuditEvent>> listAuditEvents();
}

/// An error returned while loading or changing a device session.
class DeviceSessionRepositoryException implements Exception {
  /// Creates a device-session error with a user-safe message.
  const DeviceSessionRepositoryException(this.message);

  /// A message that does not contain credentials or session tokens.
  final String message;

  @override
  String toString() => message;
}

/// A typed rejection containing the policy limit that was reached.
class DeviceLimitReachedException extends DeviceSessionRepositoryException {
  /// Creates an exception for a registration rejected by the device limit.
  const DeviceLimitReachedException({
    required this.deviceLimit,
    required this.activeDeviceCount,
  }) : super('The active-device limit has been reached.');

  /// The effective limit applied to this account and tenant.
  final int deviceLimit;

  /// The number of active installations already registered.
  final int activeDeviceCount;
}

/// Creates and persists one random opaque ID for this browser installation.
abstract interface class DeviceInstallationIdStore {
  /// Returns the saved ID or creates a new version-4 UUID.
  Future<String> getOrCreate();
}

/// Stores the opaque installation ID in the browser's local preferences.
class SharedPreferencesDeviceInstallationIdStore
    implements DeviceInstallationIdStore {
  /// Creates a browser-backed installation ID store.
  const SharedPreferencesDeviceInstallationIdStore();

  static const _preferenceKey = 'parking_device_installation_id';
  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  @override
  Future<String> getOrCreate() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? savedId = preferences.getString(_preferenceKey);
    if (savedId != null && _uuidPattern.hasMatch(savedId)) {
      return savedId;
    }

    final String newId = _createInstallationId();
    final bool saved = await preferences.setString(_preferenceKey, newId);
    if (!saved) {
      throw const DeviceSessionRepositoryException(
        'The device installation ID could not be saved.',
      );
    }
    return newId;
  }

  static String _createInstallationId() {
    final List<int> bytes = List<int>.generate(
      16,
      (_) => Random.secure().nextInt(256),
    );
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final String hex = bytes
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

/// Supabase RPC implementation for user and Super Admin device-session flows.
class SupabaseDeviceSessionRepository
    implements DeviceSessionRepository, DeviceSessionAdminRepository {
  /// Creates a repository using Supabase and the browser installation store.
  SupabaseDeviceSessionRepository(
    this._client, {
    this._installationIdStore =
        const SharedPreferencesDeviceInstallationIdStore(),
  });

  final SupabaseClient _client;
  final DeviceInstallationIdStore _installationIdStore;

  @override
  Future<void> registerCurrentSession({required String tenantId}) async {
    if (tenantId.trim().isEmpty) {
      throw const DeviceSessionRepositoryException(
        'Select a tenant before registering this device.',
      );
    }

    try {
      final String installationId = await _installationIdStore.getOrCreate();
      final Map<String, dynamic> result = _readRow(
        await _client.rpc(
          'register_device_session',
          params: {
            'p_tenant_id': tenantId,
            'p_installation_id': installationId,
          },
        ),
      );
      if (result['accepted'] == true) {
        return;
      }

      if (result['reason'] == 'device_limit_reached') {
        throw DeviceLimitReachedException(
          deviceLimit: _requiredInt(result['effective_limit']),
          activeDeviceCount: _requiredInt(result['active_device_count']),
        );
      }

      if (result['reason'] == 'session_ended' ||
          result['reason'] == 'installation_mismatch') {
        throw const DeviceSessionRepositoryException(
          'This sign-in session cannot be reused. Sign out and sign in again.',
        );
      }

      throw const DeviceSessionRepositoryException(
        'This device session could not be verified. Sign out and sign in again.',
      );
    } on PostgrestException catch (error) {
      throw _repositoryError(error);
    } on FormatException {
      throw const DeviceSessionRepositoryException(
        'The device-session response was invalid. Contact the administrator.',
      );
    }
  }

  @override
  Future<List<UserDeviceSession>> listMySessions() async {
    try {
      final String installationId = await _installationIdStore.getOrCreate();
      final List<Map<String, dynamic>> rows = _readRows(
        await _client.rpc('list_my_device_sessions'),
      );
      return rows
          .map(
            (Map<String, dynamic> row) => UserDeviceSession.fromRow(
              row,
              currentInstallationId: installationId,
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw _repositoryError(error);
    } on FormatException {
      throw const DeviceSessionRepositoryException(
        'The device-session list was invalid. Contact the administrator.',
      );
    }
  }

  @override
  Future<void> revokeMyInstallation({
    required String tenantId,
    required String installationId,
  }) async {
    if (tenantId.trim().isEmpty || !_isUuid(installationId)) {
      throw const DeviceSessionRepositoryException(
        'Select a valid device session to remove.',
      );
    }

    try {
      await _client.rpc(
        'revoke_my_device_installation',
        params: {'p_tenant_id': tenantId, 'p_installation_id': installationId},
      );
    } on PostgrestException catch (error) {
      throw _repositoryError(error);
    }
  }

  @override
  Future<void> releaseCurrentSession() async {
    try {
      await _client.rpc('release_current_device_sessions');
    } on PostgrestException catch (error) {
      throw _repositoryError(error);
    }
  }

  @override
  Future<PlatformDeviceSessionPolicy> getPlatformPolicy() {
    return _runAdmin(
      () async => PlatformDeviceSessionPolicy.fromRow(
        _readRow(await _client.rpc('get_platform_device_session_policy')),
      ),
    );
  }

  @override
  Future<void> setPlatformPolicy({
    required int deviceLimit,
    required int staleSessionDays,
  }) {
    if (deviceLimit < 1 ||
        deviceLimit > 50 ||
        staleSessionDays < 7 ||
        staleSessionDays > 365) {
      throw const DeviceSessionRepositoryException(
        'Device limits must be 1-50 and stale expiry must be 7-365 days.',
      );
    }

    return _runAdmin(() async {
      await _client.rpc(
        'set_platform_device_session_policy',
        params: {
          'p_device_limit': deviceLimit,
          'p_stale_session_days': staleSessionDays,
        },
      );
    });
  }

  @override
  Future<TenantDeviceSessionPolicy> getTenantPolicy({
    required String tenantId,
  }) {
    return _runAdmin(
      () async => TenantDeviceSessionPolicy.fromRow(
        _readRow(
          await _client.rpc(
            'get_tenant_device_session_policy',
            params: {'p_tenant_id': tenantId},
          ),
        ),
      ),
    );
  }

  @override
  Future<void> setTenantLimit({
    required String tenantId,
    required int? deviceLimit,
  }) {
    if (tenantId.trim().isEmpty ||
        (deviceLimit != null && (deviceLimit < 1 || deviceLimit > 50))) {
      throw const DeviceSessionRepositoryException(
        'Select a tenant and use a device limit between 1 and 50.',
      );
    }

    return _runAdmin(() async {
      await _client.rpc(
        'set_tenant_device_session_limit',
        params: {'p_tenant_id': tenantId, 'p_device_limit': deviceLimit},
      );
    });
  }

  @override
  Future<List<TenantMemberDevicePolicy>> listTenantMemberPolicies({
    required String tenantId,
  }) {
    return _runAdmin(() async {
      final List<Map<String, dynamic>> rows = _readRows(
        await _client.rpc(
          'list_tenant_member_device_session_policies',
          params: {'p_tenant_id': tenantId},
        ),
      );
      return rows.map(TenantMemberDevicePolicy.fromRow).toList(growable: false);
    });
  }

  @override
  Future<void> setMemberLimit({
    required String tenantId,
    required String userId,
    required int? deviceLimit,
  }) {
    if (tenantId.trim().isEmpty ||
        userId.trim().isEmpty ||
        (deviceLimit != null && (deviceLimit < 1 || deviceLimit > 50))) {
      throw const DeviceSessionRepositoryException(
        'Select a member and use a device limit between 1 and 50.',
      );
    }

    return _runAdmin(() async {
      await _client.rpc(
        'set_tenant_member_device_session_limit',
        params: {
          'p_tenant_id': tenantId,
          'p_user_id': userId,
          'p_device_limit': deviceLimit,
        },
      );
    });
  }

  @override
  Future<List<AdminDeviceSession>> listTenantSessions({
    required String tenantId,
  }) {
    return _runAdmin(() async {
      final List<Map<String, dynamic>> rows = _readRows(
        await _client.rpc(
          'list_tenant_device_sessions',
          params: {'p_tenant_id': tenantId},
        ),
      );
      return rows.map(AdminDeviceSession.fromRow).toList(growable: false);
    });
  }

  @override
  Future<void> revokeTenantInstallation({
    required String tenantId,
    required String userId,
    required String installationId,
  }) {
    if (tenantId.trim().isEmpty ||
        userId.trim().isEmpty ||
        !_isUuid(installationId)) {
      throw const DeviceSessionRepositoryException(
        'Select a valid device session to revoke.',
      );
    }

    return _runAdmin(() async {
      await _client.rpc(
        'revoke_tenant_device_installation',
        params: {
          'p_tenant_id': tenantId,
          'p_user_id': userId,
          'p_installation_id': installationId,
        },
      );
    });
  }

  @override
  Future<List<DeviceSessionAuditEvent>> listAuditEvents() {
    return _runAdmin(() async {
      final List<Map<String, dynamic>> rows = _readRows(
        await _client.rpc('list_device_session_audit_events'),
      );
      return rows.map(DeviceSessionAuditEvent.fromRow).toList(growable: false);
    });
  }

  Future<T> _runAdmin<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      throw _repositoryError(error);
    } on FormatException {
      throw const DeviceSessionRepositoryException(
        'The device policy response was invalid. Contact the administrator.',
      );
    }
  }

  static DeviceSessionRepositoryException _repositoryError(
    PostgrestException error,
  ) {
    final String message = switch (error.code) {
      '42501' =>
        'This device-session operation is not authorized or the sign-in '
            'session must be renewed.',
      '22023' => 'The device-session request was invalid.',
      'P0002' => 'The selected tenant or account could not be found.',
      '55000' => 'Device-session configuration is unavailable.',
      _ =>
        'The device-session service could not complete the request. '
            'Check your connection and retry.',
    };
    return DeviceSessionRepositoryException(message);
  }

  static Map<String, dynamic> _readRow(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw const FormatException('A device-session response row is invalid.');
  }

  static List<Map<String, dynamic>> _readRows(Object? value) {
    if (value is! Iterable) {
      throw const FormatException('A device-session response list is invalid.');
    }
    return value.map(_readRow).toList(growable: false);
  }

  static int _requiredInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    throw const FormatException('A device-session response value is invalid.');
  }

  static bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }
}
