// Zeep Community phase 1 (CS): preview the share card, pick one of three
// colours, then hand the picture to the phone's share sheet (LINE,
// Instagram, Facebook, Save image...). Opened from S.8, GR and T3.1.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../friends/characters.dart';
import '../l10n/strings.dart';
import '../share/share_card.dart';
import '../ui/widgets.dart';
import '../ui/zeep_colors.dart';

/// Hands a PNG to the system share sheet. [origin] is the button's rect:
/// iPad shows the sheet as a popover anchored there (required on iPad).
typedef ImageSharer = Future<void> Function(Uint8List png, String text, Rect? origin);

Future<void> sharePngWithSystem(Uint8List png, String text, Rect? origin) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(png, mimeType: 'image/png', name: 'zeep-breathe.png')],
      fileNameOverrides: const ['zeep-breathe.png'],
      text: text,
      sharePositionOrigin: origin,
    ),
  );
}

class ShareScreen extends StatefulWidget {
  final ShareAchievement achievement;
  final ImageSharer sharer;

  /// Who is on the card: the active character (1.7.0).
  final Character character;
  const ShareScreen({
    super.key,
    required this.achievement,
    this.sharer = sharePngWithSystem,
    this.character = Character.zeep,
  });

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final _cardKey = GlobalKey();
  ShareCardColor _theme = ShareCardColor.lavender;
  bool _busy = false;

  Future<void> _share(BuildContext buttonContext) async {
    if (_busy) return;
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize ? null : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    try {
      final boundary = _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      // 360 x 450 at 3x = 1080 x 1350, whatever size the preview is drawn at
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await widget.sharer(data!.buffer.asUint8List(), s.shareText(s.characterName(widget.character)), origin);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.shareFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: ZeepBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: s.back,
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.chevron_left_rounded, size: 32, color: ZeepColors.text),
                        ),
                        Expanded(
                          child: Text(
                            s.shareTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ZeepColors.text),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                      child: FittedBox(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: withAlpha(const Color(0xFF24304D), 0.14),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          // the clip is outside the boundary: the PNG keeps square corners
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: RepaintBoundary(
                              key: _cardKey,
                              child: ShareCard(
                                achievement: widget.achievement,
                                theme: _theme,
                                character: widget.character,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(s.cardColour, style: const TextStyle(fontSize: 14, color: ZeepColors.textSoft)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final t in ShareCardColor.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _Swatch(
                            theme: t,
                            label: s.cardThemeName(t),
                            selected: t == _theme,
                            onTap: () => setState(() => _theme = t),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    child: Builder(
                      builder: (buttonContext) => SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : () => _share(buttonContext),
                          icon: const Icon(Icons.ios_share_rounded),
                          label: Text(s.share, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          style: FilledButton.styleFrom(
                            backgroundColor: ZeepColors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ),
                    ),
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

class _Swatch extends StatelessWidget {
  final ShareCardColor theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({required this.theme, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: Tooltip(
      message: label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.swatch,
            border: Border.all(color: selected ? theme.accent : const Color(0xFFDCE3EC), width: selected ? 3 : 1.5),
          ),
          child: selected ? Icon(Icons.check_rounded, size: 22, color: theme.accent) : null,
        ),
      ),
    ),
  );
}
