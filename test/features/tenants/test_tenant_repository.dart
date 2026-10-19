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
  int addMemberCalls = 0;
  int updateMemberRoleCalls = 0;
  int removeMemberCalls = 0;
  String? lastName;
  String? lastOwnerEmail;
  String? lastRequestId;
  ParkingTenant? updatedTenant;
  List<ParkingTenantMember> members = const [];
  String? lastMemberEmail;
  ParkingTenantRole? lastMemberRole;

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
  }) async {
    createTenantCalls++;
    lastName = name;
    lastOwnerEmail = ownerEmail;
    lastRequestId = requestId;
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
  }) async {
    updateTenantCalls++;
    lastName = name;
    final error = managementError;
    if (error != null) {
      throw error;
    }
    return updatedTenant ??
        ParkingTenant(
          id: tenantId,
          name: name,
          slug: name.toLowerCase().replaceAll(' ', '-'),
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
