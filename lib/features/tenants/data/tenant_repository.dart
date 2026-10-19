import '../domain/parking_tenant.dart';

abstract interface class TenantRepository {
  Future<ParkingTenantAccess> loadAccess();

  Future<TenantCreationResult> createTenant({
    required String name,
    required String ownerEmail,
    required String requestId,
    required bool isActive,
    required DateTime validUntil,
    String? contactName,
    String? contactMobile,
    String? contactEmail,
  });

  Future<ParkingTenant> updateTenant({
    required String tenantId,
    required String name,
    required DateTime validUntil,
    String? contactName,
    String? contactMobile,
    String? contactEmail,
  });

  Future<void> archiveTenant({required String tenantId});

  Future<void> restoreTenant({required String tenantId});

  Future<List<ParkingTenantMember>> listMembers({required String tenantId});

  Future<void> addMember({
    required String tenantId,
    required String email,
    required ParkingTenantRole role,
  });

  Future<void> updateMemberRole({
    required String tenantId,
    required String userId,
    required ParkingTenantRole role,
  });

  Future<void> removeMember({required String tenantId, required String userId});
}
