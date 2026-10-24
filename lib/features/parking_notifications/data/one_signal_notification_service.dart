import 'dart:async';

import 'one_signal_browser_bridge.dart';

enum OneSignalNotificationAvailability {
  setupRequired,
  unsupported,
  permissionNotGranted,
  pending,
  enabled,
  disabled,
  failed,
}

enum OneSignalNotificationErrorCode {
  setupRequired,
  unsupported,
  permissionDenied,
  notSignedIn,
  requestFailed,
}

class OneSignalNotificationStatus {
  const OneSignalNotificationStatus(this.availability);

  final OneSignalNotificationAvailability availability;
}

class OneSignalNotificationException implements Exception {
  const OneSignalNotificationException(this.code);

  final OneSignalNotificationErrorCode code;
}

class OneSignalNotificationService {
  OneSignalNotificationService({
    required String appId,
    OneSignalBrowserBridge? browserBridge,
  }) : _appId = appId.trim(),
       _browserBridge = browserBridge ?? createOneSignalBrowserBridge();

  static const Duration _initializationTimeout = Duration(seconds: 20);
  static const String _uuidPattern =
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';

  final String _appId;
  final OneSignalBrowserBridge _browserBridge;
  Future<void>? _initialization;
  Future<void> _identityQueue = Future<void>.value();
  String? _identifiedUserId;
  String? _requestedUserId;

  bool get isConfigured =>
      RegExp(_uuidPattern, caseSensitive: false).hasMatch(_appId);

  void clearLaunchParameters() {
    _browserBridge.clearLaunchParameters();
  }

  Future<void> initialize() async {
    _requireConfigured();
    if (!_browserBridge.isSupported) {
      throw const OneSignalNotificationException(
        OneSignalNotificationErrorCode.unsupported,
      );
    }

    final Future<void>? pending = _initialization;
    if (pending != null) {
      await pending;
      return;
    }

    final Future<void> attempt = _browserBridge
        .initialize(_appId)
        .timeout(_initializationTimeout);
    _initialization = attempt;
    try {
      await attempt;
    } on Object {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> synchronizeIdentity(String? userId) {
    final String? normalizedUserId = userId?.trim();
    _requestedUserId = normalizedUserId;
    final Future<void> operation = () async {
      try {
        await _identityQueue;
      } on Object {
        // A failed previous identity update must not block the latest auth state.
      }
      await _synchronizeIdentity(normalizedUserId);
    }();
    _identityQueue = operation;
    return operation;
  }

  Future<OneSignalNotificationStatus> loadStatus() async {
    if (!isConfigured) {
      return const OneSignalNotificationStatus(
        OneSignalNotificationAvailability.setupRequired,
      );
    }
    try {
      if (!_browserBridge.isSupported) {
        return const OneSignalNotificationStatus(
          OneSignalNotificationAvailability.unsupported,
        );
      }
      await _waitForIdentitySynchronization();
      await initialize();
      final OneSignalBrowserStatus status = await _browserBridge.loadStatus();
      if (status.permission != 'granted') {
        return const OneSignalNotificationStatus(
          OneSignalNotificationAvailability.permissionNotGranted,
        );
      }
      return OneSignalNotificationStatus(switch (status.isOptedIn) {
        true => OneSignalNotificationAvailability.enabled,
        false => OneSignalNotificationAvailability.disabled,
        null => OneSignalNotificationAvailability.pending,
      });
    } on Object {
      return const OneSignalNotificationStatus(
        OneSignalNotificationAvailability.failed,
      );
    }
  }

  Future<void> enable() async {
    _requireConfigured();
    try {
      await _identityQueue;
      if (_identifiedUserId == null) {
        throw const OneSignalNotificationException(
          OneSignalNotificationErrorCode.notSignedIn,
        );
      }
      if (!_browserBridge.isSupported) {
        throw const OneSignalNotificationException(
          OneSignalNotificationErrorCode.unsupported,
        );
      }

      await initialize();
      final OneSignalBrowserStatus currentStatus = await _browserBridge
          .loadStatus();
      if (currentStatus.permission == 'denied') {
        throw const OneSignalNotificationException(
          OneSignalNotificationErrorCode.permissionDenied,
        );
      }

      final String permission = await _browserBridge.requestPermission();
      if (permission != 'granted') {
        throw const OneSignalNotificationException(
          OneSignalNotificationErrorCode.permissionDenied,
        );
      }
      await _browserBridge.optIn();
    } on OneSignalNotificationException {
      rethrow;
    } on Object {
      throw const OneSignalNotificationException(
        OneSignalNotificationErrorCode.requestFailed,
      );
    }
  }

  Future<void> disable() async {
    _requireConfigured();
    try {
      await _identityQueue;
      if (_identifiedUserId == null) {
        throw const OneSignalNotificationException(
          OneSignalNotificationErrorCode.notSignedIn,
        );
      }
      if (!_browserBridge.isSupported) {
        throw const OneSignalNotificationException(
          OneSignalNotificationErrorCode.unsupported,
        );
      }

      await initialize();
      await _browserBridge.optOut();
    } on OneSignalNotificationException {
      rethrow;
    } on Object {
      throw const OneSignalNotificationException(
        OneSignalNotificationErrorCode.requestFailed,
      );
    }
  }

  Future<void> _synchronizeIdentity(String? userId) async {
    if (userId != null &&
        !RegExp(_uuidPattern, caseSensitive: false).hasMatch(userId)) {
      throw const OneSignalNotificationException(
        OneSignalNotificationErrorCode.requestFailed,
      );
    }

    if (!isConfigured || !_browserBridge.isSupported) {
      _identifiedUserId = null;
      return;
    }

    await initialize();
    final String currentExternalId = (await _browserBridge.getExternalId())
        .trim();
    if (userId == null) {
      if (currentExternalId.isNotEmpty || _identifiedUserId != null) {
        await _browserBridge.logout();
      }
      _identifiedUserId = null;
      return;
    }

    if (currentExternalId == userId) {
      _identifiedUserId = userId;
      return;
    }
    if (currentExternalId.isNotEmpty && currentExternalId != userId) {
      await _browserBridge.logout();
    }
    await _browserBridge.login(userId);
    _identifiedUserId = userId;
  }

  void _requireConfigured() {
    if (!isConfigured) {
      throw const OneSignalNotificationException(
        OneSignalNotificationErrorCode.setupRequired,
      );
    }
  }

  Future<void> _waitForIdentitySynchronization() async {
    try {
      await _identityQueue;
    } on Object {
      await synchronizeIdentity(_requestedUserId);
    }
  }
}
