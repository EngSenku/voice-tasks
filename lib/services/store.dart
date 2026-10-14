import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import 'calendar_sync.dart';
import 'notifier.dart';

/// All tasks live on the phone (SharedPreferences). No server, no account.
class TaskStore extends ChangeNotifier {
  static final TaskStore i = TaskStore._();
  TaskStore._();

  static const _key = 'tasks_v1';
  static const _syncKey = 'sync_calendar';

  final List<Task> tasks = [];
  bool syncCalendar = true;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    tasks.clear();
    final raw = p.getString(_key);
    if (raw != null) {
      try {
        for (final j in jsonDecode(raw) as List) {
          tasks.add(Task.fromJson(Map<String, dynamic>.from(j as Map)));
        }
      } catch (_) {}
    }
    syncCalendar = p.getBool(_syncKey) ?? true;
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(tasks.map((t) => t.toJson()).toList()));
  }

  // ------------------------------------------------------------ queries

  Task? byId(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  List<Task> get open => tasks.where((t) => !t.done).toList();

  List<Task> on(DateTime day) {
    final l = tasks.where((t) => t.date != null && sameDay(t.date!, day)).toList();
    l.sort((a, b) => (a.minutes ?? 9999).compareTo(b.minutes ?? 9999));
    return l;
  }

  List<Task> get unplaced => open.where((t) => t.date == null).toList();

  List<Task> get overdue {
    final today = dateOnly(DateTime.now());
    return open.where((t) => t.date != null && t.date!.isBefore(today)).toList();
  }

  List<Task> get stuck => open.where((t) => t.postponed >= 3).toList();

  // ------------------------------------------------------------ changes

  Future<void> addAll(List<Task> ts) async {
    tasks.addAll(ts);
    await _after(ts);
  }

  Future<void> update(Task t) => _after([t]);

  Future<void> complete(Task t) async {
    TaskLogic.complete(t);
    await Notifier.i.cancelTask(t);
    await _save();
    notifyListeners();
  }

  Future<void> toggleDone(Task t) async {
    if (t.done) {
      t.done = false;
      t.completedAt = null;
      await _after([t]);
    } else {
      await complete(t);
    }
  }

  Future<void> drop(Task t) async {
    tasks.removeWhere((x) => x.id == t.id);
    await Notifier.i.cancelTask(t);
    if (syncCalendar) await CalendarSync.remove(t);
    await _save();
    notifyListeners();
  }

  Future<void> push(Task t) async {
    TaskLogic.push(t, DateTime.now());
    await _after([t]);
  }

  Future<void> carryOver(Task t) async {
    TaskLogic.carryOver(t, DateTime.now());
    await _after([t]);
  }

  Future<void> keep(Task t) async {
    t.postponed = 0;
    await _after([t]);
  }

  Future<void> makeSmaller(Task t) async {
    t.title = 'First step: ${lowerFirst(t.title)}';
    t.duration = 15;
    t.postponed = 0;
    await _after([t]);
  }

  Future<void> setSync(bool v) async {
    syncCalendar = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_syncKey, v);
    if (v) await _after(open);
    notifyListeners();
  }

  Future<void> _after(Iterable<Task> changed) async {
    await _save();
    notifyListeners();
    for (final t in changed.toList()) {
      try {
        await Notifier.i.scheduleTask(t);
        if (syncCalendar && !t.done && t.syncKey != t.syncedKey) {
          await CalendarSync.upsert(t);
        }
      } catch (_) {}
    }
    await _save();
  }

  /// Re-arm every reminder (after a reboot, a time zone change, or an app update).
  Future<void> rescheduleAll() async {
    for (final t in open) {
      await Notifier.i.scheduleTask(t);
    }
  }

  // ------------------------------------------------------------ notification buttons

  /// Done / Later / Drop pressed on a notification while the app is not running.
  static Future<void> handleBackground(String? action, String? payload) async {
    try {
      if (action == null || payload == null || !payload.startsWith('task:')) return;
      final id = payload.substring(5);
      final p = await SharedPreferences.getInstance();
      await p.reload();
      final raw = p.getString(_key);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .map((j) => Task.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
      final idx = list.indexWhere((t) => t.id == id);
      if (idx < 0) return;
      final t = list[idx];
      await Notifier.i.init();
      if (action == 'done') {
        TaskLogic.complete(t);
        await Notifier.i.cancelTask(t);
      } else if (action == 'push') {
        TaskLogic.push(t, DateTime.now());
        await Notifier.i.scheduleTask(t);
      } else if (action == 'drop') {
        list.removeAt(idx);
        await Notifier.i.cancelTask(t);
      }
      await p.setString(_key, jsonEncode(list.map((x) => x.toJson()).toList()));
    } catch (_) {}
  }
}
