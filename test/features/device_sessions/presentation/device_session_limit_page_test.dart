import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/device_sessions/data/device_session_repository.dart';
import 'package:parking_management/features/device_sessions/domain/device_session_models.dart';
import 'package:parking_management/features/device_sessions/presentation/device_session_limit_page.dart';
import 'package:parking_management/features/tenants/domain/parking_tenant.dart';
import 'package:parking_management/l10n/app_localizations.dart';

void main() {
  testWidgets('shows the effective limit and lets the user remove a device', (
    WidgetTester tester,
  ) async {
    final _FakeDeviceSessionRepository repository =
        _FakeDeviceSessionRepository(
          sessions: [
            UserDeviceSession(
              tenantId: 'tenant-a',
              tenantName: 'North lot',
              installationId: '10000000-0000-4000-8000-000000000001',
              activeSessionCount: 1,
              lastActivityAt: DateTime.utc(2026, 10, 24, 10),
              includesCurrentSession: false,
              isCurrentInstallation: false,
            ),
          ],
        );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DeviceSessionLimitPage(
          deviceLimit: 3,
          activeDeviceCount: 3,
          tenants: const [
            ParkingTenant(id: 'tenant-a', name: 'North lot', slug: 'north-lot'),
          ],
          selectedTenantId: 'tenant-a',
          repository: repository,
          onRetry: (String tenantId) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        "You've reached the maximum of 3 active devices for this account.",
      ),
      findsOneWidget,
    );
    expect(
      find.text('Active devices currently using this account: 3.'),
      findsOneWidget,
    );

    final Finder removeButton = find.byTooltip('Remove device');
    await tester.ensureVisible(removeButton);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();
    expect(find.text('Remove this device?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Remove device'));
    await tester.pumpAndSettle();

    expect(repository.revokedTenantId, 'tenant-a');
    expect(
      repository.revokedInstallationId,
      '10000000-0000-4000-8000-000000000001',
    );
    expect(find.text('No active devices'), findsOneWidget);
  });

  testWidgets('allows choosing another tenant with an independent allowance', (
    WidgetTester tester,
  ) async {
    final _FakeDeviceSessionRepository repository =
        _FakeDeviceSessionRepository(sessions: []);
    String? retriedTenantId;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DeviceSessionLimitPage(
          deviceLimit: 1,
          activeDeviceCount: 1,
          tenants: const [
            ParkingTenant(id: 'tenant-a', name: 'North lot', slug: 'north-lot'),
            ParkingTenant(id: 'tenant-b', name: 'South lot', slug: 'south-lot'),
          ],
          selectedTenantId: 'tenant-a',
          repository: repository,
          onRetry: (String tenantId) async {
            retriedTenantId = tenantId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('South lot').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(retriedTenantId, 'tenant-b');
  });
}

class _FakeDeviceSessionRepository implements DeviceSessionRepository {
  _FakeDeviceSessionRepository({required this.sessions});

  List<UserDeviceSession> sessions;
  String? revokedTenantId;
  String? revokedInstallationId;

  @override
  Future<void> registerCurrentSession({required String tenantId}) async {}

  @override
  Future<List<UserDeviceSession>> listMySessions() async => sessions;

  @override
  Future<void> revokeMyInstallation({
    required String tenantId,
    required String installationId,
  }) async {
    revokedTenantId = tenantId;
    revokedInstallationId = installationId;
    sessions = const [];
  }

  @override
  Future<void> releaseCurrentSession() async {}
}
