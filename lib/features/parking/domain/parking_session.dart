import 'parking_duration.dart';

enum ParkingSessionStatus { active, expired }

class ParkingSession {
  const ParkingSession({
    this.id,
    this.tenantId,
    this.createdBy,
    required this.plateNumber,
    this.photoPath,
    required this.entryTime,
    required this.allowedDuration,
    required this.expiresAt,
  });

  final String? id;
  final String? tenantId;
  final String? createdBy;
  final String plateNumber;
  final String? photoPath;
  final DateTime entryTime;
  final ParkingDuration allowedDuration;
  final DateTime expiresAt;

  ParkingSessionStatus statusAt(DateTime currentTime) {
    return currentTime.isBefore(expiresAt)
        ? ParkingSessionStatus.active
        : ParkingSessionStatus.expired;
  }
}
