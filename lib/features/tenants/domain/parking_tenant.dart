enum ParkingTenantRole { owner, member }

class ParkingTenant {
  const ParkingTenant({
    required this.id,
    required this.name,
    required this.slug,
    this.role,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final String slug;
  final ParkingTenantRole? role;
  final bool isArchived;
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
