import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/insights.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'checkin_screen.dart';

class CalendarScreen extends StatelessWidget {
  final String? banner;
  const CalendarScreen({super.key, this.banner});

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.i;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: ListenableBuilder(
              listenable: store,
              builder: (ctx, _) => _body(ctx, store),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, TaskStore s) {
    final open = s.open.length;
    final streak = Insights.streak(s.tasks);
    final pattern = Insights.pattern(s.tasks);
    final today = dateOnly(DateTime.now());

    final children = <Widget>[];

    if (banner != null) {
      children.add(Glass(
        border: const Color(0x73D3E87A),
        child: SizedBox(width: double.infinity, child: Text(banner!, style: t(14, height: 1.5))),
      ));
    }

    if (streak > 0 || pattern != null) {
      children.add(Glass(
        child: Row(children: [
          const Icon(Icons.local_fire_department_outlined, color: C.lime, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (streak > 0)
                Text('$streak-day streak', style: t(16, w: FontWeight.w400)),
              if (pattern != null) Text(pattern, style: t(13, c: C.mut)),
            ]),
          ),
        ]),
      ));
    }

    // Tasks you keep postponing: the app asks, like a person would.
    for (final tk in s.stuck) {
      children.add(Glass(
        border: const Color(0x8CE9C46A),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("You've moved '${tk.title}' ${tk.postponed} times.", style: t(15, w: FontWeight.w400)),
          const SizedBox(height: 4),
          Text('Still important, or should we make it smaller?', style: t(13, c: C.mut)),
          const SizedBox(height: 8),
          Wrap(spacing: 4, children: [
            TextButton(onPressed: () => s.keep(tk), child: Text('Keep', style: t(14, c: C.mut))),
            TextButton(onPressed: () => s.makeSmaller(tk), child: Text('Make it smaller', style: t(14, c: C.lime))),
            TextButton(onPressed: () => s.drop(tk), child: Text('Drop', style: t(14, c: C.orange))),
          ]),
        ]),
      ));
    }

    final late = s.overdue;
    if (late.isNotEmpty) {
      children.add(_dayCard(context, s, 'Overdue', '${late.length}', late, warn: true));
    }

    for (var i = 0; i < 7; i++) {
      final d = addDays(today, i);
      final list = s.on(d);
      children.add(_dayCard(
        context,
        s,
        i == 0 ? 'Today' : (i == 1 ? 'Tomorrow' : kDays[d.weekday - 1]),
        '${d.day}/${d.month}',
        list,
        highlight: i == 0,
      ));
    }

    final flex = s.unplaced;
    if (flex.isNotEmpty) {
      children.add(_dayCard(context, s, 'Flexible', 'this week', flex));
    }

    children.add(Glass(
      padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
      child: Row(children: [
        Expanded(child: Text('Sync to phone calendar', style: t(15))),
        Switch(
          value: s.syncCalendar,
          activeThumbColor: C.lime,
          onChanged: (v) => s.setSync(v),
        ),
      ]),
    ));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Pill(label: 'Back', icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
        Pill(
          label: 'Evening check-in',
          icon: Icons.nightlight_outlined,
          onTap: () => Navigator.of(context).push(fadeRoute(const CheckinScreen())),
        ),
      ]),
      const SizedBox(height: 18),
      Text('Your week', style: t(28, w: FontWeight.w400, ls: -.5)),
      const SizedBox(height: 4),
      Text(open == 0 ? 'Nothing planned yet' : '$open to do · tap when done, hold for more',
          style: t(14, c: C.mut)),
      const SizedBox(height: 14),
      Expanded(
        child: ListView.separated(
          itemCount: children.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => children[i],
        ),
      ),
    ]);
  }

  Widget _dayCard(BuildContext context, TaskStore s, String title, String sub, List<Task> list,
      {bool highlight = false, bool warn = false}) {
    return Glass(
      border: warn
          ? const Color(0x8CE9C46A)
          : (highlight ? const Color(0x73D3E87A) : null),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title, style: t(16, w: FontWeight.w400, c: warn ? C.warn : C.tx)),
          Text(sub, style: t(13, c: C.mut)),
        ]),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text('Free', style: t(14, c: C.mut)),
          )
        else
          ...list.map((tk) => _row(context, s, tk)),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _row(BuildContext context, TaskStore s, Task tk) {
    final time = tk.minutes != null
        ? (tk.kind == Kind.deadline ? '≤ ${fmtTime(tk.minutes!)}' : fmtTime(tk.minutes!))
        : 'Any time';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => s.toggleDone(tk),
      onLongPress: () => _sheet(context, s, tk),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x17FFFFFF)))),
        child: Row(children: [
          Icon(tk.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 22, color: tk.done ? C.lime : C.mut),
          const SizedBox(width: 12),
          SizedBox(width: 62, child: Text(time, style: t(14, c: C.lime))),
          Expanded(
            child: Text(tk.title,
                style: t(16, c: tk.done ? C.mut : C.tx).copyWith(
                    decoration: tk.done ? TextDecoration.lineThrough : null)),
          ),
          if (tk.postponed > 0 && !tk.done)
            Text('moved ${tk.postponed}×', style: t(12, c: C.mut)),
        ]),
      ),
    );
  }

  void _sheet(BuildContext context, TaskStore s, Task tk) {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.schedule_rounded, color: C.lime),
            title: Text('Push to later', style: t(16)),
            onTap: () {
              Navigator.pop(ctx);
              s.push(tk);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: C.orange),
            title: Text('Drop it', style: t(16)),
            onTap: () {
              Navigator.pop(ctx);
              s.drop(tk);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
