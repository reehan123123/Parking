class MaintenanceModeStatus {
  const MaintenanceModeStatus({
    required this.callerIsSuperAdmin,
    required this.isActive,
    required this.maintenanceUntil,
    required this.serverTime,
  });

  final bool callerIsSuperAdmin;
  final bool isActive;
  final DateTime? maintenanceUntil;
  final DateTime serverTime;

  Duration? get remainingUntilMaintenanceEnds {
    if (!isActive || maintenanceUntil == null) {
      return null;
    }

    return maintenanceUntil!.difference(serverTime);
  }

  factory MaintenanceModeStatus.fromMap(Map<String, dynamic> map) {
    final Object? callerIsSuperAdmin = map['caller_is_super_admin'];
    final Object? isActive = map['maintenance_active'];
    final Object? untilValue = map['maintenance_until'];
    final Object? serverTimeValue = map['server_time'];

    if (callerIsSuperAdmin is! bool ||
        isActive is! bool ||
        serverTimeValue is! String) {
      throw const FormatException('Maintenance status is invalid.');
    }

    final DateTime serverTime = _parseTimestamp(serverTimeValue);
    final DateTime? maintenanceUntil;
    if (untilValue == null) {
      maintenanceUntil = null;
    } else if (untilValue is String) {
      maintenanceUntil = _parseTimestamp(untilValue);
    } else {
      throw const FormatException('Maintenance end time is invalid.');
    }

    if (isActive &&
        (maintenanceUntil == null || !maintenanceUntil.isAfter(serverTime))) {
      throw const FormatException('Active maintenance has no future end time.');
    }

    return MaintenanceModeStatus(
      callerIsSuperAdmin: callerIsSuperAdmin,
      isActive: isActive,
      maintenanceUntil: maintenanceUntil,
      serverTime: serverTime,
    );
  }

  static DateTime _parseTimestamp(String value) {
    final DateTime? timestamp = DateTime.tryParse(value);
    if (timestamp == null) {
      throw const FormatException('Maintenance timestamp is invalid.');
    }
    return timestamp.toUtc();
  }
}
