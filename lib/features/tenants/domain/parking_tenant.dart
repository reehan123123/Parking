enum ParkingTenantRole { owner, member }

class ParkingTenant {
  const ParkingTenant({
    required this.id,
    required this.name,
    required this.slug,
    this.role,
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

class ParkingTenantMember {
  const ParkingTenantMember({
    required this.userId,
    required this.email,
    required this.role,
  });

  final String userId;
  final String email;
  final ParkingTenantRole role;
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
