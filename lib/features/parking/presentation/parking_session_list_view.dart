import 'package:flutter/material.dart';

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
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sessions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return Card(
          child: ListTile(
            onTap: () => onSessionTap(session),
            leading: CircleAvatar(
              child: Text(
                session.plateNumber.isEmpty
                    ? '?'
                    : session.plateNumber.substring(0, 1),
              ),
            ),
            title: Text(session.plateNumber),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Entry: ${ParkingSessionFormatters.dateTime(context, session.entryTime)}\n'
                'Expiry: ${ParkingSessionFormatters.dateTime(context, session.expiresAt)}',
              ),
            ),
            isThreeLine: true,
            trailing: ParkingSessionStatusChip(session: session),
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

  @override
  Widget build(BuildContext context) {
    final status = session.statusAt(now ?? DateTime.now());
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = status == ParkingSessionStatus.active;
    return Chip(
      avatar: Icon(
        isActive ? Icons.check_circle_outline : Icons.history,
        size: 18,
        color: isActive
            ? colorScheme.onSecondaryContainer
            : colorScheme.onSurfaceVariant,
      ),
      label: Text(isActive ? 'Active' : 'Expired'),
      backgroundColor: isActive
          ? colorScheme.secondaryContainer
          : colorScheme.surfaceContainerHighest,
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
    return '$date at $time';
  }
}
