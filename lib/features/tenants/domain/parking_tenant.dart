enum ParkingTenantRole { owner, member }

class ParkingTenant {
  const ParkingTenant({
    required this.id,
    required this.name,
    required this.slug,
    this.role,
    this.entryPermissions = const TenantEntryPermissions.all(),
    this.isArchived = false,
    this.validUntil,
    this.contactName,
    this.contactMobile,
    this.contactEmail,
  });

  final String id;
  final String name;
  final String slug;
  final ParkingTenantRole? role;
  final TenantEntryPermissions entryPermissions;
  final bool isArchived;

  /// Inclusive validity end date in the application's business timezone
  /// (Asia/Kolkata). A tenant is expired once this date has fully elapsed.
  final DateTime? validUntil;
  final String? contactName;
  final String? contactMobile;
  final String? contactEmail;

  /// Whether this tenant is currently active (not archived) and unexpired,
  /// evaluated using the business timezone's current calendar day. This is
  /// informational for the UI only; the database enforces the real
  /// authorization rule independently.
  bool isActiveAndValid(DateTime businessToday) {
    if (isArchived || validUntil == null) {
      return false;
    }
    final today = DateTime(
      businessToday.year,
      businessToday.month,
      businessToday.day,
    );
    final until = DateTime(
      validUntil!.year,
      validUntil!.month,
      validUntil!.day,
    );
    return !today.isAfter(until);
  }
}

class TenantEntryPermissions {
  const TenantEntryPermissions({
    required this.canView,
    required this.canAdd,
    required this.canEdit,
    required this.canDelete,
  });

  const TenantEntryPermissions.all()
    : this(canView: true, canAdd: true, canEdit: true, canDelete: true);

  const TenantEntryPermissions.viewOnly()
    : this(canView: true, canAdd: false, canEdit: false, canDelete: false);

  const TenantEntryPermissions.none()
    : this(canView: false, canAdd: false, canEdit: false, canDelete: false);

  final bool canView;
  final bool canAdd;
  final bool canEdit;
  final bool canDelete;

  bool get hasAnyPermission => canView || canAdd || canEdit || canDelete;

  @override
  bool operator ==(Object other) {
    return other is TenantEntryPermissions &&
        other.canView == canView &&
        other.canAdd == canAdd &&
        other.canEdit == canEdit &&
        other.canDelete == canDelete;
  }

  @override
  int get hashCode => Object.hash(canView, canAdd, canEdit, canDelete);
}

class ParkingTenantMember {
  const ParkingTenantMember({
    required this.userId,
    required this.email,
    required this.role,
    required this.permissions,
    this.createdAt,
  });

  final String userId;
  final String email;
  final ParkingTenantRole role;
  final TenantEntryPermissions permissions;
  final DateTime? createdAt;
}

class TenantMemberCreationResult {
  const TenantMemberCreationResult({
    required this.accountCreated,
    this.temporaryPassword,
  });

  final bool accountCreated;
  final String? temporaryPassword;
}

class TenantMemberCapacity {
  const TenantMemberCapacity({
    required this.tenantId,
    required this.memberLimit,
    required this.activeMemberCount,
    required this.remainingMemberCount,
  });

  final String tenantId;
  final int memberLimit;
  final int activeMemberCount;
  final int remainingMemberCount;

  bool get isAtCapacity => remainingMemberCount == 0;
}

class TenantMemberAuditEvent {
  const TenantMemberAuditEvent({
    required this.id,
    required this.action,
    required this.details,
    required this.createdAt,
    this.actorEmail,
    this.subjectEmail,
  });

  final int id;
  final String action;
  final Map<String, dynamic> details;
  final DateTime createdAt;
  final String? actorEmail;
  final String? subjectEmail;
}

class ParkingTenantAccess {
  const ParkingTenantAccess({
    required this.isSuperAdmin,
    required this.tenants,
  });

  final bool isSuperAdmin;
  final List<ParkingTenant> tenants;
}

class TenantCreationResult {
  const TenantCreationResult({required this.tenant, this.temporaryPassword});

  final ParkingTenant tenant;
  final String? temporaryPassword;
}
