/// A device installation with one or more active Auth sessions in a tenant.
class UserDeviceSession {
  /// Creates a grouped device-session record for the signed-in user.
  const UserDeviceSession({
    required this.tenantId,
    required this.tenantName,
    required this.installationId,
    required this.activeSessionCount,
    required this.lastActivityAt,
    required this.includesCurrentSession,
    required this.isCurrentInstallation,
  });

  /// The tenant in which this installation is registered.
  final String tenantId;

  /// The tenant name shown to the signed-in user.
  final String tenantName;

  /// The random opaque installation identifier.
  final String installationId;

  /// The number of active Auth sessions on this installation in this tenant.
  final int activeSessionCount;

  /// The most recent activity recorded for this installation.
  final DateTime lastActivityAt;

  /// Whether this installation includes the current Auth session.
  final bool includesCurrentSession;

  /// Whether this installation matches the current browser installation ID.
  final bool isCurrentInstallation;

  /// Creates a grouped device-session record from a database RPC row.
  factory UserDeviceSession.fromRow(
    Map<String, dynamic> row, {
    required String currentInstallationId,
  }) {
    final installationId = _requiredString(row['installation_id']);
    return UserDeviceSession(
      tenantId: _requiredString(row['tenant_id']),
      tenantName: _requiredString(row['tenant_name']),
      installationId: installationId,
      activeSessionCount: _requiredInt(row['active_session_count']),
      lastActivityAt: _requiredDateTime(row['last_activity_at']),
      includesCurrentSession: row['includes_current_session'] == true,
      isCurrentInstallation: installationId == currentInstallationId,
    );
  }
}

/// The platform-wide device-session policy.
class PlatformDeviceSessionPolicy {
  /// Creates a platform policy and its supported configuration bounds.
  const PlatformDeviceSessionPolicy({
    required this.deviceLimit,
    required this.staleSessionDays,
    required this.maxDeviceLimit,
    required this.minStaleSessionDays,
    required this.maxStaleSessionDays,
  });

  /// The limit inherited by tenants without an explicit policy.
  final int deviceLimit;

  /// The configured inactivity period before an app session becomes stale.
  final int staleSessionDays;

  /// The largest supported device limit.
  final int maxDeviceLimit;

  /// The shortest supported stale-session period.
  final int minStaleSessionDays;

  /// The longest supported stale-session period.
  final int maxStaleSessionDays;

  /// Creates a policy from the platform-policy RPC response.
  factory PlatformDeviceSessionPolicy.fromRow(Map<String, dynamic> row) {
    return PlatformDeviceSessionPolicy(
      deviceLimit: _requiredInt(row['platform_device_limit']),
      staleSessionDays: _requiredInt(row['stale_session_days']),
      maxDeviceLimit: _requiredInt(row['max_device_limit']),
      minStaleSessionDays: _requiredInt(row['min_stale_session_days']),
      maxStaleSessionDays: _requiredInt(row['max_stale_session_days']),
    );
  }
}

/// The effective policy and usage summary for a tenant.
class TenantDeviceSessionPolicy {
  /// Creates a policy summary for one tenant.
  const TenantDeviceSessionPolicy({
    required this.platformDeviceLimit,
    required this.tenantDeviceLimit,
    required this.effectiveDeviceLimit,
    required this.staleSessionDays,
    required this.activeDeviceCount,
    required this.activeSessionCount,
  });

  /// The platform default inherited when no tenant override is set.
  final int platformDeviceLimit;

  /// The explicit tenant limit, or null when the tenant inherits.
  final int? tenantDeviceLimit;

  /// The tenant's current limit after platform inheritance.
  final int effectiveDeviceLimit;

  /// The configured stale-session expiry in days.
  final int staleSessionDays;

  /// The number of currently active installations across the tenant.
  final int activeDeviceCount;

  /// The number of currently active Auth-session records in the tenant.
  final int activeSessionCount;

  /// Creates a tenant policy from its RPC response.
  factory TenantDeviceSessionPolicy.fromRow(Map<String, dynamic> row) {
    return TenantDeviceSessionPolicy(
      platformDeviceLimit: _requiredInt(row['platform_device_limit']),
      tenantDeviceLimit: _optionalInt(row['tenant_device_limit']),
      effectiveDeviceLimit: _requiredInt(row['effective_device_limit']),
      staleSessionDays: _requiredInt(row['stale_session_days']),
      activeDeviceCount: _requiredInt(row['active_device_count']),
      activeSessionCount: _requiredInt(row['active_session_count']),
    );
  }
}

/// A tenant member's effective device policy and active usage.
class TenantMemberDevicePolicy {
  /// Creates a member policy summary.
  const TenantMemberDevicePolicy({
    required this.userId,
    required this.email,
    required this.role,
    required this.accountDeviceLimit,
    required this.effectiveDeviceLimit,
    required this.policySource,
    required this.activeDeviceCount,
  });

  /// The Auth user ID of the tenant member.
  final String userId;

  /// The member's account email.
  final String email;

  /// The member's tenant role.
  final String role;

  /// The explicit account override, or null when it inherits.
  final int? accountDeviceLimit;

  /// The limit currently enforced for this member.
  final int effectiveDeviceLimit;

  /// The policy level supplying the effective limit.
  final String policySource;

  /// The member's active device count within this tenant.
  final int activeDeviceCount;

  /// Creates a member policy from a database RPC row.
  factory TenantMemberDevicePolicy.fromRow(Map<String, dynamic> row) {
    return TenantMemberDevicePolicy(
      userId: _requiredString(row['user_id']),
      email: _requiredString(row['email']),
      role: _requiredString(row['role']),
      accountDeviceLimit: _optionalInt(row['account_device_limit']),
      effectiveDeviceLimit: _requiredInt(row['effective_device_limit']),
      policySource: _requiredString(row['policy_source']),
      activeDeviceCount: _requiredInt(row['active_device_count']),
    );
  }
}

/// An installation listed in a tenant's administrative session view.
class AdminDeviceSession {
  /// Creates an administrative session summary.
  const AdminDeviceSession({
    required this.userId,
    required this.email,
    required this.installationId,
    required this.activeSessionCount,
    required this.lastActivityAt,
  });

  /// The Auth user ID associated with the installation.
  final String userId;

  /// The user's email shown to the Super Admin.
  final String email;

  /// The random opaque installation identifier used for revocation.
  final String installationId;

  /// The number of active Auth sessions on this installation.
  final int activeSessionCount;

  /// The most recent activity recorded for this installation.
  final DateTime lastActivityAt;

  /// Creates a session summary from a database RPC row.
  factory AdminDeviceSession.fromRow(Map<String, dynamic> row) {
    return AdminDeviceSession(
      userId: _requiredString(row['user_id']),
      email: _requiredString(row['email']),
      installationId: _requiredString(row['installation_id']),
      activeSessionCount: _requiredInt(row['active_session_count']),
      lastActivityAt: _requiredDateTime(row['last_activity_at']),
    );
  }
}

/// A recent platform or tenant device-session administrative event.
class DeviceSessionAuditEvent {
  /// Creates an audit event summary.
  const DeviceSessionAuditEvent({
    required this.tenantName,
    required this.actorEmail,
    required this.subjectEmail,
    required this.action,
    required this.details,
    required this.createdAt,
  });

  /// The tenant name, or null for a platform-wide policy change.
  final String? tenantName;

  /// The administrator or user that performed the action.
  final String actorEmail;

  /// The account affected by the action, when applicable.
  final String subjectEmail;

  /// The recorded action identifier.
  final String action;

  /// The non-secret details recorded with the event.
  final Map<String, dynamic> details;

  /// The time at which the event was recorded.
  final DateTime createdAt;

  /// Creates an audit event from a database RPC row.
  factory DeviceSessionAuditEvent.fromRow(Map<String, dynamic> row) {
    final details = row['details'];
    return DeviceSessionAuditEvent(
      tenantName: row['tenant_name'] is String
          ? row['tenant_name'] as String
          : null,
      actorEmail: _stringOrEmpty(row['actor_email']),
      subjectEmail: _stringOrEmpty(row['subject_email']),
      action: _requiredString(row['action']),
      details: details is Map<String, dynamic>
          ? details
          : details is Map
          ? Map<String, dynamic>.from(details)
          : const {},
      createdAt: _requiredDateTime(row['created_at']),
    );
  }
}

String _requiredString(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw const FormatException('A device-session response field is invalid.');
}

int _requiredInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw const FormatException('A device-session response field is invalid.');
}

int? _optionalInt(Object? value) {
  if (value == null) {
    return null;
  }
  return _requiredInt(value);
}

String _stringOrEmpty(Object? value) {
  return value is String ? value : '';
}

DateTime _requiredDateTime(Object? value) {
  if (value is String) {
    final dateTime = DateTime.tryParse(value);
    if (dateTime != null) {
      return dateTime;
    }
  }
  throw const FormatException('A device-session response field is invalid.');
}
