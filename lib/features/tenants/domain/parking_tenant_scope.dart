class ParkingTenantScope {
  const ParkingTenantScope({
    required this.isSuperAdmin,
    required this.tenantId,
  });

  final bool isSuperAdmin;
  final String? tenantId;

  bool get includesAllTenants => isSuperAdmin && tenantId == null;

  bool get isValid =>
      isSuperAdmin || (tenantId != null && tenantId!.trim().isNotEmpty);

  @override
  bool operator ==(Object other) {
    return other is ParkingTenantScope &&
        other.isSuperAdmin == isSuperAdmin &&
        other.tenantId == tenantId;
  }

  @override
  int get hashCode => Object.hash(isSuperAdmin, tenantId);
}
