import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/tenants/data/supabase_tenant_repository.dart';
import 'package:parking_management/features/tenants/domain/parking_tenant.dart';
import 'package:parking_management/features/tenants/presentation/tenant_admin_page.dart';

import '../test_tenant_repository.dart';

void main() {
  testWidgets('creates a tenant for an existing Supabase account', (
    WidgetTester tester,
  ) async {
    final repository = TestTenantRepository(
      access: const ParkingTenantAccess(isSuperAdmin: true, tenants: []),
    );
    ParkingTenant? createdTenant;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TenantAdminPage(
            access: repository.access,
            repository: repository,
            onTenantCreated: (tenant) async => createdTenant = tenant,
          ),
        ),
      ),
    );

    expect(find.text('Super Admin'), findsOneWidget);
    await tester.tap(find.text('Create tenant'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The owner must already have an account in Supabase Authentication.',
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'Airport Parking');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'owner@example.com',
    );
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(repository.createTenantCalls, 1);
    expect(repository.lastName, 'Airport Parking');
    expect(repository.lastOwnerEmail, 'owner@example.com');
    expect(createdTenant?.id, 'new-tenant');
    expect(find.text('No tenant workspaces yet'), findsOneWidget);
  });

  testWidgets('shows tenant creation failures without losing the form state', (
    WidgetTester tester,
  ) async {
    final repository =
        TestTenantRepository(
            access: const ParkingTenantAccess(isSuperAdmin: true, tenants: []),
          )
          ..createError = const TenantRepositoryException(
            'The owner account must already exist.',
          );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TenantAdminPage(
            access: repository.access,
            repository: repository,
            onTenantCreated: (_) async {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Create tenant'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Airport Parking');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'owner@example.com',
    );
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(find.text('The owner account must already exist.'), findsOneWidget);
    expect(find.text('Airport Parking'), findsOneWidget);
  });
}
