import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/device_sessions/data/device_session_repository.dart';
import 'package:parking_management/features/device_sessions/domain/device_session_models.dart';
import 'package:parking_management/features/device_sessions/presentation/device_session_admin_page.dart';
import 'package:parking_management/features/tenants/domain/parking_tenant.dart';
import 'package:parking_management/l10n/app_localizations.dart';

void main() {
  testWidgets('loads tenant policy and confirms administrative revocation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final _FakeDeviceSessionAdminRepository repository =
        _FakeDeviceSessionAdminRepository();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DeviceSessionAdminPage(
          tenants: const [
            ParkingTenant(id: 'tenant-a', name: 'North lot', slug: 'north-lot'),
          ],
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Platform default'), findsOneWidget);
    await tester.tap(find.text('North lot'));
    await tester.pumpAndSettle();

    expect(find.text('member@example.com'), findsNWidgets(2));
    expect(find.text('Effective limit: 3 devices'), findsOneWidget);
    final Finder revokeButton = find.byTooltip('Revoke device');
    await tester.tap(revokeButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Revoke this active device session for member@example.com?',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Revoke device'));
    await tester.pumpAndSettle();

    expect(repository.revokedTenantId, 'tenant-a');
    expect(repository.revokedUserId, 'member-id');
    expect(
      repository.revokedInstallationId,
      '10000000-0000-4000-8000-000000000001',
    );
    expect(find.text('No active device sessions.'), findsOneWidget);
    expect(find.text('Super Admin revoked a device'), findsOneWidget);
  });
}

class _FakeDeviceSessionAdminRepository
    implements DeviceSessionAdminRepository {
  int? tenantDeviceLimit = 3;
  List<AdminDeviceSession> sessions = [
    AdminDeviceSession(
      userId: 'member-id',
      email: 'member@example.com',
      installationId: '10000000-0000-4000-8000-000000000001',
      activeSessionCount: 1,
      lastActivityAt: DateTime.utc(2026, 10, 24, 10),
    ),
  ];
  final List<DeviceSessionAuditEvent> auditEvents = [];
  String? revokedTenantId;
  String? revokedUserId;
  String? revokedInstallationId;

  @override
  Future<PlatformDeviceSessionPolicy> getPlatformPolicy() async {
    return const PlatformDeviceSessionPolicy(
      deviceLimit: 1,
      staleSessionDays: 30,
      maxDeviceLimit: 50,
      minStaleSessionDays: 7,
      maxStaleSessionDays: 365,
    );
  }

  @override
  Future<void> setPlatformPolicy({
    required int deviceLimit,
    required int staleSessionDays,
  }) async {}

  @override
  Future<TenantDeviceSessionPolicy> getTenantPolicy({
    required String tenantId,
  }) async {
    return TenantDeviceSessionPolicy(
      platformDeviceLimit: 1,
      tenantDeviceLimit: tenantDeviceLimit,
      effectiveDeviceLimit: tenantDeviceLimit ?? 1,
      staleSessionDays: 30,
      activeDeviceCount: sessions.isEmpty ? 0 : 1,
      activeSessionCount: sessions.length,
    );
  }

  @override
  Future<void> setTenantLimit({
    required String tenantId,
    required int? deviceLimit,
  }) async {
    tenantDeviceLimit = deviceLimit;
  }

  @override
  Future<List<TenantMemberDevicePolicy>> listTenantMemberPolicies({
    required String tenantId,
  }) async {
    return const [
      TenantMemberDevicePolicy(
        userId: 'member-id',
        email: 'member@example.com',
        role: 'owner',
        accountDeviceLimit: null,
        effectiveDeviceLimit: 3,
        policySource: 'tenant_policy',
        activeDeviceCount: 1,
      ),
    ];
  }

  @override
  Future<void> setMemberLimit({
    required String tenantId,
    required String userId,
    required int? deviceLimit,
  }) async {}

  @override
  Future<List<AdminDeviceSession>> listTenantSessions({
    required String tenantId,
  }) async {
    return sessions;
  }

  @override
  Future<void> revokeTenantInstallation({
    required String tenantId,
    required String userId,
    required String installationId,
  }) async {
    revokedTenantId = tenantId;
    revokedUserId = userId;
    revokedInstallationId = installationId;
    sessions = const [];
    auditEvents.add(
      DeviceSessionAuditEvent(
        tenantName: 'North lot',
        actorEmail: 'admin@example.com',
        subjectEmail: 'member@example.com',
        action: 'session_revoked_by_admin',
        details: const {},
        createdAt: DateTime.utc(2026, 10, 24, 10),
      ),
    );
  }

  @override
  Future<List<DeviceSessionAuditEvent>> listAuditEvents() async => auditEvents;
}
