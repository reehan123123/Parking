import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/app.dart';
import 'package:parking_management/features/auth/presentation/auth_gate.dart';
import 'package:parking_management/features/parking/data/parking_session_repository.dart';
import 'package:parking_management/features/parking/domain/parking_duration.dart';
import 'package:parking_management/features/parking/domain/parking_duration_unit.dart';
import 'package:parking_management/features/parking/domain/parking_session.dart';
import 'package:parking_management/features/parking/presentation/parking_session_details_page.dart';
import 'package:parking_management/features/tenants/domain/parking_tenant.dart';
import 'package:parking_management/l10n/app_localizations.dart';

import 'features/auth/fake_auth_repository.dart';
import 'features/parking/presentation/parking_test_repository.dart';
import 'features/tenants/test_tenant_repository.dart';
import 'support/localization_test_support.dart';

const String _tenantId = '11111111-1111-4111-8111-111111111111';
const String _otherTenantId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const String _sessionId = '22222222-2222-4222-8222-222222222222';

void main() {
  testWidgets('notification click opens the exact authorized parking record', (
    WidgetTester tester,
  ) async {
    final TestParkingSessionRepository parkingRepository =
        TestParkingSessionRepository(
          detailResult: ParkingSessionDetailSuccess(session: _session()),
        );

    await tester.pumpWidget(
      _buildNotificationApp(
        access: _access(),
        parkingRepository: parkingRepository,
        launchUri: _launchUri(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ParkingSessionDetailsPage), findsOneWidget);
    expect(parkingRepository.lastDetailSessionId, _sessionId);
  });

  testWidgets('unauthenticated notification destination survives sign-in', (
    WidgetTester tester,
  ) async {
    final FakeAuthRepository authRepository = FakeAuthRepository();
    addTearDown(authRepository.dispose);
    final TestParkingSessionRepository parkingRepository =
        TestParkingSessionRepository(
          detailResult: ParkingSessionDetailSuccess(session: _session()),
        );

    await tester.pumpWidget(
      _buildAuthNotificationApp(
        authRepository: authRepository,
        access: _access(),
        parkingRepository: parkingRepository,
        launchUri: _launchUri(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ParkingSessionDetailsPage), findsNothing);
    expect(parkingRepository.detailCalls, 0);

    authRepository.emitSignedIn(true);
    await tester.pumpAndSettle();

    expect(find.byType(ParkingSessionDetailsPage), findsOneWidget);
    expect(parkingRepository.lastDetailSessionId, _sessionId);
  });

  testWidgets('a notification cannot open a session from another tenant', (
    WidgetTester tester,
  ) async {
    final TestParkingSessionRepository parkingRepository =
        TestParkingSessionRepository(
          detailResult: ParkingSessionDetailSuccess(
            session: _session(tenantId: _otherTenantId),
          ),
        );

    await tester.pumpWidget(
      _buildNotificationApp(
        access: _access(),
        parkingRepository: parkingRepository,
        launchUri: _launchUri(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ParkingSessionDetailsPage), findsNothing);
    expect(
      find.text('That parking session is no longer available in this tenant.'),
      findsOneWidget,
    );
  });

  testWidgets('a malformed notification link is rejected before lookup', (
    WidgetTester tester,
  ) async {
    final TestParkingSessionRepository parkingRepository =
        TestParkingSessionRepository();
    final Uri malformedUri = Uri.parse(
      'https://parking.example/?parkingSessionId=$_sessionId'
      '&parkingSessionId=$_sessionId',
    );

    await tester.pumpWidget(
      _buildNotificationApp(
        access: _access(),
        parkingRepository: parkingRepository,
        launchUri: malformedUri,
      ),
    );
    await tester.pumpAndSettle();

    expect(parkingRepository.detailCalls, 0);
    expect(
      find.text('The parking notification link is invalid or expired.'),
      findsOneWidget,
    );
  });
}

Widget _buildNotificationApp({
  required ParkingTenantAccess access,
  required TestParkingSessionRepository parkingRepository,
  required Uri launchUri,
}) {
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

Widget _buildAuthNotificationApp({
  required FakeAuthRepository authRepository,
  required ParkingTenantAccess access,
  required TestParkingSessionRepository parkingRepository,
  required Uri launchUri,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: testLocalizationBuilder,
    home: AuthGate(
      authRepository: authRepository,
      authenticatedBuilder: (context, onSignOut) => AppShell(
        onSignOut: onSignOut,
        initialTenantAccess: access,
        tenantRepository: TestTenantRepository(access: access),
        parkingSessionRepository: parkingRepository,
        notificationLaunchUri: launchUri,
      ),
    ),
  );
}

ParkingTenantAccess _access() {
  return ParkingTenantAccess(isSuperAdmin: false, tenants: [_ownerTenant()]);
}

Uri _launchUri() {
  return Uri.https('parking.example', '/', {'parkingSessionId': _sessionId});
}

ParkingTenant _ownerTenant() {
  return const ParkingTenant(
    id: _tenantId,
    name: 'North lot',
    slug: 'north-lot',
    role: ParkingTenantRole.owner,
  );
}

ParkingSession _session({String tenantId = _tenantId}) {
  return ParkingSession(
    id: _sessionId,
    tenantId: tenantId,
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
