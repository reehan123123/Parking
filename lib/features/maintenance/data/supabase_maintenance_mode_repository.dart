import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/maintenance_mode_status.dart';
import 'maintenance_mode_repository.dart';

class SupabaseMaintenanceModeRepository implements MaintenanceModeRepository {
  SupabaseMaintenanceModeRepository(SupabaseClient client) : _client = client;

  final SupabaseClient _client;

  @override
  Future<MaintenanceModeStatus> loadStatus() async {
    try {
      final Object? result = await _client.rpc('get_platform_maintenance_mode');
      return _parseStatus(result);
    } on MaintenanceModeRepositoryException {
      rethrow;
    } on PostgrestException {
      throw const MaintenanceModeRepositoryException(
        MaintenanceModeRepositoryError.loadFailed,
      );
    } on FormatException {
      throw const MaintenanceModeRepositoryException(
        MaintenanceModeRepositoryError.invalidData,
      );
    } on Exception {
      throw const MaintenanceModeRepositoryException(
        MaintenanceModeRepositoryError.loadFailed,
      );
    }
  }

  @override
  Future<MaintenanceModeStatus> setMaintenanceUntil({
    required DateTime? until,
  }) async {
    try {
      final Object? result = await _client.rpc(
        'set_platform_maintenance_mode',
        params: {'p_maintenance_until': until?.toUtc().toIso8601String()},
      );
      return _parseStatus(result);
    } on MaintenanceModeRepositoryException {
      rethrow;
    } on PostgrestException {
      throw const MaintenanceModeRepositoryException(
        MaintenanceModeRepositoryError.saveFailed,
      );
    } on FormatException {
      throw const MaintenanceModeRepositoryException(
        MaintenanceModeRepositoryError.invalidData,
      );
    } on Exception {
      throw const MaintenanceModeRepositoryException(
        MaintenanceModeRepositoryError.saveFailed,
      );
    }
  }

  MaintenanceModeStatus _parseStatus(Object? result) {
    if (result is! List || result.length != 1 || result.first is! Map) {
      throw const MaintenanceModeRepositoryException(
        MaintenanceModeRepositoryError.invalidData,
      );
    }

    try {
      return MaintenanceModeStatus.fromMap(
        Map<String, dynamic>.from(result.single as Map),
      );
    } on FormatException {
      throw const MaintenanceModeRepositoryException(
        MaintenanceModeRepositoryError.invalidData,
      );
    }
  }
}
