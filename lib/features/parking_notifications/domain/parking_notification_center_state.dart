import 'parking_notification.dart';

class ParkingNotificationCenterState {
  const ParkingNotificationCenterState({
    this.notifications = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<ParkingNotification> notifications;
  final bool isLoading;
  final String? errorMessage;

  int get unreadCount =>
      notifications.where((notification) => notification.isUnread).length;
}
