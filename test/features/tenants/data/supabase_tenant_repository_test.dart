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
          {
            'id': 'tenant-a',
            'name': 'North lot',
            'slug': 'north-lot',
            'archived_at': null,
          },
          {
            'id': 'tenant-b',
            'name': 'South lot',
            'slug': 'south-lot',
            'archived_at': '2026-10-19T00:00:00Z',
          },
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
      'rejects missing member permissions instead of granting access',
      () async {
        final store = _FakeTenantStore()
          ..membershipRows = [
            {'tenant_id': 'tenant-a', 'role': 'member'},
          ]
          ..tenantRows = [
            {
              'id': 'tenant-a',
              'name': 'North lot',
              'slug': 'north-lot',
              'archived_at': null,
            },
          ];

        await expectLater(
          SupabaseTenantRepository(null, tenantStore: store).loadAccess(),
          throwsA(
            isA<TenantRepositoryException>().having(
              (error) => error.message,
              'message',
              contains('access data is invalid'),
            ),
          ),
        );
      },
    );

    test('loads bootstrap tenant choices before device registration', () async {
      final store = _FakeDeviceSessionTenantStore()
        ..choiceRows = [
          {
            'tenant_id': 'tenant-a',
            'tenant_name': 'North lot',
            'tenant_slug': 'north-lot',
            'role': 'owner',
            'archived_at': null,
            'valid_until': '2027-01-01',
          },
        ];

      final ParkingTenantAccess access = await SupabaseTenantRepository(
        null,
        tenantStore: store,
      ).loadAccess();

      expect(access.isSuperAdmin, isFalse);
      expect(access.tenants, hasLength(1));
      expect(access.tenants.single.id, 'tenant-a');
      expect(access.tenants.single.role, ParkingTenantRole.owner);
      expect(store.tenantChoiceCalls, 1);
      expect(store.membershipCalls, 0);
      expect(store.lastTenantIds, isNull);
    });

    test(
      'loads all tenants for the database-backed Super Admin role',
      () async {
        final store = _FakeTenantStore()
          ..superAdmin = true
          ..tenantRows = [
            {
              'id': 'tenant-a',
              'name': 'North lot',
              'slug': 'north-lot',
              'archived_at': null,
            },
            {
              'id': 'tenant-b',
              'name': 'South lot',
              'slug': 'south-lot',
              'archived_at': '2026-10-19T00:00:00Z',
            },
          ];

        final access = await SupabaseTenantRepository(
          null,
          tenantStore: store,
        ).loadAccess();

        expect(access.isSuperAdmin, isTrue);
        expect(access.tenants, hasLength(2));
        expect(access.tenants.last.isArchived, isTrue);
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

    test('explains when a required tenant migration is missing', () async {
      final store = _FakeTenantStore()
        ..superAdmin = true
        ..accessError = const PostgrestException(
          message: 'The archived_at column is missing from the schema cache.',
          code: 'PGRST204',
        );

      await expectLater(
        SupabaseTenantRepository(null, tenantStore: store).loadAccess(),
        throwsA(
          isA<TenantRepositoryException>().having(
            (error) => error.message,
            'message',
            contains('Apply all tenant migrations'),
          ),
        ),
      );
    });

    test(
      'creates an existing-account tenant without returning a password',
      () async {
        final store = _FakeTenantStore()
          ..createdRow = {
            'success': true,
            'tenant': {
              'id': 'tenant-c',
              'name': 'Airport Parking',
              'slug': 'airport-parking-12345678',
            },
          };

        final result = await SupabaseTenantRepository(null, tenantStore: store)
            .createTenant(
              name: ' Airport Parking ',
              ownerEmail: ' Owner@Example.com ',
              requestId: 'e6e5b36d-1890-4fc5-9a0c-47eeacb44119',
              isActive: true,
              validUntil: DateTime(2027, 1, 1),
            );

        expect(store.lastName, 'Airport Parking');
        expect(store.lastOwnerEmail, 'owner@example.com');
        expect(store.lastRequestId, 'e6e5b36d-1890-4fc5-9a0c-47eeacb44119');
        expect(result.tenant.name, 'Airport Parking');
        expect(result.tenant.role, ParkingTenantRole.owner);
        expect(result.temporaryPassword, isNull);
      },
    );

    test('returns a one-time password for a newly created owner', () async {
      final store = _FakeTenantStore()
        ..createdRow = {
          'success': true,
          'tenant': {
            'id': 'tenant-c',
            'name': 'Airport Parking',
            'slug': 'airport-parking-12345678',
          },
          'temporaryPassword': 'temporary-value-for-test',
        };

      final result = await SupabaseTenantRepository(null, tenantStore: store)
          .createTenant(
            name: 'Airport Parking',
            ownerEmail: 'owner@example.com',
            requestId: 'e6e5b36d-1890-4fc5-9a0c-47eeacb44119',
            isActive: true,
            validUntil: DateTime(2027, 1, 1),
          );

      expect(result.temporaryPassword, 'temporary-value-for-test');
    });

    test('rejects invalid tenant input before invoking the store', () async {
      final store = _FakeTenantStore();
      final repository = SupabaseTenantRepository(null, tenantStore: store);

      await expectLater(
        repository.createTenant(
          name: ' ',
          ownerEmail: 'owner@example.com',
          requestId: 'e6e5b36d-1890-4fc5-9a0c-47eeacb44119',
          isActive: true,
          validUntil: DateTime(2027, 1, 1),
        ),
        throwsA(
          isA<TenantRepositoryException>().having(
            (error) => error.message,
            'message',
            contains('tenant name'),
          ),
        ),
      );
      await expectLater(
        repository.createTenant(
          name: 'Workspace',
          ownerEmail: 'not-an-email',
          requestId: 'e6e5b36d-1890-4fc5-9a0c-47eeacb44119',
          isActive: true,
          validUntil: DateTime(2027, 1, 1),
        ),
        throwsA(isA<TenantRepositoryException>()),
      );
      expect(store.createTenantCalls, 0);
    });

    test(
      'preserves a temporary password when tenant setup is incomplete',
      () async {
        final store = _FakeTenantStore()
          ..createError = const TenantStoreException(
            'The owner account was created, but tenant setup could not be confirmed.',
            temporaryPassword: 'temporary-value-for-test',
          );
        final repository = SupabaseTenantRepository(null, tenantStore: store);

        await expectLater(
          repository.createTenant(
            name: 'Workspace',
            ownerEmail: 'owner@example.com',
            requestId: 'e6e5b36d-1890-4fc5-9a0c-47eeacb44119',
            isActive: true,
            validUntil: DateTime(2027, 1, 1),
          ),
          throwsA(
            isA<TenantRepositoryException>().having(
              (error) => error.temporaryPassword,
              'temporaryPassword',
              'temporary-value-for-test',
            ),
          ),
        );
      },
    );

    test('updates a tenant with a normalized name', () async {
      final store = _FakeTenantStore()
        ..updatedRow = {
          'id': 'tenant-a',
          'name': 'North Lot',
          'slug': 'north-lot',
          'archived_at': null,
        };

      final tenant = await SupabaseTenantRepository(null, tenantStore: store)
          .updateTenant(
            tenantId: 'tenant-a',
            name: ' North Lot ',
            validUntil: DateTime(2027, 1, 1),
          );

      expect(store.lastTenantId, 'tenant-a');
      expect(store.lastName, 'North Lot');
      expect(tenant.name, 'North Lot');
      expect(tenant.isArchived, isFalse);
    });

    test('rejects an invalid update before invoking the store', () async {
      final store = _FakeTenantStore();
      final repository = SupabaseTenantRepository(null, tenantStore: store);

      await expectLater(
        repository.updateTenant(
          tenantId: 'tenant-a',
          name: ' ',
          validUntil: DateTime(2027, 1, 1),
        ),
        throwsA(isA<TenantRepositoryException>()),
      );
      expect(store.updateTenantCalls, 0);
    });

    test('archives and restores a tenant', () async {
      final store = _FakeTenantStore();
      final repository = SupabaseTenantRepository(null, tenantStore: store);

      await repository.archiveTenant(tenantId: 'tenant-a');
      await repository.restoreTenant(tenantId: 'tenant-a');

      expect(store.archiveTenantCalls, 1);
      expect(store.restoreTenantCalls, 1);
    });

    test('lists and manages tenant members', () async {
      final store = _FakeTenantStore()
        ..memberRows = [
          {
            'user_id': 'user-a',
            'email': 'owner@example.com',
            'role': 'owner',
            'created_at': '2026-10-01T00:00:00Z',
            'can_view_entries': true,
            'can_add_entries': true,
            'can_edit_entries': true,
            'can_delete_entries': true,
          },
        ];
      final repository = SupabaseTenantRepository(null, tenantStore: store);

      final members = await repository.listMembers(tenantId: 'tenant-a');
      await repository.addMember(
        tenantId: 'tenant-a',
        email: ' Member@Example.com ',
        requestId: '11111111-1111-4111-8111-111111111111',
        role: ParkingTenantRole.member,
      );
      await repository.updateMemberRole(
        tenantId: 'tenant-a',
        userId: 'user-a',
        role: ParkingTenantRole.member,
      );
      await repository.removeMember(tenantId: 'tenant-a', userId: 'user-a');

      expect(members.single.email, 'owner@example.com');
      expect(members.single.role, ParkingTenantRole.owner);
      expect(members.single.permissions.canDelete, isTrue);
      expect(members.single.createdAt, DateTime.utc(2026, 10, 1));
      expect(store.lastEmail, 'member@example.com');
      expect(store.lastRequestId, '11111111-1111-4111-8111-111111111111');
      expect(store.lastRole, 'member');
      expect(store.updateMemberRoleCalls, 1);
      expect(store.removeMemberCalls, 1);
    });

    test('returns the temporary password for a newly created member', () async {
      final store = _FakeTenantStore()
        ..addedMemberRow = {
          'success': true,
          'accountCreated': true,
          'userId': 'member-id',
          'email': 'member@example.com',
          'role': 'member',
          'temporaryPassword': 'temporary-member-password',
        };
      final repository = SupabaseTenantRepository(null, tenantStore: store);

      final result = await repository.addMember(
        tenantId: 'tenant-a',
        email: 'member@example.com',
        requestId: '11111111-1111-4111-8111-111111111111',
        role: ParkingTenantRole.member,
      );

      expect(result.accountCreated, isTrue);
      expect(result.temporaryPassword, 'temporary-member-password');
    });

    test('maps member capacity and saves a validated limit', () async {
      final store = _FakeTenantStore()
        ..capacityRow = {
          'member_limit': 4,
          'active_member_count': 2,
          'remaining_member_count': 2,
        };
      final repository = SupabaseTenantRepository(null, tenantStore: store);

      final capacity = await repository.getMemberCapacity(tenantId: 'tenant-a');
      final updated = await repository.setMemberLimit(
        tenantId: 'tenant-a',
        memberLimit: 5,
      );

      expect(capacity.memberLimit, 4);
      expect(capacity.activeMemberCount, 2);
      expect(capacity.remainingMemberCount, 2);
      expect(updated.memberLimit, 5);
      expect(store.lastMemberLimit, 5);
    });

    test('maps member-limit violations as a typed exception', () async {
      final store = _FakeTenantStore()
        ..managementError = const PostgrestException(
          message: 'MEMBER_LIMIT_REACHED',
          code: 'P0001',
          details: '{"memberLimit":1,"activeMemberCount":1,"remainingMemberCount":0}',
        );

      await expectLater(
        SupabaseTenantRepository(null, tenantStore: store).addMember(
          tenantId: 'tenant-a',
          email: 'member@example.com',
          requestId: '11111111-1111-4111-8111-111111111111',
          role: ParkingTenantRole.member,
        ),
        throwsA(
          isA<TenantMemberLimitReachedException>()
              .having((error) => error.memberLimit, 'memberLimit', 1)
              .having(
                (error) => error.activeMemberCount,
                'activeMemberCount',
                1,
              )
              .having(
                (error) => error.remainingMemberCount,
                'remainingMemberCount',
                0,
              ),
        ),
      );
    });

    test('maps member-limit violations from role changes', () async {
      final store = _FakeTenantStore()
        ..managementError = const PostgrestException(
          message: 'MEMBER_LIMIT_REACHED',
          code: 'P0001',
          details: '{"memberLimit":1,"activeMemberCount":1,"remainingMemberCount":0}',
        );

      await expectLater(
        SupabaseTenantRepository(null, tenantStore: store).updateMemberRole(
          tenantId: 'tenant-a',
          userId: 'user-a',
          role: ParkingTenantRole.member,
        ),
        throwsA(
          isA<TenantMemberLimitReachedException>()
              .having((error) => error.memberLimit, 'memberLimit', 1)
              .having(
                (error) => error.activeMemberCount,
                'activeMemberCount',
                1,
              )
              .having(
                (error) => error.remainingMemberCount,
                'remainingMemberCount',
                0,
              ),
        ),
      );
    });

    test('prevents removing the last tenant owner', () async {
      final store = _FakeTenantStore()
        ..managementError = const PostgrestException(
          message: 'A tenant must keep at least one owner.',
          code: '23514',
        );

      await expectLater(
        SupabaseTenantRepository(
          null,
          tenantStore: store,
        ).removeMember(tenantId: 'tenant-a', userId: 'owner-a'),
        throwsA(
          isA<TenantRepositoryException>().having(
            (error) => error.message,
            'message',
            contains('at least one owner'),
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
    'success': true,
    'tenant': {
      'id': 'new-tenant',
      'name': 'New tenant',
      'slug': 'new-tenant-12345678',
    },
  };
  Map<String, dynamic> addedMemberRow = {
    'success': true,
    'accountCreated': false,
    'userId': 'member-id',
    'email': 'member@example.com',
    'role': 'member',
  };
  Map<String, dynamic> updatedRow = {
    'id': 'tenant-a',
    'name': 'Updated tenant',
    'slug': 'updated-tenant',
    'archived_at': null,
  };
  List<Map<String, dynamic>> memberRows = [];
  Map<String, dynamic> capacityRow = {
    'member_limit': 1,
    'active_member_count': 0,
    'remaining_member_count': 1,
  };
  List<Map<String, dynamic>> capacityRows = [];
  List<Map<String, dynamic>> auditRows = [];
  Object? createError;
  PostgrestException? managementError;
  PostgrestException? accessError;
  List<String>? lastTenantIds;
  String? lastTenantId;
  String? lastUserId;
  String? lastName;
  String? lastOwnerEmail;
  String? lastRequestId;
  String? lastEmail;
  String? lastRole;
  int? lastMemberLimit;
  bool? lastIsActive;
  DateTime? lastValidUntil;
  String? lastContactName;
  String? lastContactMobile;
  String? lastContactEmail;
  int membershipCalls = 0;
  int createTenantCalls = 0;
  int updateTenantCalls = 0;
  int archiveTenantCalls = 0;
  int restoreTenantCalls = 0;
  int updateMemberRoleCalls = 0;
  int setMemberPermissionsCalls = 0;
  int removeMemberCalls = 0;

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
    final error = accessError;
    if (error != null) {
      throw error;
    }
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
    return createdRow;
  }

  @override
  Future<Map<String, dynamic>> updateTenant({
    required String tenantId,
    required String name,
    required DateTime validUntil,
    String? contactName,
    String? contactMobile,
    String? contactEmail,
  }) async {
    updateTenantCalls++;
    lastTenantId = tenantId;
    lastName = name;
    lastValidUntil = validUntil;
    lastContactName = contactName;
    lastContactMobile = contactMobile;
    lastContactEmail = contactEmail;
    final error = managementError;
    if (error != null) {
      throw error;
    }
    return updatedRow;
  }

  @override
  Future<void> archiveTenant({required String tenantId}) async {
    archiveTenantCalls++;
    lastTenantId = tenantId;
    final error = managementError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> restoreTenant({required String tenantId}) async {
    restoreTenantCalls++;
    lastTenantId = tenantId;
    final error = managementError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listTenantMembers({
    required String tenantId,
  }) async {
    lastTenantId = tenantId;
    final error = managementError;
    if (error != null) {
      throw error;
    }
    return memberRows;
  }

  @override
  Future<Map<String, dynamic>> getTenantMemberCapacity({
    required String tenantId,
  }) async {
    lastTenantId = tenantId;
    final error = managementError;
    if (error != null) {
      throw error;
    }
    return capacityRow;
  }

  @override
  Future<List<Map<String, dynamic>>> listTenantMemberCapacities() async {
    final error = managementError;
    if (error != null) {
      throw error;
    }
    return capacityRows;
  }

  @override
  Future<Map<String, dynamic>> setTenantMemberLimit({
    required String tenantId,
    required int memberLimit,
  }) async {
    lastTenantId = tenantId;
    lastMemberLimit = memberLimit;
    final error = managementError;
    if (error != null) {
      throw error;
    }
    return {...capacityRow, 'member_limit': memberLimit};
  }

  @override
  Future<List<Map<String, dynamic>>> listTenantMemberAuditEvents({
    required String tenantId,
  }) async {
    lastTenantId = tenantId;
    final error = managementError;
    if (error != null) {
      throw error;
    }
    return auditRows;
  }

  @override
  Future<Map<String, dynamic>> addTenantMember({
    required String tenantId,
    required String email,
    required String requestId,
    required String role,
  }) async {
    lastTenantId = tenantId;
    lastEmail = email;
    lastRequestId = requestId;
    lastRole = role;
    final error = managementError;
    if (error != null) {
      throw error;
    }
    return addedMemberRow;
  }

  @override
  Future<void> updateTenantMemberRole({
    required String tenantId,
    required String userId,
    required String role,
  }) async {
    updateMemberRoleCalls++;
    lastTenantId = tenantId;
    lastUserId = userId;
    lastRole = role;
    final error = managementError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> setTenantMemberPermissions({
    required String tenantId,
    required String userId,
    required TenantEntryPermissions permissions,
  }) async {
    setMemberPermissionsCalls++;
    lastTenantId = tenantId;
    lastUserId = userId;
    final error = managementError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> removeTenantMember({
    required String tenantId,
    required String userId,
  }) async {
    removeMemberCalls++;
    lastTenantId = tenantId;
    lastUserId = userId;
    final error = managementError;
    if (error != null) {
      throw error;
    }
  }
}

class _FakeDeviceSessionTenantStore extends _FakeTenantStore
    implements DeviceSessionTenantChoiceStore {
  List<Map<String, dynamic>> choiceRows = [];
  int tenantChoiceCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> currentTenantChoices() async {
    tenantChoiceCalls++;
    return choiceRows;
  }
}
