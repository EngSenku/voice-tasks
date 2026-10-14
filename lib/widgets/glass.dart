import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../theme.dart';

Route<T> fadeRoute<T>(Widget w) => PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => w,
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 250),
    );

/// Near-black canvas, olive glow in two corners, a faint dotted grid.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.bg,
      child: Stack(children: [
        const Positioned.fill(
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: RadialGradient(
                        center: Alignment.topLeft,
                        radius: 1.25,
                        colors: [Color(0x476E6E1E), Color(0x006E6E1E)])))),
        const Positioned.fill(
            child: DecoratedBox(
                decoration: BoxDecoration(
                    gradient: RadialGradient(
                        center: Alignment.bottomRight,
                        radius: 1.0,
                        colors: [Color(0x334A4A14), Color(0x004A4A14)])))),
        Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _Dots()))),
        Positioned.fill(child: child),
      ]),
    );
  }
}

class _Dots extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint();
    final cx = s.width / 2, cy = s.height * .55;
    for (double x = 11; x < s.width; x += 22) {
      for (double y = 11; y < s.height; y += 22) {
        final d = math.sqrt(math.pow(x - cx, 2) + math.pow(y - cy, 2));
        final a = (1 - d / (s.height * .6)).clamp(0.0, 1.0);
        if (a <= 0) continue;
        p.color = Color.fromRGBO(255, 255, 255, 0.08 * a);
        canvas.drawCircle(Offset(x, y), 1, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? border;
  final double radius;
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.border,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border ?? const Color(0x17FFFFFF)),
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x12FFFFFF), Color(0x06FFFFFF)]),
          ),
          child: child,
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final IconData? icon;
  const Pill({super.key, required this.label, this.onTap, this.filled = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final fg = filled ? C.ink : C.mut;
    return Material(
      color: filled ? C.lime : const Color(0x0DFFFFFF),
      shape: StadiumBorder(
          side: BorderSide(color: filled ? Colors.transparent : const Color(0x17FFFFFF))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
            Text(label, style: t(14, c: fg, w: filled ? FontWeight.w500 : FontWeight.w300)),
          ]),
        ),
      ),
    );
  }
}

class Cta extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  const Cta({super.key, required this.label, this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: Material(
        color: onTap == null ? const Color(0x33D3E87A) : C.lime,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: busy ? null : onTap,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: C.ink))
                : Text(label, style: t(18, w: FontWeight.w500, c: C.ink)),
          ),
        ),
      ),
    );
  }
}

Future<bool?> askDialog(BuildContext context,
    {required String title, required String body, String yes = 'Yes', String no = 'No'}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: t(20, w: FontWeight.w400)),
      content: Text(body, style: t(16, height: 1.4)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(no, style: t(15, c: C.mut))),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(yes, style: t(15, c: C.lime, w: FontWeight.w500))),
      ],
    ),
  );
}

Future<String?> typeDialog(BuildContext context, String hint) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Type it instead', style: t(20, w: FontWeight.w400)),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLines: 3,
        style: t(16),
        decoration: InputDecoration(hintText: hint, hintStyle: t(15, c: C.mut)),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: t(15, c: C.mut))),
        TextButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: Text('Done', style: t(15, c: C.lime, w: FontWeight.w500))),
      ],
    ),
  );
}
