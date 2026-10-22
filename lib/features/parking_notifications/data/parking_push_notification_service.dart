import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'push_browser_bridge.dart';

enum ParkingPushAvailability {
  ready,
  setupRequired,
  unsupported,
  permissionBlocked,
}

enum ParkingPushErrorCode {
  setupRequired,
  unsupported,
  permissionDenied,
  endpointInUse,
  subscriptionLimitReached,
  permissionRevoked,
  requestFailed,
}

class ParkingPushNotificationStatus {
  const ParkingPushNotificationStatus({
    required this.availability,
    this.isEnabled = false,
  });

  final ParkingPushAvailability availability;
  final bool isEnabled;
}

class ParkingPushNotificationException implements Exception {
  const ParkingPushNotificationException(this.code);

  final ParkingPushErrorCode code;
}

class ParkingPushNotificationService {
  ParkingPushNotificationService({
    required SupabaseClient supabaseClient,
    required String applicationServerKey,
    PushBrowserBridge? browserBridge,
  }) : _client = supabaseClient,
       _applicationServerKey = applicationServerKey.trim(),
       _browserBridge = browserBridge ?? createPushBrowserBridge();

  final SupabaseClient _client;
  final String _applicationServerKey;
  final PushBrowserBridge _browserBridge;

  bool get isConfigured => _isValidApplicationServerKey(_applicationServerKey);

  void clearLaunchParameters() {
    _browserBridge.clearLaunchParameters();
  }

  Future<void> enable({required String localeCode}) async {
    _requireAvailable();
    _requireSignedIn();

    try {
      final subscriptionJson = await _browserBridge.subscribe(
        _applicationServerKey,
      );
      final subscription = _parseSubscription(subscriptionJson);
      final Object? subscriptionId = await _client.rpc(
        'register_parking_push_subscription',
        params: {
          'p_endpoint': subscription.endpoint,
          'p_p256dh_key': subscription.p256dhKey,
          'p_auth_key': subscription.authKey,
          'p_locale': localeCode == 'hi' ? 'hi' : 'en',
        },
      );
      if (subscriptionId is! String || !_isUuid(subscriptionId)) {
        throw const ParkingPushNotificationException(
          ParkingPushErrorCode.requestFailed,
        );
      }
    } on ParkingPushNotificationException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _exceptionFor(error);
    } on Exception {
      throw const ParkingPushNotificationException(
        ParkingPushErrorCode.requestFailed,
      );
    }
  }

  Future<void> disable() async {
    _requireAvailable();
    _requireSignedIn();

    try {
      final subscriptionJson = await _browserBridge.getSubscriptionJson();
      final String? endpoint = subscriptionJson.isEmpty
          ? null
          : _parseSubscription(subscriptionJson).endpoint;

      if (endpoint != null) {
        await _client
            .from('parking_push_subscriptions')
            .delete()
            .eq('endpoint', endpoint);
      }
      await _browserBridge.unsubscribe();
    } on ParkingPushNotificationException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _exceptionFor(error);
    } on Exception {
      throw const ParkingPushNotificationException(
        ParkingPushErrorCode.requestFailed,
      );
    }
  }

  Future<ParkingPushNotificationStatus> loadStatus() async {
    if (!isConfigured) {
      return const ParkingPushNotificationStatus(
        availability: ParkingPushAvailability.setupRequired,
      );
    }
    if (!_browserBridge.isSupported) {
      return const ParkingPushNotificationStatus(
        availability: ParkingPushAvailability.unsupported,
      );
    }
    if (_browserBridge.permission == 'denied') {
      return const ParkingPushNotificationStatus(
        availability: ParkingPushAvailability.permissionBlocked,
      );
    }
    if (_client.auth.currentUser == null) {
      throw const ParkingPushNotificationException(
        ParkingPushErrorCode.permissionRevoked,
      );
    }

    try {
      final subscriptionJson = await _browserBridge.getSubscriptionJson();
      if (subscriptionJson.isEmpty) {
        return const ParkingPushNotificationStatus(
          availability: ParkingPushAvailability.ready,
        );
      }

      final subscription = _parseSubscription(subscriptionJson);
      final Map<String, dynamic>? registration = await _client
          .from('parking_push_subscriptions')
          .select('id')
          .eq('endpoint', subscription.endpoint)
          .maybeSingle();
      return ParkingPushNotificationStatus(
        availability: ParkingPushAvailability.ready,
        isEnabled: registration != null,
      );
    } on ParkingPushNotificationException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _exceptionFor(error);
    } on Exception {
      throw const ParkingPushNotificationException(
        ParkingPushErrorCode.requestFailed,
      );
    }
  }

  void _requireAvailable() {
    if (!isConfigured) {
      throw const ParkingPushNotificationException(
        ParkingPushErrorCode.setupRequired,
      );
    }
    if (!_browserBridge.isSupported) {
      throw const ParkingPushNotificationException(
        ParkingPushErrorCode.unsupported,
      );
    }
    if (_browserBridge.permission == 'denied') {
      throw const ParkingPushNotificationException(
        ParkingPushErrorCode.permissionDenied,
      );
    }
  }

  void _requireSignedIn() {
    if (_client.auth.currentUser == null) {
      throw const ParkingPushNotificationException(
        ParkingPushErrorCode.permissionRevoked,
      );
    }
  }

  ParkingPushNotificationException _exceptionFor(PostgrestException error) {
    if (error.message.contains('PUSH_ENDPOINT_IN_USE')) {
      return const ParkingPushNotificationException(
        ParkingPushErrorCode.endpointInUse,
      );
    }
    if (error.message.contains('PUSH_SUBSCRIPTION_LIMIT_REACHED')) {
      return const ParkingPushNotificationException(
        ParkingPushErrorCode.subscriptionLimitReached,
      );
    }
    if (error.code == '42501') {
      return const ParkingPushNotificationException(
        ParkingPushErrorCode.permissionRevoked,
      );
    }
    return const ParkingPushNotificationException(
      ParkingPushErrorCode.requestFailed,
    );
  }

  _ParsedPushSubscription _parseSubscription(String value) {
    final Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      throw const ParkingPushNotificationException(
        ParkingPushErrorCode.requestFailed,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ParkingPushNotificationException(
        ParkingPushErrorCode.requestFailed,
      );
    }

    final Object? endpointValue = decoded['endpoint'];
    final Object? keysValue = decoded['keys'];
    if (endpointValue is! String || keysValue is! Map<String, dynamic>) {
      throw const ParkingPushNotificationException(
        ParkingPushErrorCode.requestFailed,
      );
    }
    final Object? p256dhValue = keysValue['p256dh'];
    final Object? authValue = keysValue['auth'];
    if (p256dhValue is! String || authValue is! String) {
      throw const ParkingPushNotificationException(
        ParkingPushErrorCode.requestFailed,
      );
    }

    return _ParsedPushSubscription(
      endpoint: endpointValue,
      p256dhKey: p256dhValue,
      authKey: authValue,
    );
  }

  bool _isValidApplicationServerKey(String value) {
    if (value.isEmpty) {
      return false;
    }
    try {
      final Uint8List key = base64Url.decode(value);
      return key.length == 65 && key.first == 4;
    } on FormatException {
      return false;
    }
  }

  bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);
  }
}

class _ParsedPushSubscription {
  const _ParsedPushSubscription({
    required this.endpoint,
    required this.p256dhKey,
    required this.authKey,
  });

  final String endpoint;
  final String p256dhKey;
  final String authKey;
}
