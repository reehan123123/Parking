import 'parking_tenant.dart';

class ParkingTenantScope {
  const ParkingTenantScope({
    required this.isSuperAdmin,
    required this.tenantId,
    this.permissions = const TenantEntryPermissions.all(),
  });

  final bool isSuperAdmin;
  final String? tenantId;
  final TenantEntryPermissions permissions;

  bool get canViewEntries => isSuperAdmin || permissions.canView;
  bool get canAddEntries => isSuperAdmin || permissions.canAdd;
  bool get canEditEntries => isSuperAdmin || permissions.canEdit;
  bool get canDeleteEntries => isSuperAdmin || permissions.canDelete;

  bool get includesAllTenants => isSuperAdmin && tenantId == null;

  bool get isValid =>
      isSuperAdmin || (tenantId != null && tenantId!.trim().isNotEmpty);

  @override
  bool operator ==(Object other) {
    return other is ParkingTenantScope &&
        other.isSuperAdmin == isSuperAdmin &&
        other.tenantId == tenantId &&
        other.permissions == permissions;
  }

  @override
  int get hashCode => Object.hash(isSuperAdmin, tenantId, permissions);
}
