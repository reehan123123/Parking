import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/parking_notifications/data/one_signal_browser_bridge_stub.dart';
import 'package:parking_management/features/parking_notifications/data/one_signal_notification_service.dart';

void main() {
  group('OneSignalNotificationService', () {
    test('reports setup required when the public App ID is missing', () async {
      final _FakeOneSignalBrowserBridge browserBridge =
          _FakeOneSignalBrowserBridge();
      final OneSignalNotificationService service = OneSignalNotificationService(
        appId: '',
        browserBridge: browserBridge,
      );

      final OneSignalNotificationStatus status = await service.loadStatus();

      expect(
        status.availability,
        OneSignalNotificationAvailability.setupRequired,
      );
      expect(browserBridge.supportCheckCount, 0);
    });

    test(
      'reports unsupported platforms without requesting permission',
      () async {
        final _FakeOneSignalBrowserBridge browserBridge =
            _FakeOneSignalBrowserBridge(supportsPush: false);
        final OneSignalNotificationService service =
            OneSignalNotificationService(
              appId: _appId,
              browserBridge: browserBridge,
            );

        final OneSignalNotificationStatus status = await service.loadStatus();

        expect(
          status.availability,
          OneSignalNotificationAvailability.unsupported,
        );
        expect(browserBridge.permissionRequestCount, 0);
        expect(browserBridge.initializeCount, 0);
      },
    );

    test(
      'logs in once and detaches the previous identity when accounts switch',
      () async {
        final _FakeOneSignalBrowserBridge browserBridge =
            _FakeOneSignalBrowserBridge();
        final OneSignalNotificationService service =
            OneSignalNotificationService(
              appId: _appId,
              browserBridge: browserBridge,
            );

        await service.synchronizeIdentity(_userId);
        await service.synchronizeIdentity(_userId);
        await service.synchronizeIdentity(_otherUserId);
        await service.synchronizeIdentity(null);

        expect(browserBridge.identityChanges, [
          'login:$_userId',
          'logout',
          'login:$_otherUserId',
          'logout',
        ]);
      },
    );

    test(
      'waits for identity synchronization before loading subscription state',
      () async {
        final _FakeOneSignalBrowserBridge browserBridge =
            _FakeOneSignalBrowserBridge()..loginCompleter = Completer<void>();
        final OneSignalNotificationService service =
            OneSignalNotificationService(
              appId: _appId,
              browserBridge: browserBridge,
            );
        final Future<void> identityUpdate = service.synchronizeIdentity(
          _userId,
        );
        final Future<OneSignalNotificationStatus> statusUpdate = service
            .loadStatus();

        await Future<void>.delayed(Duration.zero);
        expect(browserBridge.loadStatusCount, 0);

        browserBridge.loginCompleter!.complete();
        await identityUpdate;
        expect(
          (await statusUpdate).availability,
          OneSignalNotificationAvailability.permissionNotGranted,
        );
        expect(browserBridge.loadStatusCount, 1);
      },
    );

    test(
      'requests browser permission only when enabling notifications',
      () async {
        final _FakeOneSignalBrowserBridge browserBridge =
            _FakeOneSignalBrowserBridge();
        final OneSignalNotificationService service =
            OneSignalNotificationService(
              appId: _appId,
              browserBridge: browserBridge,
            );

        await service.synchronizeIdentity(_userId);

        expect(browserBridge.permissionRequestCount, 0);
        await service.enable();

        expect(browserBridge.permissionRequestCount, 1);
        expect(browserBridge.optInCount, 1);
      },
    );

    test('does not opt in when browser permission is denied', () async {
      final _FakeOneSignalBrowserBridge browserBridge =
          _FakeOneSignalBrowserBridge(permission: 'denied');
      final OneSignalNotificationService service = OneSignalNotificationService(
        appId: _appId,
        browserBridge: browserBridge,
      );
      await service.synchronizeIdentity(_userId);

      await expectLater(
        service.enable(),
        throwsA(
          isA<OneSignalNotificationException>().having(
            (error) => error.code,
            'code',
            OneSignalNotificationErrorCode.permissionDenied,
          ),
        ),
      );
      expect(browserBridge.optInCount, 0);
    });

    test(
      'maps a failed identity update to a notification error on enable',
      () async {
        final _FakeOneSignalBrowserBridge browserBridge =
            _FakeOneSignalBrowserBridge()
              ..loginError = StateError('login failed');
        final OneSignalNotificationService service =
            OneSignalNotificationService(
              appId: _appId,
              browserBridge: browserBridge,
            );

        await expectLater(
          service.synchronizeIdentity(_userId),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          service.enable(),
          throwsA(
            isA<OneSignalNotificationException>().having(
              (error) => error.code,
              'code',
              OneSignalNotificationErrorCode.requestFailed,
            ),
          ),
        );
      },
    );
  });
}

const String _appId = '11111111-1111-4111-8111-111111111111';
const String _userId = '22222222-2222-4222-8222-222222222222';
const String _otherUserId = '33333333-3333-4333-8333-333333333333';

class _FakeOneSignalBrowserBridge implements OneSignalBrowserBridge {
  _FakeOneSignalBrowserBridge({
    this.supportsPush = true,
    this.permission = 'default',
  });

  final bool supportsPush;
  String permission;
  bool isOptedIn = false;
  String externalId = '';
  int supportCheckCount = 0;
  int initializeCount = 0;
  int permissionRequestCount = 0;
  int optInCount = 0;
  int optOutCount = 0;
  int loadStatusCount = 0;
  Object? loginError;
  Completer<void>? loginCompleter;
  final List<String> identityChanges = [];

  @override
  bool get isSupported {
    supportCheckCount++;
    return supportsPush;
  }

  @override
  void clearLaunchParameters() {}

  @override
  Future<String> getExternalId() async => externalId;

  @override
  Future<void> initialize(String appId) async {
    initializeCount++;
  }

  @override
  Future<OneSignalBrowserStatus> loadStatus() async {
    loadStatusCount++;
    return OneSignalBrowserStatus(permission: permission, isOptedIn: isOptedIn);
  }

  @override
  Future<void> login(String externalId) async {
    final Object? error = loginError;
    if (error != null) {
      throw error;
    }
    final Completer<void>? pendingLogin = loginCompleter;
    if (pendingLogin != null) {
      await pendingLogin.future;
    }
    identityChanges.add('login:$externalId');
    this.externalId = externalId;
  }

  @override
  Future<void> logout() async {
    identityChanges.add('logout');
    externalId = '';
  }

  @override
  Future<void> optIn() async {
    optInCount++;
    isOptedIn = true;
  }

  @override
  Future<void> optOut() async {
    optOutCount++;
    isOptedIn = false;
  }

  @override
  Future<String> requestPermission() async {
    permissionRequestCount++;
    permission = permission == 'denied' ? 'denied' : 'granted';
    return permission;
  }
}
