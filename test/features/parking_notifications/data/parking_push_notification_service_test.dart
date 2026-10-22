import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/parking_notifications/data/parking_push_notification_service.dart';
import 'package:parking_management/features/parking_notifications/data/push_browser_bridge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ParkingPushNotificationService', () {
    test(
      'reports setup required when no public VAPID key is configured',
      () async {
        final SupabaseClient client = _createClient();
        addTearDown(client.dispose);
        final _FakePushBrowserBridge browserBridge = _FakePushBrowserBridge(
          supportsPush: true,
        );
        final ParkingPushNotificationService service =
            ParkingPushNotificationService(
              supabaseClient: client,
              applicationServerKey: '',
              browserBridge: browserBridge,
            );

        final ParkingPushNotificationStatus status = await service.loadStatus();

        expect(status.availability, ParkingPushAvailability.setupRequired);
        expect(browserBridge.supportCheckCount, 0);
      },
    );

    test(
      'reports unsupported browsers before checking authentication',
      () async {
        final SupabaseClient client = _createClient();
        addTearDown(client.dispose);
        final _FakePushBrowserBridge browserBridge = _FakePushBrowserBridge(
          supportsPush: false,
        );
        final ParkingPushNotificationService service =
            ParkingPushNotificationService(
              supabaseClient: client,
              applicationServerKey: _publicKey(),
              browserBridge: browserBridge,
            );

        final ParkingPushNotificationStatus status = await service.loadStatus();

        expect(status.availability, ParkingPushAvailability.unsupported);
        expect(status.isEnabled, isFalse);
      },
    );

    test('reports notification permission blocked by the browser', () async {
      final SupabaseClient client = _createClient();
      addTearDown(client.dispose);
      final _FakePushBrowserBridge browserBridge = _FakePushBrowserBridge(
        supportsPush: true,
        permission: 'denied',
      );
      final ParkingPushNotificationService service =
          ParkingPushNotificationService(
            supabaseClient: client,
            applicationServerKey: _publicKey(),
            browserBridge: browserBridge,
          );

      final ParkingPushNotificationStatus status = await service.loadStatus();

      expect(status.availability, ParkingPushAvailability.permissionBlocked);
      expect(status.isEnabled, isFalse);
    });
  });
}

SupabaseClient _createClient() {
  return SupabaseClient(
    'https://parking-test.supabase.co',
    'test-publishable-key',
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
  );
}

String _publicKey() {
  final Uint8List key = Uint8List(65)..[0] = 4;
  return base64Url.encode(key);
}

class _FakePushBrowserBridge implements PushBrowserBridge {
  _FakePushBrowserBridge({
    required this.supportsPush,
    this.permission = 'default',
  });

  @override
  bool get isSupported {
    supportCheckCount++;
    return supportsPush;
  }

  @override
  final String permission;

  final bool supportsPush;
  int supportCheckCount = 0;

  @override
  Future<String> getSubscriptionJson() async => '';

  @override
  Future<String> subscribe(String applicationServerKey) async => '';

  @override
  Future<bool> unsubscribe() async => true;

  @override
  void clearLaunchParameters() {}
}
