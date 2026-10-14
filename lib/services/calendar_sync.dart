import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';

/// Writes tasks into the phone's own calendar. Free, no server.
class CalendarSync {
  static final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();
  static String? _calId;

  static Future<bool> ensure() async {
    try {
      final has = await _plugin.hasPermissions();
      if (!(has.isSuccess && (has.data ?? false))) {
        final r = await _plugin.requestPermissions();
        if (!(r.isSuccess && (r.data ?? false))) return false;
      }
      if (_calId != null) return true;
      final cals = await _plugin.retrieveCalendars();
      final list = (cals.data ?? []).where((c) => !(c.isReadOnly ?? true)).toList();
      if (list.isEmpty) return false;
      final def = list.firstWhere((c) => c.isDefault ?? false, orElse: () => list.first);
      _calId = def.id;
      return _calId != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> upsert(Task t) async {
    try {
      if (t.date == null || !await ensure()) return;
      final s = t.blockStart;
      final allDay = s == null;
      final start = allDay ? t.date! : s;
      final end = allDay ? addDays(t.date!, 1) : t.blockEnd!;
      final ev = Event(
        _calId,
        eventId: t.eventId,
        title: t.title,
        description: 'Added by Voice Tasks',
        start: tz.TZDateTime.from(start, tz.local),
        end: tz.TZDateTime.from(end, tz.local),
        allDay: allDay,
      );
      final r = await _plugin.createOrUpdateEvent(ev);
      if (r != null && r.isSuccess && r.data != null) {
        t.eventId = r.data;
        t.syncedKey = t.syncKey;
      }
    } catch (_) {}
  }

  static Future<void> remove(Task t) async {
    try {
      if (t.eventId == null || !await ensure()) return;
      await _plugin.deleteEvent(_calId, t.eventId);
    } catch (_) {}
  }
}
