import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/parking_notification.dart';

enum ParkingNotificationRepositoryError {
  tenantUnavailable,
  loadFailed,
  invalidData,
  markReadFailed,
  clearAllFailed,
}

class ParkingNotificationRepositoryException implements Exception {
  const ParkingNotificationRepositoryException(this.code);

  final ParkingNotificationRepositoryError code;
}

abstract interface class ParkingNotificationRepository {
  Future<List<ParkingNotification>> listActive({required String tenantId});

  Future<void> markRead({required String notificationId});

  Future<void> clearAll({required String tenantId});
}

class SupabaseParkingNotificationRepository
    implements ParkingNotificationRepository {
  SupabaseParkingNotificationRepository(SupabaseClient client)
    : _client = client;

  static const int maximumNotifications = 50;
  static const String _notificationColumns =
      'id,tenant_id,session_id,notification_type,created_at,'
      'last_reminded_at,reminder_interval_at,read_at,'
      'parking_sessions(plate_number)';

  final SupabaseClient _client;

  @override
  Future<List<ParkingNotification>> listActive({
    required String tenantId,
  }) async {
    if (!_isUuid(tenantId)) {
      throw const ParkingNotificationRepositoryException(
        ParkingNotificationRepositoryError.tenantUnavailable,
      );
    }

    try {
      final List<dynamic> rows = await _client
          .from('parking_in_app_notifications')
          .select(_notificationColumns)
          .eq('tenant_id', tenantId)
          .isFilter('resolved_at', null)
          .order('last_reminded_at', ascending: false)
          .limit(maximumNotifications);
      return rows
          .map(
            (row) => ParkingNotification.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException {
      throw const ParkingNotificationRepositoryException(
        ParkingNotificationRepositoryError.loadFailed,
      );
    } on FormatException {
      throw const ParkingNotificationRepositoryException(
        ParkingNotificationRepositoryError.invalidData,
      );
    } on Exception {
      throw const ParkingNotificationRepositoryException(
        ParkingNotificationRepositoryError.loadFailed,
      );
    }
  }

  @override
  Future<void> markRead({required String notificationId}) async {
    if (!_isUuid(notificationId)) {
      throw const ParkingNotificationRepositoryException(
        ParkingNotificationRepositoryError.tenantUnavailable,
      );
    }

    try {
      final Object? result = await _client.rpc(
        'mark_parking_in_app_notification_read',
        params: {'p_notification_id': notificationId},
      );
      if (result != true) {
        throw const ParkingNotificationRepositoryException(
          ParkingNotificationRepositoryError.tenantUnavailable,
        );
      }
    } on ParkingNotificationRepositoryException {
      rethrow;
    } on PostgrestException {
      throw const ParkingNotificationRepositoryException(
        ParkingNotificationRepositoryError.markReadFailed,
      );
    } on Exception {
      throw const ParkingNotificationRepositoryException(
        ParkingNotificationRepositoryError.markReadFailed,
      );
    }
  }

  @override
  Future<void> clearAll({required String tenantId}) async {
    if (!_isUuid(tenantId)) {
      throw const ParkingNotificationRepositoryException(
        ParkingNotificationRepositoryError.tenantUnavailable,
      );
    }

    try {
      await _client.rpc(
        'mark_all_parking_in_app_notifications_read',
        params: {'p_tenant_id': tenantId},
      );
    } on PostgrestException {
      throw const ParkingNotificationRepositoryException(
        ParkingNotificationRepositoryError.clearAllFailed,
      );
    } on Exception {
      throw const ParkingNotificationRepositoryException(
        ParkingNotificationRepositoryError.clearAllFailed,
      );
    }
  }

  bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);
  }
}
