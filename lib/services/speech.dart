import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Free speech-to-text using the phone's built-in recognizer (English).
class SpeechService {
  final stt.SpeechToText _s = stt.SpeechToText();
  bool _ready = false, _want = false, _long = false, _restarting = false;
  String _buffer = '', _cur = '';
  void Function(String)? _onText;

  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _s.initialize(onStatus: _status, onError: (e) {});
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  void _emit() {
    final all = _buffer.trim();
    if (all.isNotEmpty) _onText?.call(all);
  }

  /// Merge a newly recognized piece of text into [a] without duplicating the
  /// words the recognizer repeats. Android re-sends the words you already said
  /// when it restarts a session after a pause (e.g. "i want to play" then
  /// "to play"), so a plain join would double them. This trims the overlap.
  @visibleForTesting
  static String mergeSpeechText(String a, String b) {
    a = a.trim();
    b = b.trim();
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    if (a == b) return a;
    if (b.startsWith(a)) return b; // b is the full transcript, extended
    if (a.startsWith(b)) return a; // b is a shorter repeat
    if (_endsWithWord(a, b)) return a; // b already sits at the tail of a
    final max = math.min(a.length, b.length);
    for (var k = max; k > 0; k--) {
      final sa = a.substring(a.length - k).toLowerCase();
      final sb = b.substring(0, k).toLowerCase();
      if (sa != sb) continue;
      // Only accept a word-aligned overlap so we never cut mid-word.
      final aLeft = a.length - k == 0 || a[a.length - k - 1] == ' ';
      final bRight = k == b.length || b[k] == ' ';
      if (aLeft && bRight) return '$a${b.substring(k)}';
    }
    return '$a $b'; // genuinely new words
  }

  /// True when [tail] is a whole-word suffix of [a].
  static bool _endsWithWord(String a, String tail) {
    if (!a.toLowerCase().endsWith(tail.toLowerCase())) return false;
    final i = a.length - tail.length;
    return i == 0 || a[i - 1] == ' ';
  }

  /// Merge a newly recognized piece of text into the running transcript.
  /// Android can deliver the recognizer's output several ways: the same
  /// transcript grown with the latest words, the whole transcript again, or a
  /// fresh segment (often repeating the previous tail) after a paused session.
  /// [_merge] handles all of them so pausing and continuing never loses or
  /// doubles what you said.
  void _ingest(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _buffer = mergeSpeechText(_buffer, t);
    _cur = t;
    _emit();
  }

  // Android ends a session after a pause; keep going while the user is still recording.
  void _status(String s) {
    if (!_want || _restarting) return;
    if (s == 'done' || s == 'notListening') {
      _restarting = true;
      // The final text of the ended session is usually delivered via onResult
      // before the status change. This is a safety join so a pause mid-
      // utterance is not lost (merge prevents duplication).
      if (_cur.isNotEmpty) {
        _buffer = mergeSpeechText(_buffer, _cur);
        _cur = '';
        _emit();
      }
      Future.delayed(const Duration(milliseconds: 250), () async {
        _restarting = false;
        if (_want) await _begin();
      });
    }
  }

  Future<void> _begin() async {
    if (_s.isListening) return;
    try {
      await _s.listen(
        onResult: (r) => _ingest(r.recognizedWords),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
          listenFor: const Duration(minutes: 5),
          pauseFor: Duration(seconds: _long ? 30 : 12),
          localeId: 'en_US',
        ),
      );
    } catch (_) {}
  }

  Future<bool> start(void Function(String) onText, {bool long = false}) async {
    if (!await init()) return false;
    _want = true;
    _long = long;
    _buffer = '';
    _cur = '';
    _onText = onText;
    await _begin();
    return true;
  }

  Future<String> stop() async {
    _want = false;
    try {
      await _s.stop();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 350));
    final all = _cur.isEmpty ? _buffer : mergeSpeechText(_buffer, _cur);
    return all.trim();
  }
}

/// Free spoken replies using the phone's built-in text-to-speech.
class Speaker {
  static final FlutterTts _t = FlutterTts();
  static bool _init = false;

  static Future<void> say(String s) async {
    try {
      if (!_init) {
        await _t.setLanguage('en-US');
        await _t.setSpeechRate(0.48);
        await _t.setPitch(1.0);
        _init = true;
      }
      await _t.stop();
      await _t.speak(s);
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _t.stop();
    } catch (_) {}
  }
}