// Text that wraps into lines of about equal length (like CSS text-wrap:
// balance), so a wide font or large text never leaves one word alone on the
// last line. Used for the short centred texts on cards and dialogs.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
      child: Text(text, style: style, textAlign: textAlign),
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

  double _width(double max) => balancedWidth(text, style, max, scaler, direction, hug: hug);

  BoxConstraints _childConstraints(BoxConstraints c) {
    if (!c.maxWidth.isFinite) return c.loosen();
    return BoxConstraints.tightFor(width: _width(c.maxWidth)).enforce(c.loosen());
  }

  // like Align(widthFactor: 1): as wide as the text, as tall as allowed
  Size _sizeFor(BoxConstraints c, Size child) =>
      c.constrain(Size(child.width, c.maxHeight.isFinite ? double.infinity : child.height));

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final c = child;
    if (c == null) return constraints.smallest;
    return _sizeFor(constraints, c.getDryLayout(_childConstraints(constraints)));
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(_childConstraints(constraints), parentUsesSize: true);
    size = _sizeFor(constraints, c.size);
    (c.parentData! as BoxParentData).offset = Offset(
      (size.width - c.size.width) / 2,
      (size.height - c.size.height) / 2,
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      child?.getMinIntrinsicHeight(width.isFinite ? _width(width) : width) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      child?.getMaxIntrinsicHeight(width.isFinite ? _width(width) : width) ?? 0;
}

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
  var lo = maxWidth / lines * 0.5, hi = maxWidth;
  for (var i = 0; i < 14 && hi - lo > 0.5; i++) {
    final mid = (lo + hi) / 2;
    if (linesAt(mid) > lines) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  tp.dispose();
  // a hair of slack so rounding never pushes a word onto a new line
  return (hi + 1).clamp(0.0, maxWidth);
}
