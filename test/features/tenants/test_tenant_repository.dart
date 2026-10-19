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
  TenantRepositoryException? createError;
  int loadAccessCalls = 0;
  int createTenantCalls = 0;
  String? lastName;
  String? lastOwnerEmail;

  @override
  Future<ParkingTenantAccess> loadAccess() async {
    loadAccessCalls++;
    return access;
  }

  @override
  Future<ParkingTenant> createTenant({
    required String name,
    required String ownerEmail,
  }) async {
    createTenantCalls++;
    lastName = name;
    lastOwnerEmail = ownerEmail;
    final error = createError;
    if (error != null) {
      throw error;
    }

    return createdTenant;
  }
}
