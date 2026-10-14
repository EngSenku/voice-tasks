import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/task.dart';
import 'cloud_ai.dart';

/// Turns spoken text into tasks with the cloud model (NVIDIA Nemotron).
///
/// The model does the whole job: it splits the sentence into tasks and works
/// out each task's day, clock time and kind. Everything below is only the
/// contract (a strict JSON schema), plus validation and normalisation of what
/// comes back so the app never shows a malformed task.
class AiTasks {
  /// Diagnostics for the debug panel.
  static String? lastRaw;
  static String? lastError;
  static int lastMs = 0;

  /// True when the cloud model is configured and ready to use.
  static bool get ready => CloudAi.configured;

  /// Extracts tasks from [text]. Returns null when the model is not configured
  /// or the call/parse failed, so the caller can show a friendly error.
  static Future<List<Task>?> parse(String text, {bool diary = false}) async {
    lastRaw = null;
    lastError = null;
    lastMs = 0;
    await CloudAi.load();
    if (!CloudAi.configured) {
      lastError = 'cloud AI not configured';
      return null;
    }
    final now = DateTime.now();
    final sw = Stopwatch()..start();
    try {
      final raw = await CloudAi.complete(prompt(diary: diary, now: now), text);
      lastMs = sw.elapsedMilliseconds;
      lastRaw = raw;
      debugPrint('[AiTasks] ${lastMs}ms: $raw');
      final tasks = tasksFromJson(raw, now: now, source: text);
      if (tasks == null) {
        lastError = 'model returned invalid JSON';
        return null;
      }
      if (tasks.isEmpty) {
        lastError = 'no tasks found in that';
        return null;
      }
      return tasks;
    } catch (e) {
      lastMs = sw.elapsedMilliseconds;
      lastError = '$e';
      debugPrint('[AiTasks] error after ${lastMs}ms: $e');
      return null;
    }
  }

  // --------------------------------------------------------------- the prompt

  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  /// The next occurrence of [weekday] strictly after [today].
  static DateTime _nextWeekday(DateTime today, int weekday) {
    var diff = (weekday - today.weekday + 7) % 7;
    if (diff == 0) diff = 7;
    return addDays(today, diff);
  }

  /// The day a bare clock time refers to: today if still ahead, else tomorrow.
  static DateTime _dayForTime(DateTime now, int minutes) =>
      minutes > now.hour * 60 + now.minute
          ? dateOnly(now)
          : addDays(dateOnly(now), 1);

  /// The system prompt. The date and the example dates are computed from [now]
  /// so the model always resolves relative days against the real today, and the
  /// example verbs are deliberately uncommon so real inputs are not pattern-
  /// matched onto an example's date.
  @visibleForTesting
  static String prompt({required bool diary, required DateTime now}) {
    final today = dateOnly(now);
    final tomorrow = addDays(today, 1);
    final friday = _nextWeekday(today, DateTime.friday);
    final monday = _nextWeekday(today, DateTime.monday);
    final nine = _iso(_dayForTime(now, 9 * 60));
    final six = _iso(_dayForTime(now, 18 * 60));
    final tToday = _iso(today), tTom = _iso(tomorrow);
    final tFri = _iso(friday), tMon = _iso(monday);
    final diaryRule = diary
        ? '\n- The person is describing their day: keep only the things they plan, want, need or must do.'
        : '';
    return '''
You convert one spoken sentence into a list of to-do tasks. Reply with ONLY a JSON object, no prose.

Today is ${_days[now.weekday - 1]}, $tToday. The local time is now ${_two(now.hour)}:${_two(now.minute)}.

Return: {"tasks":[{"title":str,"date":str|null,"time":str|null,"kind":str,"duration":int,"unsure":bool}]}
- title: short imperative phrase (2-6 words), capitalise the first letter. Drop "I", "want to", "need to" and filler ("um","like","maybe").
- date: the exact day as "YYYY-MM-DD", resolved from today. Use null ONLY for vague time ("this week", "sometime", "soon", "later") or when no time at all was said.
- If a clock time is given but no day ("at 6pm"), use today when that time is still ahead of the local time, otherwise tomorrow. The same applies to morning/afternoon/evening.
- "next week" / "next month" mean a real future day, not null.
- time: "HH:MM" 24-hour. A clock time, or a time of day (morning=09:00, noon=12:00, afternoon=15:00, evening=19:00, night=21:00). Never copy a time from another task. Otherwise null.
- kind: "deadline" only when the time is a limit ("before 5", "by friday"); a plain time ("at 6pm", "in the morning") is "fixed"; use "flexible" when there is no date and no time.
- duration: best estimate in minutes (15,20,30,45,60).
- unsure: true only if the day is genuinely ambiguous, else false.
- Split every separate activity into its own task. If one day word covers several activities, repeat that date for each, but never invent a day or a time that was not said.$diaryRule

Examples:
user: email the landlord and mail the keys tomorrow
assistant: {"tasks":[{"title":"Email the landlord","date":"$tTom","time":null,"kind":"fixed","duration":15,"unsure":false},{"title":"Mail the keys","date":"$tTom","time":null,"kind":"fixed","duration":15,"unsure":false}]}
user: jog paint and visit the museum
assistant: {"tasks":[{"title":"Jog","date":null,"time":null,"kind":"flexible","duration":30,"unsure":false},{"title":"Paint","date":null,"time":null,"kind":"flexible","duration":60,"unsure":false},{"title":"Visit the museum","date":null,"time":null,"kind":"flexible","duration":60,"unsure":false}]}
user: sharpen the knives
assistant: {"tasks":[{"title":"Sharpen the knives","date":null,"time":null,"kind":"flexible","duration":20,"unsure":false}]}
user: today sail and trim the hedge and tomorrow polish the silver and sketch
assistant: {"tasks":[{"title":"Sail","date":"$tToday","time":null,"kind":"fixed","duration":60,"unsure":false},{"title":"Trim the hedge","date":"$tToday","time":null,"kind":"fixed","duration":45,"unsure":false},{"title":"Polish the silver","date":"$tTom","time":null,"kind":"fixed","duration":30,"unsure":false},{"title":"Sketch","date":"$tTom","time":null,"kind":"fixed","duration":45,"unsure":false}]}
user: swim at 6pm
assistant: {"tasks":[{"title":"Swim","date":"$six","time":"18:00","kind":"fixed","duration":60,"unsure":false}]}
user: nudge the editor tomorrow at 5
assistant: {"tasks":[{"title":"Nudge the editor","date":"$tTom","time":"17:00","kind":"fixed","duration":15,"unsure":false}]}
user: submit the tax report by friday
assistant: {"tasks":[{"title":"Submit the tax report","date":"$tFri","time":null,"kind":"deadline","duration":60,"unsure":false}]}
user: recycle the batteries before 9am
assistant: {"tasks":[{"title":"Recycle the batteries","date":"$nine","time":"09:00","kind":"deadline","duration":15,"unsure":false}]}
user: this week tidy the shed and fix the fence
assistant: {"tasks":[{"title":"Tidy the shed","date":null,"time":null,"kind":"flexible","duration":45,"unsure":false},{"title":"Fix the fence","date":null,"time":null,"kind":"flexible","duration":60,"unsure":false}]}
user: next week renew the lease
assistant: {"tasks":[{"title":"Renew the lease","date":"$tMon","time":null,"kind":"fixed","duration":30,"unsure":false}]}
user: collect the parcel on monday
assistant: {"tasks":[{"title":"Collect the parcel","date":"$tMon","time":null,"kind":"fixed","duration":15,"unsure":false}]}
Output ONLY JSON.
user: ''';
  }

  // ------------------------------------------------------------- JSON -> tasks

  /// Parses the model's `{"tasks":[...]}` output into [Task]s, filling in and
  /// cleaning up anything the model left vague. Returns null if the JSON is not
  /// usable (so the caller can report a failure), or a possibly-empty list.
  @visibleForTesting
  static List<Task>? tasksFromJson(
    String raw, {
    required DateTime now,
    String source = '',
  }) {
    final body = extractJson(raw);
    if (body == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final items = decoded['tasks'];
    if (items is! List) return null;

    final today = dateOnly(now);
    final nowMin = now.hour * 60 + now.minute;
    // A "deadline" only exists if the sentence actually said before/by/until.
    final hasLimit =
        RegExp(r'\b(before|by|until|no later than)\b', caseSensitive: false)
            .hasMatch(source);

    final out = <Task>[];
    final seen = <String>{};
    for (final it in items) {
      if (it is! Map) continue;
      final title = (it['title'] is String) ? (it['title'] as String).trim() : '';
      if (title.isEmpty) continue;

      var date = _parseDate(it['date']);
      var minutes = _parseTime(it['time']);
      var kind = _parseKind(it['kind']);
      var unsure = it['unsure'] == true;
      final duration = _parseDuration(it['duration']);

      // --- normalise so the task is always coherent ---
      // A clock time with no day: today if still ahead, else tomorrow.
      if (date == null && minutes != null) {
        date = minutes > nowMin + 5 ? today : addDays(today, 1);
      }
      if (date == null) {
        minutes = null;
        kind = Kind.flexible;
      } else if (kind == Kind.flexible) {
        kind = Kind.fixed;
      }
      if (kind == Kind.deadline && !hasLimit) kind = Kind.fixed;
      if (date != null && date.isBefore(today)) {
        unsure = true; // the model produced a past day: flag it for review
      }

      final key = '${title.toLowerCase()}|${date?.toIso8601String()}|$minutes';
      if (!seen.add(key)) continue;
      out.add(Task.create(
        title: upperFirst(title),
        date: date,
        minutes: minutes,
        kind: kind,
        unsure: unsure,
        duration: duration,
      ));
      if (out.length >= 24) break;
    }
    return out;
  }

  static DateTime? _parseDate(Object? v) {
    if (v is! String || v.trim().isEmpty) return null;
    final d = DateTime.tryParse(v.trim());
    return d == null ? null : dateOnly(d);
  }

  static int? _parseTime(Object? v) {
    if (v is! String) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final mi = int.parse(m.group(2)!);
    if (h > 23 || mi > 59) return null;
    return h * 60 + mi;
  }

  static Kind _parseKind(Object? v) => switch (v) {
        'fixed' => Kind.fixed,
        'deadline' => Kind.deadline,
        _ => Kind.flexible,
      };

  static int _parseDuration(Object? v) {
    final n = (v is int) ? v : int.tryParse('$v');
    return (n ?? 30).clamp(5, 480);
  }

  /// The outermost balanced {...} block of [raw] (tolerates markdown fences and
  /// trailing chatter), or null if none found.
  @visibleForTesting
  static String? extractJson(String raw) {
    final start = raw.indexOf('{');
    if (start < 0) return null;
    var depth = 0, inStr = false, esc = false;
    for (var i = start; i < raw.length; i++) {
      final c = raw[i];
      if (inStr) {
        if (esc) {
          esc = false;
        } else if (c == r'\') {
          esc = true;
        } else if (c == '"') {
          inStr = false;
        }
        continue;
      }
      if (c == '"') {
        inStr = true;
      } else if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) return raw.substring(start, i + 1);
      }
    }
    return null;
  }
}
