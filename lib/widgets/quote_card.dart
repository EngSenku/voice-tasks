import 'dart:async';
import 'package:flutter/material.dart';
import '../services/quotes.dart';
import '../theme.dart';
import 'glass.dart';

/// Quote card above the mic. Pulled from a free quotes API, rotates every 12 s.
class QuoteCard extends StatefulWidget {
  const QuoteCard({super.key});
  @override
  State<QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<QuoteCard> {
  List<Quote> _q = QuoteService.fallback;
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    QuoteService.load().then((l) {
      if (mounted && l.isNotEmpty) setState(() => _q = [...l]..shuffle());
    });
    _timer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) setState(() => _i++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q[_i % _q.length];
    return Glass(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: SizedBox(
        width: double.infinity,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Column(
            key: ValueKey('${q.text}$_i'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 78),
                child: Text(q.text, style: t(19, height: 1.35, ls: -.2)),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: C.lime)),
                const SizedBox(width: 8),
                Expanded(child: Text(q.author, style: t(13, c: C.mut), overflow: TextOverflow.ellipsis)),
                Text(q.source, style: t(12, c: C.mut)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
