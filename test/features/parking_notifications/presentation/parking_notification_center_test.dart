import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/app.dart';
import 'package:parking_management/features/parking/data/parking_session_repository.dart';
import 'package:parking_management/features/parking/domain/parking_duration.dart';
import 'package:parking_management/features/parking/domain/parking_duration_unit.dart';
import 'package:parking_management/features/parking/domain/parking_session.dart';
import 'package:parking_management/features/parking/presentation/parking_session_details_page.dart';
import 'package:parking_management/features/parking_notifications/data/parking_notification_repository.dart';
import 'package:parking_management/features/parking_notifications/domain/parking_notification.dart';
import 'package:parking_management/features/tenants/domain/parking_tenant.dart';
import 'package:parking_management/l10n/app_localizations.dart';

import '../../parking/presentation/parking_test_repository.dart';
import '../../../support/localization_test_support.dart';

const String _tenantId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const String _otherTenantId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const String _sessionId = '22222222-2222-4222-8222-222222222222';
const String _notificationId = '33333333-3333-4333-8333-333333333333';

void main() {
  testWidgets(
    'opens a notification through the authorized repository and marks it read',
    (WidgetTester tester) async {
      final _FakeParkingNotificationRepository notifications =
          _FakeParkingNotificationRepository([_notification()]);
      final TestParkingSessionRepository parkingRepository =
          TestParkingSessionRepository(
            detailResult: ParkingSessionDetailSuccess(session: _session()),
          );

      await tester.pumpWidget(
        _buildApp(
          access: _ownerAccess(),
          notificationRepository: notifications,
          parkingRepository: parkingRepository,
        ),
      );
      await tester.pumpAndSettle();

      expect(notifications.requestedTenantIds, [_tenantId]);
      await tester.tap(find.byTooltip('Parking notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Parking Expired'), findsOneWidget);

      await tester.tap(find.text('Parking Expired'));
      await tester.pumpAndSettle();

      expect(parkingRepository.lastDetailSessionId, _sessionId);
      expect(find.byType(ParkingSessionDetailsPage), findsOneWidget);
      expect(notifications.markedReadIds, [_notificationId]);
    },
  );

  testWidgets('hides the notification bell in All Tenants mode', (
    WidgetTester tester,
  ) async {
    final _FakeParkingNotificationRepository notifications =
        _FakeParkingNotificationRepository([]);
    const ParkingTenantAccess access = ParkingTenantAccess(
      isSuperAdmin: true,
      tenants: [
        ParkingTenant(id: _tenantId, name: 'North lot', slug: 'north-lot'),
      ],
    );

    await tester.pumpWidget(
      _buildApp(access: access, notificationRepository: notifications),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Parking notifications'), findsNothing);
    expect(notifications.listCalls, 0);
  });

  testWidgets('clears and reloads notifications when the app pauses', (
    WidgetTester tester,
  ) async {
    final _FakeParkingNotificationRepository notifications =
        _FakeParkingNotificationRepository([]);

    await tester.pumpWidget(
      _buildApp(access: _ownerAccess(), notificationRepository: notifications),
    );
    await tester.pumpAndSettle();
    final int initialCallCount = notifications.listCalls;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(minutes: 2));
    expect(notifications.listCalls, initialCallCount);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(notifications.listCalls, greaterThan(initialCallCount));
  });

  testWidgets('reloads only the selected tenants notifications', (
    WidgetTester tester,
  ) async {
    final _FakeParkingNotificationRepository notifications =
        _FakeParkingNotificationRepository([]);
    const ParkingTenantAccess access = ParkingTenantAccess(
      isSuperAdmin: true,
      tenants: [
        ParkingTenant(id: _tenantId, name: 'North lot', slug: 'north-lot'),
        ParkingTenant(id: _otherTenantId, name: 'South lot', slug: 'south-lot'),
      ],
    );

    await tester.pumpWidget(
      _buildApp(access: access, notificationRepository: notifications),
    );
    await tester.pumpAndSettle();
    expect(notifications.requestedTenantIds, isEmpty);

    await tester.tap(find.byTooltip('Select tenant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('North lot'));
    await tester.pumpAndSettle();
    expect(notifications.requestedTenantIds, [_tenantId]);

    await tester.tap(find.byTooltip('Select tenant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('South lot'));
    await tester.pumpAndSettle();
    expect(notifications.requestedTenantIds, [_tenantId, _otherTenantId]);
  });
}

Widget _buildApp({
  required ParkingTenantAccess access,
  required _FakeParkingNotificationRepository notificationRepository,
  ParkingSessionRepository? parkingRepository,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: testLocalizationBuilder,
    home: AppShell(
      initialTenantAccess: access,
      parkingSessionRepository: parkingRepository,
      parkingNotificationRepository: notificationRepository,
    ),
  );
}

ParkingTenantAccess _ownerAccess() {
  return const ParkingTenantAccess(
    isSuperAdmin: false,
    tenants: [
      ParkingTenant(
        id: _tenantId,
        name: 'North lot',
        slug: 'north-lot',
        role: ParkingTenantRole.owner,
      ),
    ],
  );
}

ParkingNotification _notification({
  String tenantId = _tenantId,
  String sessionId = _sessionId,
  String id = _notificationId,
  DateTime? readAt,
}) {
  final DateTime timestamp = DateTime.utc(2026, 10, 25, 10, 15);
  return ParkingNotification(
    id: id,
    tenantId: tenantId,
    sessionId: sessionId,
    createdAt: timestamp,
    lastRemindedAt: timestamp,
    reminderIntervalAt: timestamp,
    readAt: readAt,
    notificationType: 'expired',
  );
}

ParkingSession _session() {
  return ParkingSession(
    id: _sessionId,
    tenantId: _tenantId,
    plateNumber: 'AB 123',
    entryTime: DateTime(2026, 10, 25, 10),
    allowedDuration: const ParkingDuration(
      value: 30,
      unit: ParkingDurationUnit.minutes,
    ),
    expiresAt: DateTime(2026, 10, 25, 10, 30),
    totalCharge: 100,
    paidAmount: 25,
  );
}

class _FakeParkingNotificationRepository
    implements ParkingNotificationRepository {
  _FakeParkingNotificationRepository(this.notifications);

  List<ParkingNotification> notifications;
  final List<String> requestedTenantIds = [];
  final List<String> markedReadIds = [];
  int listCalls = 0;

  @override
  Future<List<ParkingNotification>> listActive({
    required String tenantId,
  }) async {
    listCalls++;
    requestedTenantIds.add(tenantId);
    return notifications
        .where((notification) => notification.tenantId == tenantId)
        .toList(growable: false);
  }

  @override
  Future<void> markRead({required String notificationId}) async {
    markedReadIds.add(notificationId);
    notifications = notifications
        .map(
          (notification) => notification.id == notificationId
              ? _notification(
                  id: notification.id,
                  tenantId: notification.tenantId,
                  sessionId: notification.sessionId,
                  readAt: DateTime.utc(2026, 10, 25, 10, 16),
                )
              : notification,
        )
        .toList(growable: false);
  }
}
