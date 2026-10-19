import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parking_management/app.dart';
import 'package:parking_management/shared/widgets/empty_state_view.dart';
import 'package:parking_management/shared/widgets/error_state_view.dart';
import 'package:parking_management/shared/widgets/loading_view.dart';
import 'package:parking_management/features/parking/presentation/parking_entry_page.dart';
import 'package:parking_management/features/tenants/domain/parking_tenant.dart';
import 'package:parking_management/features/tenants/domain/parking_tenant_scope.dart';
import 'package:parking_management/features/tenants/presentation/tenant_admin_page.dart';

import 'features/tenants/test_tenant_repository.dart';
import 'features/parking/presentation/parking_test_repository.dart';

Widget _buildShell() {
  return const MaterialApp(
    home: AppShell(
      initialTenantAccess: ParkingTenantAccess(
        isSuperAdmin: false,
        tenants: [
          ParkingTenant(
            id: 'test-tenant',
            name: 'Parking workspace',
            slug: 'parking-workspace',
            role: ParkingTenantRole.owner,
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('renders the dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(_buildShell());

    expect(find.text('Parking Management'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('No parking sessions yet'), findsOneWidget);
  });

  testWidgets('navigates between destinations', (WidgetTester tester) async {
    await tester.pumpWidget(_buildShell());

    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();

    expect(find.text('No parking history'), findsOneWidget);
  });

  testWidgets('renders the narrow-screen navigation bar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(480, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildShell());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('renders the wide-screen navigation rail', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_buildShell());

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('shows tenant administration only to a Super Admin', (
    WidgetTester tester,
  ) async {
    const access = ParkingTenantAccess(isSuperAdmin: true, tenants: []);
    final tenantRepository = TestTenantRepository(access: access);

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          initialTenantAccess: access,
          tenantRepository: tenantRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin'), findsOneWidget);
    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    expect(find.text('Super Admin'), findsOneWidget);
    expect(find.text('Create tenant'), findsOneWidget);
  });

  testWidgets('switches the parking repository scope with the tenant', (
    WidgetTester tester,
  ) async {
    const access = ParkingTenantAccess(
      isSuperAdmin: true,
      tenants: [
        ParkingTenant(id: 'north-tenant', name: 'North lot', slug: 'north-lot'),
        ParkingTenant(id: 'south-tenant', name: 'South lot', slug: 'south-lot'),
      ],
    );
    final tenantRepository = TestTenantRepository(access: access);
    final parkingRepository = TestParkingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          initialTenantAccess: access,
          tenantRepository: tenantRepository,
          parkingSessionRepository: parkingRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      parkingRepository.lastScope,
      const ParkingTenantScope(isSuperAdmin: true, tenantId: null),
    );
    await tester.tap(find.byTooltip('Select tenant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('North lot'));
    await tester.pumpAndSettle();

    expect(
      parkingRepository.lastScope,
      const ParkingTenantScope(isSuperAdmin: true, tenantId: 'north-tenant'),
    );
  });

  testWidgets(
    'creates a parking entry from All Tenants after choosing an active tenant',
    (WidgetTester tester) async {
      const access = ParkingTenantAccess(
        isSuperAdmin: true,
        tenants: [
          ParkingTenant(
            id: 'north-tenant',
            name: 'North lot',
            slug: 'north-lot',
          ),
          ParkingTenant(
            id: 'archived-tenant',
            name: 'Archived lot',
            slug: 'archived-lot',
            isArchived: true,
          ),
        ],
      );
      final tenantRepository = TestTenantRepository(access: access);
      final parkingRepository = TestParkingSessionRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            initialTenantAccess: access,
            tenantRepository: tenantRepository,
            parkingSessionRepository: parkingRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Parking Entry').first);
      await tester.pumpAndSettle();

      expect(find.text('Select a tenant'), findsOneWidget);
      expect(find.text('Archived lot'), findsNothing);
      await tester.tap(find.text('North lot').last);
      await tester.pumpAndSettle();

      final entryPage = tester.widget<ParkingEntryPage>(
        find.byType(ParkingEntryPage),
      );
      expect(entryPage.tenantId, 'north-tenant');
    },
  );

  testWidgets('renders the tenant Admin page at mobile width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const access = ParkingTenantAccess(
      isSuperAdmin: true,
      tenants: [
        ParkingTenant(id: 'north-tenant', name: 'North lot', slug: 'north-lot'),
      ],
    );
    final repository = TestTenantRepository(access: access);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TenantAdminPage(
            access: access,
            repository: repository,
            onTenantChanged: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('Super Admin'), findsOneWidget);
    expect(find.text('North lot'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows configuration guidance without Supabase setup', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ParkingManagementApp());

    expect(find.text('Supabase configuration required'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });

  testWidgets('renders reusable loading empty and error states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            LoadingView(message: 'Loading sessions'),
            EmptyStateView(title: 'No sessions', message: 'Nothing to show'),
            ErrorStateView(message: 'The connection failed'),
          ],
        ),
      ),
    );

    expect(find.text('Loading sessions'), findsOneWidget);
    expect(find.text('No sessions'), findsOneWidget);
    expect(find.text('The connection failed'), findsOneWidget);
    expect(find.text('Something went wrong'), findsOneWidget);
  });
}
