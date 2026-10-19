enum ParkingTenantRole { owner, member }

class ParkingTenant {
  const ParkingTenant({
    required this.id,
    required this.name,
    required this.slug,
    this.role,
  });

  final String id;
  final String name;
  final String slug;
  final ParkingTenantRole? role;
}

class ParkingTenantAccess {
  const ParkingTenantAccess({
    required this.isSuperAdmin,
    required this.tenants,
  });

  final bool isSuperAdmin;
  final List<ParkingTenant> tenants;
}
