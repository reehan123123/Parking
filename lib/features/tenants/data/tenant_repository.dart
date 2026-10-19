import '../domain/parking_tenant.dart';

abstract interface class TenantRepository {
  Future<ParkingTenantAccess> loadAccess();

  Future<ParkingTenant> createTenant({
    required String name,
    required String ownerEmail,
  });
}
