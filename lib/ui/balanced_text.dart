// Text that wraps into lines of about equal length (like CSS text-wrap:
// balance), so a wide font or large text never leaves one word alone on the
// last line. Used for the short centred texts on cards and dialogs.

import 'package:flutter/material.dart';

class BalancedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  const BalancedText(this.text, {super.key, this.style, this.textAlign = TextAlign.center});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = balancedWidth(
          text,
          DefaultTextStyle.of(context).style.merge(style),
          box.maxWidth,
          MediaQuery.textScalerOf(context),
          Directionality.of(context),
        );
        return Align(
          widthFactor: 1,
          child: SizedBox(
            width: width,
            child: Text(text, style: style, textAlign: textAlign),
          ),
        );
      },
    );
  }
}

/// The narrowest width (up to [maxWidth]) that keeps the same number of lines
/// as at [maxWidth]: the lines then share the words evenly.
double balancedWidth(String text, TextStyle style, double maxWidth, TextScaler scaler, TextDirection dir) {
  if (!maxWidth.isFinite || maxWidth <= 0) return maxWidth;
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
    tp.dispose();
    return maxWidth;
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
