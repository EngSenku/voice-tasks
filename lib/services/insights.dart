import '../models/task.dart';
import 'store.dart';

/// Streaks, patterns, and the morning briefing text.
class Insights {
  static int streak(List<Task> ts) {
    final days = ts
        .where((t) => t.completedAt != null)
        .map((t) => dateOnly(t.completedAt!))
        .toSet();
    var d = dateOnly(DateTime.now());
    if (!days.contains(d)) d = addDays(d, -1);
    var n = 0;
    while (days.contains(d)) {
      n++;
      d = addDays(d, -1);
    }
    return n;
  }

  static List<DateTime> _completions(List<Task> ts) =>
      ts.where((t) => t.completedAt != null).map((t) => t.completedAt!).toList();

  /// The hour (in minutes) when you usually finish things. Default 10 am.
  static int preferredMinutes(List<Task> ts) {
    final c = _completions(ts);
    if (c.length < 5) return 10 * 60;
    final hist = List<int>.filled(24, 0);
    for (final d in c) {
      hist[d.hour]++;
    }
    var best = 10;
    for (var h = 0; h < 24; h++) {
      if (hist[h] > hist[best]) best = h;
    }
    return best.clamp(8, 20).toInt() * 60;
  }

  static String? pattern(List<Task> ts) {
    final c = _completions(ts);
    if (c.length < 5) return null;
    final am = c.where((d) => d.hour < 12).length;
    final pm = c.where((d) => d.hour >= 12 && d.hour < 17).length;
    final eve = c.length - am - pm;
    final top = [am, pm, eve].reduce((a, b) => a > b ? a : b);
    if (top / c.length < 0.5) return null;
    if (top == am) return 'You finish most tasks before noon.';
    if (top == pm) return 'You get the most done in the afternoon.';
    return 'You do your best work in the evening.';
  }

  static String briefing(TaskStore s) {
    final now = DateTime.now();
    final g = now.hour < 12
        ? 'Good morning'
        : now.hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    final today = s.on(now).where((t) => !t.done).toList();
    final late = s.overdue.length;
    final b = StringBuffer('$g. ');
    if (today.isEmpty && late == 0) {
      b.write('Nothing is planned today. Enjoy the space.');
    } else {
      if (today.isNotEmpty) {
        b.write('You have ${today.length} ${today.length == 1 ? 'task' : 'tasks'} today. ');
        for (var i = 0; i < today.length && i < 4; i++) {
          final t = today[i];
          b.write(i == 0 ? 'First, ' : 'Then, ');
          if (t.minutes != null) {
            b.write(t.kind == Kind.deadline ? 'before ' : 'at ');
            b.write('${fmtTime(t.minutes!)}, ');
          }
          b.write('${lowerFirst(t.title)}. ');
        }
        if (today.length > 4) b.write('And ${today.length - 4} more. ');
      }
      if (late > 0) {
        b.write('Also, $late from earlier ${late == 1 ? 'still needs' : 'still need'} attention.');
      }
    }
    return b.toString();
  }
}
