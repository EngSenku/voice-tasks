import 'package:flutter_test/flutter_test.dart';
import 'package:voice_tasks/models/task.dart';
import 'package:voice_tasks/services/ai.dart';

void main() {
  // Wednesday, 14 October 2026, 14:30.
  final now = DateTime(2026, 10, 14, 14, 30);

  group('prompt', () {
    test('carries the current date, time and schema', () {
      final p = AiTasks.prompt(diary: false, now: now);
      expect(p, contains('2026-10-14'));
      expect(p, contains('Wednesday'));
      expect(p, contains('14:30'));
      expect(p, contains('"tasks"'));
    });

    test('adds the diary rule only in diary mode', () {
      expect(AiTasks.prompt(diary: true, now: now), contains('describing their day'));
      expect(
          AiTasks.prompt(diary: false, now: now), isNot(contains('describing their day')));
    });
  });

  group('tasksFromJson', () {
    test('reads titles, dates, times and kinds', () {
      final tasks = AiTasks.tasksFromJson(
        '{"tasks":['
        '{"title":"Call mom","date":"2026-10-15","time":"17:00","kind":"fixed","duration":15,"unsure":false},'
        '{"title":"Study","date":null,"time":null,"kind":"flexible","duration":45,"unsure":false}'
        ']}',
        now: now,
      );
      expect(tasks, isNotNull);
      expect(tasks!.map((t) => t.title).toList(), ['Call mom', 'Study']);
      expect(tasks[0].date, DateTime(2026, 10, 15));
      expect(tasks[0].minutes, 17 * 60);
      expect(tasks[0].kind, Kind.fixed);
      expect(tasks[0].duration, 15);
      expect(tasks[1].date, isNull);
      expect(tasks[1].minutes, isNull);
      expect(tasks[1].kind, Kind.flexible);
    });

    test('tolerates markdown fences and surrounding prose', () {
      const raw = 'Sure!\n```json\n'
          '{"tasks":[{"title":"Play","date":null,"time":null,"kind":"flexible","duration":30,"unsure":false}]}\n'
          '```\nDone.';
      final tasks = AiTasks.tasksFromJson(raw, now: now);
      expect(tasks!.single.title, 'Play');
    });

    test('returns null for unusable output', () {
      expect(AiTasks.tasksFromJson('not json', now: now), isNull);
      expect(AiTasks.tasksFromJson('{"foo":1}', now: now), isNull);
      expect(AiTasks.tasksFromJson('{"tasks":"nope"}', now: now), isNull);
    });

    test('an empty task list is valid but empty', () {
      expect(AiTasks.tasksFromJson('{"tasks":[]}', now: now), isEmpty);
    });

    test('upper-cases the first letter and trims the title', () {
      final t = AiTasks.tasksFromJson(
        '{"tasks":[{"title":"  call mom  "}]}',
        now: now,
      )!.single;
      expect(t.title, 'Call mom');
    });
  });

  group('normalisation', () {
    test('a clock time with no day lands on today when still ahead', () {
      final t = AiTasks.tasksFromJson(
        '{"tasks":[{"title":"Gym","date":null,"time":"18:00","kind":"fixed","duration":60}]}',
        now: now,
      )!.single;
      expect(t.date, DateTime(2026, 10, 14));
      expect(t.minutes, 18 * 60);
    });

    test('a clock time already past lands on tomorrow', () {
      final t = AiTasks.tasksFromJson(
        '{"tasks":[{"title":"Gym","date":null,"time":"09:00","kind":"fixed","duration":60}]}',
        now: now,
      )!.single;
      expect(t.date, DateTime(2026, 10, 15));
    });

    test('a task with no date and no time is flexible', () {
      final t = AiTasks.tasksFromJson(
        '{"tasks":[{"title":"Tidy up","date":null,"time":null,"kind":"fixed"}]}',
        now: now,
      )!.single;
      expect(t.date, isNull);
      expect(t.minutes, isNull);
      expect(t.kind, Kind.flexible);
    });

    test('a dated task that came back flexible becomes fixed', () {
      final t = AiTasks.tasksFromJson(
        '{"tasks":[{"title":"Play","date":"2026-10-14","time":null,"kind":"flexible"}]}',
        now: now,
      )!.single;
      expect(t.date, DateTime(2026, 10, 14));
      expect(t.kind, Kind.fixed);
    });

    test('deadline is downgraded to fixed when no limit word was said', () {
      final t = AiTasks.tasksFromJson(
        '{"tasks":[{"title":"Pay the bill","date":"2026-10-16","kind":"deadline","duration":15}]}',
        now: now,
        source: 'pay the electricity bill on friday',
      )!.single;
      expect(t.kind, Kind.fixed);
    });

    test('a real deadline (before / by / until) survives', () {
      final t = AiTasks.tasksFromJson(
        '{"tasks":[{"title":"Submit the report","date":"2026-10-16","kind":"deadline","duration":60}]}',
        now: now,
        source: 'submit the report by friday',
      )!.single;
      expect(t.kind, Kind.deadline);
    });

    test('a day in the past is flagged unsure', () {
      final t = AiTasks.tasksFromJson(
        '{"tasks":[{"title":"Old thing","date":"2026-10-01","kind":"fixed"}]}',
        now: now,
      )!.single;
      expect(t.unsure, isTrue);
    });

    test('duration is clamped to a sane range', () {
      final t = AiTasks.tasksFromJson(
        '{"tasks":[{"title":"Marathon","date":null,"time":null,"kind":"flexible","duration":5000}]}',
        now: now,
      )!.single;
      expect(t.duration, 480);
    });

    test('duplicate tasks are dropped', () {
      final tasks = AiTasks.tasksFromJson(
        '{"tasks":['
        '{"title":"Buy milk","date":"2026-10-15","time":null,"kind":"fixed"},'
        '{"title":"buy milk","date":"2026-10-15","time":null,"kind":"fixed"}'
        ']}',
        now: now,
      );
      expect(tasks!.length, 1);
    });
  });
}
