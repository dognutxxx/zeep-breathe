import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../exercises/exercises.dart';
import '../history/session_history.dart';
import '../l10n/strings.dart';
import '../ui/zeep_character.dart';
import '../ui/zeep_colors.dart';

class ProgressScreen extends StatefulWidget {
  final AppController app;
  final DateTime Function() clock;
  const ProgressScreen({super.key, required this.app, this.clock = DateTime.now});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = widget.clock();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.clock();
    final h = widget.app.history;
    final st = h.stats(now);
    final recent = h.records.reversed.take(5).toList();
    final l = S.of(context);

    return SafeArea(
      top: !widget.app.bannerVisible,
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Text(
            l.progressTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ZeepColors.text),
          ),
          const SizedBox(height: 16),
          _StreakCard(stats: st, practisedToday: st.practisedOn(now)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Tile(value: '${st.totalMinutes}', label: l.totalMin, icon: Icons.schedule_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Tile(value: '${st.sessions}', label: l.sessionsLabel, icon: Icons.self_improvement_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Tile(value: '${st.longestStreak}', label: l.bestStreak, icon: Icons.emoji_events_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: l.prevMonth,
                      onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        l.monthYear(_month),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ZeepColors.text),
                      ),
                    ),
                    IconButton(
                      tooltip: l.nextMonth,
                      onPressed: (_month.year == now.year && _month.month == now.month)
                          ? null
                          : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _MonthGrid(month: _month, stats: st, today: dayOf(now)),
                const SizedBox(height: 10),
                Text(
                  l.lastSevenDays(st.minutesThisWeek(now)),
                  style: const TextStyle(fontSize: 12.5, color: ZeepColors.textSoft),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.recentSessions,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ZeepColors.text),
                ),
                const SizedBox(height: 6),
                if (recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(l.noSessions, style: const TextStyle(fontSize: 13, color: ZeepColors.textSoft)),
                  ),
                for (final r in recent) _RecentRow(r: r, now: now),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: withAlpha(Colors.black, 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}

class _StreakCard extends StatelessWidget {
  final HistoryStats stats;
  final bool practisedToday;
  const _StreakCard({required this.stats, required this.practisedToday});

  @override
  Widget build(BuildContext context) {
    final n = stats.currentStreak;
    final l = S.of(context);
    final msg = n == 0
        ? l.streakStart
        : practisedToday
        ? l.streakToday
        : l.streakKeep;
    return Semantics(
      label: l.streakSemantics(n, msg),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFDDEBFA), Color(0xFFE6E1FA)]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.currentStreak,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3463CC)),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$n',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: ZeepColors.text,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l.dayUnit(n),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ZeepColors.textSoft),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(msg, style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A4E58))),
                ],
              ),
            ),
            ZeepAvatar(
              tint: practisedToday ? const Color(0xFFCCC7F5) : const Color(0xFFBDDEF7),
              size: 96,
              breath: practisedToday ? 0.9 : 0.4,
              hold: practisedToday ? 1 : 0,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String value, label;
  final IconData icon;
  const _Tile({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(icon, size: 18, color: ZeepColors.blue),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ZeepColors.text),
            ),
            Text(label, style: const TextStyle(fontSize: 11.5, color: ZeepColors.textSoft)),
          ],
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final HistoryStats stats;
  final DateTime today;
  const _MonthGrid({required this.month, required this.stats, required this.today});

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday % 7; // Sunday-first grid
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();
    final l = S.of(context);
    final head = l.weekdayHeads;

    return Column(
      children: [
        Row(
          children: [
            for (final d in head)
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ZeepColors.textFaint),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < rows; r++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [for (var c = 0; c < 7; c++) Expanded(child: _dayCell(r * 7 + c - lead + 1, daysInMonth, l))],
            ),
          ),
      ],
    );
  }

  Widget _dayCell(int day, int daysInMonth, S l) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 36);
    final date = DateTime(month.year, month.month, day);
    final secs = stats.secondsByDay[date] ?? 0;
    final done = secs >= 30;
    final isToday = date == today;
    final future = date.isAfter(today);
    // more minutes -> deeper colour (1, 3, 6+ min)
    final depth = secs >= 360
        ? 1.0
        : secs >= 180
        ? 0.75
        : 0.5;
    return Semantics(
      label: '$day ${l.monthShort[month.month - 1]}${done ? ', ${l.minutes((secs / 60).round())}' : ''}',
      excludeSemantics: true,
      child: SizedBox(
        height: 36,
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? Color.lerp(const Color(0xFFD6E9FB), const Color(0xFF8DB8F2), depth) : null,
              border: isToday ? Border.all(color: ZeepColors.blue, width: 2) : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: done || isToday ? FontWeight.w700 : FontWeight.w400,
                color: future
                    ? ZeepColors.textFaint.withValues(alpha: 0.5)
                    : (done ? ZeepColors.text : ZeepColors.textSoft),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final SessionRecord r;
  final DateTime now;
  const _RecentRow({required this.r, required this.now});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final d = dayOf(r.start);
    final today = dayOf(now);
    final when = d == today
        ? l.today
        : d == DateTime(today.year, today.month, today.day - 1)
        ? l.yesterday
        : '${r.start.day} ${l.monthShort[r.start.month - 1]}';
    final time = '${r.start.hour.toString().padLeft(2, '0')}:${r.start.minute.toString().padLeft(2, '0')}';
    final mins = l.duration(r.seconds);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: r.completed ? const Color(0xFFE3F5EF) : ZeepColors.btnBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              r.completed ? Icons.check_rounded : Icons.timelapse_rounded,
              size: 18,
              color: r.completed ? ZeepColors.mintDark : ZeepColors.textSoft,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exerciseDisplayName(r.exercise, l),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ZeepColors.text),
                ),
                Text('$when · $time', style: const TextStyle(fontSize: 12, color: ZeepColors.textSoft)),
              ],
            ),
          ),
          Text(
            mins,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: ZeepColors.text),
          ),
        ],
      ),
    );
  }
}
