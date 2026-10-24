import 'package:parking_management/features/maintenance/data/maintenance_mode_repository.dart';
import 'package:parking_management/features/maintenance/domain/maintenance_mode_status.dart';

class TestMaintenanceModeRepository implements MaintenanceModeRepository {
  TestMaintenanceModeRepository({
    required this.status,
    this.queuedStatuses = const [],
  });

  MaintenanceModeStatus status;
  List<MaintenanceModeStatus> queuedStatuses;
  MaintenanceModeRepositoryException? loadError;
  MaintenanceModeRepositoryException? saveError;
  int loadCalls = 0;
  int saveCalls = 0;
  DateTime? lastMaintenanceUntil;

  @override
  Future<MaintenanceModeStatus> loadStatus() async {
    loadCalls++;
    final MaintenanceModeRepositoryException? error = loadError;
    if (error != null) {
      throw error;
    }
    if (queuedStatuses.isNotEmpty) {
      status = queuedStatuses.removeAt(0);
    }
    return status;
  }

  @override
  Future<MaintenanceModeStatus> setMaintenanceUntil({
    required DateTime? until,
  }) async {
    saveCalls++;
    lastMaintenanceUntil = until;
    final MaintenanceModeRepositoryException? error = saveError;
    if (error != null) {
      throw error;
    }

    final DateTime serverTime = DateTime.now().toUtc();
    status = MaintenanceModeStatus(
      callerIsSuperAdmin: true,
      isActive: until != null && until.isAfter(serverTime),
      maintenanceUntil: until,
      serverTime: serverTime,
    );
    return status;
  }
}
