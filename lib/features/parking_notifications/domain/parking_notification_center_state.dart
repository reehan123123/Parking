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

  List<ParkingNotification> get unreadNotifications => notifications
      .where((notification) => notification.isUnread)
      .toList(growable: false);

  int get unreadCount => unreadNotifications.length;
}
