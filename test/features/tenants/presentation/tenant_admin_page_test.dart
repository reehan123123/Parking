import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/tenants/data/supabase_tenant_repository.dart';
import 'package:parking_management/features/tenants/domain/parking_tenant.dart';
import 'package:parking_management/features/tenants/presentation/tenant_admin_page.dart';
import 'package:parking_management/l10n/app_localizations.dart';

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
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TenantAdminPage(
            access: repository.access,
            repository: repository,
            onTenantChanged: (tenant) async => createdTenant = tenant,
          ),
        ),
      ),
    );

    expect(find.text('Super Admin'), findsOneWidget);
    await tester.tap(find.text('Create tenant'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('An existing account keeps its current password.'),
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
    expect(repository.lastRequestId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(createdTenant?.id, 'new-tenant');
    expect(find.text('No tenant workspaces yet'), findsOneWidget);
  });

  testWidgets('shows the temporary password once before completing creation', (
    WidgetTester tester,
  ) async {
    final repository = TestTenantRepository(
      access: const ParkingTenantAccess(isSuperAdmin: true, tenants: []),
    )..createdTemporaryPassword = 'temporary-value-for-test';
    ParkingTenant? createdTenant;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TenantAdminPage(
            access: repository.access,
            repository: repository,
            onTenantChanged: (tenant) async => createdTenant = tenant,
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

    expect(find.text('temporary-value-for-test'), findsOneWidget);
    expect(
      find.textContaining(
        'must change this password before accessing tenant data',
      ),
      findsOneWidget,
    );
    expect(createdTenant, isNull);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(createdTenant?.id, 'new-tenant');
    expect(find.text('temporary-value-for-test'), findsNothing);
  });

  testWidgets('preserves the temporary password after a partial failure', (
    WidgetTester tester,
  ) async {
    final repository =
        TestTenantRepository(
            access: const ParkingTenantAccess(isSuperAdmin: true, tenants: []),
          )
          ..createError = const TenantRepositoryException(
            'The owner account was created, but tenant setup could not be confirmed.',
            temporaryPassword: 'temporary-value-for-test',
          );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TenantAdminPage(
            access: repository.access,
            repository: repository,
            onTenantChanged: (_) async {},
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

    expect(
      find.text(
        'The owner account was created, but tenant setup could not be confirmed.',
      ),
      findsOneWidget,
    );
    expect(find.text('temporary-value-for-test'), findsOneWidget);
    expect(find.text('Retry tenant setup'), findsOneWidget);
    expect(find.text('Airport Parking'), findsOneWidget);
  });

  testWidgets('archives a tenant without deleting its data', (
    WidgetTester tester,
  ) async {
    const tenant = ParkingTenant(
      id: 'north-tenant',
      name: 'North lot',
      slug: 'north-lot',
    );
    final repository = TestTenantRepository(
      access: const ParkingTenantAccess(isSuperAdmin: true, tenants: [tenant]),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TenantAdminPage(
            access: repository.access,
            repository: repository,
            onTenantChanged: (_) async {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Manage North lot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive tenant').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Parking records and photos will be retained'),
      findsOneWidget,
    );
    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();

    expect(repository.archiveTenantCalls, 1);
    expect(
      find.text('North lot was archived. Its data was retained.'),
      findsOneWidget,
    );
  });

  testWidgets('renames a tenant and refreshes the tenant list', (
    WidgetTester tester,
  ) async {
    const tenant = ParkingTenant(
      id: 'north-tenant',
      name: 'North lot',
      slug: 'north-lot',
    );
    final repository =
        TestTenantRepository(
            access: const ParkingTenantAccess(
              isSuperAdmin: true,
              tenants: [tenant],
            ),
          )
          ..updatedTenant = const ParkingTenant(
            id: 'north-tenant',
            name: 'North parking',
            slug: 'north-lot',
          );
    ParkingTenant? changedTenant = tenant;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TenantAdminPage(
            access: repository.access,
            repository: repository,
            onTenantChanged: (updated) async => changedTenant = updated,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Manage North lot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'North parking');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.updateTenantCalls, 1);
    expect(repository.lastName, 'North parking');
    expect(changedTenant, isNull);
  });

  testWidgets('restores an archived tenant', (WidgetTester tester) async {
    const tenant = ParkingTenant(
      id: 'north-tenant',
      name: 'North lot',
      slug: 'north-lot',
      isArchived: true,
    );
    final repository = TestTenantRepository(
      access: const ParkingTenantAccess(isSuperAdmin: true, tenants: [tenant]),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TenantAdminPage(
            access: repository.access,
            repository: repository,
            onTenantChanged: (_) async {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Manage North lot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore tenant'));
    await tester.pumpAndSettle();

    expect(repository.restoreTenantCalls, 1);
    expect(find.text('North lot was restored.'), findsOneWidget);
  });

  testWidgets('adds and removes tenant members', (WidgetTester tester) async {
    const tenant = ParkingTenant(
      id: 'north-tenant',
      name: 'North lot',
      slug: 'north-lot',
    );
    final repository =
        TestTenantRepository(
            access: const ParkingTenantAccess(
              isSuperAdmin: true,
              tenants: [tenant],
            ),
          )
          ..members = const [
            ParkingTenantMember(
              userId: 'owner-id',
              email: 'owner@example.com',
              role: ParkingTenantRole.owner,
              permissions: TenantEntryPermissions.all(),
            ),
            ParkingTenantMember(
              userId: 'member-id',
              email: 'member@example.com',
              role: ParkingTenantRole.member,
              permissions: TenantEntryPermissions.viewOnly(),
            ),
          ];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TenantAdminPage(
            access: repository.access,
            repository: repository,
            onTenantChanged: (_) async {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Manage North lot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage members'));
    await tester.pumpAndSettle();

    expect(find.text('owner@example.com'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).last,
      'new-member@example.com',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Add'));
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(repository.addMemberCalls, 1);
    expect(repository.lastMemberEmail, 'new-member@example.com');
    expect(repository.lastMemberRole, ParkingTenantRole.member);

    await tester.tap(find.byTooltip('Manage member@example.com'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove member').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();

    expect(repository.removeMemberCalls, 1);
    expect(
      find.text(
        'Remove member@example.com from North lot? Their Auth account and parking records will not be deleted.',
      ),
      findsNothing,
    );
  });

  testWidgets('shows a new member temporary password once', (
    WidgetTester tester,
  ) async {
    const ParkingTenant tenant = ParkingTenant(
      id: 'north-tenant',
      name: 'North lot',
      slug: 'north-lot',
    );
    final TestTenantRepository repository =
        TestTenantRepository(
            access: const ParkingTenantAccess(
              isSuperAdmin: true,
              tenants: [tenant],
            ),
          )
          ..memberCreationResult = const TenantMemberCreationResult(
            accountCreated: true,
            temporaryPassword: 'temporary-member-password',
          );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TenantAdminPage(
            access: repository.access,
            repository: repository,
            onTenantChanged: (_) async {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Manage North lot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage members'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).last,
      'new-member@example.com',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Add'));
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(repository.lastMemberRequestId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(find.text('New member account'), findsOneWidget);
    expect(find.text('temporary-member-password'), findsOneWidget);
    expect(find.textContaining('added only to this tenant'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('temporary-member-password'), findsNothing);
  });

  testWidgets(
    'hides Add Member at capacity and allows a Super Admin to raise the limit',
    (WidgetTester tester) async {
      const ParkingTenant tenant = ParkingTenant(
        id: 'north-tenant',
        name: 'North lot',
        slug: 'north-lot',
      );
      final TestTenantRepository repository =
          TestTenantRepository(
              access: const ParkingTenantAccess(
                isSuperAdmin: true,
                tenants: [tenant],
              ),
            )
            ..memberCapacity = const TenantMemberCapacity(
              tenantId: 'north-tenant',
              memberLimit: 1,
              activeMemberCount: 1,
              remainingMemberCount: 0,
            )
            ..members = const [
              ParkingTenantMember(
                userId: 'owner-id',
                email: 'owner@example.com',
                role: ParkingTenantRole.owner,
                permissions: TenantEntryPermissions.all(),
              ),
              ParkingTenantMember(
                userId: 'member-id',
                email: 'member@example.com',
                role: ParkingTenantRole.member,
                permissions: TenantEntryPermissions.viewOnly(),
              ),
            ];

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TenantAdminPage(
              access: repository.access,
              repository: repository,
              onTenantChanged: (_) async {},
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Manage North lot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage members'));
      await tester.pumpAndSettle();

      expect(find.text('Member limit reached'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add'), findsNothing);

      await tester.ensureVisible(find.text('Increase member limit'));
      await tester.tap(find.text('Increase member limit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, '2');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repository.lastMemberLimit, 2);
      expect(find.widgetWithText(FilledButton, 'Add'), findsOneWidget);
    },
  );

  testWidgets('saves independent entry permissions for a member', (
    WidgetTester tester,
  ) async {
    const ParkingTenant tenant = ParkingTenant(
      id: 'north-tenant',
      name: 'North lot',
      slug: 'north-lot',
    );
    final TestTenantRepository repository =
        TestTenantRepository(
            access: const ParkingTenantAccess(
              isSuperAdmin: true,
              tenants: [tenant],
            ),
          )
          ..members = const [
            ParkingTenantMember(
              userId: 'owner-id',
              email: 'owner@example.com',
              role: ParkingTenantRole.owner,
              permissions: TenantEntryPermissions.all(),
            ),
            ParkingTenantMember(
              userId: 'member-id',
              email: 'member@example.com',
              role: ParkingTenantRole.member,
              permissions: TenantEntryPermissions.viewOnly(),
            ),
          ];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TenantAdminPage(
            access: repository.access,
            repository: repository,
            onTenantChanged: (_) async {},
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Manage North lot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage members'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Manage member@example.com'));
    await tester.tap(find.byTooltip('Manage member@example.com'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit entry permissions'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Add'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.updateMemberPermissionsCalls, 1);
    expect(
      repository.lastMemberPermissions,
      const TenantEntryPermissions(
        canView: true,
        canAdd: true,
        canEdit: false,
        canDelete: false,
      ),
    );
  });
}
