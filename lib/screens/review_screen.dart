import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';
import '../services/insights.dart';
import '../services/ai.dart';
import '../services/scheduler.dart';
import '../services/speech.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/mic_button.dart';
import 'calendar_screen.dart';

/// Validation: two actions only. Re-say one task by voice, or "Looks good".
class ReviewScreen extends StatefulWidget {
  final List<Task> tasks;
  final String transcript;
  const ReviewScreen({super.key, required this.tasks, required this.transcript});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _speech = SpeechService();
  final _store = TaskStore.i;
  late final List<Task> _tasks = [...widget.tasks];
  String? _activeId;
  String _partial = '';
  bool _busy = false, _stopping = false;
  Future<bool>? _starting;

  void _start(Task t) {
    if (_activeId != null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _activeId = t.id;
      _partial = '';
    });
    _starting = _speech.start((s) {
      if (mounted) setState(() => _partial = s);
    }, long: true);
    _starting!.then((ok) {
      if (!ok && mounted) {
        setState(() => _activeId = null);
        _toast('Microphone unavailable');
      }
    });
  }

  Future<void> _stop(Task t) async {
    if (_activeId != t.id || _stopping) return;
    _stopping = true;
    final ok = await (_starting ?? Future.value(true));
    if (!ok) {
      _stopping = false;
      return;
    }
    final text = await _speech.stop();
    _stopping = false;
    if (!mounted) return;
    setState(() => _activeId = null);
    if (text.isEmpty) {
      _toast('Hold the mic while you speak');
      return;
    }
    final tasks = await AiTasks.parse(text, diary: false);
    if (!mounted) return;
    if (tasks == null || tasks.isEmpty) {
      _toast("Couldn't read that, try again");
      return;
    }
    final f = tasks.first;
    setState(() {
      t.title = f.title;
      t.duration = f.duration;
      t.date = f.date;
      t.minutes = f.minutes;
      t.kind = f.kind;
      t.unsure = f.unsure;
    });
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(m, style: t(14)),
      backgroundColor: C.panel,
      behavior: SnackBarBehavior.floating,
    ));

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final all = _store.tasks;
    final existing = all.where((x) => !x.done).toList();
    final prefer = Insights.preferredMinutes(all);
    final notes = <String>[];
    final accepted = <Task>[];

    // 1. Flexible tasks get a slot on your lightest day, at your best hour.
    for (final t in _tasks.where((x) => x.date == null)) {
      final days = Scheduler.byLoad(Scheduler.weekDays(DateTime.now()), [...existing, ...accepted]);
      final s = Scheduler.findSlot(t, [...existing, ...accepted], days, prefer: prefer);
      if (s != null) {
        t.date = s.day;
        t.minutes = s.minutes;
        t.autoPlaced = true;
        notes.add("'${t.title}' → ${dayLabel(s.day)}, ${fmtTime(s.minutes)}");
      }
      accepted.add(t);
    }

    // 2. Overlaps and packed days: offer a better slot.
    for (final t in _tasks.where((x) => !x.autoPlaced && x.date != null)) {
      if (t.kind != Kind.deadline) {
        final pool = [...existing, ...accepted];
        final clash = Scheduler.conflict(t, pool);
        final isPacked = clash == null && Scheduler.packed(t, pool);
        if (clash != null || isPacked) {
          final alt = Scheduler.alternative(t, pool, prefer: prefer);
          if (alt != null && mounted) {
            final why = clash != null
                ? "'${t.title}' overlaps with '${clash.title}'."
                : '${dayLabel(t.date!)} is packed.';
            final move = await askDialog(context,
                title: 'Heads up',
                body: "$why Move it to ${dayLabel(alt.day)} at ${fmtTime(alt.minutes)}?",
                yes: 'Move',
                no: 'Keep');
            if (move == true) {
              t.date = alt.day;
              t.minutes = alt.minutes;
              t.kind = Kind.fixed;
              notes.add("'${t.title}' → ${dayLabel(alt.day)}, ${fmtTime(alt.minutes)}");
            }
          }
        }
      }
      accepted.add(t);
    }

    await _store.addAll(_tasks);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(fadeRoute(CalendarScreen(
        banner: notes.isEmpty ? null : 'Placed for you:\n${notes.join('\n')}')));
  }

  Color _dot(Kind k) =>
      k == Kind.fixed ? C.lime : (k == Kind.deadline ? C.orange : C.mut);

  Widget _card(Task task) {
    final active = _activeId == task.id;
    final label = active
        ? (_partial.isEmpty ? 'Listening…' : _partial)
        : '${task.whenLabel}${task.unsure ? ' · this week or next?' : ''}';
    return Glass(
      border: task.unsure ? const Color(0x8CE9C46A) : null,
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task.title, style: t(17, w: FontWeight.w400)),
            const SizedBox(height: 7),
            Row(children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: _dot(task.kind))),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    style: t(13, c: task.unsure && !active ? C.warn : C.mut),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 12),
        HoldMic(active: active, onStart: () => _start(task), onStop: () => _stop(task)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unsure = _tasks.any((x) => x.unsure);
    final n = _tasks.length;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Pill(label: 'Cancel', onTap: () => Navigator.of(context).pop()),
              const SizedBox(height: 20),
              Text('$n ${n == 1 ? 'task' : 'tasks'} found', style: t(28, w: FontWeight.w400, ls: -.5)),
              const SizedBox(height: 4),
              Text(
                unsure
                    ? 'The highlighted one needs a quick look. Tap its mic and say it again.'
                    : 'Tap a mic to re-say one task. Flexible ones go on your lightest day.',
                style: t(14, c: C.mut, height: 1.4),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _tasks.isEmpty
                    ? Center(child: Text('Nothing here. Go back and try again.', style: t(15, c: C.mut)))
                    : ListView.separated(
                        itemCount: _tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _card(_tasks[i]),
                      ),
              ),
              const SizedBox(height: 14),
              Cta(label: 'Looks good', busy: _busy, onTap: _tasks.isEmpty ? null : _confirm),
            ]),
          ),
        ),
      ),
    );
  }
}
