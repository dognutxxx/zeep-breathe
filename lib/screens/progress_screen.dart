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

  /// Day shown in the timeline; null = today.
  DateTime? _day;

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
    final l = S.of(context);
    final today = dayOf(now);
    final selected = _day ?? today;

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
                _MonthGrid(
                  month: _month,
                  stats: st,
                  today: today,
                  selected: selected,
                  onSelect: (d) => setState(() => _day = d),
                ),
                const SizedBox(height: 10),
                Text(
                  l.lastSevenDays(st.minutesThisWeek(now)),
                  style: const TextStyle(fontSize: 12.5, color: ZeepColors.textSoft),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DayTimeline(
            day: selected,
            isToday: selected == today,
            records: h.onDay(selected),
            onBreathe: () => widget.app.setTab(HomeTab.breathe),
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
  final DateTime today, selected;
  final ValueChanged<DateTime> onSelect;
  const _MonthGrid({
    required this.month,
    required this.stats,
    required this.today,
    required this.selected,
    required this.onSelect,
  });

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
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 40);
    final date = DateTime(month.year, month.month, day);
    final secs = stats.secondsByDay[date] ?? 0;
    final done = secs >= 30;
    final isToday = date == today;
    final isSelected = date == selected;
    final future = date.isAfter(today);
    // more minutes -> deeper colour (1, 3, 6+ min)
    final depth = secs >= 360
        ? 1.0
        : secs >= 180
        ? 0.75
        : 0.5;
    final circle = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? Color.lerp(const Color(0xFFD6E9FB), const Color(0xFF8DB8F2), depth) : null,
        border: isSelected
            ? Border.all(color: ZeepColors.text, width: 2.5)
            : isToday
            ? Border.all(color: ZeepColors.blue, width: 2)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '$day',
        style: TextStyle(
          fontSize: 13,
          fontWeight: done || isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
          color: future ? ZeepColors.textFaint.withValues(alpha: 0.5) : (done ? ZeepColors.text : ZeepColors.textSoft),
        ),
      ),
    );
    return Semantics(
      button: !future,
      selected: isSelected,
      label: l.daySemantics(day, l.monthShort[month.month - 1], done ? (secs / 60).round() : null, isSelected),
      excludeSemantics: true,
      child: SizedBox(
        height: 40,
        child: Center(
          child: future ? circle : InkResponse(onTap: () => onSelect(date), radius: 22, child: circle),
        ),
      ),
    );
  }
}

/// One day's sessions as a vertical timeline: time on the left, a dot in the
/// mode's colour on the line, and a card with mode, duration and status.
class _DayTimeline extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final List<SessionRecord> records;
  final VoidCallback onBreathe;
  const _DayTimeline({required this.day, required this.isToday, required this.records, required this.onBreathe});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final total = records.fold<int>(0, (a, r) => a + r.seconds);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isToday ? '${l.today} · ${l.dayHeading(day)}' : l.dayHeading(day),
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: ZeepColors.text),
          ),
          if (records.isNotEmpty)
            Text(l.daySummary(records.length, total), style: const TextStyle(fontSize: 13, color: ZeepColors.textSoft)),
          const SizedBox(height: 12),
          if (records.isEmpty)
            _EmptyDay(isToday: isToday, onBreathe: onBreathe)
          else
            for (final (i, r) in records.indexed) _TimelineEntry(r: r, first: i == 0, last: i == records.length - 1),
          const SizedBox(height: 6),
          Text(l.dayTimelineHint, style: const TextStyle(fontSize: 12, color: ZeepColors.textFaint)),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final SessionRecord r;
  final bool first, last;
  const _TimelineEntry({required this.r, required this.first, required this.last});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final ex = exercises.where((e) => e.id == r.exercise).firstOrNull;
    final tint = ex?.tint ?? (r.exercise == 'default' ? const Color(0xFFBDDEF7) : const Color(0xFFDCE3EC));
    final time = '${r.start.hour.toString().padLeft(2, '0')}:${r.start.minute.toString().padLeft(2, '0')}';
    const lineColor = Color(0xFFD9E3EE);
    final status = r.completed ? l.completedLabel : l.stoppedEarly;
    final statusColor = r.completed ? ZeepColors.mintDark : ZeepColors.textSoft;
    return Semantics(
      label: '$time, ${exerciseDisplayName(r.exercise, l)}, ${l.duration(r.seconds)}, $status',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 46,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  time,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ZeepColors.textSoft,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            // the line and the dot
            SizedBox(
              width: 22,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  if (!(first && last))
                    Positioned(
                      top: first ? 17 : 0,
                      bottom: last ? null : 0,
                      height: last ? 17 : null,
                      child: Container(width: 2, color: lineColor),
                    ),
                  Positioned(
                    top: 10,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: mix(tint, const Color(0xFF6F8FBF), 0.3),
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: withAlpha(tint, 0.30),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: withAlpha(tint, 0.9)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exerciseDisplayName(r.exercise, l),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: ZeepColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  r.completed ? Icons.check_circle_rounded : Icons.timelapse_rounded,
                                  size: 14,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 4),
                                Text(status, style: TextStyle(fontSize: 12, color: statusColor)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        l.duration(r.seconds),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ZeepColors.text),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  final bool isToday;
  final VoidCallback onBreathe;
  const _EmptyDay({required this.isToday, required this.onBreathe});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(color: ZeepColors.bgTop, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          const ZeepAvatar(tint: Color(0xFFDCE3EC), size: 64, breath: 0.2),
          const SizedBox(height: 4),
          Text(
            isToday ? l.noSessionsToday : l.noSessionsThisDay,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: ZeepColors.textSoft),
          ),
          if (isToday) ...[
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onBreathe,
              style: FilledButton.styleFrom(backgroundColor: ZeepColors.mint, foregroundColor: ZeepColors.mintDark),
              child: Text(l.breatheNow, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}
