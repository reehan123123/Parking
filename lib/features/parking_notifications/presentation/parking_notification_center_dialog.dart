import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../domain/parking_notification.dart';
import '../domain/parking_notification_center_state.dart';

class ParkingNotificationCenterDialog extends StatelessWidget {
  const ParkingNotificationCenterDialog({
    required this.state,
    required this.onRefresh,
    required this.onOpen,
    required this.onClearAll,
    super.key,
  });

  final ValueListenable<ParkingNotificationCenterState> state;
  final Future<void> Function() onRefresh;
  final Future<void> Function(ParkingNotification notification) onOpen;
  final Future<void> Function() onClearAll;

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final double width = screenSize.width < 592 ? screenSize.width - 32 : 560;
    final double height = screenSize.height < 672
        ? screenSize.height - 32
        : 640;
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.parkingNotificationsCenterTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.commonRetry,
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: l10n.commonClose,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<ParkingNotificationCenterState>(
                valueListenable: state,
                builder: (context, snapshot, _) {
                  if (snapshot.unreadCount == 0) {
                    return const SizedBox.shrink();
                  }
                  return Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: ActionChip(
                      label: Text(l10n.parkingNotificationsClearAll),
                      onPressed: snapshot.isLoading
                          ? null
                          : () => unawaited(onClearAll()),
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ValueListenableBuilder<ParkingNotificationCenterState>(
                  valueListenable: state,
                  builder: (context, snapshot, _) {
                    final List<ParkingNotification> notifications =
                        snapshot.unreadNotifications;
                    if (snapshot.isLoading &&
                        notifications.isEmpty &&
                        snapshot.errorMessage == null) {
                      return LoadingView(
                        message: l10n.parkingNotificationsStatusLoading,
                      );
                    }
                    if (snapshot.errorMessage != null &&
                        notifications.isEmpty) {
                      return ErrorStateView(
                        message: snapshot.errorMessage!,
                        onRetry: onRefresh,
                      );
                    }
                    if (notifications.isEmpty) {
                      return EmptyStateView(
                        icon: Icons.notifications_none_outlined,
                        title: l10n.parkingNotificationsEmptyTitle,
                        message: l10n.parkingNotificationsEmptyMessage,
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (snapshot.isLoading) const LinearProgressIndicator(),
                        if (snapshot.errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            snapshot.errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.separated(
                            itemCount: notifications.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final ParkingNotification notification =
                                  notifications[index];
                              return _ParkingNotificationTile(
                                notification: notification,
                                onTap: () => unawaited(onOpen(notification)),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParkingNotificationTile extends StatelessWidget {
  const _ParkingNotificationTile({
    required this.notification,
    required this.onTap,
  });

  final ParkingNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String timestamp = DateFormat.yMMMd(l10n.localeName)
        .add_jm()
        .format(notification.lastRemindedAt.toLocal());

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Icon(
        notification.isUnread
            ? Icons.notifications_active_outlined
            : Icons.notifications_none_outlined,
        color: notification.isUnread
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        l10n.parkingNotificationExpiredTitle(notification.plateNumberPrefix),
      ),
      subtitle: Text('${l10n.parkingNotificationExpiredBody}\n$timestamp'),
      isThreeLine: true,
      trailing: notification.isUnread
          ? Icon(
              Icons.circle,
              size: 9,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: onTap,
    );
  }
}
