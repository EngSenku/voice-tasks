import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// The cloud LLM — NVIDIA NIM (an OpenAI-compatible endpoint).
///
/// This is the app's only task extractor: the model splits a spoken sentence
/// into tasks and resolves each task's day, clock time and kind. See
/// [AiTasks] for the prompt and the JSON contract.
///
/// The API key is **not** committed. Supply it at build time with
/// `--dart-define=NVIDIA_API_KEY=...`, or let the user paste it in Settings
/// (where it is stored in `shared_preferences`). A `String.fromEnvironment`
/// default keeps the public source clean of credentials.
class CloudAi {
  static const String defaultBaseUrl = 'https://integrate.api.nvidia.com/v1';
  static const String defaultModel = 'nvidia/nemotron-3.5-lightning-30b-a3b';

  /// Build-time key. Empty unless `--dart-define=NVIDIA_API_KEY=...` was passed.
  static const String defaultKey =
      String.fromEnvironment('NVIDIA_API_KEY');

  /// Whether cloud parsing is switched on.
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  static String _key = defaultKey;
  static String _model = defaultModel;
  static String _baseUrl = defaultBaseUrl;
  static bool _loaded = false;

  static String get key => _key;
  static String get model => _model;
  static String get baseUrl => _baseUrl;

  /// True when a cloud call should be attempted.
  static bool get configured => enabled.value && _key.trim().isNotEmpty;

  /// The key with the middle hidden, for display in the settings dialog.
  static String get maskedKey {
    final k = _key.trim();
    if (k.length <= 12) return k.isEmpty ? '(none)' : k;
    return '${k.substring(0, 9)}…${k.substring(k.length - 4)}';
  }

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final p = await SharedPreferences.getInstance();
      _key = p.getString('ai_key') ?? defaultKey;
      _model = p.getString('ai_model') ?? defaultModel;
      _baseUrl = p.getString('ai_url') ?? defaultBaseUrl;
      enabled.value = p.getBool('ai_cloud') ?? true;
    } catch (_) {
      // Fall back to the built-in defaults.
    }
    _loaded = true;
  }

  static Future<void> save({
    bool? on,
    String? key,
    String? model,
    String? baseUrl,
  }) async {
    if (on != null) enabled.value = on;
    if (key != null) _key = key.trim();
    if (model != null && model.trim().isNotEmpty) _model = model.trim();
    if (baseUrl != null && baseUrl.trim().isNotEmpty) {
      _baseUrl = baseUrl.trim();
    }
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('ai_cloud', enabled.value);
      await p.setString('ai_key', _key);
      await p.setString('ai_model', _model);
      await p.setString('ai_url', _baseUrl);
    } catch (_) {
      // Preferences are best-effort; the in-memory values still apply.
    }
  }

  /// Sends a system + user prompt and returns the assistant text.
  ///
  /// Nemotron is a reasoning model: by default it "thinks" first (slow, and the
  /// answer lands in `reasoning_content` while `content` stays empty). The chat
  /// template's `enable_thinking:false` switch turns that off, cutting a call
  /// from ~5s to ~0.6s.
  static Future<String> complete(
    String system,
    String user, {
    bool thinking = false,
    Duration timeout = const Duration(seconds: 30),
    int maxTokens = 800,
  }) async {
    final base = _baseUrl.replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/chat/completions');
    final res = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $_key',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'model': _model,
            'messages': [
              {'role': 'system', 'content': system},
              {'role': 'user', 'content': user},
            ],
            'temperature': 0.1,
            'max_tokens': maxTokens,
            'stream': false,
            if (!thinking) 'chat_template_kwargs': {'enable_thinking': false},
          }),
        )
        .timeout(timeout);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${_short(res.body)}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) throw Exception('malformed response');
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) throw Exception('no choices');
    final message = (choices.first is Map) ? (choices.first as Map)['message'] : null;
    final content = (message is Map) ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw Exception('empty content');
    }
    return content;
  }

  static String _short(String s) => s.length <= 200 ? s : '${s.substring(0, 200)}…';
}
