import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/subscription_model.dart';
import 'db_helper.dart';

class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String _channelId = 'subpulse_notifications';
  static const String _channelName = 'SubPulse Bildirimleri';
  static const String _channelDescription =
      'Ödeme, deneme süresi ve AI öneri bildirimleri';

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      settings: initializationSettings,
    );

    final androidPlugin =
    _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    try {
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (_) {}

    _initialized = true;
  }

  Future<bool> notificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications') ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', enabled);

    if (enabled) {
      await rescheduleAll();
    } else {
      await cancelAll();
    }
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    await init();
    return await _notifications.pendingNotificationRequests();
  }

  NotificationDetails _notificationDetails() {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    return const NotificationDetails(
      android: androidDetails,
    );
  }

  Future<void> rescheduleAll() async {
    await init();

    final enabled = await notificationsEnabled();

    if (!enabled) {
      await cancelAll();
      return;
    }

    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      await cancelAll();
      return;
    }

    final subscriptions = await DbHelper.instance.getSubscriptionsByUser(
      currentUser.uid,
    );

    await cancelAll();

    await _scheduleDailyAiNotification(subscriptions);
    await _schedulePaymentNotifications(subscriptions);
    await _showUrgentNotificationsIfNeeded(subscriptions);
  }

  Future<void> _scheduleDailyAiNotification(
      List<Subscription> subscriptions,
      ) async {
    final now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      10,
      0,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final message = _buildDailyAiMessage(subscriptions);

    await _notifications.zonedSchedule(
      id: 1000,
      title: 'SubPulse AI Günlük Öneri',
      body: message,
      scheduledDate: scheduledDate,
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_ai',
    );
  }

  Future<void> _schedulePaymentNotifications(
      List<Subscription> subscriptions,
      ) async {
    for (final sub in subscriptions) {
      if (sub.id == null) continue;

      final nextPaymentDate = _nextPaymentDate(sub.billingDate);

      final reminders = [
        _ReminderConfig(
          suffix: 7,
          durationBefore: const Duration(days: 7),
          title: '1 hafta sonra ödeme var',
          bodyBuilder: () =>
          '${sub.name} aboneliğinin ödemesine 1 hafta kaldı.',
        ),
        _ReminderConfig(
          suffix: 3,
          durationBefore: const Duration(days: 3),
          title: '3 gün sonra ödeme var',
          bodyBuilder: () =>
          '${sub.name} aboneliğinin ödemesine 3 gün kaldı.',
        ),
        _ReminderConfig(
          suffix: 24,
          durationBefore: const Duration(hours: 24),
          title: 'Son 24 saat',
          bodyBuilder: () =>
          '${sub.name} aboneliğinin ödemesine son 24 saat kaldı.',
        ),
        _ReminderConfig(
          suffix: 5,
          durationBefore: const Duration(minutes: 5),
          title: 'Son 5 dakika',
          bodyBuilder: () =>
          '${sub.name} aboneliğinin ödemesine son 5 dakika kaldı.',
        ),
      ];

      for (final reminder in reminders) {
        final reminderDate = nextPaymentDate.subtract(
          reminder.durationBefore,
        );

        if (reminderDate.isBefore(DateTime.now())) {
          continue;
        }

        final notificationId = _notificationId(sub.id!, reminder.suffix);

        await _notifications.zonedSchedule(
          id: notificationId,
          title: reminder.title,
          body: reminder.bodyBuilder(),
          scheduledDate: _toTZDateTime(reminderDate),
          notificationDetails: _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'payment_${sub.id}_${reminder.suffix}',
        );
      }
    }
  }

  Future<void> _showUrgentNotificationsIfNeeded(
      List<Subscription> subscriptions,
      ) async {
    final now = DateTime.now();

    for (final sub in subscriptions) {
      if (sub.id == null) continue;

      final nextPaymentDate = _nextPaymentDate(sub.billingDate);
      final remaining = nextPaymentDate.difference(now);

      final paymentCycleKey =
          "${sub.id}_${nextPaymentDate.year}_${nextPaymentDate.month}_${nextPaymentDate.day}";

      if (remaining.inHours <= 24 &&
          remaining.inMinutes > 5 &&
          remaining.inMinutes > 0) {
        await _showImmediateNotificationOnce(
          onceKey: "urgent_payment_$paymentCycleKey",
          id: _notificationId(sub.id!, 91),
          title: 'Acil ödeme uyarısı',
          body: '${sub.name} ödemesine 24 saatten az kaldı.',
          payload: 'urgent_payment_${sub.id}',
        );
      }

      if (sub.isTrial && remaining.inDays <= 3 && remaining.inMinutes > 0) {
        await _showImmediateNotificationOnce(
          onceKey: "urgent_trial_$paymentCycleKey",
          id: _notificationId(sub.id!, 92),
          title: 'Deneme süresi bitiyor',
          body:
          '${sub.name} deneme süresi yakında bitiyor. Ücret başlamadan kontrol et.',
          payload: 'urgent_trial_${sub.id}',
        );
      }
    }
  }

  Future<void> _showImmediateNotificationOnce({
    required String onceKey,
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final alreadyShown = prefs.getBool(onceKey) ?? false;

    if (alreadyShown) {
      return;
    }

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _notificationDetails(),
      payload: payload,
    );

    await prefs.setBool(onceKey, true);
  }

  DateTime _nextPaymentDate(DateTime billingDate) {
    final now = DateTime.now();

    int targetDay = billingDate.day;

    final lastDayOfThisMonth = DateTime(now.year, now.month + 1, 0).day;
    if (targetDay > lastDayOfThisMonth) {
      targetDay = lastDayOfThisMonth;
    }

    DateTime next = DateTime(
      now.year,
      now.month,
      targetDay,
      9,
      0,
    );

    if (next.isBefore(now)) {
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final lastDayOfNextMonth =
          DateTime(nextMonth.year, nextMonth.month + 1, 0).day;

      int nextTargetDay = billingDate.day;
      if (nextTargetDay > lastDayOfNextMonth) {
        nextTargetDay = lastDayOfNextMonth;
      }

      next = DateTime(
        nextMonth.year,
        nextMonth.month,
        nextTargetDay,
        9,
        0,
      );
    }

    return next;
  }

  tz.TZDateTime _toTZDateTime(DateTime dateTime) {
    return tz.TZDateTime(
      tz.local,
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
      dateTime.second,
    );
  }

  int _notificationId(int subscriptionId, int suffix) {
    return subscriptionId * 100 + suffix;
  }

  String _buildDailyAiMessage(List<Subscription> subscriptions) {
    if (subscriptions.isEmpty) {
      return 'Henüz abonelik eklemedin. Aboneliklerini ekleyerek kişisel tasarruf önerileri alabilirsin.';
    }

    final now = DateTime.now();

    final trialSubs = subscriptions.where((sub) {
      if (!sub.isTrial) return false;

      final nextPayment = _nextPaymentDate(sub.billingDate);
      final remainingDays = nextPayment.difference(now).inDays;

      return remainingDays <= 3;
    }).toList();

    if (trialSubs.isNotEmpty) {
      final sub = trialSubs.first;
      return '${sub.name} deneme süren yakında bitiyor. Ücretli döneme geçmeden kontrol etmeyi unutma.';
    }

    final nearPaymentSubs = subscriptions.where((sub) {
      final nextPayment = _nextPaymentDate(sub.billingDate);
      final remainingDays = nextPayment.difference(now).inDays;

      return remainingDays <= 3;
    }).toList();

    if (nearPaymentSubs.isNotEmpty) {
      final sub = nearPaymentSubs.first;
      return '${sub.name} ödemesi yaklaşıyor. Bütçeni planlamak için bugün kontrol edebilirsin.';
    }

    final expensiveSubs = [...subscriptions];
    expensiveSubs.sort((a, b) => b.price.compareTo(a.price));

    final expensive = expensiveSubs.first;

    if (!expensive.isShared && expensive.price >= 100) {
      final sharedPrice = expensive.price / 4;

      return '${expensive.name} aboneliğini ortak kullanırsan kişi başı maliyet yaklaşık ${sharedPrice.toStringAsFixed(0)} TL olabilir.';
    }

    final totalMonthly = subscriptions.fold<double>(
      0,
          (sum, sub) {
        if (sub.isShared && sub.personCount > 0) {
          return sum + (sub.price / sub.personCount);
        }

        return sum + sub.price;
      },
    );

    return 'Bu ay aboneliklerine yaklaşık ${totalMonthly.toStringAsFixed(0)} TL harcıyorsun. Gereksiz abonelikleri kontrol ederek tasarruf edebilirsin.';
  }
}

class _ReminderConfig {
  final int suffix;
  final Duration durationBefore;
  final String title;
  final String Function() bodyBuilder;

  _ReminderConfig({
    required this.suffix,
    required this.durationBefore,
    required this.title,
    required this.bodyBuilder,
  });
}