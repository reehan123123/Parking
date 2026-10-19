import 'parking_duration.dart';

enum ParkingSessionStatus { active, expired }

/// Derived payment state for a session's parking charge.
enum ParkingPaymentStatus { unpaid, partiallyPaid, paid }

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
    this.totalCharge = 0,
    this.paidAmount = 0,
    this.contactNumber,
  });

  final String? id;
  final String? tenantId;
  final String? createdBy;
  final String plateNumber;
  final String? photoPath;
  final DateTime entryTime;
  final ParkingDuration allowedDuration;
  final DateTime expiresAt;

  /// Normalized `+91XXXXXXXXXX` mobile number for the vehicle owner or
  /// customer, or `null` when not recorded.
  final String? contactNumber;

  /// The total parking charge for this session. Zero means no charge is
  /// recorded.
  final double totalCharge;

  /// The amount actually paid so far. Always between 0 and [totalCharge].
  final double paidAmount;

  ParkingSessionStatus statusAt(DateTime currentTime) {
    return currentTime.isBefore(expiresAt)
        ? ParkingSessionStatus.active
        : ParkingSessionStatus.expired;
  }

  /// The outstanding balance still owed, never negative.
  double get remainingBalance {
    final remaining = totalCharge - paidAmount;
    return remaining > 0 ? remaining : 0;
  }

  ParkingPaymentStatus get paymentStatus {
    if (totalCharge <= 0) {
      return paidAmount > 0
          ? ParkingPaymentStatus.paid
          : ParkingPaymentStatus.unpaid;
    }
    if (paidAmount <= 0) {
      return ParkingPaymentStatus.unpaid;
    }
    if (paidAmount >= totalCharge) {
      return ParkingPaymentStatus.paid;
    }
    return ParkingPaymentStatus.partiallyPaid;
  }
}
