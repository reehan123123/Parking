import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/app.dart';
import 'package:parking_management/features/parking/data/parking_session_repository.dart';
import 'package:parking_management/features/parking/domain/parking_duration.dart';
import 'package:parking_management/features/parking/domain/parking_duration_unit.dart';
import 'package:parking_management/features/parking/domain/parking_session.dart';
import 'package:parking_management/features/parking/presentation/parking_session_details_page.dart';
import 'package:parking_management/features/tenants/domain/parking_tenant.dart';
import 'package:parking_management/l10n/app_localizations.dart';

import 'features/parking/presentation/parking_test_repository.dart';
import 'features/tenants/test_tenant_repository.dart';
import 'support/localization_test_support.dart';

const String _tenantId = '11111111-1111-4111-8111-111111111111';
const String _sessionId = '22222222-2222-4222-8222-222222222222';

void main() {
  testWidgets('notification payment action requires in-app confirmation', (
    WidgetTester tester,
  ) async {
    final TestParkingSessionRepository parkingRepository =
        TestParkingSessionRepository(
          detailResult: ParkingSessionDetailSuccess(session: _session()),
          paymentResult: const ParkingSessionPaymentSuccess(
            wasMarkedPaid: true,
          ),
        );

    await tester.pumpWidget(
      _buildNotificationApp(
        tenant: _ownerTenant(),
        parkingRepository: parkingRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mark parking as fully paid?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(parkingRepository.markFullyPaidCalls, 0);
    expect(find.byType(ParkingSessionDetailsPage), findsOneWidget);
  });

  testWidgets('confirmed notification payment uses the authorized repository', (
    WidgetTester tester,
  ) async {
    final TestParkingSessionRepository parkingRepository =
        TestParkingSessionRepository(
          detailResult: ParkingSessionDetailSuccess(session: _session()),
          paymentResult: const ParkingSessionPaymentSuccess(
            wasMarkedPaid: true,
          ),
        );

    await tester.pumpWidget(
      _buildNotificationApp(
        tenant: _ownerTenant(),
        parkingRepository: parkingRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Mark Full Paid'));
    await tester.pumpAndSettle();

    expect(parkingRepository.markFullyPaidCalls, 1);
    expect(parkingRepository.lastPaymentSessionId, _sessionId);
    expect(find.byType(ParkingSessionDetailsPage), findsOneWidget);
  });

  testWidgets('view-only members cannot use a forged Full Paid launch', (
    WidgetTester tester,
  ) async {
    final TestParkingSessionRepository parkingRepository =
        TestParkingSessionRepository(
          detailResult: ParkingSessionDetailSuccess(session: _session()),
        );
    const ParkingTenant tenant = ParkingTenant(
      id: _tenantId,
      name: 'North lot',
      slug: 'north-lot',
      role: ParkingTenantRole.member,
      entryPermissions: TenantEntryPermissions.viewOnly(),
    );

    await tester.pumpWidget(
      _buildNotificationApp(
        tenant: tenant,
        parkingRepository: parkingRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mark parking as fully paid?'), findsNothing);
    expect(parkingRepository.markFullyPaidCalls, 0);
    expect(find.byType(ParkingSessionDetailsPage), findsOneWidget);
  });
}

Widget _buildNotificationApp({
  required ParkingTenant tenant,
  required TestParkingSessionRepository parkingRepository,
}) {
  final ParkingTenantAccess access = ParkingTenantAccess(
    isSuperAdmin: false,
    tenants: [tenant],
  );
  final Uri launchUri = Uri.https('parking.example', '/', {
    'parkingSessionId': _sessionId,
    'parkingTenantId': _tenantId,
    'parkingAction': 'full-paid',
  });

  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: testLocalizationBuilder,
    home: AppShell(
      initialTenantAccess: access,
      tenantRepository: TestTenantRepository(access: access),
      parkingSessionRepository: parkingRepository,
      notificationLaunchUri: launchUri,
    ),
  );
}

ParkingTenant _ownerTenant() {
  return const ParkingTenant(
    id: _tenantId,
    name: 'North lot',
    slug: 'north-lot',
    role: ParkingTenantRole.owner,
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
