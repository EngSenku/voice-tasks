import '../models/task.dart';

class Slot {
  final DateTime day;
  final int minutes;
  Slot(this.day, this.minutes);
}

/// The "smart calendar": places flexible tasks, spots overlaps and packed days.
class Scheduler {
  static int load(List<Task> ex, DateTime day) => ex
      .where((t) => !t.done && t.date != null && sameDay(t.date!, day))
      .length;

  static bool overlap(Task a, Task b) {
    final as = a.blockStart, ae = a.blockEnd, bs = b.blockStart, be = b.blockEnd;
    if (as == null || ae == null || bs == null || be == null) return false;
    return as.isBefore(be) && bs.isBefore(ae);
  }

  static Task? conflict(Task t, List<Task> ex) {
    for (final o in ex) {
      if (o.done || o.id == t.id) continue;
      if (overlap(t, o)) return o;
    }
    return null;
  }

  static bool packed(Task t, List<Task> ex) =>
      t.date != null &&
      ex
              .where((o) =>
                  !o.done &&
                  o.id != t.id &&
                  o.date != null &&
                  sameDay(o.date!, t.date!))
              .length >=
          4;

  static List<DateTime> weekDays(DateTime now) {
    final today = dateOnly(now);
    final end = addDays(today, 7 - today.weekday); // Sunday
    var list = <DateTime>[];
    for (var d = today; !d.isAfter(end); d = addDays(d, 1)) {
      list.add(d);
    }
    if (list.length < 2) {
      list = [for (var i = 0; i < 7; i++) addDays(today, i)];
    }
    return list;
  }

  static List<DateTime> byLoad(List<DateTime> days, List<Task> ex) {
    final l = [...days];
    l.sort((a, b) {
      final c = load(ex, a).compareTo(load(ex, b));
      return c != 0 ? c : a.compareTo(b);
    });
    return l;
  }

  static Slot? findSlot(Task t, List<Task> ex, List<DateTime> days,
      {int prefer = 600, DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = dateOnly(n);
    final dur = t.duration;
    final int pref = prefer.clamp(8 * 60, 20 * 60).toInt();
    for (final day in days) {
      final busy = ex
          .where((o) =>
              !o.done &&
              o.id != t.id &&
              o.date != null &&
              sameDay(o.date!, day) &&
              o.blockStart != null)
          .toList();
      final starts = <int>[];
      for (var m = pref; m <= 20 * 60; m += 30) {
        starts.add(m);
      }
      for (var m = 8 * 60; m < pref; m += 30) {
        starts.add(m);
      }
      for (final m in starts) {
        if (m + dur > 22 * 60) continue;
        if (sameDay(day, today) && m < n.hour * 60 + n.minute + 30) continue;
        final s = DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);
        final e = s.add(Duration(minutes: dur));
        final clash =
            busy.any((o) => s.isBefore(o.blockEnd!) && o.blockStart!.isBefore(e));
        if (!clash) return Slot(day, m);
      }
    }
    return null;
  }

  /// Where to move a task that overlaps or sits on a packed day.
  static Slot? alternative(Task t, List<Task> ex, {int prefer = 600}) {
    final base = t.date!;
    final days = <DateTime>[];
    if (!packed(t, ex)) days.add(base);
    for (var i = 1; i <= 6; i++) {
      days.add(addDays(base, i));
    }
    return findSlot(t, ex, days, prefer: t.minutes ?? prefer);
  }
}
