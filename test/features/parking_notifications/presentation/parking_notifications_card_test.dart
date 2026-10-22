import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/parking_notifications/data/parking_push_notification_service.dart';
import 'package:parking_management/features/parking_notifications/data/push_browser_bridge.dart';
import 'package:parking_management/features/parking_notifications/presentation/parking_notifications_card.dart';
import 'package:parking_management/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final SupabaseClient client = SupabaseClient(
    'https://parking-test.supabase.co',
    'test-publishable-key',
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
  );

  testWidgets('shows setup guidance and disables the toggle without a key', (
    WidgetTester tester,
  ) async {
    addTearDown(client.dispose);
    final ParkingPushNotificationService service =
        ParkingPushNotificationService(
          supabaseClient: client,
          applicationServerKey: '',
          browserBridge: const StubPushBrowserBridge(),
        );

    await tester.pumpWidget(_buildCard(service));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'Push notifications are not configured for this deployment yet.',
      ),
      findsOneWidget,
    );
    final SwitchListTile switchTile = tester.widget(
      find.byType(SwitchListTile),
    );
    expect(switchTile.onChanged, isNull);
  });
}

Widget _buildCard(ParkingPushNotificationService service) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: ParkingNotificationsCard(service: service)),
  );
}
