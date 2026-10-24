import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/parking_notifications/data/one_signal_browser_bridge_stub.dart';
import 'package:parking_management/features/parking_notifications/data/one_signal_notification_service.dart';
import 'package:parking_management/features/parking_notifications/presentation/parking_notifications_card.dart';
import 'package:parking_management/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'shows setup guidance and disables push actions without an App ID',
    (WidgetTester tester) async {
      final OneSignalNotificationService service = OneSignalNotificationService(
        appId: '',
        browserBridge: const StubOneSignalBrowserBridge(),
      );

      await tester.pumpWidget(_buildCard(service));
      await tester.pumpAndSettle();

      expect(
        find.text('OneSignal is not configured for this deployment.'),
        findsOneWidget,
      );
      final FilledButton enableButton = tester.widget(
        find.byType(FilledButton),
      );
      expect(enableButton.onPressed, isNull);
    },
  );
}

Widget _buildCard(OneSignalNotificationService service) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: OneSignalNotificationsCard(service: service)),
  );
}
