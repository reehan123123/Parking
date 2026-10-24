class ParkingNotification {
  const ParkingNotification({
    required this.id,
    required this.tenantId,
    required this.sessionId,
    required this.plateNumber,
    required this.createdAt,
    required this.lastRemindedAt,
    required this.readAt,
    required this.reminderIntervalAt,
    required this.notificationType,
  });

  factory ParkingNotification.fromMap(Map<String, dynamic> row) {
    final Object? type = row['notification_type'];
    if (type != 'expired' ||
        !_isUuid(row['id']) ||
        !_isUuid(row['tenant_id']) ||
        !_isUuid(row['session_id']) ||
        row['parking_sessions'] is! Map) {
      throw const FormatException('The parking notification type is invalid.');
    }

    final Map<String, dynamic> session = Map<String, dynamic>.from(
      row['parking_sessions'] as Map,
    );
    final Object? plateNumber = session['plate_number'];
    if (plateNumber is! String ||
        plateNumber.trim().isEmpty ||
        plateNumber.length > 64) {
      throw const FormatException(
        'The parking notification registration is invalid.',
      );
    }

    return ParkingNotification(
      id: _requiredString(row, 'id'),
      tenantId: _requiredString(row, 'tenant_id'),
      sessionId: _requiredString(row, 'session_id'),
      plateNumber: plateNumber.trim(),
      createdAt: _requiredDateTime(row, 'created_at'),
      lastRemindedAt: _requiredDateTime(row, 'last_reminded_at'),
      readAt: _optionalDateTime(row, 'read_at'),
      reminderIntervalAt: _requiredDateTime(row, 'reminder_interval_at'),
      notificationType: 'expired',
    );
  }

  final String id;
  final String tenantId;
  final String sessionId;
  final String plateNumber;
  final DateTime createdAt;
  final DateTime lastRemindedAt;
  final DateTime? readAt;
  final DateTime reminderIntervalAt;
  final String notificationType;

  bool get isUnread => readAt == null;

  String get plateNumberPrefix {
    return plateNumber.length <= 7 ? plateNumber : plateNumber.substring(0, 7);
  }
}

String _requiredString(Map<String, dynamic> row, String key) {
  final Object? value = row[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('The parking notification field $key is invalid.');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> row, String key) {
  final DateTime? value = _optionalDateTime(row, key);
  if (value == null) {
    throw FormatException('The parking notification field $key is invalid.');
  }
  return value;
}

DateTime? _optionalDateTime(Map<String, dynamic> row, String key) {
  final Object? value = row[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('The parking notification field $key is invalid.');
  }
  final DateTime? dateTime = DateTime.tryParse(value);
  if (dateTime == null) {
    throw FormatException('The parking notification field $key is invalid.');
  }
  return dateTime;
}

bool _isUuid(Object? value) {
  return value is String &&
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(value);
}
