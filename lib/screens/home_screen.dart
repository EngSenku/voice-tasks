import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_controller.dart';
import '../services/ai.dart';
import '../services/cloud_ai.dart';
import '../services/insights.dart';
import '../services/speech.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/mic_button.dart';
import '../widgets/quote_card.dart';
import 'calendar_screen.dart';
import 'checkin_screen.dart';
import 'review_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _speech = SpeechService();
  final _store = TaskStore.i;
  bool _active = false, _stopping = false, _diary = false;
  String _live = '';
  String? _override;
  Future<bool>? _starting;

  @override
  void initState() {
    super.initState();
    AppController.i.addListener(_onApp);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onApp());
    CloudAi.enabled.addListener(_onAiStatus);
    unawaited(CloudAi.load().then((_) => _onAiStatus()));
  }

  void _onAiStatus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CloudAi.enabled.removeListener(_onAiStatus);
    AppController.i.removeListener(_onApp);
    Speaker.stop();
    super.dispose();
  }

  void _onApp() {
    final a = AppController.i.take();
    if (a == null || !mounted) return;
    switch (a) {
      case 'record': // from the home-screen shortcut: tap to start, tap to stop
        _start();
        break;
      case 'briefing':
        _briefing();
        break;
      case 'checkin':
        Navigator.of(context).push(fadeRoute(const CheckinScreen()));
        break;
      case 'calendar':
        Navigator.of(context).push(fadeRoute(const CalendarScreen()));
        break;
    }
  }

  String get _hint {
    if (_active) return _live.isEmpty ? 'Listening…' : _live;
    if (_override != null) return _override!;
    return _diary
        ? 'Tap, tell me about your day, then tap again.'
        : 'Tap, tell me what you need to do and when, then tap again.';
  }

  void _start() {
    if (_active) return;
    HapticFeedback.mediumImpact();
    Speaker.stop();
    setState(() {
      _active = true;
      _live = '';
      _override = null;
    });
    _starting = _speech.start((t) {
      if (mounted) setState(() => _live = t);
    }, long: true);
    _starting!.then((ok) {
      if (!ok && mounted) {
        setState(() {
          _active = false;
          _override = 'Microphone unavailable. Use "Type instead" below.';
        });
      }
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
    setState(() {
      _active = false;
    });
    await _handle(text);
  }

  Future<void> _handle(String text) async {
    if (text.trim().isEmpty) {
      setState(() => _override = "Didn't catch that. Try again.");
      return;
    }
    if (!CloudAi.configured) {
      setState(() => _override = 'Add your cloud AI key in AI settings first.');
      _aiInfo();
      return;
    }
    setState(() => _override = 'Understanding…');
    final tasks = await AiTasks.parse(text, diary: _diary);
    if (!mounted) return;
    if (tasks == null) {
      setState(() => _override =
          "Couldn't reach the AI. Check your connection and try again.");
      return;
    }
    await Navigator.of(context).push(fadeRoute(ReviewScreen(tasks: tasks, transcript: text)));
    if (mounted) setState(() => _override = null);
  }

  Future<void> _typeIt() async {
    final text = await typeDialog(context, 'Tomorrow call the dentist in the morning…');
    if (text != null && mounted) await _handle(text);
  }

  void _briefing() {
    Speaker.say(Insights.briefing(_store));
    setState(() => _override = 'Playing your briefing…');
  }

  void _aiInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final raw = AiTasks.lastRaw;
          final err = AiTasks.lastError;
          final on = CloudAi.configured;
          return AlertDialog(
            backgroundColor: C.panel,
            title: Text('Cloud AI', style: t(16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    on
                        ? 'NVIDIA Nemotron (30B) — nothing to download.'
                        : 'Off. Add a key to turn the AI on.',
                    style: t(13, c: on ? C.mut : C.warn),
                  ),
                  const SizedBox(height: 6),
                  Text('Model: ${CloudAi.model}', style: t(13, c: C.mut)),
                  Text('Key: ${CloudAi.maskedKey}', style: t(13, c: C.mut)),
                  Text('Last run: ${AiTasks.lastMs} ms', style: t(13, c: C.mut)),
                  if (err != null) ...[
                    const SizedBox(height: 10),
                    Text('Last error: $err', style: t(13, c: C.warn)),
                  ],
                  if (raw != null) ...[
                    const SizedBox(height: 10),
                    Text('Last model output:', style: t(13, c: C.mut)),
                    const SizedBox(height: 4),
                    SelectableText(raw, style: t(12)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => _cloudSettings(setDialog),
                child: Text('Settings', style: t(14, c: C.lime)),
              ),
              TextButton(
                onPressed: () async {
                  await AiTasks.parse(
                      'today i want to play and go to the store and tomorrow '
                      'i will clean the house and study',
                      diary: false);
                  setDialog(() {});
                },
                child: Text('Run test', style: t(14, c: C.lime)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close', style: t(14, c: C.mut)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _cloudSettings(void Function(void Function()) refresh) async {
    final keyC = TextEditingController(text: CloudAi.key);
    final modelC = TextEditingController(text: CloudAi.model);
    final urlC = TextEditingController(text: CloudAi.baseUrl);
    var on = CloudAi.enabled.value;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: C.panel,
          title: Text('Cloud AI', style: t(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: on,
                  onChanged: (v) => set(() => on = v),
                  title: Text('Use cloud model', style: t(14)),
                  subtitle: Text('NVIDIA Nemotron — no download, needs internet.',
                      style: t(12, c: C.mut)),
                ),
                TextField(
                  controller: modelC,
                  decoration: const InputDecoration(labelText: 'Model'),
                  style: t(13),
                ),
                TextField(
                  controller: urlC,
                  decoration: const InputDecoration(labelText: 'Base URL'),
                  style: t(13),
                ),
                TextField(
                  controller: keyC,
                  decoration: const InputDecoration(labelText: 'API key'),
                  style: t(13),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await CloudAi.save(
                  on: on,
                  key: keyC.text,
                  model: modelC.text,
                  baseUrl: urlC.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                refresh(() {});
              },
              child: Text('Save', style: t(14, c: C.lime)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: t(14, c: C.mut)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiStatus() {
    final on = CloudAi.configured;
    return GestureDetector(
      onTap: _aiInfo,
      child: Text(
        on ? 'AI · Nemotron (cloud) · tap for info' : 'Cloud AI off · tap to set up',
        style: t(12, c: on ? C.mut : C.warn),
      ),
    );
  }

  Widget _chip(String l, bool on, VoidCallback f) => GestureDetector(
        onTap: _active ? null : f,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: on ? const Color(0x26D3E87A) : Colors.transparent,
            border: Border.all(color: on ? const Color(0x80D3E87A) : const Color(0x17FFFFFF)),
          ),
          child: Text(l, style: t(14, c: on ? C.lime : C.mut)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(children: [
              ListenableBuilder(
                listenable: _store,
                builder: (_, __) {
                  final n = _store.open.length;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Pill(label: 'Briefing', icon: Icons.volume_up_outlined, onTap: _briefing),
                      Pill(
                        label: n > 0 ? 'Calendar · $n' : 'Calendar',
                        icon: Icons.calendar_today_outlined,
                        onTap: () => Navigator.of(context).push(fadeRoute(const CalendarScreen())),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              const QuoteCard(),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MicButton(
                      active: _active,
                      toggle: true,
                      onStart: _start,
                      onStop: _stop,
                    ),
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300, minHeight: 44),
                      child: Text(
                        _hint,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: t(15, c: _active ? C.tx : C.mut, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _aiStatus(),
                    const SizedBox(height: 16),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      _chip('Tasks', !_diary, () => setState(() => _diary = false)),
                      const SizedBox(width: 8),
                      _chip('Diary', _diary, () => setState(() => _diary = true)),
                    ]),
                  ],
                ),
              ),
              TextButton(
                onPressed: _active ? null : _typeIt,
                child: Text('Type instead', style: t(14, c: C.mut)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
