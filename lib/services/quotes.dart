import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Quote {
  final String text, author, source;
  const Quote(this.text, this.author, this.source);
}

/// Free quotes from ZenQuotes (https://zenquotes.io). Cached daily, with
/// built-in fallbacks so the card is never empty (offline, rate limit).
class QuoteService {
  static const fallback = [
    Quote('The secret of getting ahead is getting started.', 'Mark Twain', 'built-in'),
    Quote('Well begun is half done.', 'Aristotle', 'built-in'),
    Quote('Do what you can, with what you have, where you are.', 'Theodore Roosevelt', 'built-in'),
    Quote('It always seems impossible until it is done.', 'Nelson Mandela', 'built-in'),
    Quote('Action is the foundational key to all success.', 'Pablo Picasso', 'built-in'),
  ];

  static Future<List<Quote>> load() async {
    final p = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    List<Quote> fromRaw(String? raw) {
      if (raw == null) return [];
      try {
        return (jsonDecode(raw) as List)
            .map((e) => Quote(e['q'] as String, e['a'] as String, 'ZenQuotes'))
            .toList();
      } catch (_) {
        return [];
      }
    }

    if (p.getString('quotes_day') == today) {
      final c = fromRaw(p.getString('quotes'));
      if (c.isNotEmpty) return c;
    }
    try {
      final r = await http
          .get(Uri.parse('https://zenquotes.io/api/quotes'))
          .timeout(const Duration(seconds: 6));
      final d = jsonDecode(r.body);
      if (d is List && d.isNotEmpty) {
        final keep = d
            .where((e) => e is Map && (e['q'] as String).length <= 140 && e['a'] != 'zenquotes.io')
            .map((e) => {'q': e['q'], 'a': e['a']})
            .toList();
        if (keep.isNotEmpty) {
          await p.setString('quotes', jsonEncode(keep));
          await p.setString('quotes_day', today);
          return fromRaw(jsonEncode(keep));
        }
      }
    } catch (_) {}
    final old = fromRaw(p.getString('quotes'));
    return old.isNotEmpty ? old : fallback;
  }
}
