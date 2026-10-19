import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parking_management/core/network/local_api_client.dart';
import 'package:parking_management/features/auth/data/local_auth_repository.dart';
import 'package:parking_management/features/parking/data/local_api_parking_session_store.dart';
import 'package:parking_management/features/tenants/data/local_api_tenant_store.dart';
import 'package:parking_management/features/tenants/data/supabase_tenant_repository.dart';
import 'package:parking_management/features/tenants/domain/parking_tenant.dart';
import 'package:parking_management/features/tenants/domain/parking_tenant_scope.dart';

void main() {
  group('Local API repositories', () {
    test(
      'local auth gates access until a temporary password is changed',
      () async {
        final client = MockClient((request) async {
          if (request.url.path == '/api/auth/sign-in') {
            expect(request.headers['authorization'], isNull);
            expect(jsonDecode(request.body), {
              'email': 'local-admin@parking.test',
              'password': 'temporary',
            });
            return _jsonResponse({
              'accessToken': 'test-access-token',
              'user': {
                'id': 'admin-id',
                'requiresTemporaryPasswordChange': true,
              },
            });
          }
          if (request.url.path == '/api/auth/change-password') {
            expect(
              request.headers['authorization'],
              'Bearer test-access-token',
            );
            return _jsonResponse({'success': true});
          }
          if (request.url.path == '/api/auth/sign-out') {
            expect(
              request.headers['authorization'],
              'Bearer test-access-token',
            );
            return http.Response('', 204);
          }
          throw StateError('Unexpected request: ${request.url}');
        });
        final api = LocalApiClient(
          baseUri: Uri.parse('http://127.0.0.1:8765'),
          client: client,
        );
        final repository = LocalAuthRepository(api);

        await repository.signIn(
          email: 'local-admin@parking.test',
          password: 'temporary',
        );
        expect(repository.isSignedIn, isTrue);
        expect(repository.currentUserId, 'admin-id');
        expect(repository.requiresTemporaryPasswordChange, isTrue);

        await repository.changeTemporaryPassword(
          newPassword: 'a-new-local-password-123',
        );
        expect(repository.requiresTemporaryPasswordChange, isFalse);

        await repository.signOut();
        expect(repository.isSignedIn, isFalse);
        expect(api.accessToken, isNull);
        client.close();
      },
    );

    test(
      'tenant access uses the local API and preserves temporary passwords',
      () async {
        var accessRequests = 0;
        final client = MockClient((request) async {
          if (request.url.path == '/api/tenants/access') {
            accessRequests++;
            return _jsonResponse({
              'isSuperAdmin': false,
              'memberships': [
                {'tenant_id': 'tenant-id', 'role': 'owner'},
              ],
              'tenants': [
                {
                  'id': 'tenant-id',
                  'name': 'Local tenant',
                  'slug': 'local-tenant',
                  'archived_at': null,
                },
              ],
            });
          }
          if (request.url.path == '/api/tenants') {
            return _jsonResponse({
              'success': true,
              'tenant': {
                'id': 'created-tenant-id',
                'name': 'New tenant',
                'slug': 'new-tenant-12345678',
              },
              'temporaryPassword': 'temporary-password-for-test',
            });
          }
          throw StateError('Unexpected request: ${request.url}');
        });
        final api = LocalApiClient(
          baseUri: Uri.parse('http://127.0.0.1:8765'),
          client: client,
        )..accessToken = 'local-access-token';
        final repository = SupabaseTenantRepository(
          null,
          tenantStore: LocalApiTenantStore(api),
        );

        final access = await repository.loadAccess();
        expect(access.isSuperAdmin, isFalse);
        expect(access.tenants.single.id, 'tenant-id');
        expect(access.tenants.single.role, ParkingTenantRole.owner);
        expect(accessRequests, 1);

        final creation = await repository.createTenant(
          name: 'New tenant',
          ownerEmail: 'owner@example.test',
          requestId: 'e6e5b36d-1890-4fc5-9a0c-47eeacb44119',
          isActive: true,
          validUntil: DateTime(2027, 1, 1),
        );
        expect(creation.tenant.id, 'created-tenant-id');
        expect(creation.temporaryPassword, 'temporary-password-for-test');
        client.close();
      },
    );

    test(
      'tenant access cache is not reused after a different account signs in',
      () async {
        final requestedTokens = <String?>[];
        final client = MockClient((request) async {
          if (request.url.path == '/api/tenants/access') {
            requestedTokens.add(request.headers['authorization']);
            final isSuperAdminAccount =
                request.headers['authorization'] == 'Bearer super-admin-token';
            return _jsonResponse({
              'isSuperAdmin': isSuperAdminAccount,
              'memberships': isSuperAdminAccount
                  ? []
                  : [
                      {'tenant_id': 'testtenat-id', 'role': 'owner'},
                    ],
              'tenants': [
                {
                  'id': 'testtenat-id',
                  'name': 'testtenat',
                  'slug': 'testtenat-4ad46566',
                  'archived_at': null,
                },
              ],
            });
          }
          throw StateError('Unexpected request: ${request.url}');
        });
        final api = LocalApiClient(
          baseUri: Uri.parse('http://127.0.0.1:8765'),
          client: client,
        );
        final repository = SupabaseTenantRepository(
          null,
          tenantStore: LocalApiTenantStore(api),
        );

        api.accessToken = 'super-admin-token';
        final superAdminAccess = await repository.loadAccess();
        expect(superAdminAccess.isSuperAdmin, isTrue);

        // Sign out, then a different account (the new tenant owner) signs in.
        api.accessToken = null;
        api.accessToken = 'tenant-owner-token';
        final ownerAccess = await repository.loadAccess();

        expect(ownerAccess.isSuperAdmin, isFalse);
        expect(ownerAccess.tenants.single.role, ParkingTenantRole.owner);
        expect(requestedTokens, [
          'Bearer super-admin-token',
          'Bearer tenant-owner-token',
        ]);
        client.close();
      },
    );

    test(
      'parking store sends tenant-scoped pagination and parses results',
      () async {
        final client = MockClient((request) async {
          expect(request.url.path, '/api/parking-sessions');
          expect(request.url.queryParameters, {
            'offset': '25',
            'limit': '51',
            'search': 'MH03',
            'tenant_id': 'tenant-id',
          });
          expect(request.headers['authorization'], 'Bearer local-access-token');
          return _jsonResponse({
            'sessions': [
              {'id': 'session-id', 'plate_number': 'MH03AB1234'},
            ],
          });
        });
        final api = LocalApiClient(
          baseUri: Uri.parse('http://127.0.0.1:8765'),
          client: client,
        )..accessToken = 'local-access-token';
        final store = LocalApiParkingSessionStore(api);

        final rows = await store.list(
          scope: const ParkingTenantScope(
            isSuperAdmin: false,
            tenantId: 'tenant-id',
          ),
          offset: 25,
          limit: 51,
          search: 'MH03',
        );

        expect(rows.single['id'], 'session-id');
        client.close();
      },
    );
  });
}

http.Response _jsonResponse(Map<String, Object?> value) {
  return http.Response(
    jsonEncode(value),
    200,
    headers: const {'content-type': 'application/json'},
  );
}
