import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/maintenance/domain/maintenance_mode_status.dart';

void main() {
  test('parses an active server status and its remaining duration', () {
    final MaintenanceModeStatus status = MaintenanceModeStatus.fromMap({
      'caller_is_super_admin': false,
      'maintenance_active': true,
      'maintenance_until': '2026-10-24T12:15:00Z',
      'server_time': '2026-10-24T12:00:00Z',
    });

    expect(status.callerIsSuperAdmin, isFalse);
    expect(status.isActive, isTrue);
    expect(status.remainingUntilMaintenanceEnds, const Duration(minutes: 15));
  });

  test('rejects an active status without a future end time', () {
    expect(
      () => MaintenanceModeStatus.fromMap({
        'caller_is_super_admin': false,
        'maintenance_active': true,
        'maintenance_until': '2026-10-24T11:59:00Z',
        'server_time': '2026-10-24T12:00:00Z',
      }),
      throwsFormatException,
    );
  });
}
