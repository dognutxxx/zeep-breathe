// Text that wraps into lines of about equal length (like CSS text-wrap:
// balance), so a wide font or large text never leaves one word alone on the
// last line. Used for the short centred texts on cards and dialogs.
//
// A word wider than the whole line (e.g. "Wongwong" in bold at 2x text on a
// 320 px screen) is never broken inside: the text is drawn a little smaller
// instead, down to [minFit] (QA 1.9.0 #7). Screen readers get the text
// without the invisible word joiners that keep Thai words whole (QA 1.9.0 #8).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../l10n/strings.dart' show plainText;

/// The smallest a text is drawn to keep its widest word on one line, for
/// [scaler]: down to the user's normal (x1.0) text size with large text (a
/// 2x name never ends up smaller than at 1x), and to 0.8 at most settings.
double minFit(TextScaler scaler) => math.min(0.8, 16 / scaler.scale(16));

class BalancedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  /// Shrink to the text on one line too (a badge), instead of taking the
  /// full width.
  final bool hug;
  const BalancedText(this.text, {super.key, this.style, this.textAlign = TextAlign.center, this.hug = false});

  @override
  Widget build(BuildContext context) {
    // A render box rather than a LayoutBuilder, so it also works inside an
    // IntrinsicHeight (the Breathe tab's greeting bubble, QA r2 #2).
    return _Balanced(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
      scaler: MediaQuery.textScalerOf(context),
      direction: Directionality.of(context),
      hug: hug,
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        semanticsLabel: text.contains('\u2060') || text.contains('\u200B') ? plainText(text) : null,
      ),
    );
  }
}

class _Balanced extends SingleChildRenderObjectWidget {
  final String text;
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;
  final bool hug;
  const _Balanced({
    required this.text,
    required this.style,
    required this.scaler,
    required this.direction,
    required this.hug,
    required super.child,
  });

  @override
  _RenderBalanced createRenderObject(BuildContext context) => _RenderBalanced(text, style, scaler, direction, hug);

  @override
  void updateRenderObject(BuildContext context, _RenderBalanced r) {
    if (r.text == text && r.style == style && r.scaler == scaler && r.direction == direction && r.hug == hug) return;
    r
      ..text = text
      ..style = style
      ..scaler = scaler
      ..direction = direction
      ..hug = hug
      ..markNeedsLayout();
  }
}

/// Lays the text out at its balanced width (for the width it is given) and
/// centres it, as `Align(widthFactor: 1, child: SizedBox(width: ...))` did.
class _RenderBalanced extends RenderShiftedBox {
  String text;
  TextStyle style;
  TextScaler scaler;
  TextDirection direction;
  bool hug;
  _RenderBalanced(this.text, this.style, this.scaler, this.direction, this.hug) : super(null);

  /// How much smaller the text is drawn at [max] width: 1, or less when its
  /// widest word does not fit (never below [minFit]).
  double _fit(double max) => max.isFinite ? fitScale(text, style, max, scaler, direction) : 1;

  /// The layout width for the child (before the [_fit] scale).
  double _width(double max) {
    final f = _fit(max);
    return balancedWidth(text, style, max / f, scaler, direction, hug: hug);
  }

  BoxConstraints _childConstraints(BoxConstraints c) {
    if (!c.maxWidth.isFinite) return c.loosen();
    final f = _fit(c.maxWidth);
    final loose = c.loosen();
    return BoxConstraints.tightFor(width: _width(c.maxWidth))
        .enforce(BoxConstraints(maxWidth: loose.maxWidth / f, maxHeight: loose.maxHeight / f));
  }

  // like Align(widthFactor: 1): as wide as the (scaled) text, as tall as allowed
  Size _sizeFor(BoxConstraints c, Size child, double f) =>
      c.constrain(Size(child.width * f, c.maxHeight.isFinite ? double.infinity : child.height * f));

  double _scale = 1;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final c = child;
    if (c == null) return constraints.smallest;
    final f = constraints.maxWidth.isFinite ? _fit(constraints.maxWidth) : 1.0;
    return _sizeFor(constraints, c.getDryLayout(_childConstraints(constraints)), f);
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    _scale = constraints.maxWidth.isFinite ? _fit(constraints.maxWidth) : 1.0;
    c.layout(_childConstraints(constraints), parentUsesSize: true);
    size = _sizeFor(constraints, c.size, _scale);
    (c.parentData! as BoxParentData).offset = Offset(
      (size.width - c.size.width * _scale) / 2,
      (size.height - c.size.height * _scale) / 2,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null) return;
    if (_scale == 1) return super.paint(context, offset);
    final at = offset + (c.parentData! as BoxParentData).offset;
    context.pushTransform(
      needsCompositing,
      at,
      Matrix4.diagonal3Values(_scale, _scale, 1),
      (context, o) => context.paintChild(c, o),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    super.applyPaintTransform(child, transform);
    if (_scale != 1) transform.scaleByDouble(_scale, _scale, 1, 1);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    final at = (c.parentData! as BoxParentData).offset;
    return result.addWithPaintTransform(
      transform: Matrix4.translationValues(at.dx, at.dy, 0)..scaleByDouble(_scale, _scale, 1, 1),
      position: position,
      hitTest: (result, p) => c.hitTest(result, position: p),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) => width.isFinite
      ? (child?.getMinIntrinsicHeight(_width(width)) ?? 0) * _fit(width)
      : child?.getMinIntrinsicHeight(width) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) => width.isFinite
      ? (child?.getMaxIntrinsicHeight(_width(width)) ?? 0) * _fit(width)
      : child?.getMaxIntrinsicHeight(width) ?? 0;
}

/// Whether [tp] (laid out from [text]) breaks a line inside a word: between
/// two Latin letters ("Wongwon / g"), or next to a word joiner (U+2060) that
/// holds Thai words together. The engine does that only when a word is wider
/// than the line.
bool splitsWord(TextPainter tp, String text) {
  if (tp.computeLineMetrics().length < 2) return false;
  bool latin(int c) => (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);
  int line(int at) => tp.getLineBoundary(TextPosition(offset: at)).start;
  for (var i = 1; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c == 0x2060 && i + 1 < text.length) {
      if (line(i - 1) != line(i + 1)) return true;
    } else if (latin(text.codeUnitAt(i - 1)) && latin(c)) {
      if (line(i - 1) != line(i)) return true;
    }
  }
  return false;
}

/// How much smaller [text] must be drawn so no word is broken inside at
/// [maxWidth]: 1 when nothing breaks, never below [minFit]. Cached like
/// [balancedWidth].
double fitScale(String text, TextStyle style, double maxWidth, TextScaler scaler, TextDirection dir) {
  if (!maxWidth.isFinite || maxWidth <= 0) return 1;
  final key = (text, style, maxWidth, scaler, dir);
  final hit = _fitCache[key];
  if (hit != null) return hit;
  if (_fitCache.length >= _cacheMax) _fitCache.clear();
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: dir,
    textScaler: scaler,
  );
  bool splitsAt(double f) {
    tp.layout(maxWidth: maxWidth / f);
    return splitsWord(tp, text);
  }

  var f = 1.0;
  if (splitsAt(1)) {
    // the largest scale that keeps every word whole (a few steps are enough)
    var lo = minFit(scaler), hi = 1.0;
    if (splitsAt(lo)) {
      f = lo;
    } else {
      for (var i = 0; i < 8; i++) {
        final mid = (lo + hi) / 2;
        if (splitsAt(mid)) {
          hi = mid;
        } else {
          lo = mid;
        }
      }
      f = lo;
    }
  }
  tp.dispose();
  return _fitCache[key] = f;
}

final _fitCache = <(String, TextStyle, double, TextScaler, TextDirection), double>{};

/// Widths already worked out, by (text, style, maxWidth, scaler, direction,
/// hug). BalancedText is often rebuilt every frame (T1, the garden tab and
/// the friends sheet are under the app's ticker), and each width costs up to
/// ~15 text layouts (Pim r2 #1). Small: cleared when it gets big.
final _cache = <(String, TextStyle, double, TextScaler, TextDirection, bool), double>{};
const _cacheMax = 256;

/// How many widths were worked out (not taken from the cache), for tests.
@visibleForTesting
int balancedLayouts = 0;

/// The narrowest width (up to [maxWidth]) that keeps the same number of lines
/// as at [maxWidth]: the lines then share the words evenly. With [hug], one
/// line is as wide as its text rather than [maxWidth]. Cached.
double balancedWidth(
  String text,
  TextStyle style,
  double maxWidth,
  TextScaler scaler,
  TextDirection dir, {
  bool hug = false,
}) {
  if (!maxWidth.isFinite || maxWidth <= 0) return maxWidth;
  final key = (text, style, maxWidth, scaler, dir, hug);
  final hit = _cache[key];
  if (hit != null) return hit;
  if (_cache.length >= _cacheMax) _cache.clear();
  return _cache[key] = _balancedWidth(text, style, maxWidth, scaler, dir, hug);
}

double _balancedWidth(String text, TextStyle style, double maxWidth, TextScaler scaler, TextDirection dir, bool hug) {
  balancedLayouts++;
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: dir,
    textScaler: scaler,
  );
  int linesAt(double w) {
    tp.layout(maxWidth: w);
    return tp.computeLineMetrics().length;
  }

  final lines = linesAt(maxWidth);
  if (lines <= 1) {
    final one = tp.width;
    tp.dispose();
    // the same hair of slack as below, so the line never wraps
    return hug ? math.min(one + 1, maxWidth) : maxWidth;
  }
  // never so narrow that a word is broken inside (a long word, or Thai words
  // held together by word joiners): the engine does that without adding a
  // line (QA 1.9.0 #4, #7)
  if (splitsWord(tp, text)) {
    tp.dispose();
    return maxWidth;
  }
  var lo = maxWidth / lines * 0.5, hi = maxWidth;
  for (var i = 0; i < 14 && hi - lo > 0.5; i++) {
    final mid = (lo + hi) / 2;
    if (linesAt(mid) > lines || splitsWord(tp, text)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  tp.dispose();
  // a hair of slack so rounding never pushes a word onto a new line
  return (hi + 1).clamp(0.0, maxWidth);
}
