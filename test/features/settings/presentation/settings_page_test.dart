import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/locale/locale_controller.dart';
import 'package:parking_management/features/settings/presentation/settings_page.dart';
import 'package:parking_management/features/tenants/domain/parking_tenant.dart';
import 'package:parking_management/l10n/app_localizations.dart';

import '../../tenants/test_tenant_repository.dart';

void main() {
  testWidgets('Super Admin can open tenant management from Settings', (
    WidgetTester tester,
  ) async {
    bool openedTenantManagement = false;
    final LocaleController localeController = LocaleController();
    addTearDown(localeController.dispose);

    await tester.pumpWidget(
      LocaleScope(
        controller: localeController,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SettingsPage(
              isSuperAdmin: true,
              onManageTenants: () => openedTenantManagement = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Manage tenants'), findsOneWidget);
    expect(find.text('Settings are coming later'), findsNothing);
    expect(
      find.text(
        'Account and application settings will be added in a later phase.',
      ),
      findsNothing,
    );
    await tester.tap(find.text('Manage tenants'));

    expect(openedTenantManagement, isTrue);
  });

  testWidgets('tenant owners can open Manage Members from Settings', (
    WidgetTester tester,
  ) async {
    const ParkingTenant tenant = ParkingTenant(
      id: 'tenant-id',
      name: 'North lot',
      slug: 'north-lot',
      role: ParkingTenantRole.owner,
    );
    final TestTenantRepository repository = TestTenantRepository(
      access: const ParkingTenantAccess(isSuperAdmin: false, tenants: [tenant]),
    );
    final LocaleController localeController = LocaleController();
    addTearDown(localeController.dispose);

    await tester.pumpWidget(
      LocaleScope(
        controller: localeController,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SettingsPage(tenant: tenant, tenantRepository: repository),
          ),
        ),
      ),
    );

    expect(find.text('Manage members'), findsOneWidget);
    expect(find.text('Settings are coming later'), findsNothing);
    expect(
      find.text(
        'Account and application settings will be added in a later phase.',
      ),
      findsNothing,
    );
    await tester.tap(find.text('Manage members'));
    await tester.pumpAndSettle();

    expect(find.text('Members: North lot'), findsOneWidget);
    expect(find.text('0 of 1 members used (owner excluded)'), findsOneWidget);
    expect(find.text('Change limit'), findsNothing);
  });

  testWidgets('regular members do not receive owner member controls', (
    WidgetTester tester,
  ) async {
    const ParkingTenant tenant = ParkingTenant(
      id: 'tenant-id',
      name: 'North lot',
      slug: 'north-lot',
      role: ParkingTenantRole.member,
    );
    final TestTenantRepository repository = TestTenantRepository(
      access: const ParkingTenantAccess(isSuperAdmin: false, tenants: [tenant]),
    );
    final LocaleController localeController = LocaleController();
    addTearDown(localeController.dispose);

    await tester.pumpWidget(
      LocaleScope(
        controller: localeController,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SettingsPage(tenant: tenant, tenantRepository: repository),
          ),
        ),
      ),
    );

    expect(find.text('Manage members'), findsNothing);
    expect(find.text('Tenant members'), findsNothing);
    expect(find.text('Settings are coming later'), findsNothing);
    expect(
      find.text(
        'Account and application settings will be added in a later phase.',
      ),
      findsNothing,
    );
  });
}
