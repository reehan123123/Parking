import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/tenants/data/supabase_tenant_repository.dart';
import 'package:parking_management/features/tenants/domain/parking_tenant.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseTenantRepository', () {
    test('loads only tenant memberships for a regular user', () async {
      final store = _FakeTenantStore()
        ..membershipRows = [
          {'tenant_id': 'tenant-a', 'role': 'owner'},
        ]
        ..tenantRows = [
          {'id': 'tenant-a', 'name': 'North lot', 'slug': 'north-lot'},
          {'id': 'tenant-b', 'name': 'South lot', 'slug': 'south-lot'},
        ];

      final access = await SupabaseTenantRepository(
        null,
        tenantStore: store,
      ).loadAccess();

      expect(access.isSuperAdmin, isFalse);
      expect(access.tenants, hasLength(1));
      expect(access.tenants.single.id, 'tenant-a');
      expect(access.tenants.single.role, ParkingTenantRole.owner);
      expect(store.lastTenantIds, ['tenant-a']);
    });

    test(
      'loads all tenants for the database-backed Super Admin role',
      () async {
        final store = _FakeTenantStore()
          ..superAdmin = true
          ..tenantRows = [
            {'id': 'tenant-a', 'name': 'North lot', 'slug': 'north-lot'},
            {'id': 'tenant-b', 'name': 'South lot', 'slug': 'south-lot'},
          ];

        final access = await SupabaseTenantRepository(
          null,
          tenantStore: store,
        ).loadAccess();

        expect(access.isSuperAdmin, isTrue);
        expect(access.tenants, hasLength(2));
        expect(store.membershipCalls, 0);
        expect(store.lastTenantIds, isNull);
      },
    );

    test(
      'does not request tenant rows when a user has no memberships',
      () async {
        final store = _FakeTenantStore();

        final access = await SupabaseTenantRepository(
          null,
          tenantStore: store,
        ).loadAccess();

        expect(access.isSuperAdmin, isFalse);
        expect(access.tenants, isEmpty);
        expect(store.lastTenantIds, isEmpty);
      },
    );

    test(
      'creates a tenant from normalized values returned by the store',
      () async {
        final store = _FakeTenantStore()
          ..createdRow = {
            'id': 'tenant-c',
            'name': 'Airport Parking',
            'slug': 'airport-parking-12345678',
          };

        final tenant = await SupabaseTenantRepository(null, tenantStore: store)
            .createTenant(
              name: ' Airport Parking ',
              ownerEmail: ' Owner@Example.com ',
            );

        expect(store.lastName, 'Airport Parking');
        expect(store.lastOwnerEmail, 'owner@example.com');
        expect(tenant.name, 'Airport Parking');
        expect(tenant.role, ParkingTenantRole.owner);
      },
    );

    test('rejects invalid tenant input before invoking the store', () async {
      final store = _FakeTenantStore();
      final repository = SupabaseTenantRepository(null, tenantStore: store);

      await expectLater(
        repository.createTenant(name: ' ', ownerEmail: 'owner@example.com'),
        throwsA(
          isA<TenantRepositoryException>().having(
            (error) => error.message,
            'message',
            contains('tenant name'),
          ),
        ),
      );
      await expectLater(
        repository.createTenant(name: 'Workspace', ownerEmail: 'not-an-email'),
        throwsA(isA<TenantRepositoryException>()),
      );
      expect(store.createTenantCalls, 0);
    });

    test('explains that the tenant owner account must already exist', () async {
      final store = _FakeTenantStore()
        ..createError = const PostgrestException(
          message: 'Owner account not found.',
          code: 'P0002',
        );
      final repository = SupabaseTenantRepository(null, tenantStore: store);

      await expectLater(
        repository.createTenant(
          name: 'Workspace',
          ownerEmail: 'owner@example.com',
        ),
        throwsA(
          isA<TenantRepositoryException>().having(
            (error) => error.message,
            'message',
            contains('does not have a Supabase account'),
          ),
        ),
      );
    });
  });
}

class _FakeTenantStore implements TenantStore {
  bool superAdmin = false;
  List<Map<String, dynamic>> membershipRows = [];
  List<Map<String, dynamic>> tenantRows = [];
  Map<String, dynamic> createdRow = {
    'id': 'new-tenant',
    'name': 'New tenant',
    'slug': 'new-tenant-12345678',
  };
  PostgrestException? createError;
  List<String>? lastTenantIds;
  String? lastName;
  String? lastOwnerEmail;
  int membershipCalls = 0;
  int createTenantCalls = 0;

  @override
  Future<bool> isSuperAdmin() async => superAdmin;

  @override
  Future<List<Map<String, dynamic>>> memberships() async {
    membershipCalls++;
    return membershipRows;
  }

  @override
  Future<List<Map<String, dynamic>>> tenants({List<String>? tenantIds}) async {
    lastTenantIds = tenantIds;
    if (tenantIds == null) {
      return tenantRows;
    }

    return tenantRows
        .where((row) => tenantIds.contains(row['id']))
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> createTenant({
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
    return createdRow;
  }
}
