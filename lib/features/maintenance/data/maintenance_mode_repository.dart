import '../domain/maintenance_mode_status.dart';

enum MaintenanceModeRepositoryError { loadFailed, saveFailed, invalidData }

class MaintenanceModeRepositoryException implements Exception {
  const MaintenanceModeRepositoryException(this.code);

  final MaintenanceModeRepositoryError code;
}

abstract interface class MaintenanceModeRepository {
  Future<MaintenanceModeStatus> loadStatus();

  Future<MaintenanceModeStatus> setMaintenanceUntil({required DateTime? until});
}
