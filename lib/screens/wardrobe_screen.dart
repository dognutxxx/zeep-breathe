// W: Zeep's wardrobe. Two tabs: outfits (28 items, one per slot) and the
// flower garden (W.2: level, leaves, 20 flower kinds). Opened from the hanger
// button (T1.9), from the new-item card (N) and from the bloom strip on the
// finish card (S.9). (Tapping the character on T1.5 opens the friends picker
// since 1.7.0.)

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app_controller.dart';
import '../l10n/strings.dart';
import '../ui/widgets.dart';
import '../ui/zeep_character.dart';
import '../ui/zeep_colors.dart';
import '../wardrobe/flowers.dart';
import '../wardrobe/outfits.dart';
import '../wardrobe/wardrobe_controller.dart';

/// Opens W; the future completes when it is closed.
Future<void> openWardrobe(BuildContext context, AppController app, {int tab = 0}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => WardrobeScreen(app: app, initialTab: tab),
    ),
  );
}

class WardrobeScreen extends StatefulWidget {
  final AppController app;
  final int initialTab;
  const WardrobeScreen({super.key, required this.app, this.initialTab = 0});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> with SingleTickerProviderStateMixin {
  late int _tab = widget.initialTab;

  // The Breathe tab's ticker stops while this page covers it, so Zeep here
  // has its own idle animator and ticker.
  final _anim = Animator();
  final _frame = ValueNotifier<int>(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    // whatever was new has now been seen: the red dot on T1.9 goes away
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.app.wardrobe.markAllSeen());
    _ticker = createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
      _last = elapsed;
      _anim.update(dt, 0, 0, false);
      _frame.value++;
    });
    if (!widget.app.reduceMotion) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final w = app.wardrobe;
    final l = S.of(context);
    return Scaffold(
      body: ZeepBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListenableBuilder(
                listenable: Listenable.merge([app, w, _frame]),
                builder: (context, _) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: l.back,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.chevron_left_rounded, size: 32, color: ZeepColors.text),
                          ),
                          Expanded(
                            child: Text(
                              l.wardrobe,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ZeepColors.text),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 200,
                      child: ExcludeSemantics(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: ZeepPainter(
                            pose: _anim.pose,
                            time: _anim.time,
                            ripples: const [],
                            reduceMotion: app.reduceMotion,
                            outfit: w.outfit,
                            growth: w.growth,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '${l.practiceDays(w.practiceDays)} · ${l.levelN(w.garden.level)}',
                      style: const TextStyle(fontSize: 14, color: ZeepColors.textSoft),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<int>(
                      segments: [
                        ButtonSegment(value: 0, label: Text(l.tabOutfits), icon: const Icon(Icons.checkroom_rounded)),
                        ButtonSegment(
                          value: 1,
                          label: Text(l.tabGarden),
                          icon: const Icon(Icons.local_florist_rounded),
                        ),
                      ],
                      selected: {_tab},
                      showSelectedIcon: false,
                      onSelectionChanged: (v) => setState(() => _tab = v.first),
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: ZeepColors.blue,
                        selectedForegroundColor: Colors.white,
                        foregroundColor: ZeepColors.text,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _tab == 0 ? _OutfitsTab(w: w) : _GardenTab(w: w),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- outfits tab

class _OutfitsTab extends StatelessWidget {
  final WardrobeController w;
  const _OutfitsTab({required this.w});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text(
          l.outfitsHint,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: ZeepColors.textSoft),
        ),
        for (final slot in OutfitSlot.values) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l.slotName(slot),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ZeepColors.text),
                  ),
                ),
              ),
              ChoiceChip(
                label: Text(l.wearNone),
                selected: w.outfit[slot] == null,
                onSelected: (_) => w.clearSlot(slot),
                selectedColor: ZeepColors.blueSoft,
                backgroundColor: Colors.white,
                showCheckmark: false,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [for (final i in OutfitItem.values.where((i) => i.slot == slot)) _ItemTile(w: w, item: i)],
          ),
        ],
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  final WardrobeController w;
  final OutfitItem item;
  const _ItemTile({required this.w, required this.item});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final open = w.isUnlocked(item);
    final on = w.outfit.wears(item);
    final name = l.itemName(item);
    final state = on ? l.wearing : (open ? '' : '${l.locked}, ${l.daysLeft(w.daysLeft(item))}');
    return Semantics(
      button: open,
      selected: on,
      label: state.isEmpty ? name : '$name, $state',
      excludeSemantics: true,
      child: Material(
        color: on ? ZeepColors.blueSoft : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: on ? ZeepColors.blue : const Color(0xFFE1E7EE), width: on ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: open ? () => w.toggle(item) : null,
          child: ConstrainedBox(
            // as tall as the text needs (large text sizes)
            constraints: const BoxConstraints.tightFor(width: 112).copyWith(minHeight: 136),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
              child: Column(
                children: [
                  Opacity(
                    opacity: open ? 1 : 0.35,
                    child: SizedBox(
                      width: 96,
                      height: 78,
                      child: CustomPaint(painter: ZeepThumbPainter(outfit: Outfit.of([item]))),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, height: 1.2, color: ZeepColors.text),
                  ),
                  if (!open)
                    Text.rich(
                      TextSpan(
                        children: [
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Icon(Icons.lock_rounded, size: 12, color: ZeepColors.textFaint),
                          ),
                          TextSpan(text: ' ${l.daysLeft(w.daysLeft(item))}'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: ZeepColors.textSoft),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- garden tab

class _GardenTab extends StatelessWidget {
  final WardrobeController w;
  const _GardenTab({required this.w});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final g = w.garden;
    final counts = g.bloomCounts;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFDDF3EC), borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              Text(
                l.levelLeaves(g.level, g.leaves, g.leavesNeeded),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ZeepColors.mintDark),
              ),
              const SizedBox(height: 6),
              ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < g.leavesNeeded; i++)
                      Icon(
                        Icons.eco_rounded,
                        size: 22,
                        color: i < g.leaves ? const Color(0xFF4FA77F) : withAlpha(ZeepColors.mintDark, 0.18),
                      ),
                    Icon(Icons.local_florist_rounded, size: 22, color: withAlpha(ZeepColors.mintDark, 0.18)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(l.stepsToBloom(g.stepsToBloom), style: const TextStyle(fontSize: 14, color: ZeepColors.mintDark)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l.gardenHint,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: ZeepColors.textSoft),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: ChoiceChip(
            label: Text(l.noFlower),
            selected: w.wornFlower == null,
            onSelected: (_) => w.chooseFlower(null),
            selectedColor: ZeepColors.blueSoft,
            backgroundColor: Colors.white,
            showCheckmark: false,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < flowerKinds.length; i++)
              _FlowerTile(w: w, kind: flowerKinds[i], count: counts[i], level: i + 2),
          ],
        ),
      ],
    );
  }
}

class _FlowerTile extends StatelessWidget {
  final WardrobeController w;
  final FlowerKind kind;
  final int count, level;
  const _FlowerTile({required this.w, required this.kind, required this.count, required this.level});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final open = count > 0;
    final on = w.wornFlower == kind;
    final name = open ? l.flowerName(kind) : l.levelN(level);
    final state = on ? l.wearing : (open ? (count > 1 ? l.bloomCount(count) : '') : l.locked);
    return Semantics(
      button: open,
      selected: on,
      label: state.isEmpty ? name : '$name, $state',
      excludeSemantics: true,
      child: Material(
        color: on ? ZeepColors.blueSoft : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: on ? ZeepColors.blue : const Color(0xFFE1E7EE), width: on ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: open ? () => w.chooseFlower(kind) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints.tightFor(width: 82).copyWith(minHeight: 100),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    // fill the tile so a short name doesn't pull the flower to the left
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: open ? 1 : 0.2,
                        child: SizedBox(width: 56, height: 56, child: CustomPaint(painter: _BloomPainter(kind))),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: open ? ZeepColors.text : ZeepColors.textSoft),
                        ),
                      ),
                    ],
                  ),
                ),
                if (count > 1)
                  Positioned(
                    top: 4,
                    right: 6,
                    child: Text(
                      l.bloomCount(count),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ZeepColors.mintDark),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BloomPainter extends CustomPainter {
  final FlowerKind kind;
  _BloomPainter(this.kind);

  @override
  void paint(Canvas canvas, Size size) {
    // centre the drawing itself (some kinds are taller above their middle),
    // and shrink only the ones that would not fit
    final b = bloomBounds(kind);
    final k = math.min(size.shortestSide / 21, math.min(size.width / b.width, size.height / b.height));
    drawBloom(canvas, kind, size.center(Offset.zero) - b.center * k, k);
  }

  @override
  bool shouldRepaint(covariant _BloomPainter old) => old.kind != kind;
}

/// A still Zeep sized so hats and friends fit inside the box (item tiles,
/// new-item card, summary card).
class ZeepThumbPainter extends CustomPainter {
  final Outfit outfit;
  final SproutGrowth growth;
  ZeepThumbPainter({this.outfit = Outfit.none, this.growth = SproutGrowth.none});

  static const _pose = Pose(
    breath: 0.3,
    armLift: 0.3,
    cheekPuff: 0.2,
    eyeSqueeze: 0,
    mouthOpen: 0,
    hold: 0,
    tint: tintInhale,
  );

  @override
  void paint(Canvas canvas, Size size) {
    // Zeep plus a friend spans ~250 x 230 design units
    final s = size.shortestSide / 175;
    final c = Offset(size.width / 2, size.height * 0.64);
    drawZeep(canvas, c, s, _pose, 0.95, c.dy + 64 * s, const [], reduceMotion: true, outfit: outfit, growth: growth);
  }

  @override
  bool shouldRepaint(covariant ZeepThumbPainter old) => old.outfit != outfit || old.growth.leaves != growth.leaves;
}
