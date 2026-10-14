import 'dart:math';

enum Kind { fixed, deadline, flexible }

const kDays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];
const kMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
int daysBetween(DateTime a, DateTime b) =>
    (dateOnly(b).difference(dateOnly(a)).inHours / 24).round();

String _two(int n) => n.toString().padLeft(2, '0');

String dayLabel(DateTime d, {DateTime? now}) {
  final diff = daysBetween(now ?? DateTime.now(), d);
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff > 1 && diff < 7) return kDays[d.weekday - 1];
  return '${kDays[d.weekday - 1].substring(0, 3)} ${d.day} ${kMonths[d.month - 1]}';
}

String fmtTime(int m) {
  final h = m ~/ 60, mm = m % 60;
  final hh = (h + 11) % 12 + 1;
  final suf = h < 12 ? 'am' : 'pm';
  return mm == 0 ? '$hh $suf' : '$hh:${_two(mm)} $suf';
}

String lowerFirst(String s) =>
    s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
String upperFirst(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class Task {
  String id;
  int nid; // notification id base
  String title;
  DateTime? date; // day only
  int? minutes; // minutes since midnight
  Kind kind;
  bool done;
  int postponed;
  int duration; // minutes
  bool unsure;
  bool autoPlaced;
  String? eventId;
  String? syncedKey;
  DateTime? completedAt;

  Task({
    required this.id,
    required this.nid,
    required this.title,
    this.date,
    this.minutes,
    this.kind = Kind.flexible,
    this.done = false,
    this.postponed = 0,
    this.duration = 30,
    this.unsure = false,
    this.autoPlaced = false,
    this.eventId,
    this.syncedKey,
    this.completedAt,
  });

  factory Task.create({
    required String title,
    DateTime? date,
    int? minutes,
    Kind kind = Kind.flexible,
    bool unsure = false,
    int duration = 30,
  }) {
    final r = Random();
    return Task(
      id: '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${r.nextInt(9999)}',
      nid: r.nextInt(100000000) + 10,
      title: title,
      date: date,
      minutes: minutes,
      kind: kind,
      unsure: unsure,
      duration: duration,
    );
  }

  DateTime? get timeAt => (date == null || minutes == null)
      ? null
      : DateTime(date!.year, date!.month, date!.day, minutes! ~/ 60, minutes! % 60);

  /// The block of time this task occupies in the calendar.
  DateTime? get blockStart => kind == Kind.deadline
      ? timeAt?.subtract(Duration(minutes: duration))
      : timeAt;
  DateTime? get blockEnd => kind == Kind.deadline
      ? timeAt
      : timeAt?.add(Duration(minutes: duration));

  /// When the first nudge should fire.
  DateTime? get remindAt {
    if (date == null) return null;
    final d = date!;
    if (minutes == null) return DateTime(d.year, d.month, d.day, 9);
    final s = timeAt!;
    if (kind == Kind.deadline) {
      final eight = DateTime(d.year, d.month, d.day, 8);
      var r = s.subtract(const Duration(hours: 2));
      if (r.isBefore(eight)) {
        r = s.isAfter(eight) ? eight : s.subtract(const Duration(minutes: 30));
      }
      return r;
    }
    return s;
  }

  String get whenLabel {
    if (date == null) return 'This week · flexible';
    final d = dayLabel(date!);
    if (minutes == null) return '$d · any time';
    final tm = fmtTime(minutes!);
    if (kind == Kind.deadline) return '$d · before $tm';
    return autoPlaced ? '$d · $tm · suggested' : '$d · $tm';
  }

  String get syncKey => '$title|${date?.toIso8601String()}|$minutes|$duration';

  Map<String, dynamic> toJson() => {
        'id': id,
        'nid': nid,
        'title': title,
        'date': date == null
            ? null
            : '${date!.year.toString().padLeft(4, '0')}-${_two(date!.month)}-${_two(date!.day)}',
        'minutes': minutes,
        'kind': kind.name,
        'done': done,
        'postponed': postponed,
        'duration': duration,
        'unsure': unsure,
        'autoPlaced': autoPlaced,
        'eventId': eventId,
        'syncedKey': syncedKey,
        'completedAt': completedAt?.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        nid: j['nid'] as int,
        title: j['title'] as String,
        date: j['date'] == null ? null : DateTime.parse(j['date'] as String),
        minutes: j['minutes'] as int?,
        kind: Kind.values.firstWhere((k) => k.name == j['kind'],
            orElse: () => Kind.fixed),
        done: j['done'] as bool? ?? false,
        postponed: j['postponed'] as int? ?? 0,
        duration: j['duration'] as int? ?? 30,
        unsure: j['unsure'] as bool? ?? false,
        autoPlaced: j['autoPlaced'] as bool? ?? false,
        eventId: j['eventId'] as String?,
        syncedKey: j['syncedKey'] as String?,
        completedAt: j['completedAt'] == null
            ? null
            : DateTime.parse(j['completedAt'] as String),
      );
}

/// Pure mutations, shared by the app and the background notification handler.
class TaskLogic {
  static void complete(Task t) {
    t.done = true;
    t.completedAt = DateTime.now();
  }

  /// "Push it to later": afternoon, then evening, then tomorrow morning.
  static void push(Task t, DateTime now) {
    final today = dateOnly(now);
    final m = now.hour * 60 + now.minute;
    if (m < 14 * 60) {
      t.date = today;
      t.minutes = 15 * 60;
    } else if (m < 19 * 60) {
      t.date = today;
      t.minutes = 19 * 60 + 30;
    } else {
      t.date = addDays(today, 1);
      t.minutes = 9 * 60;
    }
    t.postponed++;
    t.kind = Kind.fixed;
    t.autoPlaced = false;
  }

  /// Not done today: carry it over to tomorrow, same time of day.
  static void carryOver(Task t, DateTime now) {
    t.date = addDays(dateOnly(now), 1);
    t.postponed++;
    if (t.kind == Kind.deadline) t.kind = Kind.fixed;
  }
}
