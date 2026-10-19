import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/parking_session.dart';

class ParkingSessionListView extends StatelessWidget {
  const ParkingSessionListView({
    required this.sessions,
    required this.onSessionTap,
    super.key,
  });

  final List<ParkingSession> sessions;
  final ValueChanged<ParkingSession> onSessionTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sessions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return Card(
          child: InkWell(
            onTap: () => onSessionTap(session),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    child: Text(
                      session.plateNumber.isEmpty
                          ? '?'
                          : session.plateNumber.substring(0, 1),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.plateNumber,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.sessionEntryExpiryTemplate(
                            ParkingSessionFormatters.dateTime(
                              context,
                              session.entryTime,
                            ),
                            ParkingSessionFormatters.dateTime(
                              context,
                              session.expiresAt,
                            ),
                          ),
                        ),
                        if (session.contactNumber != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            l10n.contactLineTemplate(session.contactNumber!),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        if (session.totalCharge > 0) ...[
                          const SizedBox(height: 8),
                          ParkingPaymentStatusChip(session: session),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ParkingSessionStatusChip(session: session),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ParkingSessionStatusChip extends StatelessWidget {
  const ParkingSessionStatusChip({required this.session, this.now, super.key});

  final ParkingSession session;
  final DateTime? now;

  /// Returns how far an active session has progressed through its allowed
  /// duration, as a value clamped to `[0, 1]`. A zero-length or already
  /// elapsed window reports `1` (treated as fully elapsed).
  static double elapsedFraction(ParkingSession session, DateTime now) {
    final totalMs = session.expiresAt
        .difference(session.entryTime)
        .inMilliseconds;
    if (totalMs <= 0) {
      return 1;
    }
    final elapsedMs = now.difference(session.entryTime).inMilliseconds;
    return (elapsedMs / totalMs).clamp(0, 1).toDouble();
  }

  /// Steps the elapsed-duration fraction into a traffic-light color band
  /// that shifts every 30% of the allowed duration: green, amber, deep
  /// orange, then red as the session approaches or passes expiry.
  static Color activeBandColor(double elapsedFraction) {
    if (elapsedFraction < 0.3) {
      return Colors.green.shade600;
    }
    if (elapsedFraction < 0.6) {
      return Colors.amber.shade700;
    }
    if (elapsedFraction < 0.9) {
      return Colors.deepOrange.shade600;
    }
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedNow = now ?? DateTime.now();
    final status = session.statusAt(resolvedNow);
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = status == ParkingSessionStatus.active;
    final activeColor = isActive
        ? activeBandColor(elapsedFraction(session, resolvedNow))
        : null;
    final l10n = AppLocalizations.of(context);
    return Chip(
      avatar: Icon(
        isActive ? Icons.check_circle_outline : Icons.history,
        size: 18,
        color: isActive ? Colors.white : colorScheme.onSurfaceVariant,
      ),
      label: Text(
        isActive ? l10n.commonActive : l10n.commonExpired,
        style: isActive ? const TextStyle(color: Colors.white) : null,
      ),
      backgroundColor: isActive
          ? activeColor
          : colorScheme.surfaceContainerHighest,
    );
  }
}

class ParkingPaymentStatusChip extends StatelessWidget {
  const ParkingPaymentStatusChip({required this.session, super.key});

  final ParkingSession session;

  @override
  Widget build(BuildContext context) {
    final status = session.paymentStatus;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final (label, icon) = switch (status) {
      ParkingPaymentStatus.paid => (
        l10n.historyFilterPaid,
        Icons.check_circle_outline,
      ),
      ParkingPaymentStatus.partiallyPaid => (
        l10n.historyFilterPartiallyPaid,
        Icons.hourglass_bottom_outlined,
      ),
      ParkingPaymentStatus.unpaid => (
        l10n.historyFilterUnpaid,
        Icons.error_outline,
      ),
    };
    final backgroundColor = switch (status) {
      ParkingPaymentStatus.paid => colorScheme.secondaryContainer,
      ParkingPaymentStatus.partiallyPaid => colorScheme.tertiaryContainer,
      ParkingPaymentStatus.unpaid => colorScheme.errorContainer,
    };
    return Tooltip(
      message: l10n.paymentTooltipTemplate(
        ParkingSessionFormatters.currency(session.totalCharge),
        ParkingSessionFormatters.currency(session.paidAmount),
        ParkingSessionFormatters.currency(session.remainingBalance),
      ),
      child: Chip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        backgroundColor: backgroundColor,
      ),
    );
  }
}

class ParkingSessionFormatters {
  const ParkingSessionFormatters._();

  static String dateTime(BuildContext context, DateTime value) {
    final localValue = value.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(localValue);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localValue),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return AppLocalizations.of(context).dateTimeAtTemplate(date, time);
  }

  static String currency(double value) {
    return '₹${value.toStringAsFixed(2)}';
  }
}
