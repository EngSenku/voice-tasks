import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';
import '../services/checkin.dart';
import '../services/speech.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/mic_button.dart';

/// Evening check-in: "I did the invoice but didn't call the dentist."
/// The app updates everything and moves what's left to tomorrow.
class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});
  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final _speech = SpeechService();
  final _store = TaskStore.i;
  late final List<Task> _open;
  Map<String, bool>? _plan;
  bool _active = false, _stopping = false, _busy = false;
  String _live = '';
  Future<bool>? _starting;

  @override
  void initState() {
    super.initState();
    final today = dateOnly(DateTime.now());
    _open = _store.open.where((t) => t.date != null && !t.date!.isAfter(today)).toList();
    if (_open.isNotEmpty) Speaker.say('How did today go?');
  }

  @override
  void dispose() {
    Speaker.stop();
    super.dispose();
  }

  void _start() {
    if (_active) return;
    HapticFeedback.mediumImpact();
    Speaker.stop();
    setState(() {
      _active = true;
      _live = '';
    });
    _starting = _speech.start((s) {
      if (mounted) setState(() => _live = s);
    }, long: true);
    _starting!.then((ok) {
      if (!ok && mounted) setState(() => _active = false);
    });
  }

  Future<void> _stop() async {
    if (!_active || _stopping) return;
    _stopping = true;
    final ok = await (_starting ?? Future.value(true));
    if (!ok) {
      _stopping = false;
      return;
    }
    final text = await _speech.stop();
    _stopping = false;
    if (!mounted) return;
    setState(() => _active = false);
    _analyze(text);
  }

  void _analyze(String text) {
    if (text.trim().isEmpty) return;
    setState(() => _plan = Checkin.analyze(text, _open));
  }

  Future<void> _typeIt() async {
    final text = await typeDialog(context, "I did the invoice but didn't call the dentist");
    if (text != null && mounted) _analyze(text);
  }

  Future<void> _apply() async {
    setState(() => _busy = true);
    for (final t in _open) {
      if (_plan![t.id] == true) {
        await _store.complete(t);
      } else {
        await _store.carryOver(t);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Widget _row(Task task) {
    final done = _plan![task.id] == true;
    return GestureDetector(
      onTap: () => setState(() => _plan![task.id] = !done),
      child: Glass(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Row(children: [
          Icon(done ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
              color: done ? C.lime : C.orange, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(task.title, style: t(16, w: FontWeight.w400))),
          Text(done ? 'Done' : 'Tomorrow', style: t(13, c: done ? C.lime : C.orange)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final planned = _plan != null;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Pill(label: 'Close', onTap: () => Navigator.of(context).pop()),
              const SizedBox(height: 20),
              Text('How did today go?', style: t(28, w: FontWeight.w400, ls: -.5)),
              const SizedBox(height: 4),
              Text(
                _open.isEmpty
                    ? 'Nothing was planned for today.'
                    : planned
                        ? 'Tap a task to flip it. Everything not done moves to tomorrow.'
                        : 'Tap the mic, tell me what you did and what you didn\'t, then tap again.',
                style: t(14, c: C.mut, height: 1.4),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(children: [
                  for (final task in _open) ...[
                    planned
                        ? _row(task)
                        : Glass(
                            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                            child: Row(children: [
                              Expanded(child: Text(task.title, style: t(16))),
                              Text(task.minutes != null ? fmtTime(task.minutes!) : '', style: t(13, c: C.mut)),
                            ])),
                    const SizedBox(height: 10),
                  ],
                  if (!planned && _open.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Center(child: MicButton(active: _active, toggle: true, onStart: _start, onStop: _stop)),
                    Center(
                      child: Text(_active ? (_live.isEmpty ? 'Listening…' : _live) : '',
                          textAlign: TextAlign.center, style: t(15, height: 1.4)),
                    ),
                    Center(
                      child: TextButton(
                          onPressed: _active ? null : _typeIt,
                          child: Text('Type instead', style: t(14, c: C.mut))),
                    ),
                  ],
                ]),
              ),
              if (planned) ...[
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _plan = null),
                    child: Text('Say it again', style: t(14, c: C.mut)),
                  ),
                ),
                Cta(label: 'Looks good', busy: _busy, onTap: _apply),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
