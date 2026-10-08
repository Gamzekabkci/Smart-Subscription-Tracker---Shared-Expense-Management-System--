import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<PendingNotificationRequest> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    final pending =
    await NotificationService.instance.getPendingNotifications();

    if (!mounted) return;

    setState(() {
      _notifications = pending;
      _isLoading = false;
    });
  }

  String _getNotificationType(PendingNotificationRequest notification) {
    final payload = notification.payload ?? "";

    if (payload.contains("daily_ai")) {
      return "AI Günlük Öneri";
    }

    if (payload.contains("payment")) {
      return "Ödeme Hatırlatması";
    }

    if (payload.contains("urgent_payment")) {
      return "Acil Ödeme Uyarısı";
    }

    if (payload.contains("urgent_trial")) {
      return "Deneme Süresi Uyarısı";
    }

    return "Bildirim";
  }

  IconData _getNotificationIcon(PendingNotificationRequest notification) {
    final payload = notification.payload ?? "";

    if (payload.contains("daily_ai")) {
      return Icons.psychology_rounded;
    }

    if (payload.contains("payment")) {
      return Icons.payments_rounded;
    }

    if (payload.contains("urgent_trial")) {
      return Icons.warning_amber_rounded;
    }

    return Icons.notifications_rounded;
  }

  Color _getNotificationColor(
      PendingNotificationRequest notification,
      Color primaryColor,
      ) {
    final payload = notification.payload ?? "";

    if (payload.contains("daily_ai")) {
      return primaryColor;
    }

    if (payload.contains("urgent")) {
      return Colors.redAccent;
    }

    if (payload.contains("payment")) {
      return Colors.orangeAccent;
    }

    return primaryColor;
  }

  Future<void> _refreshNotifications() async {
    await NotificationService.instance.rescheduleAll();
    await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;
    final cardColor = theme.colorScheme.surface;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          "Bildirimler",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _refreshNotifications,
            icon: Icon(
              Icons.refresh_rounded,
              color: textColor,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: primaryColor,
        ),
      )
          : RefreshIndicator(
        color: primaryColor,
        onRefresh: _refreshNotifications,
        child: _notifications.isEmpty
            ? ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 80),
            Icon(
              Icons.notifications_off_outlined,
              color: primaryColor,
              size: 70,
            ),
            const SizedBox(height: 20),
            Text(
              "Planlanmış bildirim yok",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Bildirimler açıksa abonelik eklediğinde ödeme hatırlatmaları ve günlük AI önerileri burada görünecek.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        )
            : ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final notification = _notifications[index];
            final color = _getNotificationColor(
              notification,
              primaryColor,
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      _getNotificationIcon(notification),
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getNotificationType(notification),
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification.title ?? "Bildirim",
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification.body ?? "",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}