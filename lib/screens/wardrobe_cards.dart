// Small wardrobe pieces used on other screens: the hanger button (T1.9), the
// growth strip on the finish cards (S.9), the new-item card (N) and the
// one-time summary card for people who used the app before the wardrobe.

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n/strings.dart';
import '../ui/zeep_colors.dart';
import '../wardrobe/flowers.dart';
import '../wardrobe/outfits.dart';
import '../wardrobe/wardrobe_controller.dart';
import 'bloom_card.dart';
import 'wardrobe_screen.dart';

/// T1.9: opens the wardrobe; a red dot while something new is unseen.
class HangerButton extends StatelessWidget {
  final AppController app;
  const HangerButton({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    final dot = app.wardrobe.unseen.isNotEmpty;
    return Semantics(
      label: dot ? '${l.openWardrobe}, ${l.newItem}' : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 1,
            shadowColor: withAlpha(Colors.black, 0.2),
            child: IconButton(
              tooltip: l.openWardrobe,
              onPressed: () => openWardrobe(context, app),
              icon: const Icon(Icons.checkroom_rounded, color: ZeepColors.text, size: 22),
            ),
          ),
          if (dot)
            Positioned(
              right: 2,
              top: 2,
              child: IgnorePointer(
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5484D),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// S.9: what the session just grew. Nothing for a session that did not count.
class GrowthStrip extends StatelessWidget {
  final AppController app;
  final GrowthEvent? event;
  const GrowthStrip({super.key, required this.app, required this.event});

  @override
  Widget build(BuildContext context) {
    final e = event;
    if (e == null || (!e.grew && !e.dailyLimit)) return const SizedBox.shrink();
    final l = S.of(context);
    final g = e.after;
    final Color bg, fg;
    final String title, detail;
    if (e.bloomed) {
      bg = const Color(0xFFFFF1D2);
      fg = const Color(0xFF6B4500);
      title = l.bloomedTitle;
      detail = l.bloomedDetail(g.level, l.flowerName(e.newFlower!));
    } else if (e.grew) {
      bg = const Color(0xFFDDF3EC);
      fg = ZeepColors.mintDark;
      title = l.leafGrew;
      detail = '${l.levelLeaves(g.level, g.leaves, g.leavesNeeded)}\n${l.stepsToBloom(g.stepsToBloom)}';
    } else {
      bg = const Color(0xFFF1F3F6);
      fg = ZeepColors.textSoft;
      title = '';
      detail = l.dailyLimit;
    }
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(e.bloomed ? Icons.local_florist_rounded : Icons.eco_rounded, size: 18, color: fg),
                if (title.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.35, color: fg),
            ),
            if (e.bloomed)
              TextButton(
                onPressed: () => openWardrobe(context, app, tab: 1),
                style: TextButton.styleFrom(foregroundColor: fg, visualDensity: VisualDensity.compact),
                child: Text(l.seeGarden, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }
}

/// N: one card per newly unlocked item. "Try it on" wears it and opens the
/// wardrobe; "Later" leaves the red dot on the hanger button.
Future<void> showNewItemCards(BuildContext context, AppController app, List<OutfitItem> items) async {
  for (final item in items) {
    if (!context.mounted) return;
    final l = S.of(context);
    final tryOn = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ZeepDialog(
        outfit: Outfit.of([item]),
        title: l.newItemTitle,
        body: l.newItemBody(l.itemName(item), item.unlockDays),
        primary: l.tryItOn,
        secondary: l.later,
      ),
    );
    if (tryOn == true && context.mounted) {
      app.wardrobe.wear(item);
      openWardrobe(context, app);
      return;
    }
  }
}

/// Once, for people who practised before the wardrobe existed.
Future<void> showSummaryCard(BuildContext context, AppController app) async {
  final w = app.wardrobe;
  if (!w.summaryPending) return;
  final l = S.of(context);
  final open = await showDialog<bool>(
    context: context,
    builder: (ctx) => _ZeepDialog(
      growth: w.growth,
      title: l.summaryTitle,
      body: l.summaryBody(w.garden.level, w.unlocked.length),
      primary: l.openWardrobe,
      secondary: l.later,
    ),
  );
  w.dismissSummary();
  if (open == true && context.mounted) openWardrobe(context, app);
}

class _ZeepDialog extends StatelessWidget {
  final Outfit outfit;
  final SproutGrowth growth;
  final String title, body, primary, secondary;
  const _ZeepDialog({
    this.outfit = Outfit.none,
    this.growth = SproutGrowth.none,
    required this.title,
    required this.body,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: SizedBox(
                width: 150,
                height: 130,
                child: CustomPaint(
                  painter: ZeepThumbPainter(outfit: outfit, growth: growth),
                ),
              ),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: ZeepColors.text),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.4, color: ZeepColors.textSoft),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: FilledButton.styleFrom(
                      backgroundColor: ZeepColors.btnBg,
                      foregroundColor: ZeepColors.text,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text(secondary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: ZeepColors.mint,
                      foregroundColor: ZeepColors.mintDark,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text(primary, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// After "Done" on the finish card or the game results: card L if a flower
/// bloomed, then card N for each new item. Pass the navigator's context (the
/// finish card itself is gone by then).
Future<void> showGrowthCards(BuildContext context, AppController app) async {
  final bloom = app.wardrobe.takePendingBloom();
  final items = app.wardrobe.takePendingNewItems();
  if (bloom != null) {
    final choice = await showBloomCard(context, app, bloom);
    if (!context.mounted) return;
    if (choice == BloomChoice.garden) {
      // the garden first; new items still get their card when it closes
      await openWardrobe(context, app, tab: 1);
      if (!context.mounted) return;
    }
  }
  if (items.isNotEmpty && context.mounted) await showNewItemCards(context, app, items);
}
