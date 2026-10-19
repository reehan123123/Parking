import 'package:parking_management/features/tenants/data/supabase_tenant_repository.dart';
import 'package:parking_management/features/tenants/data/tenant_repository.dart';
import 'package:parking_management/features/tenants/domain/parking_tenant.dart';

class TestTenantRepository implements TenantRepository {
  TestTenantRepository({
    required this.access,
    this.createdTenant = const ParkingTenant(
      id: 'new-tenant',
      name: 'New tenant',
      slug: 'new-tenant',
      role: ParkingTenantRole.owner,
    ),
  });

  ParkingTenantAccess access;
  ParkingTenant createdTenant;
  String? createdTemporaryPassword;
  TenantRepositoryException? createError;
  TenantRepositoryException? managementError;
  int loadAccessCalls = 0;
  int createTenantCalls = 0;
  int updateTenantCalls = 0;
  int archiveTenantCalls = 0;
  int restoreTenantCalls = 0;
  int listMembersCalls = 0;
  int getMemberCapacityCalls = 0;
  int listMemberCapacitiesCalls = 0;
  int setMemberLimitCalls = 0;
  int listMemberAuditEventsCalls = 0;
  int addMemberCalls = 0;
  int updateMemberRoleCalls = 0;
  int updateMemberPermissionsCalls = 0;
  int removeMemberCalls = 0;
  String? lastName;
  String? lastOwnerEmail;
  String? lastRequestId;
  bool? lastIsActive;
  DateTime? lastValidUntil;
  String? lastContactName;
  String? lastContactMobile;
  String? lastContactEmail;
  ParkingTenant? updatedTenant;
  List<ParkingTenantMember> members = const [];
  TenantMemberCapacity memberCapacity = const TenantMemberCapacity(
    tenantId: 'tenant-id',
    memberLimit: 1,
    activeMemberCount: 0,
    remainingMemberCount: 1,
  );
  List<TenantMemberCapacity> memberCapacities = const [];
  List<TenantMemberAuditEvent> memberAuditEvents = const [];
  String? lastMemberEmail;
  ParkingTenantRole? lastMemberRole;
  TenantEntryPermissions? lastMemberPermissions;
  int? lastMemberLimit;

  @override
  Future<ParkingTenantAccess> loadAccess() async {
    loadAccessCalls++;
    return access;
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
    createTenantCalls++;
    lastName = name;
    lastOwnerEmail = ownerEmail;
    lastRequestId = requestId;
    lastIsActive = isActive;
    lastValidUntil = validUntil;
    lastContactName = contactName;
    lastContactMobile = contactMobile;
    lastContactEmail = contactEmail;
    final error = createError;
    if (error != null) {
      throw error;
    }

    return TenantCreationResult(
      tenant: createdTenant,
      temporaryPassword: createdTemporaryPassword,
    );
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
    updateTenantCalls++;
    lastName = name;
    lastValidUntil = validUntil;
    lastContactName = contactName;
    lastContactMobile = contactMobile;
    lastContactEmail = contactEmail;
    final error = managementError;
    if (error != null) {
      throw error;
    }
    return updatedTenant ??
        ParkingTenant(
          id: tenantId,
          name: name,
          slug: name.toLowerCase().replaceAll(' ', '-'),
          validUntil: validUntil,
          contactName: contactName,
          contactMobile: contactMobile,
          contactEmail: contactEmail,
        );
  }

  @override
  Future<void> archiveTenant({required String tenantId}) async {
    archiveTenantCalls++;
    final error = managementError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> restoreTenant({required String tenantId}) async {
    restoreTenantCalls++;
    final error = managementError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<List<ParkingTenantMember>> listMembers({
    required String tenantId,
  }) async {
    listMembersCalls++;
    final error = managementError;
    if (error != null) {
      throw error;
    }
    return members;
  }

  @override
  Future<TenantMemberCapacity> getMemberCapacity({
    required String tenantId,
  }) async {
    getMemberCapacityCalls++;
    final error = managementError;
    if (error != null) {
      throw error;
    }
    return memberCapacity;
  }

  @override
  Future<List<TenantMemberCapacity>> listMemberCapacities() async {
    listMemberCapacitiesCalls++;
    final error = managementError;
    if (error != null) {
      throw error;
    }
    return memberCapacities;
  }

  @override
  Future<TenantMemberCapacity> setMemberLimit({
    required String tenantId,
    required int memberLimit,
  }) async {
    setMemberLimitCalls++;
    lastMemberLimit = memberLimit;
    final error = managementError;
    if (error != null) {
      throw error;
    }
    return memberCapacity = TenantMemberCapacity(
      tenantId: tenantId,
      memberLimit: memberLimit,
      activeMemberCount: memberCapacity.activeMemberCount,
      remainingMemberCount: memberLimit > memberCapacity.activeMemberCount
          ? memberLimit - memberCapacity.activeMemberCount
          : 0,
    );
  }

  @override
  Future<List<TenantMemberAuditEvent>> listMemberAuditEvents({
    required String tenantId,
  }) async {
    listMemberAuditEventsCalls++;
    final error = managementError;
    if (error != null) {
      throw error;
    }
    return memberAuditEvents;
  }

  @override
  Future<void> addMember({
    required String tenantId,
    required String email,
    required ParkingTenantRole role,
  }) async {
    addMemberCalls++;
    lastMemberEmail = email;
    lastMemberRole = role;
    final error = managementError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> updateMemberRole({
    required String tenantId,
    required String userId,
    required ParkingTenantRole role,
  }) async {
    updateMemberRoleCalls++;
    lastMemberRole = role;
    final error = managementError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> updateMemberPermissions({
    required String tenantId,
    required String userId,
    required TenantEntryPermissions permissions,
  }) async {
    updateMemberPermissionsCalls++;
    lastMemberPermissions = permissions;
    final error = managementError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> removeMember({
    required String tenantId,
    required String userId,
  }) async {
    removeMemberCalls++;
    final error = managementError;
    if (error != null) {
      throw error;
    }
  }
}
