import '../models/task.dart';

/// Understands the evening answer: "I did the invoice but didn't call the dentist".
class Checkin {
  static const _stop = {
    'the', 'a', 'an', 'to', 'of', 'my', 'for', 'and', 'that', 'this', 'it', 'up',
    'at', 'on', 'in', 'with', 'did', 'didnt', 'not', 'have', 'had', 'but', 'was',
    'were', 'got', 'me', 'some', 'all', 'just', 'then'
  };
  static const _neg =
      r"(didn't|didnt|did not|haven't|havent|have not|couldn't|couldnt|could not|wasn't|never|forgot|skipped|missed|not|failed|no)";

  static String _stem(String w) => w.length > 4 ? w.substring(0, 4) : w;

  static Set<String> _stems(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z\s']"), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length >= 3 && !_stop.contains(w.replaceAll("'", '')))
      .map(_stem)
      .toSet();

  /// Returns taskId -> true (done) / false (not done, move it).
  static Map<String, bool> analyze(String text, List<Task> open) {
    final l = text.toLowerCase();
    final res = <String, bool>{for (final t in open) t.id: false};

    final nothing = RegExp(
            r"\b(nothing|didn't do anything|did not do anything|didnt do anything|haven't done anything)\b")
        .hasMatch(l);
    final everything =
        RegExp(r"\b(everything|all done|did it all|all of it|finished all)\b").hasMatch(l) &&
            !RegExp(r"\b(not|n't|never)\s+(do |done |finish |finished )?(everything|all)\b").hasMatch(l);
    if (nothing) return res;
    if (everything) {
      for (final k in res.keys.toList()) {
        res[k] = true;
      }
      return res;
    }

    bool? last;
    final clauses = l.split(RegExp(r"\bbut\b|\bhowever\b|[,;.]|\band\b|\bthen\b|\bexcept\b"));
    for (final clause in clauses) {
      final c = clause.trim();
      if (c.isEmpty) continue;
      final isNeg = RegExp('\\b$_neg\\b').hasMatch(c);
      final isPos = RegExp(
              r'\b(did|done|finished|completed|sent|called|bought|booked|made|got|handled|took|picked|paid|wrote|started|cleaned|submitted|had|managed)\b')
          .hasMatch(c);
      final bool? pol = isNeg ? false : (isPos ? true : last);
      if (pol == null) continue;
      last = pol;
      final cs = _stems(c);
      Task? best;
      var bs = 0;
      for (final t in open) {
        final sc = _stems(t.title).where(cs.contains).length;
        if (sc > bs) {
          bs = sc;
          best = t;
        }
      }
      if (best != null) res[best.id] = pol;
    }
    return res;
  }
}
