import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';
import 'store.dart';

/// Runs when you tap Done / Later / Drop on a notification while the app is closed.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse r) {
  TaskStore.handleBackground(r.actionId, r.payload);
}

/// Reminders that talk like a person: a nudge, then a follow-up that asks
/// "do it now, push it, or drop it?". All local, all free.
class Notifier {
  static final Notifier i = Notifier._();
  Notifier._();

  final FlutterLocalNotificationsPlugin _p = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  static void Function(NotificationResponse)? onResponse;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    String? name;
    final sp = await SharedPreferences.getInstance();
    try {
      name = await FlutterTimezone.getLocalTimezone();
      await sp.setString('tz', name);
    } catch (_) {
      name = sp.getString('tz');
    }
    try {
      if (name != null) tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {}

    final ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory('task', actions: [
          DarwinNotificationAction.plain('done', 'Done'),
          DarwinNotificationAction.plain('push', 'Later'),
          DarwinNotificationAction.plain('drop', 'Drop'),
        ]),
      ],
    );
    await _p.initialize(
      InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: ios,
      ),
      onDidReceiveNotificationResponse: (r) => onResponse?.call(r),
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    _ready = true;
  }

  Future<void> requestPermissions() async {
    try {
      await _p
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _p
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
  }

  Future<String?> launchPayload() async {
    try {
      final d = await _p.getNotificationAppLaunchDetails();
      if (d?.didNotificationLaunchApp == true) {
        return d?.notificationResponse?.payload;
      }
    } catch (_) {}
    return null;
  }

  NotificationDetails _details(bool actions) => NotificationDetails(
        android: AndroidNotificationDetails(
          actions ? 'nudges' : 'daily',
          actions ? 'Reminders' : 'Daily rituals',
          channelDescription:
              actions ? 'Gentle nudges for your tasks' : 'Morning briefing and evening check-in',
          importance: Importance.high,
          priority: Priority.high,
          actions: actions
              ? const [
                  AndroidNotificationAction('done', 'Done',
                      cancelNotification: true, showsUserInterface: false),
                  AndroidNotificationAction('push', 'Later',
                      cancelNotification: true, showsUserInterface: false),
                  AndroidNotificationAction('drop', 'Drop',
                      cancelNotification: true, showsUserInterface: false),
                ]
              : null,
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: actions ? 'task' : null),
      );

  Future<void> _zoned(int id, String title, String body, DateTime when,
      String payload, bool actions,
      {DateTimeComponents? repeat}) async {
    try {
      await _p.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        _details(actions),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
        matchDateTimeComponents: repeat,
      );
    } catch (_) {}
  }

  Future<void> cancelTask(Task t) async {
    try {
      await _p.cancel(t.nid * 4);
      await _p.cancel(t.nid * 4 + 1);
    } catch (_) {}
  }

  Future<void> scheduleTask(Task t) async {
    await init();
    await cancelTask(t);
    if (t.done) return;
    final at = t.remindAt;
    if (at == null) return;
    final now = DateTime.now();
    final payload = 'task:${t.id}';

    if (at.isAfter(now)) {
      final body = t.kind == Kind.deadline && t.minutes != null
          ? 'Hey, this is due before ${fmtTime(t.minutes!)}.'
          : "Hey, you said you'd do this${t.minutes != null ? ' around ${fmtTime(t.minutes!)}' : ' today'}.";
      await _zoned(t.nid * 4, t.title, body, at, payload, true);
    }

    final f = at.add(const Duration(minutes: 45));
    final tooLate = t.kind == Kind.deadline && t.timeAt != null && !f.isBefore(t.timeAt!);
    if (!tooLate && f.isAfter(now)) {
      final body = t.postponed >= 3
          ? "You've moved this ${t.postponed} times. Still important, or make it smaller?"
          : 'Still open. Do it now, push it to later, or drop it?';
      await _zoned(t.nid * 4 + 1, t.title, body, f, payload, true);
    }
  }

  /// 8:00 morning briefing and 21:00 evening check-in, every day.
  Future<void> scheduleDaily() async {
    await init();
    await _daily(1, 8, 0, 'Your morning briefing', 'Twenty seconds on what matters today.', 'briefing');
    await _daily(2, 21, 0, 'How did today go?', 'Tell me what you got done.', 'checkin');
  }

  Future<void> _daily(int id, int h, int m, String title, String body, String payload) async {
    final n = DateTime.now();
    var w = DateTime(n.year, n.month, n.day, h, m);
    if (!w.isAfter(n)) w = DateTime(n.year, n.month, n.day + 1, h, m);
    await _zoned(id, title, body, w, payload, false, repeat: DateTimeComponents.time);
  }
}
